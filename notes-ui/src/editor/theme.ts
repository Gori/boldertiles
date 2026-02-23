import { EditorView } from "@codemirror/view";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";

const bolderColors = {
  bg: "#1a1a1a",
  fg: "#d9d9d9",
  cursor: "#cccccc",
  selection: "#264f78",
  gutterBg: "#1a1a1a",
  gutterFg: "#555555",
  heading: "#e0c080",
  emphasis: "#b0b0b0",
  strong: "#e0e0e0",
  link: "#6caceb",
  url: "#6caceb",
  quote: "#7a9070",
  code: "#c89060",
  list: "#888888",
  meta: "#666666",
  comment: "#555555",
};

export const bolderTheme = EditorView.theme(
  {
    // DEBUG: subtle bg tints to visualize CM blocks
    "&": {
      color: bolderColors.fg,
      backgroundColor: "rgba(0, 40, 80, 0.15)", // blue tint — .cm-editor
      fontFamily: "'JetBrains Mono', ui-monospace, monospace",
      fontSize: "14px",
      lineHeight: "1.6",
      height: "100%",
      outline: "1px solid rgba(60, 120, 200, 0.3)",
    },
    ".cm-scroller": {
      overflow: "auto",
      backgroundColor: "rgba(80, 0, 40, 0.1)", // magenta tint — scroller
    },
    ".cm-content": {
      caretColor: bolderColors.cursor,
      padding: "28px",
      backgroundColor: "rgba(0, 60, 0, 0.1)", // green tint — content area
    },
    ".cm-line": {
      backgroundColor: "rgba(60, 60, 0, 0.06)", // yellow tint — each line
    },
    ".cm-activeLine": {
      backgroundColor: "rgba(255, 255, 255, 0.04)", // brighter — active line
    },
    ".cm-cursor, .cm-dropCursor": {
      borderLeftColor: bolderColors.cursor,
      borderLeftWidth: "2px",
    },
    "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection":
      {
        backgroundColor: bolderColors.selection,
      },
    ".cm-gutters": {
      backgroundColor: "rgba(80, 0, 0, 0.15)", // red tint — gutters
      color: bolderColors.gutterFg,
      border: "none",
    },
    ".cm-activeLineGutter": {
      backgroundColor: "rgba(80, 0, 0, 0.25)",
    },
    // Suggestion widget containers
    ".suggestion-widget": {
      margin: "8px 0",
      backgroundColor: "rgba(100, 50, 0, 0.15)", // orange tint — widgets
      outline: "1px dashed rgba(200, 100, 0, 0.4)",
    },
  },
  { dark: true },
);

const bolderHighlightStyle = HighlightStyle.define([
  { tag: tags.heading1, color: bolderColors.heading, fontWeight: "bold", fontSize: "1.4em" },
  { tag: tags.heading2, color: bolderColors.heading, fontWeight: "bold", fontSize: "1.2em" },
  { tag: tags.heading3, color: bolderColors.heading, fontWeight: "bold", fontSize: "1.1em" },
  { tag: [tags.heading4, tags.heading5, tags.heading6], color: bolderColors.heading, fontWeight: "bold" },
  { tag: tags.emphasis, color: bolderColors.emphasis, fontStyle: "italic" },
  { tag: tags.strong, color: bolderColors.strong, fontWeight: "bold" },
  { tag: tags.link, color: bolderColors.link, textDecoration: "underline" },
  { tag: tags.url, color: bolderColors.url },
  { tag: tags.quote, color: bolderColors.quote },
  { tag: [tags.monospace, tags.processingInstruction], color: bolderColors.code },
  { tag: tags.list, color: bolderColors.list },
  { tag: tags.meta, color: bolderColors.meta },
  { tag: tags.comment, color: bolderColors.comment },
  { tag: tags.contentSeparator, color: bolderColors.meta },
]);

export const bolderSyntaxHighlighting = syntaxHighlighting(bolderHighlightStyle);
