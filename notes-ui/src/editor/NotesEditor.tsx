import { useRef, useEffect, useCallback, useState } from "react";
import { EditorView } from "@codemirror/view";
import { EditorState, Compartment } from "@codemirror/state";
import { buildExtensions } from "./extensions";
import {
  suggestionsField,
  setSuggestionsEffect,
  removeSuggestionEffect,
  clearSuggestionsEffect,
  suggestionWidgetPlugin,
} from "./suggestionWidgets";
import { SuggestionPortal } from "../suggestions/SuggestionPortal";
import { useBridge } from "../bridge/useBridge";
import { useBridgeContext } from "../bridge/BridgeContext";
import type { Suggestion } from "../types";
import type { BridgeEvent } from "../bridge/protocol";

// Compartment for runtime reconfiguration of editable state
const editableCompartment = new Compartment();

export function NotesEditor() {
  const containerRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView | null>(null);
  const { postMessage } = useBridgeContext();
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const hasSuggestions = suggestions.some((s) => s.state === "pending");

  const onContentChange = useCallback(
    (text: string) => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => {
        postMessage({ type: "contentChanged", text });
      }, 300);
    },
    [postMessage],
  );

  const onKeyCommand = useCallback(
    (key: "tab" | "escape"): boolean => {
      if (!hasSuggestions) return false;
      postMessage({ type: "keyCommand", key });
      return true;
    },
    [hasSuggestions, postMessage],
  );

  const onSuggestionAction = useCallback(
    (id: string, action: string, choiceIndex?: number, responseText?: string) => {
      postMessage({
        type: "suggestionAction",
        id,
        action: action as "accept" | "reject" | "choice" | "response" | "dismiss",
        choiceIndex,
        responseText,
      });
    },
    [postMessage],
  );

  // Initialize CodeMirror
  useEffect(() => {
    console.log("[NotesEditor] useEffect — mounting CodeMirror, container:", containerRef.current);
    if (!containerRef.current) return;

    const extensions = buildExtensions({
      onContentChange,
      onKeyCommand,
    });

    const state = EditorState.create({
      doc: "",
      extensions: [
        suggestionsField,
        suggestionWidgetPlugin,
        editableCompartment.of(EditorView.editable.of(true)),
        ...extensions,
      ],
    });

    const view = new EditorView({
      state,
      parent: containerRef.current,
    });

    viewRef.current = view;
    console.log("[NotesEditor] CodeMirror mounted, dom:", view.dom.offsetWidth, "x", view.dom.offsetHeight);

    // Notify Swift we're ready
    console.log("[NotesEditor] posting 'ready' to Swift");
    postMessage({ type: "ready" });

    return () => {
      view.destroy();
      viewRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Handle bridge events
  const handleEvent = useCallback(
    (event: BridgeEvent) => {
      console.log("[NotesEditor] handleEvent:", event.type, event);
      const view = viewRef.current;
      if (!view) {
        console.warn("[NotesEditor] handleEvent but no view!");
        return;
      }

      switch (event.type) {
        case "setContent": {
          const currentDoc = view.state.doc.toString();
          if (currentDoc !== event.text) {
            view.dispatch({
              changes: {
                from: 0,
                to: view.state.doc.length,
                insert: event.text,
              },
            });
          }
          break;
        }
        case "setSuggestions": {
          const pending = event.suggestions.filter((s) => s.state === "pending");
          console.log("[NotesEditor] setSuggestions:", event.suggestions.length, "total,", pending.length, "pending", pending.map(s => ({ id: s.id, type: s.content.type })));
          setSuggestions(pending);
          view.dispatch({
            effects: setSuggestionsEffect.of(pending),
          });
          // Check if widgets were created
          requestAnimationFrame(() => {
            const widgets = document.querySelectorAll(".suggestion-widget");
            console.log("[NotesEditor] widget DOM elements after dispatch:", widgets.length);
          });
          break;
        }
        case "removeSuggestion": {
          setSuggestions((prev) => prev.filter((s) => s.id !== event.id));
          view.dispatch({
            effects: removeSuggestionEffect.of(event.id),
          });
          break;
        }
        case "clearSuggestions": {
          setSuggestions([]);
          view.dispatch({
            effects: clearSuggestionsEffect.of(null),
          });
          break;
        }
        case "setFontSize": {
          view.dom.style.fontSize = `${event.size}px`;
          break;
        }
        case "setEditable": {
          view.dispatch({
            effects: editableCompartment.reconfigure(
              EditorView.editable.of(event.editable),
            ),
          });
          break;
        }
        case "focus": {
          view.focus();
          break;
        }
      }
    },
    [],
  );

  useBridge(handleEvent);

  return (
    <div
      ref={containerRef}
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: "#1a1a1a",
        overflow: "auto",
      }}
    >
      <SuggestionPortal
        suggestions={suggestions}
        onAction={onSuggestionAction}
      />
    </div>
  );
}
