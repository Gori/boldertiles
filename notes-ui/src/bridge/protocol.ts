import type { Suggestion } from "../types";

// Swift → JS events
export type BridgeEvent =
  | SetContentEvent
  | SetSuggestionsEvent
  | RemoveSuggestionEvent
  | ClearSuggestionsEvent
  | SetFontSizeEvent
  | SetEditableEvent
  | FocusEvent;

export interface SetContentEvent {
  type: "setContent";
  text: string;
}

export interface SetSuggestionsEvent {
  type: "setSuggestions";
  suggestions: Suggestion[];
}

export interface RemoveSuggestionEvent {
  type: "removeSuggestion";
  id: string;
}

export interface ClearSuggestionsEvent {
  type: "clearSuggestions";
}

export interface SetFontSizeEvent {
  type: "setFontSize";
  size: number;
}

export interface SetEditableEvent {
  type: "setEditable";
  editable: boolean;
}

export interface FocusEvent {
  type: "focus";
}

// JS → Swift messages
export type BridgeMessage =
  | ContentChangedMessage
  | SuggestionActionMessage
  | KeyCommandMessage
  | ReadyMessage;

export interface ContentChangedMessage {
  type: "contentChanged";
  text: string;
}

export interface SuggestionActionMessage {
  type: "suggestionAction";
  id: string;
  action: "accept" | "reject" | "choice" | "response" | "dismiss";
  choiceIndex?: number;
  responseText?: string;
}

export interface KeyCommandMessage {
  type: "keyCommand";
  key: "tab" | "escape";
}

export interface ReadyMessage {
  type: "ready";
}
