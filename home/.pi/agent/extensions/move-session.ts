import type { ExtensionAPI, SessionEntry } from "@earendil-works/pi-coding-agent";
import { SessionManager, SettingsManager } from "@earendil-works/pi-coding-agent";
import { CombinedAutocompleteProvider, type AutocompleteItem } from "@earendil-works/pi-tui";
import { accessSync, constants, statSync, writeFileSync, writeSync } from "node:fs";
import { mkdir, realpath, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { delimiter, isAbsolute, join, resolve } from "node:path";
import { randomBytes } from "node:crypto";

type ExecveProcess = NodeJS.Process & {
	execve?: (file: string, args: string[], env: Record<string, string>) => never;
};

const CUSTOM_ENTRY_TYPE = "move-session";

function stripMatchingQuotes(value: string): string {
	const trimmed = value.trim();
	if (trimmed.length < 2) return trimmed;

	const first = trimmed[0];
	const last = trimmed[trimmed.length - 1];
	if ((first === '"' || first === "'") && first === last) {
		return trimmed.slice(1, -1);
	}
	return trimmed;
}

function expandHome(path: string): string {
	if (path === "~") return homedir();
	if (path.startsWith("~/")) return join(homedir(), path.slice(2));
	return path;
}

function resolveTargetPath(input: string, cwd: string): string {
	const expanded = expandHome(stripMatchingQuotes(input));
	return isAbsolute(expanded) ? resolve(expanded) : resolve(cwd, expanded);
}

async function ensureDirectory(path: string, ctx: { ui: { confirm(title: string, message: string): Promise<boolean> } }): Promise<boolean> {
	try {
		const info = await stat(path);
		return info.isDirectory();
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
	}

	const shouldCreate = await ctx.ui.confirm("Create directory?", `${path} does not exist. Create it?`);
	if (!shouldCreate) return false;

	await mkdir(path, { recursive: true });
	const created = await stat(path);
	return created.isDirectory();
}

async function canonicalPath(path: string): Promise<string> {
	try {
		return await realpath(path);
	} catch {
		return resolve(path);
	}
}

function getTargetSessionDir(targetCwd: string): string | undefined {
	try {
		return SettingsManager.create(targetCwd).getSessionDir();
	} catch {
		return undefined;
	}
}

function generateEntryId(usedIds: Set<string>): string {
	for (;;) {
		const id = randomBytes(4).toString("hex");
		if (!usedIds.has(id)) {
			usedIds.add(id);
			return id;
		}
	}
}

function createMovedSessionFile(options: {
	targetCwd: string;
	sourceCwd: string;
	sourceSessionFile?: string;
	entries: SessionEntry[];
	leafId: string | null;
}): string {
	const targetManager = SessionManager.create(options.targetCwd, getTargetSessionDir(options.targetCwd));
	const targetHeader = targetManager.getHeader();
	const targetSessionFile = targetManager.getSessionFile();

	if (!targetHeader || !targetSessionFile) {
		throw new Error("Failed to create target session metadata");
	}

	const timestamp = new Date().toISOString();
	const usedIds = new Set(options.entries.map((entry) => entry.id));
	const marker: SessionEntry = {
		type: "custom",
		id: generateEntryId(usedIds),
		parentId: options.leafId,
		timestamp,
		customType: CUSTOM_ENTRY_TYPE,
		data: {
			movedAt: timestamp,
			sourceCwd: options.sourceCwd,
			sourceSessionFile: options.sourceSessionFile,
		},
	};

	const relocated = [
		{
			...targetHeader,
			cwd: options.targetCwd,
			parentSession: options.sourceSessionFile,
		},
		...options.entries,
		marker,
	];

	writeFileSync(targetSessionFile, `${relocated.map((entry) => JSON.stringify(entry)).join("\n")}\n`);
	return targetSessionFile;
}

function isExecutable(path: string): boolean {
	try {
		accessSync(path, constants.X_OK);
		return statSync(path).isFile();
	} catch {
		return false;
	}
}

function findExecutable(name: string): string | undefined {
	for (const dir of (process.env.PATH ?? "").split(delimiter)) {
		if (!dir) continue;
		const candidate = join(dir, name);
		if (isExecutable(candidate)) return candidate;
	}
	return undefined;
}

function buildPiInvocation(sessionFile: string): { file: string; args: string[] } {
	const scriptArg = process.argv[1];
	const scriptPath = scriptArg ? (isAbsolute(scriptArg) ? scriptArg : resolve(process.cwd(), scriptArg)) : undefined;

	if (scriptPath && statSyncSafe(scriptPath)?.isFile()) {
		return {
			file: process.execPath,
			args: [process.execPath, ...process.execArgv, scriptPath, "--session", sessionFile],
		};
	}

	const pi = findExecutable("pi");
	if (pi) return { file: pi, args: [pi, "--session", sessionFile] };

	throw new Error("Could not find the current pi entrypoint or a pi executable on PATH");
}

function statSyncSafe(path: string): ReturnType<typeof statSync> | undefined {
	try {
		return statSync(path);
	} catch {
		return undefined;
	}
}

function cleanEnv(targetCwd: string): Record<string, string> {
	const env: Record<string, string> = {};
	for (const [key, value] of Object.entries(process.env)) {
		if (typeof value === "string") env[key] = value;
	}
	env.PWD = targetCwd;
	return env;
}

function scheduleInPlaceRelaunch(targetCwd: string, sessionFile: string): void {
	const execve = (process as ExecveProcess).execve;
	if (typeof execve !== "function") {
		throw new Error("This Node.js runtime does not expose process.execve(); cannot relaunch pi in-place");
	}

	const invocation = buildPiInvocation(sessionFile);
	process.once("exit", () => {
		try {
			process.chdir(targetCwd);
			execve(invocation.file, invocation.args, cleanEnv(targetCwd));
		} catch (error) {
			const message = error instanceof Error ? error.message : String(error);
			try {
				writeSync(2, `\n[move-session] Failed to relaunch pi: ${message}\n`);
			} catch {
				// Nothing else is safe from an exit handler.
			}
		}
	});
}

function shorten(path: string): string {
	const home = homedir();
	if (path === home) return "~";
	if (path.startsWith(`${home}/`)) return `~/${path.slice(home.length + 1)}`;
	return path;
}

async function getDirectoryCompletions(prefix: string, cwd: string): Promise<AutocompleteItem[] | null> {
	const provider = new CombinedAutocompleteProvider([], cwd);
	const suggestions = await provider.getSuggestions([prefix], 0, prefix.length, {
		signal: new AbortController().signal,
		force: true,
	});
	const directories = suggestions?.items.filter((item) => item.label.endsWith("/")) ?? [];
	return directories.length > 0 ? directories : null;
}

export default function (pi: ExtensionAPI) {
	let completionCwd = process.cwd();

	pi.on("session_start", (_event, ctx) => {
		completionCwd = ctx.cwd;
	});

	pi.registerCommand("move-session", {
		description: "Move the current session to another directory and relaunch pi there",
		getArgumentCompletions: (prefix) => getDirectoryCompletions(prefix, completionCwd),
		handler: async (args, ctx) => {
			if (!process.stdin.isTTY || !process.stdout.isTTY) {
				ctx.ui.notify("/move-session can only relaunch from an interactive terminal", "error");
				return;
			}

			let directoryArg = args.trim();
			if (!directoryArg) {
				const entered = await ctx.ui.input("Move session to directory", "Path relative to this session, or ~/path");
				if (!entered?.trim()) {
					ctx.ui.notify("Move cancelled", "info");
					return;
				}
				directoryArg = entered;
			}

			const targetPath = resolveTargetPath(directoryArg, ctx.cwd);
			const isDirectory = await ensureDirectory(targetPath, ctx);
			if (!isDirectory) {
				ctx.ui.notify(`${targetPath} is not a directory`, "error");
				return;
			}

			const [targetCwd, currentCwd] = await Promise.all([
				canonicalPath(targetPath),
				canonicalPath(ctx.sessionManager.getCwd()),
			]);

			if (targetCwd === currentCwd) {
				ctx.ui.notify("That is already this session's working directory", "warning");
				return;
			}

			const confirmed = await ctx.ui.confirm(
				"Move session?",
				`Move this session from ${shorten(currentCwd)} to ${shorten(targetCwd)} and relaunch pi there?`,
			);
			if (!confirmed) {
				ctx.ui.notify("Move cancelled", "info");
				return;
			}

			await ctx.waitForIdle();

			let movedSessionFile: string;
			try {
				movedSessionFile = createMovedSessionFile({
					targetCwd,
					sourceCwd: currentCwd,
					sourceSessionFile: ctx.sessionManager.getSessionFile(),
					entries: ctx.sessionManager.getEntries(),
					leafId: ctx.sessionManager.getLeafId(),
				});
				scheduleInPlaceRelaunch(targetCwd, movedSessionFile);
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(`Failed to move session: ${message}`, "error");
				return;
			}

			ctx.ui.notify(`Relaunching pi in ${shorten(targetCwd)}...`, "info");
			ctx.shutdown();
		},
	});
}
