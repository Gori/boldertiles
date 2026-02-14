export interface AskQuestionOption {
  label: string;
  description?: string;
}

export interface AskQuestionItem {
  question: string;
  options: AskQuestionOption[];
  multiSelect?: boolean;
}

export interface AskQuestionData {
  questions: AskQuestionItem[];
  answered?: boolean;
}

export interface ToolCall {
  id: string;
  name: string;
  input: Record<string, unknown>;
  result?: string;
  isError?: boolean;
  askQuestion?: AskQuestionData;
}

export interface ChatMessage {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  thinking?: string;
  toolCalls: ToolCall[];
  isStreaming: boolean;
  images?: string[];
  parentToolUseId?: string;
}

export interface ChatState {
  sessionId: string | null;
  model: string | null;
  autoApprove: boolean;
  planMode: boolean;
  messages: ChatMessage[];
  isStreaming: boolean;
  totalCost: number;
  error: string | null;
  deniedTools: Array<{ name: string; input: Record<string, unknown> }>;
  tools?: string[];
  mcpServers?: string[];
  permissionMode?: string;
  cwd?: string;
}
