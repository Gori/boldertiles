export type SuggestionType =
  | "rewrite"
  | "append"
  | "insert"
  | "compression"
  | "question"
  | "critique"
  | "promote"
  | "advancePhase";

export type CritiqueSeverity = "strong" | "weak" | "cut" | "rethink";

export type SuggestionState = "pending" | "accepted" | "rejected" | "expired";

export interface RewriteContent {
  type: "rewrite";
  original: string;
  replacement: string;
  contextBefore: string;
  contextAfter: string;
}

export interface AppendContent {
  type: "append";
  text: string;
}

export interface InsertContent {
  type: "insert";
  text: string;
  afterContext: string;
}

export interface CompressionContent {
  type: "compression";
  original: string;
  replacement: string;
  contextBefore: string;
  contextAfter: string;
}

export interface QuestionContent {
  type: "question";
  text: string;
  choices: string[];
}

export interface CritiqueContent {
  type: "critique";
  severity: CritiqueSeverity;
  targetText: string;
  critiqueText: string;
  contextBefore: string;
  contextAfter: string;
}

export interface PromoteContent {
  type: "promote";
  title: string;
  description: string;
}

export interface AdvancePhaseContent {
  type: "advancePhase";
  nextPhase: string;
  reasoning: string;
}

export type SuggestionContent =
  | RewriteContent
  | AppendContent
  | InsertContent
  | CompressionContent
  | QuestionContent
  | CritiqueContent
  | PromoteContent
  | AdvancePhaseContent;

export interface Suggestion {
  id: string;
  type: SuggestionType;
  content: SuggestionContent;
  reasoning: string;
  createdAt: string;
  state: SuggestionState;
}
