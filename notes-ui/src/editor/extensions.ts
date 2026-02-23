import { keymap } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import { EditorView } from "@codemirror/view";
import { bolderTheme, bolderSyntaxHighlighting } from "./theme";
import { markdownExtension } from "./markdown";
import type { Extension } from "@codemirror/state";

interface ExtensionOptions {
  onContentChange: (text: string) => void;
  onKeyCommand: (key: "tab" | "escape") => boolean;
}

export function buildExtensions(opts: ExtensionOptions): Extension[] {
  return [
    bolderTheme,
    bolderSyntaxHighlighting,
    markdownExtension(),
    history(),
    closeBrackets(),
    keymap.of([
      {
        key: "Tab",
        run: () => opts.onKeyCommand("tab"),
      },
      {
        key: "Escape",
        run: () => opts.onKeyCommand("escape"),
      },
      ...closeBracketsKeymap,
      ...historyKeymap,
      ...defaultKeymap,
    ]),
    EditorView.updateListener.of((update) => {
      if (update.docChanged) {
        opts.onContentChange(update.state.doc.toString());
      }
    }),
    EditorView.lineWrapping,
  ];
}
