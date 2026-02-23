import {
  Decoration,
  type DecorationSet,
  WidgetType,
  EditorView,
} from "@codemirror/view";
import { StateEffect, StateField } from "@codemirror/state";
import type { Suggestion } from "../types";

// --- State effects to update suggestions ---

export const setSuggestionsEffect = StateEffect.define<Suggestion[]>();
export const removeSuggestionEffect = StateEffect.define<string>();
export const clearSuggestionsEffect = StateEffect.define<null>();

// --- Suggestions state field ---

export const suggestionsField = StateField.define<Suggestion[]>({
  create: () => [],
  update(value, tr) {
    for (const effect of tr.effects) {
      if (effect.is(setSuggestionsEffect)) return effect.value;
      if (effect.is(clearSuggestionsEffect)) return [];
      if (effect.is(removeSuggestionEffect)) {
        return value.filter((s) => s.id !== effect.value);
      }
    }
    return value;
  },
});

// --- Widget class ---

class SuggestionWidgetType extends WidgetType {
  constructor(readonly suggestion: Suggestion) {
    super();
  }

  eq(other: SuggestionWidgetType): boolean {
    return this.suggestion.id === other.suggestion.id;
  }

  toDOM(): HTMLElement {
    const container = document.createElement("div");
    container.className = "suggestion-widget";
    container.dataset["suggestionId"] = this.suggestion.id;
    return container;
  }

  ignoreEvent(): boolean {
    return true;
  }
}

// --- Text matching (port of SuggestionMatcher) ---

function findTextPosition(text: string, search: string, contextBefore: string, contextAfter: string): number | null {
  if (!search || !text) return null;

  const occurrences: number[] = [];
  let start = 0;
  while (true) {
    const idx = text.indexOf(search, start);
    if (idx === -1) break;
    occurrences.push(idx);
    start = idx + search.length;
  }

  if (occurrences.length === 0) return null;
  if (occurrences.length === 1) return occurrences[0]!;

  // Disambiguate using context
  let bestIdx = occurrences[0]!;
  let bestScore = -1;

  for (const idx of occurrences) {
    let score = 0;
    if (contextBefore) {
      const beforeStart = Math.max(0, idx - contextBefore.length);
      const actualBefore = text.slice(beforeStart, idx);
      if (actualBefore === contextBefore) {
        score += 100;
      } else {
        const minLen = Math.min(contextBefore.length, actualBefore.length);
        for (let i = 1; i <= minLen; i++) {
          if (contextBefore[contextBefore.length - i] === actualBefore[actualBefore.length - i]) {
            score++;
          } else {
            break;
          }
        }
      }
    }
    if (contextAfter) {
      const afterEnd = Math.min(text.length, idx + search.length + contextAfter.length);
      const actualAfter = text.slice(idx + search.length, afterEnd);
      if (actualAfter === contextAfter) {
        score += 100;
      } else {
        const minLen = Math.min(contextAfter.length, actualAfter.length);
        for (let i = 0; i < minLen; i++) {
          if (contextAfter[i] === actualAfter[i]) {
            score++;
          } else {
            break;
          }
        }
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestIdx = idx;
    }
  }

  return bestIdx;
}

function findInsertionPos(doc: string, suggestion: Suggestion): number {
  const content = suggestion.content;

  switch (content.type) {
    case "rewrite":
    case "compression": {
      const pos = findTextPosition(doc, content.original, content.contextBefore, content.contextAfter);
      if (pos !== null) return pos + content.original.length;
      return doc.length;
    }
    case "append":
      return doc.length;
    case "insert": {
      if (content.afterContext) {
        const idx = doc.indexOf(content.afterContext);
        if (idx !== -1) return idx + content.afterContext.length;
      }
      return doc.length;
    }
    case "critique": {
      if (content.targetText) {
        const pos = findTextPosition(doc, content.targetText, content.contextBefore, content.contextAfter);
        if (pos !== null) return pos + content.targetText.length;
      }
      return doc.length;
    }
    case "question":
    case "promote":
    case "advancePhase":
      return doc.length;
  }
}

// --- Build decorations from suggestions ---

function buildDecorations(suggestions: Suggestion[], doc: string, docObj: { lineAt(pos: number): { to: number } }): DecorationSet {
  if (suggestions.length === 0) return Decoration.none;

  const widgets: { pos: number; widget: WidgetType }[] = [];

  console.log("[suggestionWidgets] buildDecorations:", suggestions.length, "suggestions, doc length:", doc.length);

  for (const suggestion of suggestions) {
    if (suggestion.state !== "pending") continue;
    const rawPos = findInsertionPos(doc, suggestion);
    const pos = Math.min(rawPos, doc.length);
    const line = docObj.lineAt(pos);
    console.log("[suggestionWidgets] widget:", suggestion.id, "type:", suggestion.content.type, "pos:", rawPos, "→ line.to:", line.to);
    widgets.push({
      pos: line.to,
      widget: new SuggestionWidgetType(suggestion),
    });
  }

  // Sort by position (required for DecorationSet)
  widgets.sort((a, b) => a.pos - b.pos);

  return Decoration.set(
    widgets.map((w) =>
      Decoration.widget({
        widget: w.widget,
        block: true,
        side: 1,
      }).range(w.pos),
    ),
  );
}

// --- StateField providing block decorations ---
// Block decorations MUST come from a StateField, not a ViewPlugin.

export const suggestionWidgetPlugin = StateField.define<DecorationSet>({
  create(state) {
    const suggestions = state.field(suggestionsField);
    return buildDecorations(suggestions, state.doc.toString(), state.doc);
  },
  update(value, tr) {
    let rebuild = false;
    for (const effect of tr.effects) {
      if (
        effect.is(setSuggestionsEffect) ||
        effect.is(removeSuggestionEffect) ||
        effect.is(clearSuggestionsEffect)
      ) {
        rebuild = true;
      }
    }
    if (rebuild || tr.docChanged) {
      const suggestions = tr.state.field(suggestionsField);
      return buildDecorations(suggestions, tr.state.doc.toString(), tr.state.doc);
    }
    return value;
  },
  provide: (field) => EditorView.decorations.from(field),
});
