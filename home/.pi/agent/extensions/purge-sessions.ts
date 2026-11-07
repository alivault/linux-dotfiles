import type { ExtensionAPI, ExtensionCommandContext, SessionInfo } from "@earendil-works/pi-coding-agent";
import { SessionManager } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { realpath, stat, unlink } from "node:fs/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";

const DAY_MS = 24 * 60 * 60 * 1000;
const PREVIEW_LIMIT = 8;
const TRASH_BATCH_SIZE = 200;

type PurgeOptions = {
	days?: number;
	all: boolean;
	dryRun: boolean;
	permanent: boolean;
	help: boolean;
};

type Candidate = {
	session: SessionInfo;
	sizeBytes: number;
};

type DeleteResult =
	| { ok: true; method: "trash" | "unlink" }
	| { ok: false; method: "trash" | "unlink"; error: string };

type PurgeScope = "current" | "all";
type ScopeSelection = { scope: PurgeScope; sessions: SessionInfo[] };

async function selectScope(
	ctx: ExtensionCommandContext,
	initial: PurgeScope,
): Promise<ScopeSelection | undefined> {
	return ctx.ui.custom<ScopeSelection | undefined>((tui, theme, _keybindings, done) => {
		let scope = initial;
		let loading = false;
		let progress: { loaded: number; total: number } | undefined;
		let error: string | undefined;

		const load = async () => {
			loading = true;
			progress = undefined;
			error = undefined;
			tui.requestRender();

			try {
				const sessions =
					scope === "all"
						? await SessionManager.listAll((loaded, total) => {
								progress = { loaded, total };
								tui.requestRender();
							})
						: await SessionManager.list(ctx.cwd, ctx.sessionManager.getSessionDir());
				done({ scope, sessions });
			} catch (cause) {
				error = cause instanceof Error ? cause.message : String(cause);
				loading = false;
				tui.requestRender();
			}
		};

		return {
			invalidate() {},
			handleInput(data: string) {
				if (loading) return;
				if (matchesKey(data, Key.tab) || matchesKey(data, Key.left) || matchesKey(data, Key.right)) {
					scope = scope === "current" ? "all" : "current";
					error = undefined;
					tui.requestRender();
					return;
				}
				if (matchesKey(data, Key.enter)) {
					void load();
					return;
				}
				if (matchesKey(data, Key.escape)) done(undefined);
			},
			render(width: number) {
				const title = theme.bold(
					scope === "current" ? "Purge Sessions (Current Folder)" : "Purge Sessions (All)",
				);
				const current =
					scope === "current" && !loading
						? theme.fg("accent", "◉ Current Folder")
						: theme.fg("muted", "○ Current Folder");
				const all =
					scope === "all" && !loading ? theme.fg("accent", "◉ All") : theme.fg("muted", "○ All");
				const loadingLabel = progress ? `Loading ${progress.loaded}/${progress.total}` : "Loading…";
				const tabs = `${current}${theme.fg("muted", " | ")}${all}`;
				const availableTitle = Math.max(0, width - visibleWidth(tabs) - 1);
				const left = truncateToWidth(title, availableTitle, "");
				const spacing = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(tabs)));

				return [
					truncateToWidth(`${left}${spacing}${tabs}`, width, ""),
					loading
						? theme.fg("accent", truncateToWidth(`○ ${loadingLabel}`, width, "…"))
						: error
							? theme.fg("error", truncateToWidth(`Failed to load: ${error} · Enter retry`, width, "…"))
							: theme.fg("muted", truncateToWidth("Tab/←→ scope · Enter continue · Esc cancel", width, "…")),
				];
			},
		};
	});
}

function parseArgs(raw: string): { options?: PurgeOptions; error?: string } {
	const options: PurgeOptions = {
		all: false,
		dryRun: false,
		permanent: false,
		help: false,
	};
	const positional: string[] = [];

	for (const token of raw.trim().split(/\s+/).filter(Boolean)) {
		if (token === "--all" || token === "-a") {
			options.all = true;
			continue;
		}
		if (token === "--dry-run" || token === "--dryrun" || token === "-n") {
			options.dryRun = true;
			continue;
		}
		if (token === "--permanent") {
			options.permanent = true;
			continue;
		}
		if (token === "--help" || token === "-h") {
			options.help = true;
			continue;
		}
		if (token.startsWith("--days=")) {
			positional.push(token.slice("--days=".length));
			continue;
		}
		if (token.startsWith("-")) {
			return { error: `Unknown option: ${token}` };
		}
		positional.push(token);
	}

	if (positional.length > 1) {
		return { error: `Expected at most one age threshold, got: ${positional.join(" ")}` };
	}

	if (positional[0] !== undefined) {
		const days = Number(positional[0]);
		if (!Number.isFinite(days) || days <= 0) {
			return { error: `Invalid day threshold: ${positional[0]}` };
		}
		options.days = days;
	}

	return { options };
}

function usage(): string {
	return [
		"Usage: /purge-sessions [days] [--all] [--dry-run] [--permanent]",
		"",
		"Deletes sessions whose session file was last modified more than [days] days ago.",
		"Named sessions are included. The currently active session is never deleted.",
		"",
		"Options:",
		"  --all        Include sessions from all projects instead of only the current project.",
		"  --dry-run    Preview matching sessions without deleting anything.",
		"  --permanent  Permanently delete instead of moving to Trash.",
	].join("\n");
}

function shortenPath(path: string | undefined): string {
	if (!path) return "";
	const home = homedir();
	if (path === home) return "~";
	if (path.startsWith(`${home}/`)) return `~/${path.slice(home.length + 1)}`;
	return path;
}

function compactText(text: string | undefined, fallback: string): string {
	const value = text?.replace(/\s+/g, " ").trim() || fallback;
	return value.length <= 72 ? value : `${value.slice(0, 69).trimEnd()}…`;
}

function formatDate(date: Date): string {
	return date.toISOString().slice(0, 10);
}

function formatBytes(bytes: number): string {
	if (bytes < 1024) return `${bytes}B`;
	const kib = bytes / 1024;
	if (kib < 1024) return `${kib.toFixed(kib < 10 ? 1 : 0)}KB`;
	const mib = kib / 1024;
	if (mib < 1024) return `${mib.toFixed(mib < 10 ? 1 : 0)}MB`;
	const gib = mib / 1024;
	return `${gib.toFixed(gib < 10 ? 1 : 0)}GB`;
}

function plural(count: number, singular: string, pluralForm = `${singular}s`): string {
	return `${count} ${count === 1 ? singular : pluralForm}`;
}

async function canonicalize(path: string | undefined): Promise<string | undefined> {
	if (!path) return undefined;
	try {
		return await realpath(path);
	} catch {
		return resolve(path);
	}
}

async function getFileSize(path: string): Promise<number> {
	try {
		return (await stat(path)).size;
	} catch {
		return 0;
	}
}

async function buildCandidates(sessions: SessionInfo[], cutoffMs: number, activeSessionPath: string | undefined): Promise<Candidate[]> {
	const activeCanonical = await canonicalize(activeSessionPath);
	const candidates = (
		await Promise.all(
			sessions.map(async (session): Promise<Candidate | undefined> => {
		const modifiedMs = session.modified.getTime();
		if (!Number.isFinite(modifiedMs) || modifiedMs >= cutoffMs) return undefined;

		const sessionCanonical = await canonicalize(session.path);
		if (activeCanonical && sessionCanonical === activeCanonical) return undefined;

		return {
			session,
			sizeBytes: await getFileSize(session.path),
		};
			}),
		)
	).filter((candidate): candidate is Candidate => candidate !== undefined);

	candidates.sort((a, b) => a.session.modified.getTime() - b.session.modified.getTime());
	return candidates;
}

function describeSession(candidate: Candidate, showCwd: boolean): string {
	const { session, sizeBytes } = candidate;
	const label = compactText(session.name ?? session.firstMessage, session.id.slice(0, 8));
	const cwd = showCwd && session.cwd ? ` • ${shortenPath(session.cwd)}` : "";
	return `- ${formatDate(session.modified)} • ${formatBytes(sizeBytes)} • ${label}${cwd}`;
}

function buildPreview(candidates: Candidate[], options: Required<PurgeOptions>): string {
	const totalBytes = candidates.reduce((sum, candidate) => sum + candidate.sizeBytes, 0);
	const oldest = candidates[0]?.session.modified;
	const newest = candidates[candidates.length - 1]?.session.modified;
	const scope = options.all ? "all projects" : "current project";
	const action = options.dryRun
		? "Would purge"
		: options.permanent
			? "Permanently delete"
			: "Move to Trash";

	const lines = [
		`${action} ${plural(candidates.length, "session")} older than ${options.days} days in ${scope}.`,
		`Total size: ${formatBytes(totalBytes)}`,
		oldest && newest ? `Modified range: ${formatDate(oldest)} to ${formatDate(newest)}` : "",
		"",
		"Examples:",
		...candidates.slice(0, PREVIEW_LIMIT).map((candidate) => describeSession(candidate, options.all)),
	];

	if (candidates.length > PREVIEW_LIMIT) {
		lines.push(`...and ${plural(candidates.length - PREVIEW_LIMIT, "more session")}.`);
	}

	return lines.filter((line, index) => line || index === 3).join("\n");
}

function trashErrorHint(result: ReturnType<typeof spawnSync>): string {
	const parts: string[] = [];
	if (result.error) parts.push(result.error.message);
	const stderr = typeof result.stderr === "string" ? result.stderr.trim() : "";
	if (stderr) parts.push(stderr.split("\n")[0] ?? stderr);
	if (typeof result.status === "number") parts.push(`exit ${result.status}`);
	return parts.length > 0 ? parts.join(" · ").slice(0, 240) : "trash command failed";
}

async function moveToTrash(path: string): Promise<DeleteResult> {
	const trashArgs = path.startsWith("-") ? ["--", path] : [path];
	const result = spawnSync("trash", trashArgs, { encoding: "utf8" });
	if (result.status === 0 || !existsSync(path)) {
		return { ok: true, method: "trash" };
	}
	return { ok: false, method: "trash", error: trashErrorHint(result) };
}

async function unlinkSession(path: string): Promise<DeleteResult> {
	try {
		await unlink(path);
		return { ok: true, method: "unlink" };
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === "ENOENT") {
			return { ok: true, method: "unlink" };
		}
		const message = error instanceof Error ? error.message : String(error);
		return { ok: false, method: "unlink", error: message };
	}
}

async function deleteWithTrash(candidates: Candidate[]): Promise<{ trashed: number; failures: Array<{ path: string; error: string }> }> {
	let trashed = 0;
	const failures: Array<{ path: string; error: string }> = [];

	for (let index = 0; index < candidates.length; index += TRASH_BATCH_SIZE) {
		const batch = candidates.slice(index, index + TRASH_BATCH_SIZE);
		const paths = batch.map((candidate) => candidate.session.path);
		const result = spawnSync("trash", paths, { encoding: "utf8" });
		const error = result.status === 0 ? undefined : trashErrorHint(result);

		for (const path of paths) {
			if (!existsSync(path)) trashed += 1;
			else failures.push({ path, error: error ?? "trash command did not remove the file" });
		}
	}

	return { trashed, failures };
}

async function deletePermanently(candidates: Candidate[]): Promise<{ deleted: number; failures: Array<{ path: string; error: string }> }> {
	const results = await Promise.all(
		candidates.map(async (candidate) => ({
			path: candidate.session.path,
			result: await unlinkSession(candidate.session.path),
		})),
	);
	const deleted = results.filter(({ result }) => result.ok).length;
	const failures = results.flatMap(({ path, result }) =>
		result.ok ? [] : [{ path, error: result.error }],
	);

	return { deleted, failures };
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("purge-sessions", {
		description: "Purge old saved sessions by age",
		handler: async (args, ctx) => {
			const parsed = parseArgs(args);
			if (parsed.error) {
				ctx.ui.notify(parsed.error, "error");
				return;
			}

			const options = parsed.options!;
			if (options.help) {
				await ctx.ui.confirm("Purge sessions", usage());
				return;
			}

			let loadedSessions: SessionInfo[] | undefined;
			if (ctx.hasUI) {
				const selection = await selectScope(ctx, options.all ? "all" : "current");
				if (selection === undefined) {
					ctx.ui.notify("Purge cancelled", "info");
					return;
				}
				options.all = selection.scope === "all";
				loadedSessions = selection.sessions;
			}

			if (!ctx.hasUI && options.days === undefined) {
				ctx.ui.notify("/purge-sessions requires a day threshold when UI is unavailable", "error");
				return;
			}

			if (options.days === undefined) {
				const entered = await ctx.ui.input("Purge sessions older than how many days?", "30");
				if (!entered?.trim()) {
					ctx.ui.notify("Purge cancelled", "info");
					return;
				}
				const days = Number(entered.trim());
				if (!Number.isFinite(days) || days <= 0) {
					ctx.ui.notify(`Invalid day threshold: ${entered}`, "error");
					return;
				}
				options.days = days;
			}

			await ctx.waitForIdle();

			const finalized = options as Required<PurgeOptions>;
			const statusKey = "purge-sessions";
			ctx.ui.setStatus(statusKey, "Loading sessions...");

			try {
				const sessions =
					loadedSessions ??
					(finalized.all
						? await SessionManager.listAll()
						: await SessionManager.list(ctx.cwd, ctx.sessionManager.getSessionDir()));
				const cutoffMs = Date.now() - finalized.days * DAY_MS;
				const candidates = await buildCandidates(sessions, cutoffMs, ctx.sessionManager.getSessionFile());

				if (candidates.length === 0) {
					ctx.ui.notify(`No sessions older than ${finalized.days} days found`, "info");
					return;
				}

				const preview = buildPreview(candidates, finalized);
				if (finalized.dryRun) {
					await ctx.ui.confirm("Dry run: purge sessions", `${preview}\n\nNo sessions were deleted.`);
					return;
				}

				const confirmed = await ctx.ui.confirm("Confirm session purge", preview);
				if (!confirmed) {
					ctx.ui.notify("Purge cancelled", "info");
					return;
				}

				ctx.ui.setStatus(statusKey, finalized.permanent ? "Deleting sessions..." : "Moving sessions to Trash...");

				let trashed = 0;
				let deleted = 0;
				let failures: Array<{ path: string; error: string }> = [];

				if (finalized.permanent) {
					const result = await deletePermanently(candidates);
					deleted = result.deleted;
					failures = result.failures;
				} else {
					const trashResult = await deleteWithTrash(candidates);
					trashed = trashResult.trashed;
					failures = trashResult.failures;

					if (failures.length > 0) {
						const failedPaths = new Set(failures.map((failure) => failure.path));
						const failedCandidates = candidates.filter((candidate) => failedPaths.has(candidate.session.path));
						const firstFailure = failures[0];
						const fallbackConfirmed = await ctx.ui.confirm(
							"Trash failed. Permanently delete instead?",
							[
								`Trash failed for ${plural(failedCandidates.length, "session")}.`,
								firstFailure ? `First error: ${firstFailure.error}` : "",
								"",
								"Permanently delete only those sessions that could not be moved to Trash?",
							]
								.filter(Boolean)
								.join("\n"),
						);

						if (fallbackConfirmed) {
							ctx.ui.setStatus(statusKey, "Deleting sessions...");
							const fallbackResult = await deletePermanently(failedCandidates);
							deleted += fallbackResult.deleted;
							failures = fallbackResult.failures;
						}
					}
				}

				const summary = [
					trashed > 0 ? `${plural(trashed, "session")} moved to Trash` : "",
					deleted > 0 ? `${plural(deleted, "session")} permanently deleted` : "",
					failures.length > 0 ? `${plural(failures.length, "failure")}` : "",
				]
					.filter(Boolean)
					.join("; ");

				ctx.ui.notify(summary || "No sessions deleted", failures.length > 0 ? "warning" : "info");
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`Failed to purge sessions: ${message}`, "error");
			} finally {
				ctx.ui.setStatus(statusKey, undefined);
			}
		},
	});
}
