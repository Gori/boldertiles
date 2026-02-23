import { markdown, markdownLanguage } from "@codemirror/lang-markdown";

export function markdownExtension() {
  return markdown({
    base: markdownLanguage,
  });
}
