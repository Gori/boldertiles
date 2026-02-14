import type { BridgeEvent } from "../types/events";

export interface AddUserMessageAction {
  type: "add_user_message";
  text: string;
  images?: string[];
}

export interface AddSystemMessageAction {
  type: "add_system_message";
  text: string;
}

export interface SetPlanModeAction {
  type: "set_plan_mode";
  enabled: boolean;
}

export interface AnswerAskQuestionAction {
  type: "answer_ask_question";
  toolId: string;
}

/** All actions the reducer handles. Bridge events pass through directly. */
export type ChatAction =
  | BridgeEvent
  | AddUserMessageAction
  | AddSystemMessageAction
  | SetPlanModeAction
  | AnswerAskQuestionAction;
