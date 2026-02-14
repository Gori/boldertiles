/** Messages sent from JS → Swift via webkit.messageHandlers.claude.postMessage() */

export type BridgeMessage =
  | ReadyMessage
  | PromptMessage
  | CancelMessage
  | SetAutoApproveMessage
  | SetModelMessage
  | AddAllowedToolMessage;

export interface ReadyMessage {
  type: "ready";
}

export interface PromptMessage {
  type: "prompt";
  text: string;
  images?: string[];
}

export interface CancelMessage {
  type: "cancel";
}

export interface SetAutoApproveMessage {
  type: "set_auto_approve";
  enabled: boolean;
}

export interface SetModelMessage {
  type: "set_model";
  model: string;
}

export interface AddAllowedToolMessage {
  type: "add_allowed_tool";
  tool: string;
}
