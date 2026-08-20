import { basename } from "node:path";
import type { ExtensionAPI, ExtensionContext, InputEvent } from "@earendil-works/pi-coding-agent";

const MAX_SESSION_NAME_LENGTH = 48;
const MAX_SESSION_NAME_WORDS = 6;
const MAX_PROMPT_CHARS = 1600;
const IMAGE_ONLY_NAME = "Image task";
const TITLE_SYSTEM_PROMPT = `You write short session names for coding-agent terminal tabs.

Return only the title text.

Rules:
- 2 to 6 words.
- Prefer under 48 characters.
- No quotes, markdown, bullets, emoji, or trailing punctuation.
- Be concrete and task-focused.
- Favor libraries, frameworks, files, APIs, errors, and user intent.
- Drop filler such as "please", "help", "can you", and "I need to".
- Avoid repeating the current folder name unless it is essential.
- If the prompt is mostly logs or code, infer the likely task from the important nouns and errors.`;

function normalizeWhitespace(text: string): string {
	return text.replace(/\s+/g, " ").trim();
}

function trimTrailingPunctuation(text: string): string {
	return text.replace(/[.!?…,:;\-–—\s]+$/g, "").trim();
}

function stripLeadingFiller(text: string): string {
	const patterns = [
		/^(please\s+)+/i,
		/^(can|could|would|will)\s+you\s+/i,
		/^help\s+me\s+(?:with\s+)?/i,
		/^please\s+help\s+me\s+(?:with\s+)?/i,
		/^i\s+need\s+(?:you\s+)?to\s+/i,
		/^i\s+want\s+(?:you\s+)?to\s+/i,
		/^we\s+need\s+to\s+/i,
		/^let'?s\s+/i,
		/^how\s+do\s+i\s+/i,
		/^how\s+to\s+/i,
		/^what'?s\s+the\s+best\s+way\s+to\s+/i,
	];

	let current = text.trim();
	let changed = true;
	while (changed) {
		changed = false;
		for (const pattern of patterns) {
			const next = current.replace(pattern, "").trim();
			if (next && next !== current) {
				current = next;
				changed = true;
			}
		}
	}
	return current;
}

function truncateSessionName(text: string, maxLength = MAX_SESSION_NAME_LENGTH): string {
	if (text.length <= maxLength) return text;

	const slice = text.slice(0, Math.max(0, maxLength - 1));
	const lastSpace = slice.lastIndexOf(" ");
	const cutoff = lastSpace >= Math.floor(maxLength * 0.6) ? slice.slice(0, lastSpace) : slice;
	return `${cutoff.trimEnd()}…`;
}

function cleanupCandidate(raw: string | undefined): string | undefined {
	if (!raw) return undefined;

	let text = raw.split(/\r?\n/).find((line) => line.trim()) ?? raw;
	text = text.replace(/^[\s>*`"'#[\]-]+/, "");
	text = text.replace(/^(title|session title|name)\s*:\s*/i, "");
	text = normalizeWhitespace(text);
	text = stripLeadingFiller(text);
	text = trimTrailingPunctuation(text);

	if (!text) return undefined;

	const words = text.split(" ");
	if (words.length > MAX_SESSION_NAME_WORDS) {
		text = words.slice(0, MAX_SESSION_NAME_WORDS).join(" ");
	}

	text = truncateSessionName(text);
	return text || undefined;
}

function simplifyPromptForHeuristic(text: string): string {
	return normalizeWhitespace(
		text
			.replace(/```[\s\S]*?```/g, " code ")
			.replace(/`([^`]+)`/g, "$1")
			.replace(/\[(.*?)\]\((.*?)\)/g, "$1")
			.replace(/[#>*_~]/g, " "),
	);
}

function deriveHeuristicSessionName(text: string, imageCount: number): string | undefined {
	const simplified = simplifyPromptForHeuristic(text);
	if (!simplified) {
		return imageCount > 0 ? IMAGE_ONLY_NAME : undefined;
	}

	const firstClause = simplified.split(/[\n.!?]/, 1)[0] ?? simplified;
	const stripped = stripLeadingFiller(firstClause) || simplified;
	return cleanupCandidate(stripped) ?? (imageCount > 0 ? IMAGE_ONLY_NAME : undefined);
}

function summarizeContent(content: unknown): { text: string; imageCount: number } {
	if (typeof content === "string") {
		return { text: content, imageCount: 0 };
	}

	if (!Array.isArray(content)) {
		return { text: "", imageCount: 0 };
	}

	let imageCount = 0;
	const text = content
		.map((block) => {
			if (!block || typeof block !== "object") return "";

			const candidate = block as { type?: unknown; text?: unknown };
			if (candidate.type === "text" && typeof candidate.text === "string") {
				return candidate.text;
			}
			if (candidate.type === "image") {
				imageCount += 1;
			}
			return "";
		})
		.join(" ");

	return { text, imageCount };
}

function getCurrentSessionName(ctx: ExtensionContext): string | undefined {
	return cleanupCandidate(ctx.sessionManager.getSessionName());
}

function setCurrentSessionName(pi: ExtensionAPI, name: string, ctx: ExtensionContext): void {
	try {
		pi.setSessionName(name);
	} catch (error) {
		const appendSessionInfo = (ctx.sessionManager as { appendSessionInfo?: (nextName: string) => void }).appendSessionInfo;
		if (
			appendSessionInfo
			&& error instanceof Error
			&& /Extension runtime not initialized/i.test(error.message)
		) {
			appendSessionInfo.call(ctx.sessionManager, name);
			return;
		}
		throw error;
	}
}

function buildTitlePrompt(prompt: string, cwdBasename: string, imageCount: number): string {
	const normalizedPrompt = normalizeWhitespace(prompt).slice(0, MAX_PROMPT_CHARS);
	return [
		`Current folder: ${cwdBasename || "unknown"}`,
		imageCount > 0 ? `Attached images: ${imageCount}` : "",
		"",
		"First user prompt:",
		normalizedPrompt,
	]
		.filter(Boolean)
		.join("\n");
}

async function generateSessionNameWithLlm(
	text: string,
	imageCount: number,
	ctx: ExtensionContext,
): Promise<string | undefined> {
	const model = ctx.modelRegistry.find("openai-codex", "gpt-5.4-mini");
	if (!model) return undefined;

	if (!ctx.modelRegistry.hasConfiguredAuth(model)) return undefined;

	const response = await ctx.modelRegistry.complete(
		model,
		{
			systemPrompt: TITLE_SYSTEM_PROMPT,
			messages: [
				{
					role: "user",
					content: [
						{
							type: "text",
							text: buildTitlePrompt(text, basename(ctx.sessionManager.getCwd()), imageCount),
						},
					],
					timestamp: Date.now(),
				},
			],
		},
		{ reasoningEffort: "minimal" },
	);

	const raw = response.content
		.filter((block): block is { type: "text"; text: string } => block.type === "text")
		.map((block) => block.text)
		.join(" ");

	return cleanupCandidate(raw);
}

function extractFirstUserPromptFromBranch(ctx: ExtensionContext): { text: string; imageCount: number } | undefined {
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "message" || entry.message.role !== "user") continue;
		const summary = summarizeContent(entry.message.content);
		if (!summary.text && summary.imageCount === 0) continue;
		return summary;
	}
	return undefined;
}

export default function (pi: ExtensionAPI) {
	let sessionNonce = 0;
	let activeSessionId: string | undefined;
	let pendingGeneration = false;
	let managedSessionName: string | undefined;
	let disposed = false;

	function resetState(ctx: ExtensionContext): void {
		sessionNonce += 1;
		activeSessionId = ctx.sessionManager.getSessionId();
		pendingGeneration = false;
		managedSessionName = undefined;
		disposed = false;
	}

	function applyManagedName(name: string | undefined, mode: "initial" | "refine", ctx: ExtensionContext): boolean {
		const next = cleanupCandidate(name);
		if (!next) return false;

		const current = getCurrentSessionName(ctx);
		if (mode === "initial") {
			if (current) return false;
		} else if (current && current !== managedSessionName) {
			return false;
		}

		if (current !== next) {
			setCurrentSessionName(pi, next, ctx);
		}
		managedSessionName = next;
		return true;
	}

	function scheduleRefinement(text: string, imageCount: number, ctx: ExtensionContext): void {
		if (pendingGeneration) return;
		pendingGeneration = true;

		const nonce = sessionNonce;
		const sessionId = activeSessionId;

		void (async () => {
			try {
				const generated = await generateSessionNameWithLlm(text, imageCount, ctx);
				if (!generated) return;
				if (disposed || nonce !== sessionNonce || sessionId !== activeSessionId) return;
				applyManagedName(generated, "refine", ctx);
			} catch {
				// Keep the heuristic name when generation fails.
			} finally {
				if (nonce === sessionNonce) {
					pendingGeneration = false;
				}
			}
		})();
	}

	function startAutoNaming(text: string, imageCount: number, ctx: ExtensionContext): void {
		if (getCurrentSessionName(ctx)) return;

		const heuristic = deriveHeuristicSessionName(text, imageCount);
		applyManagedName(heuristic, "initial", ctx);
		scheduleRefinement(text, imageCount, ctx);
	}

	pi.on("session_start", async (_event, ctx) => {
		resetState(ctx);
		if (getCurrentSessionName(ctx)) return;

		const firstPrompt = extractFirstUserPromptFromBranch(ctx);
		if (!firstPrompt) return;

		startAutoNaming(firstPrompt.text, firstPrompt.imageCount, ctx);
	});

	pi.on("session_shutdown", async () => {
		disposed = true;
		sessionNonce += 1;
		pendingGeneration = false;
	});

	pi.on("input", async (event: InputEvent, ctx) => {
		if (event.source === "extension") {
			return { action: "continue" as const };
		}

		if (getCurrentSessionName(ctx)) {
			return { action: "continue" as const };
		}

		const promptText = event.text.trim();
		const imageCount = event.images?.length ?? 0;
		if (!promptText && imageCount === 0) {
			return { action: "continue" as const };
		}

		startAutoNaming(promptText, imageCount, ctx);
		return { action: "continue" as const };
	});
}
