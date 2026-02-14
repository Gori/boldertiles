import { useReducer, useCallback, useEffect } from "react";
import { postMessage } from "../bridge";
import { initialState } from "../state/initial";
import { reducer } from "../state/reducer";
import { useBridge } from "./useBridge";
import type { ChatState } from "../types/state";

const AVAILABLE_MODELS = ["sonnet", "opus", "haiku"];

const PLAN_PREFIX =
  "You are in plan mode. Before writing any code, analyze the request and produce a detailed implementation plan. " +
  "Describe what files need to change, what the changes are, and why. Do not write code yet.\n\n";

export interface ChatActions {
  sendPrompt: (text: string, images?: string[]) => void;
  answerQuestion: (toolId: string, text: string) => void;
  cancel: () => void;
  setAutoApprove: (enabled: boolean) => void;
  addAllowedTool: (tool: string) => void;
}

export function useChat(): [ChatState, ChatActions] {
  const [state, dispatch] = useReducer(reducer, initialState);

  useBridge(dispatch);

  useEffect(() => {
    postMessage({ type: "ready" });
  }, []);

  const sendPrompt = useCallback(
    (text: string, images?: string[]) => {
      const trimmed = text.trim();

      // Handle slash commands
      if (trimmed.startsWith("/")) {
        const parts = trimmed.split(/\s+/);
        const cmd = parts[0]!.toLowerCase();
        const arg = parts.slice(1).join(" ").trim();

        switch (cmd) {
          case "/model": {
            if (!arg) {
              dispatch({
                type: "add_system_message",
                text: `Available models: ${AVAILABLE_MODELS.join(", ")}`,
              });
            } else {
              dispatch({
                type: "add_system_message",
                text: `Switching to ${arg}...`,
              });
              postMessage({ type: "set_model", model: arg });
            }
            return;
          }

          case "/plan": {
            const newMode = !state.planMode;
            dispatch({ type: "set_plan_mode", enabled: newMode });
            dispatch({
              type: "add_system_message",
              text: newMode ? "Plan mode enabled" : "Plan mode disabled",
            });
            return;
          }

          default: {
            dispatch({
              type: "add_system_message",
              text: `Unknown command: ${cmd}`,
            });
            return;
          }
        }
      }

      // Normal prompt
      const promptText = state.planMode ? PLAN_PREFIX + text : text;
      dispatch({ type: "add_user_message", text, images });
      postMessage({ type: "prompt", text: promptText, images });
    },
    [state.planMode],
  );

  const cancel = useCallback(() => {
    postMessage({ type: "cancel" });
  }, []);

  const setAutoApprove = useCallback((enabled: boolean) => {
    postMessage({ type: "set_auto_approve", enabled });
  }, []);

  const answerQuestion = useCallback((toolId: string, text: string) => {
    dispatch({ type: "answer_ask_question", toolId });
    dispatch({ type: "add_user_message", text });
    postMessage({ type: "prompt", text });
  }, []);

  const addAllowedTool = useCallback((tool: string) => {
    dispatch({ type: "add_system_message", text: `Allowing tool: ${tool}...` });
    postMessage({ type: "add_allowed_tool", tool });
  }, []);

  return [state, { sendPrompt, answerQuestion, cancel, setAutoApprove, addAllowedTool }];
}
