import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import type { Suggestion } from "../types";
import { SuggestionCard } from "./SuggestionCard";
import { RewriteCard } from "./RewriteCard";
import { QuestionCard } from "./QuestionCard";
import { CritiqueCard } from "./CritiqueCard";
import { ActionCard } from "./ActionCard";
import { AppendCard } from "./AppendCard";

interface Props {
  suggestions: Suggestion[];
  onAction: (id: string, action: string, choiceIndex?: number, responseText?: string) => void;
}

export function SuggestionPortal({ suggestions, onAction }: Props) {
  // Force a re-render after CM widgets are in the DOM.
  // CM dispatch is synchronous but React render may happen before
  // the widget DOM nodes are flushed, so we scan after a microtask.
  const [tick, setTick] = useState(0);

  useEffect(() => {
    // After each render triggered by suggestion changes, bump tick
    // so we re-render once more with the containers now in the DOM.
    if (suggestions.length > 0) {
      const id = requestAnimationFrame(() => setTick((n) => n + 1));
      return () => cancelAnimationFrame(id);
    }
  }, [suggestions]);

  // Scan for widget containers in the DOM right now (during render)
  const containerMap = new Map<string, HTMLElement>();
  const containers = document.querySelectorAll<HTMLElement>(
    ".suggestion-widget[data-suggestion-id]"
  );
  containers.forEach((el) => {
    const id = el.dataset["suggestionId"];
    if (id) containerMap.set(id, el);
  });

  // Debug: log what we found
  if (suggestions.length > 0) {
    console.log(
      `[SuggestionPortal] tick=${tick}, suggestions=${suggestions.length}, containers=${containerMap.size}`,
      [...containerMap.keys()]
    );
  }

  const portals: React.ReactNode[] = [];

  for (const suggestion of suggestions) {
    const container = containerMap.get(suggestion.id);
    if (!container) continue;

    const card = renderCard(suggestion, onAction);
    portals.push(createPortal(card, container, suggestion.id));
  }

  return <>{portals}</>;
}

function renderCard(
  suggestion: Suggestion,
  onAction: (id: string, action: string, choiceIndex?: number, responseText?: string) => void,
): React.ReactNode {
  const { content } = suggestion;

  switch (content.type) {
    case "rewrite":
    case "compression":
      return (
        <SuggestionCard suggestion={suggestion}>
          <RewriteCard
            suggestion={suggestion}
            onAccept={() => onAction(suggestion.id, "accept")}
            onReject={() => onAction(suggestion.id, "reject")}
          />
        </SuggestionCard>
      );
    case "question":
      return (
        <SuggestionCard suggestion={suggestion}>
          <QuestionCard
            suggestion={suggestion}
            onChoose={(idx) => onAction(suggestion.id, "choice", idx)}
            onRespond={(text) => onAction(suggestion.id, "response", undefined, text)}
            onDismiss={() => onAction(suggestion.id, "dismiss")}
          />
        </SuggestionCard>
      );
    case "critique":
      return (
        <SuggestionCard suggestion={suggestion}>
          <CritiqueCard
            suggestion={suggestion}
            onRespond={(text) => onAction(suggestion.id, "response", undefined, text)}
            onDismiss={() => onAction(suggestion.id, "dismiss")}
          />
        </SuggestionCard>
      );
    case "promote":
    case "advancePhase":
      return (
        <SuggestionCard suggestion={suggestion}>
          <ActionCard
            suggestion={suggestion}
            onAccept={() => onAction(suggestion.id, "accept")}
            onDismiss={() => onAction(suggestion.id, "dismiss")}
          />
        </SuggestionCard>
      );
    case "append":
    case "insert":
      return (
        <SuggestionCard suggestion={suggestion}>
          <AppendCard
            suggestion={suggestion}
            onAccept={() => onAction(suggestion.id, "accept")}
            onReject={() => onAction(suggestion.id, "reject")}
          />
        </SuggestionCard>
      );
  }
}
