import { basename } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const WORKING_INDICATOR = "⏳";
const DONE_INDICATOR = "✅";

type TabState = "initial" | "working" | "done";

function buildTitle(prefix: string, ctx: ExtensionContext): string {
	const cwd = basename(ctx.sessionManager.getCwd());
	const sessionName = ctx.sessionManager.getSessionName();
	return sessionName ? `${prefix} - ${sessionName} - ${cwd}` : `${prefix} - ${cwd}`;
}

export default function (pi: ExtensionAPI) {
	let state: TabState = "initial";
	let deferredTitleTimer: ReturnType<typeof setTimeout> | undefined;

	function setTitle(prefix: string, ctx: ExtensionContext): void {
		ctx.ui.setTitle(buildTitle(prefix, ctx));
	}

	function clearDeferredTitleTimer(): void {
		if (!deferredTitleTimer) return;
		clearTimeout(deferredTitleTimer);
		deferredTitleTimer = undefined;
	}

	function showWorking(ctx: ExtensionContext): void {
		state = "working";
		setTitle(WORKING_INDICATOR, ctx);
	}

	function showDone(ctx: ExtensionContext): void {
		state = "done";
		setTitle(DONE_INDICATOR, ctx);
	}

	function reapplyTitleAfterPiUpdate(ctx: ExtensionContext): void {
		if (state === "initial") return;
		if (deferredTitleTimer) clearTimeout(deferredTitleTimer);

		// Pi also updates the title when the session name changes. Reapply our
		// state on the next task so its built-in π title cannot overwrite it.
		deferredTitleTimer = setTimeout(() => {
			deferredTitleTimer = undefined;
			setTitle(state === "working" ? WORKING_INDICATOR : DONE_INDICATOR, ctx);
		}, 0);
	}

	pi.on("session_start", () => {
		clearDeferredTitleTimer();
		state = "initial";
		// Keep Pi's normal π title until the first agent run starts.
	});

	pi.on("agent_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		showWorking(ctx);
	});

	pi.on("agent_settled", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		showDone(ctx);
	});

	pi.on("session_info_changed", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		reapplyTitleAfterPiUpdate(ctx);
	});

	pi.on("session_shutdown", () => {
		clearDeferredTitleTimer();
		state = "initial";
	});
}
