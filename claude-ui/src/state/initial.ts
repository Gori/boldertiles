import type { ChatState } from "../types/state";

export const initialState: ChatState = {
  sessionId: null,
  model: null,
  autoApprove: false,
  planMode: false,
  messages: [],
  isStreaming: false,
  totalCost: 0,
  error: null,
  deniedTools: [],
};
