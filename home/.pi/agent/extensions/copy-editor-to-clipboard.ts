import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { copyToClipboard } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerShortcut("alt+s", {
    description: "Copy editor draft to clipboard and clear it",
    handler: async (ctx) => {
      const text = ctx.ui.getEditorText();
      if (!text.trim()) {
        ctx.ui.notify("Editor is empty", "info");
        return;
      }
      await copyToClipboard(text);
      ctx.ui.setEditorText("");
      ctx.ui.notify("Copied draft to clipboard", "info");
    },
  });
}
