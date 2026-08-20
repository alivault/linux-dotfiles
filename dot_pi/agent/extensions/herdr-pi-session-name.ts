import { createConnection } from "node:net";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const socketPath = process.env.HERDR_SOCKET_PATH;
const paneId = process.env.HERDR_PANE_ID;
const source = "user:pi-session-name";
const agentSource = "herdr:pi";

function enabled(): boolean {
	return process.env.HERDR_ENV === "1" && Boolean(socketPath) && Boolean(paneId);
}

function sendAttempt(request: unknown, timeoutMs: number): Promise<boolean> {
	if (!enabled()) return Promise.resolve(true);

	return new Promise((resolve) => {
		const socket = createConnection(socketPath!);
		let finished = false;
		let timeout: ReturnType<typeof setTimeout> | undefined;

		const finish = (delivered: boolean) => {
			if (finished) return;
			finished = true;
			if (timeout) clearTimeout(timeout);
			socket.destroy();
			resolve(delivered);
		};

		socket.on("error", () => finish(false));
		socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
		socket.on("data", () => finish(true));
		socket.on("end", () => finish(false));
		timeout = setTimeout(() => finish(false), timeoutMs);
		timeout.unref?.();
	});
}

async function send(request: unknown): Promise<void> {
	if (await sendAttempt(request, 500)) return;
	await sendAttempt(request, 1500);
}

let sequence = Date.now() * 1000;

function reportTokens(tokens: Record<string, string | null>): Promise<void> {
	sequence += 1;
	return send({
		id: `${source}:${Date.now()}:${Math.random().toString(36).slice(2)}`,
		method: "pane.report_metadata",
		params: {
			pane_id: paneId,
			source,
			agent: "pi",
			applies_to_source: agentSource,
			tokens,
			seq: sequence,
		},
	});
}

function singleLine(value: string | undefined): string | undefined {
	const line = value?.replace(/\s+/g, " ").trim();
	if (!line) return undefined;
	return line.length > 160 ? `${line.slice(0, 157)}...` : line;
}

function userMessageText(message: any): string | undefined {
	if (message?.role !== "user") return undefined;
	if (typeof message.content === "string") return singleLine(message.content);
	if (!Array.isArray(message.content)) return undefined;

	return singleLine(
		message.content
			.filter((part: any) => part?.type === "text" && typeof part.text === "string")
			.map((part: any) => part.text)
			.join(" "),
	);
}

function latestUserMessage(ctx: any): string | undefined {
	const branch = ctx?.sessionManager?.getBranch?.();
	if (!Array.isArray(branch)) return undefined;

	for (let index = branch.length - 1; index >= 0; index -= 1) {
		const entry = branch[index];
		if (entry?.type !== "message") continue;
		const text = userMessageText(entry.message);
		if (text) return text;
	}
	return undefined;
}

function currentThinkingTitle(message: any): string | undefined {
	if (message?.role !== "assistant" || !Array.isArray(message.content)) return undefined;

	const thinking = message.content
		.filter((part: any) => part?.type === "thinking" && typeof part.thinking === "string")
		.map((part: any) => part.thinking)
		.join("\n");

	let title: string | undefined;
	for (const match of thinking.matchAll(/\*\*([^*\n]+)\*\*/g)) {
		title = match[1];
	}
	for (const match of thinking.matchAll(/^\s*#{1,6}\s+(.+)$/gm)) {
		title = match[1];
	}

	return singleLine(title?.replace(/^[#*_`\s]+|[#*_`\s]+$/g, ""));
}

export default function (pi: ExtensionAPI) {
	if (!enabled()) return;

	let rootSession = false;
	let lastUserMessage: string | undefined;
	let thinkingTitle: string | undefined;
	let displayedActivity: string | undefined;

	async function reportActivity(activity: string | undefined): Promise<void> {
		if (activity === displayedActivity) return;
		displayedActivity = activity;
		await reportTokens({ activity: activity ?? null });
	}

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.hasUI !== true) return;
		rootSession = true;
		lastUserMessage = latestUserMessage(ctx);
		displayedActivity = lastUserMessage;
		await reportTokens({
			session_name: pi.getSessionName() ?? null,
			activity: lastUserMessage ?? null,
		});
	});

	pi.on("session_info_changed", async (event) => {
		if (!rootSession) return;
		await reportTokens({ session_name: event.name ?? null });
	});

	pi.on("before_agent_start", async (event) => {
		if (!rootSession) return;
		lastUserMessage = singleLine(event.prompt);
		thinkingTitle = undefined;
		await reportActivity(lastUserMessage);
	});

	pi.on("message_update", async (event) => {
		if (!rootSession) return;
		const update = event.assistantMessageEvent;
		if (
			update.type !== "thinking_start" &&
			update.type !== "thinking_delta" &&
			update.type !== "thinking_end"
		) {
			return;
		}
		const title = currentThinkingTitle(update.partial);
		if (!title || title === thinkingTitle) return;
		thinkingTitle = title;
		await reportActivity(title);
	});

	pi.on("agent_end", async () => {
		if (!rootSession) return;
		thinkingTitle = undefined;
		await reportActivity(lastUserMessage);
	});

	pi.on("session_shutdown", async (event) => {
		if (!rootSession || event.reason !== "quit") return;
		await reportTokens({ session_name: null, activity: null });
	});
}
