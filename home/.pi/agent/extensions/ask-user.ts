/**
 * ask_user: let the agent ask the user one or more questions.
 *
 * - Single-select, multi-select, and free-text questions.
 * - "Type your own answer" choice on option questions.
 * - Optional note to the agent on the Submit tab.
 * - TUI: custom dialog. RPC: select/input fallback. Print/JSON: error result.
 */

import type { ExtensionAPI, ExtensionUIContext } from "@earendil-works/pi-coding-agent";
import { Editor, type EditorTheme, Key, matchesKey, Text, visibleWidth, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { type Static, Type } from "typebox";

// ---------- Schema ----------

const OptionSchema = Type.Object({
	label: Type.String({ description: "Short answer text shown to the user and returned to you" }),
	description: Type.Optional(Type.String({ description: "Optional detail shown below the label" })),
});

const QuestionSchema = Type.Object({
	id: Type.String({ description: "Short unique key for this question, e.g. 'scope'. Also the tab label." }),
	prompt: Type.String({ description: "The full question" }),
	options: Type.Optional(
		Type.Array(OptionSchema, {
			description: "Choices. Leave out or empty for a free-text question.",
		}),
	),
	multiSelect: Type.Optional(Type.Boolean({ description: "Let the user pick more than one option (default false)" })),
	allowOther: Type.Optional(
		Type.Boolean({ description: "Add a 'Type your own answer' choice to option questions (default true)" }),
	),
});

const Params = Type.Object({
	questions: Type.Array(QuestionSchema, { minItems: 1, maxItems: 4, description: "1 to 4 questions" }),
});

const AnswerSchema = Type.Object({
	id: Type.String(),
	question: Type.String(),
	selected: Type.Array(Type.String()),
	custom: Type.Union([Type.String(), Type.Null()]),
});

const OutputSchema = Type.Object({
	cancelled: Type.Boolean(),
	answers: Type.Array(AnswerSchema),
	note: Type.Union([Type.String(), Type.Null()]),
});

type QuestionInput = Static<typeof QuestionSchema>;
type Answer = Static<typeof AnswerSchema>;
type Output = Static<typeof OutputSchema>;

interface Question {
	id: string;
	prompt: string;
	options: { label: string; description?: string }[];
	multiSelect: boolean;
	allowOther: boolean;
	freeText: boolean;
}

interface Details extends Output {
	questions: { id: string; prompt: string }[];
	error?: string;
}

// ---------- Helpers ----------

function normalize(q: QuestionInput): Question {
	const options = q.options ?? [];
	const freeText = options.length === 0;
	return {
		id: q.id,
		prompt: q.prompt,
		options,
		multiSelect: !freeText && q.multiSelect === true,
		allowOther: !freeText && q.allowOther !== false,
		freeText,
	};
}

function formatAnswer(a: Answer): string {
	const parts = a.selected.map((s) => `"${s}"`);
	if (a.custom !== null) parts.push(`wrote "${a.custom}"`);
	return parts.join(", ");
}

function buildResult(questions: Question[], out: Output) {
	const details: Details = { ...out, questions: questions.map((q) => ({ id: q.id, prompt: q.prompt })) };
	if (out.cancelled) {
		return {
			content: [
				{
					type: "text" as const,
					text: "The user cancelled the questions. Do not guess the answers. Stop and wait for the user's instructions.",
				},
			],
			details,
			structuredContent: out,
			terminate: true,
		};
	}
	const lines = ["The user answered:"];
	for (const a of out.answers) lines.push(`- ${a.id} (${a.question}): ${formatAnswer(a)}`);
	if (out.note) lines.push("", `Note from the user: ${out.note}`);
	return { content: [{ type: "text" as const, text: lines.join("\n") }], details, structuredContent: out };
}

function errorResult(message: string, questions: Question[] = []) {
	const out: Output = { cancelled: true, answers: [], note: null };
	const details: Details = { ...out, questions: questions.map((q) => ({ id: q.id, prompt: q.prompt })), error: message };
	return { content: [{ type: "text" as const, text: message }], details, structuredContent: out, isError: true };
}

// ---------- RPC fallback ----------

const OTHER_LABEL = "Type your own answer…";
const DONE_LABEL = "✓ Done";

async function askWithDialogs(ui: ExtensionUIContext, questions: Question[], signal?: AbortSignal): Promise<Output> {
	const cancelled: Output = { cancelled: true, answers: [], note: null };
	const answers: Answer[] = [];
	const opts = { signal };
	for (const q of questions) {
		const title = questions.length > 1 ? `[${q.id}] ${q.prompt}` : q.prompt;
		if (q.freeText) {
			const text = (await ui.input(title, undefined, opts))?.trim();
			if (!text) return cancelled;
			answers.push({ id: q.id, question: q.prompt, selected: [], custom: text });
			continue;
		}
		const labels = q.options.map((o) => o.label);
		if (!q.multiSelect) {
			const choice = await ui.select(title, q.allowOther ? [...labels, OTHER_LABEL] : labels, opts);
			if (choice === undefined) return cancelled;
			if (choice === OTHER_LABEL) {
				const text = (await ui.input(title, undefined, opts))?.trim();
				if (!text) return cancelled;
				answers.push({ id: q.id, question: q.prompt, selected: [], custom: text });
			} else {
				answers.push({ id: q.id, question: q.prompt, selected: [choice], custom: null });
			}
			continue;
		}
		const checked = new Set<string>();
		let custom: string | null = null;
		for (;;) {
			const items = labels.map((l) => `${checked.has(l) ? "[x]" : "[ ]"} ${l}`);
			if (q.allowOther) items.push(custom ? `[x] ${OTHER_LABEL} (${custom})` : `[ ] ${OTHER_LABEL}`);
			items.push(DONE_LABEL);
			const choice = await ui.select(title, items, opts);
			if (choice === undefined) return cancelled;
			if (choice === DONE_LABEL) {
				if (checked.size || custom) break;
				continue;
			}
			const idx = items.indexOf(choice);
			if (idx < labels.length) {
				const l = labels[idx];
				if (checked.has(l)) checked.delete(l);
				else checked.add(l);
			} else {
				custom = (await ui.input(title, custom ?? undefined, opts))?.trim() || null;
			}
		}
		answers.push({ id: q.id, question: q.prompt, selected: labels.filter((l) => checked.has(l)), custom });
	}
	return { cancelled: false, answers, note: null };
}

// ---------- TUI dialog ----------

interface QState {
	cursor: number;
	checked: Set<number>;
	custom: string | null;
}

type EditTarget = { kind: "other"; q: number } | { kind: "free"; q: number } | { kind: "note" } | null;

function askWithTui(ui: ExtensionUIContext, questions: Question[], signal?: AbortSignal): Promise<Output | null> {
	return ui.custom<Output | null>((tui, theme, _kb, done) => {
		const states: QState[] = questions.map(() => ({ cursor: 0, checked: new Set(), custom: null }));
		const submitTab = questions.length;
		const fastPath = questions.length === 1 && !questions[0].multiSelect;
		let tab = 0;
		let submitCursor = 0; // 0 = Submit, 1 = Note
		let note: string | null = null;
		let edit: EditTarget = null;
		let warning: string | null = null;
		let finished = false;
		let cached: string[] | undefined;

		const editorTheme: EditorTheme = {
			borderColor: (s) => theme.fg("accent", s),
			selectList: {
				selectedPrefix: (t) => theme.fg("accent", t),
				selectedText: (t) => theme.fg("accent", t),
				description: (t) => theme.fg("muted", t),
				scrollInfo: (t) => theme.fg("dim", t),
				noMatch: (t) => theme.fg("warning", t),
			},
		};
		const editor = new Editor(tui, editorTheme);

		const onAbort = () => finish(null);
		signal?.addEventListener("abort", onAbort, { once: true });

		function finish(result: Output | null) {
			if (finished) return;
			finished = true;
			signal?.removeEventListener("abort", onAbort);
			done(result);
		}

		function refresh() {
			cached = undefined;
			tui.requestRender();
		}

		function isAnswered(i: number): boolean {
			const s = states[i];
			return s.checked.size > 0 || s.custom !== null;
		}

		function answers(): Answer[] {
			return questions.map((q, i) => ({
				id: q.id,
				question: q.prompt,
				selected: q.options.filter((_, j) => states[i].checked.has(j)).map((o) => o.label),
				custom: states[i].custom,
			}));
		}

		function submit() {
			const missing = questions.filter((_, i) => !isAnswered(i)).map((q) => q.id);
			if (missing.length) {
				warning = `Answer these first: ${missing.join(", ")}`;
				refresh();
				return;
			}
			finish({ cancelled: false, answers: answers(), note });
		}

		function rowCount(q: Question): number {
			return q.options.length + (q.allowOther ? 1 : 0);
		}

		function saveFreeDraft() {
			if (edit?.kind === "free") states[edit.q].custom = editor.getText().trim() || null;
		}

		function goTab(t: number) {
			saveFreeDraft();
			tab = (t + submitTab + 1) % (submitTab + 1);
			warning = null;
			edit = null;
			if (tab < submitTab && questions[tab].freeText) {
				edit = { kind: "free", q: tab };
				editor.setText(states[tab].custom ?? "");
			}
			refresh();
		}

		function advance() {
			if (fastPath) {
				submit();
				return;
			}
			for (let i = tab + 1; i < submitTab; i++) {
				if (!isAnswered(i)) return goTab(i);
			}
			for (let i = 0; i < tab; i++) {
				if (!isAnswered(i)) return goTab(i);
			}
			goTab(submitTab);
		}

		function openEditor(target: Exclude<EditTarget, null>, text: string) {
			edit = target;
			editor.setText(text);
			refresh();
		}

		editor.onSubmit = (value) => {
			const text = value.trim() || null;
			const target = edit;
			if (!target) return;
			editor.setText("");
			if (target.kind === "note") {
				note = text;
				edit = null;
				refresh();
				return;
			}
			const s = states[target.q];
			const q = questions[target.q];
			edit = null;
			if (target.kind === "free") {
				s.custom = text;
				if (text) advance();
				else openEditor({ kind: "free", q: target.q }, "");
				return;
			}
			// "other" choice
			s.custom = text;
			if (!q.multiSelect && text) {
				s.checked.clear();
				advance();
				return;
			}
			refresh();
		}

		function activateRow(i: number, toggleOnly: boolean) {
			const q = questions[tab];
			const s = states[tab];
			s.cursor = i;
			warning = null;
			if (i >= q.options.length) {
				openEditor({ kind: "other", q: tab }, s.custom ?? "");
				return;
			}
			if (q.multiSelect) {
				if (toggleOnly) {
					if (s.checked.has(i)) s.checked.delete(i);
					else s.checked.add(i);
					refresh();
					return;
				}
				if (!isAnswered(tab)) s.checked.add(i);
				advance();
				return;
			}
			s.checked = new Set([i]);
			s.custom = null;
			advance();
		}

		function handleInput(data: string) {
			// Text editing
			if (edit) {
				if (edit.kind === "free") {
					if (matchesKey(data, Key.tab)) return goTab(tab + 1);
					if (matchesKey(data, Key.shift("tab"))) return goTab(tab - 1);
					if (matchesKey(data, Key.escape)) return finish(null);
				} else if (matchesKey(data, Key.escape)) {
					edit = null;
					editor.setText("");
					refresh();
					return;
				}
				// Plain Enter always submits a dialog field, even when the user binds
				// tui.input.submit to another key. Ctrl+J ("\n") stays a new line.
				if (data !== "\n" && matchesKey(data, Key.enter)) {
					editor.onSubmit?.(editor.getText());
					return;
				}
				editor.handleInput(data);
				refresh();
				return;
			}

			if (matchesKey(data, Key.escape)) return finish(null);
			if (matchesKey(data, Key.tab) || matchesKey(data, Key.right)) return goTab(tab + 1);
			if (matchesKey(data, Key.shift("tab")) || matchesKey(data, Key.left)) return goTab(tab - 1);

			// Submit tab
			if (tab === submitTab) {
				if (matchesKey(data, Key.up) || matchesKey(data, Key.down)) {
					submitCursor = 1 - submitCursor;
					refresh();
				} else if (matchesKey(data, Key.enter)) {
					if (submitCursor === 0) submit();
					else openEditor({ kind: "note" }, note ?? "");
				}
				return;
			}

			// Option list
			const q = questions[tab];
			const s = states[tab];
			const rows = rowCount(q);
			if (matchesKey(data, Key.up)) {
				s.cursor = (s.cursor - 1 + rows) % rows;
				refresh();
				return;
			}
			if (matchesKey(data, Key.down)) {
				s.cursor = (s.cursor + 1) % rows;
				refresh();
				return;
			}
			if (matchesKey(data, Key.space)) return activateRow(s.cursor, q.multiSelect);
			if (matchesKey(data, Key.enter)) return activateRow(s.cursor, false);
			if (/^[1-9]$/.test(data)) {
				const i = Number(data) - 1;
				if (i < rows) activateRow(i, q.multiSelect);
			}
		}

		function render(width: number): string[] {
			if (cached) return cached;
			const w = Math.max(1, width);
			const lines: string[] = [];
			const add = (prefix: string, text: string) => {
				const pw = visibleWidth(prefix);
				if (pw >= w) {
					lines.push(...wrapTextWithAnsi(prefix + text, w));
					return;
				}
				const pad = " ".repeat(pw);
				wrapTextWithAnsi(text, w - pw).forEach((l, i) => lines.push((i === 0 ? prefix : pad) + l));
			};
			const editorLines = () => {
				for (const l of editor.render(Math.max(1, w - 2))) lines.push(` ${l}`);
			};

			lines.push(theme.fg("accent", "─".repeat(w)));

			// Tab bar
			const tabs = questions.map((q, i) => {
				const label = ` ${isAnswered(i) ? "■" : "□"} ${q.id} `;
				if (i === tab) return theme.bg("selectedBg", theme.fg("text", label));
				return theme.fg(isAnswered(i) ? "success" : "muted", label);
			});
			const submitLabel = " ✓ Submit ";
			tabs.push(
				tab === submitTab
					? theme.bg("selectedBg", theme.fg("text", submitLabel))
					: theme.fg(questions.every((_, i) => isAnswered(i)) ? "success" : "dim", submitLabel),
			);
			add(" ", tabs.join(" "));
			lines.push("");

			let help: string;
			if (tab === submitTab) {
				add(" ", theme.fg("accent", theme.bold("Review your answers")));
				lines.push("");
				for (const a of answers()) {
					const value = a.selected.length || a.custom ? formatAnswer(a) : theme.fg("warning", "(no answer)");
					add(" ", `${theme.fg("muted", `${a.id}: `)}${theme.fg("text", value)}`);
				}
				lines.push("");
				const row = (i: number, text: string) =>
					add(i === submitCursor && edit === null ? theme.fg("accent", "> ") : "  ", theme.fg(i === submitCursor ? "accent" : "text", text));
				row(0, "Submit answers");
				row(1, note ? `Edit note for the agent: ${note}` : "Add a note for the agent (optional)");
				if (edit?.kind === "note") {
					lines.push("");
					add(" ", theme.fg("muted", "Note for the agent:"));
					editorLines();
					help = "Enter save • Shift+Enter new line • Esc back";
				} else {
					help = "↑↓ move • Enter choose • Tab/←→ switch question • Esc cancel";
				}
				if (warning) {
					lines.push("");
					add(" ", theme.fg("warning", warning));
				}
			} else {
				const q = questions[tab];
				const s = states[tab];
				add(" ", theme.fg("text", theme.bold(q.prompt)));
				if (q.multiSelect) add(" ", theme.fg("dim", "(pick one or more)"));
				lines.push("");
				if (q.freeText) {
					editorLines();
					help = "Enter submit • Shift+Enter new line • Tab switch question • Esc cancel";
				} else {
					const rows = rowCount(q);
					for (let i = 0; i < rows; i++) {
						const isOther = i >= q.options.length;
						const selected = i === s.cursor;
						const on = isOther ? s.custom !== null : s.checked.has(i);
						const mark = q.multiSelect ? (on ? "[x] " : "[ ] ") : on ? "● " : "";
						const label = isOther ? (s.custom ? `Your answer: ${s.custom}` : OTHER_LABEL) : q.options[i].label;
						const prefix = selected ? theme.fg("accent", "> ") : "  ";
						add(prefix, theme.fg(selected ? "accent" : on ? "success" : "text", `${i + 1}. ${mark}${label}`));
						const desc = isOther ? undefined : q.options[i].description;
						if (desc) add("     ", theme.fg("muted", desc));
					}
					if (edit?.kind === "other") {
						lines.push("");
						add(" ", theme.fg("muted", "Your answer:"));
						editorLines();
						help = "Enter save • Shift+Enter new line • Esc back";
					} else if (q.multiSelect) {
						help = "↑↓ move • Space/1-9 toggle • Enter done • Tab/←→ switch • Esc cancel";
					} else {
						help = `↑↓ move • Enter/1-9 pick • ${fastPath ? "→ add note" : "Tab/←→ switch"} • Esc cancel`;
					}
				}
			}

			lines.push("");
			add(" ", theme.fg("dim", help));
			lines.push(theme.fg("accent", "─".repeat(w)));
			cached = lines;
			return lines;
		}

		// Start on a free-text question with the editor open.
		goTab(0);

		return {
			render,
			handleInput,
			invalidate: () => {
				cached = undefined;
			},
			get focused() {
				return editor.focused;
			},
			set focused(value: boolean) {
				editor.focused = value;
			},
			dispose: () => {
				signal?.removeEventListener("abort", onAbort);
			},
		};
	});
}

// ---------- Extension ----------

export default function askUser(pi: ExtensionAPI) {
	pi.registerTool({
		name: "ask_user",
		label: "Ask user",
		description:
			"Ask the user 1 to 4 questions and wait for the answers. Each question can be single-select, multi-select (multiSelect: true), or free text (no options). Option questions also let the user type their own answer. The user can add a note.",
		promptSnippet: "Ask the user clarifying questions with options and wait for the answers",
		promptGuidelines: [
			"Use ask_user only when the answer changes what you do and you cannot find it out yourself (from files, docs, or commands).",
			"Put related questions in one ask_user call instead of several calls one after another.",
			"Give concrete, short options in ask_user and put the option you recommend first, with a description that says why.",
			"If the user cancels ask_user, do not guess the answers. Stop and wait for the user.",
		],
		parameters: Params,
		outputSchema: OutputSchema,
		exposure: "model-only",
		executionMode: "sequential",

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const questions = params.questions.map(normalize);
			if (questions.length === 0) return errorResult("Error: give at least one question.");
			const ids = new Set(questions.map((q) => q.id));
			if (ids.size !== questions.length) return errorResult("Error: each question needs a unique id.", questions);
			if (signal?.aborted) return buildResult(questions, { cancelled: true, answers: [], note: null });

			let out: Output | null;
			if (ctx.mode === "tui") {
				out = await askWithTui(ctx.ui, questions, signal);
			} else if (ctx.hasUI) {
				out = await askWithDialogs(ctx.ui, questions, signal);
			} else {
				return errorResult(
					"Error: no user is present (non-interactive mode). Do not wait for answers; make a reasonable choice and say which assumptions you made.",
					questions,
				);
			}
			return buildResult(questions, out ?? { cancelled: true, answers: [], note: null });
		},

		renderCall(args, theme) {
			const qs = Array.isArray(args.questions) ? args.questions : [];
			let text = theme.fg("toolTitle", theme.bold("ask_user"));
			for (const q of qs) {
				if (!q) continue;
				const opts = Array.isArray(q.options) ? q.options.map((o) => o?.label).filter(Boolean) : [];
				text += `\n${theme.fg("accent", `${q.id ?? "?"}: `)}${theme.fg("muted", q.prompt ?? "")}`;
				if (opts.length) text += theme.fg("dim", `  [${opts.join(" / ")}${q.multiSelect ? ", multi" : ""}]`);
			}
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme) {
			const d = result.details as Details | undefined;
			if (!d) {
				const c = result.content[0];
				return new Text(c?.type === "text" ? c.text : "", 0, 0);
			}
			if (d.error) return new Text(theme.fg("error", d.error), 0, 0);
			if (d.cancelled) return new Text(theme.fg("warning", "Cancelled by user"), 0, 0);
			const lines = d.answers.map(
				(a) => `${theme.fg("success", "✓ ")}${theme.fg("accent", `${a.id}: `)}${theme.fg("text", formatAnswer(a))}`,
			);
			if (d.note) lines.push(`${theme.fg("muted", "Note: ")}${d.note}`);
			return new Text(lines.join("\n"), 0, 0);
		},
	});
}
