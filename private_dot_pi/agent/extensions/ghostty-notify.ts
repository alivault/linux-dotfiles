import { basename } from "node:path";
import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const PREVIEW_MAX_LENGTH = 160;
const NOTIFICATION_DELAY_MS = 100;

function isGhostty(): boolean {
	return (
		process.env.TERM_PROGRAM?.toLowerCase() === "ghostty" ||
		process.env.TERM === "xterm-ghostty" ||
		Boolean(process.env.GHOSTTY_RESOURCES_DIR)
	);
}

function sanitizeOscField(value: string): string {
	return value.replaceAll(";", ":").replace(/[\x00-\x1f\x7f]/g, " ").trim();
}

function notifyGhostty(title: string, body: string): void {
	// Ghostty supports desktop notifications via OSC 777:
	// ESC ] 777 ; notify ; <title> ; <body> BEL
	process.stdout.write(
		`\x1b]777;notify;${sanitizeOscField(title)};${sanitizeOscField(body)}\x07`,
	);
}

function getLastAssistantPreview(ctx: ExtensionContext): string | undefined {
	const branch = ctx.sessionManager.getBranch();

	for (let i = branch.length - 1; i >= 0; i--) {
		const entry = branch[i];
		if (entry.type !== "message" || entry.message.role !== "assistant") continue;

		const text = entry.message.content
			.filter(
				(part): part is { type: "text"; text: string } => part.type === "text",
			)
			.map((part) => part.text)
			.join(" ")
			.replace(/\s+/g, " ")
			.trim();
		if (!text) continue;

		const characters = [...text];
		if (characters.length <= PREVIEW_MAX_LENGTH) return text;

		return `${characters.slice(0, PREVIEW_MAX_LENGTH - 1).join("").trimEnd()}…`;
	}

	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("agent_settled", (_event, ctx) => {
		// Direct terminal output would corrupt JSON/print mode output.
		if (ctx.mode !== "tui" || !process.stdout.isTTY || !isGhostty()) return;

		const project = basename(ctx.cwd) || ctx.cwd;
		const preview = getLastAssistantPreview(ctx);
		const body = preview || "Ready for input";

		// Ghostty debounces terminal-title changes by 75 ms. Wait for the done
		// title to commit before Ghostty snapshots it as the notification subtitle.
		setTimeout(
			() => notifyGhostty(`Pi · ${project}`, body),
			NOTIFICATION_DELAY_MS,
		);
	});
}
