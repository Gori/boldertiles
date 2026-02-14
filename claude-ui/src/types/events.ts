/** Events sent from Swift → JS via window.__bolder__.onEvent() */

export type BridgeEvent =
  | InitEvent
  | StreamStartEvent
  | ThinkingStartEvent
  | TextDeltaEvent
  | ThinkingDeltaEvent
  | ToolUseEvent
  | ToolInputEvent
  | ToolResultEvent
  | TurnCompleteEvent
  | DeniedToolsEvent
  | ErrorEvent
  | SystemMessageEvent;

export interface InitEvent {
  type: "init";
  sessionId: string;
  model: string;
  autoApprove: boolean;
  tools?: string[];
  mcpServers?: string[];
  permissionMode?: string;
  cwd?: string;
}

export interface StreamStartEvent {
  type: "stream_start";
  parentToolUseId?: string;
}

export interface ThinkingStartEvent {
  type: "thinking_start";
  parentToolUseId?: string;
}

export interface TextDeltaEvent {
  type: "text_delta";
  text: string;
}

export interface ThinkingDeltaEvent {
  type: "thinking_delta";
  text: string;
}

export interface ToolUseEvent {
  type: "tool_use";
  id: string;
  name: string;
  input: Record<string, unknown>;
}

export interface ToolInputEvent {
  type: "tool_input";
  id: string;
  input: Record<string, unknown>;
}

export interface ToolResultEvent {
  type: "tool_result";
  toolUseId: string;
  content: string;
  isError: boolean;
}

export interface TurnCompleteEvent {
  type: "turn_complete";
  usage?: {
    input_tokens?: number;
    output_tokens?: number;
    cache_creation_input_tokens?: number;
    cache_read_input_tokens?: number;
  };
  cost?: number;
  errorMessage?: string;
}

export interface DeniedToolsEvent {
  type: "denied_tools";
  tools: Array<{ name: string; input: Record<string, unknown> }>;
}

export interface ErrorEvent {
  type: "error";
  message: string;
}

export interface SystemMessageEvent {
  type: "system_message";
  text: string;
}
