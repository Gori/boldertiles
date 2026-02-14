import type { ChatState, ChatMessage, AskQuestionItem } from "../types/state";
import type { ChatAction } from "./actions";

let msgCounter = 0;
function nextId(): string {
  return `msg-${++msgCounter}`;
}

function lastAssistantMessage(state: ChatState): ChatMessage | undefined {
  for (let i = state.messages.length - 1; i >= 0; i--) {
    if (state.messages[i]!.role === "assistant") return state.messages[i];
  }
  return undefined;
}

function updateLastAssistant(
  state: ChatState,
  updater: (msg: ChatMessage) => ChatMessage,
): ChatState {
  const last = lastAssistantMessage(state);
  if (!last) return state;
  return {
    ...state,
    messages: state.messages.map((m) => (m === last ? updater(m) : m)),
  };
}

export function reducer(state: ChatState, action: ChatAction): ChatState {
  switch (action.type) {
    case "init":
      return {
        ...state,
        sessionId: action.sessionId || state.sessionId,
        model: action.model,
        autoApprove: action.autoApprove,
        error: null,
        tools: action.tools ?? state.tools,
        mcpServers: action.mcpServers ?? state.mcpServers,
        permissionMode: action.permissionMode ?? state.permissionMode,
        cwd: action.cwd ?? state.cwd,
      };

    case "add_user_message":
      return {
        ...state,
        messages: [
          ...state.messages,
          {
            id: nextId(),
            role: "user",
            content: action.text,
            toolCalls: [],
            isStreaming: false,
            images: action.images,
          },
        ],
        error: null,
        deniedTools: [],
      };

    case "stream_start": {
      const newMsg: ChatMessage = {
        id: nextId(),
        role: "assistant",
        content: "",
        toolCalls: [],
        isStreaming: true,
        parentToolUseId: action.parentToolUseId,
      };
      return {
        ...state,
        isStreaming: true,
        messages: [...state.messages, newMsg],
      };
    }

    case "thinking_start": {
      const existing = lastAssistantMessage(state);
      if (existing?.isStreaming) {
        return updateLastAssistant(state, (m) => ({
          ...m,
          thinking: m.thinking ?? "",
        }));
      }
      const newMsg: ChatMessage = {
        id: nextId(),
        role: "assistant",
        content: "",
        thinking: "",
        toolCalls: [],
        isStreaming: true,
        parentToolUseId: action.parentToolUseId,
      };
      return {
        ...state,
        isStreaming: true,
        messages: [...state.messages, newMsg],
      };
    }

    case "text_delta":
      return updateLastAssistant(state, (m) => ({
        ...m,
        content: m.content + action.text,
      }));

    case "thinking_delta":
      return updateLastAssistant(state, (m) => ({
        ...m,
        thinking: (m.thinking ?? "") + action.text,
      }));

    case "tool_use": {
      let askQuestion: { questions: AskQuestionItem[]; answered?: boolean } | undefined;
      if (action.name === "AskUserQuestion") {
        const input = action.input as { questions?: AskQuestionItem[] };
        if (input.questions) {
          askQuestion = { questions: input.questions };
        }
      }
      return updateLastAssistant(state, (m) => ({
        ...m,
        toolCalls: [
          ...m.toolCalls,
          {
            id: action.id,
            name: action.name,
            input: action.input,
            askQuestion,
          },
        ],
      }));
    }

    case "tool_input":
      return updateLastAssistant(state, (m) => ({
        ...m,
        toolCalls: m.toolCalls.map((tc) => {
          if (tc.id !== action.id) return tc;
          const updated = { ...tc, input: action.input };
          if (tc.name === "AskUserQuestion") {
            const input = action.input as { questions?: AskQuestionItem[] };
            if (input.questions) {
              updated.askQuestion = { questions: input.questions };
            }
          }
          return updated;
        }),
      }));

    case "tool_result":
      return updateLastAssistant(state, (m) => ({
        ...m,
        toolCalls: m.toolCalls.map((tc) =>
          tc.id === action.toolUseId
            ? { ...tc, result: action.content, isError: action.isError }
            : tc,
        ),
      }));

    case "turn_complete":
      return {
        ...updateLastAssistant(state, (m) => ({
          ...m,
          isStreaming: false,
        })),
        isStreaming: false,
        totalCost: action.cost ?? state.totalCost,
        error: action.errorMessage ?? state.error,
      };

    case "denied_tools":
      return { ...state, deniedTools: action.tools };

    case "error":
      return { ...state, error: action.message, isStreaming: false };

    case "add_system_message":
      return {
        ...state,
        messages: [
          ...state.messages,
          {
            id: nextId(),
            role: "system",
            content: action.text,
            toolCalls: [],
            isStreaming: false,
          },
        ],
      };

    case "set_plan_mode":
      return { ...state, planMode: action.enabled };

    case "answer_ask_question":
      return updateLastAssistant(state, (m) => ({
        ...m,
        toolCalls: m.toolCalls.map((tc) =>
          tc.id === action.toolId && tc.askQuestion
            ? { ...tc, askQuestion: { ...tc.askQuestion, answered: true } }
            : tc,
        ),
      }));

    case "system_message":
      return {
        ...state,
        messages: [
          ...state.messages,
          {
            id: nextId(),
            role: "system" as const,
            content: action.text,
            toolCalls: [],
            isStreaming: false,
          },
        ],
      };
  }
}
