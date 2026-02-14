import type { ChatMessage } from "../types/state";
import { Markdown } from "./Markdown";
import { ThinkingBlock } from "./ThinkingBlock";
import { ToolCall } from "./ToolCall";
import { AskQuestion } from "./AskQuestion";

interface Props {
  message: ChatMessage;
  onAnswerQuestion?: (toolId: string, text: string) => void;
}

export function Message({ message, onAnswerQuestion }: Props) {
  if (message.role === "system") {
    return (
      <div className="px-4 py-1.5 text-center">
        <span className="text-[11px] text-zinc-500 italic">{message.content}</span>
      </div>
    );
  }

  const isUser = message.role === "user";
  const hasActiveAskQuestion = message.toolCalls.some(
    (tc) => tc.askQuestion && !tc.askQuestion.answered,
  );

  return (
    <div className={`px-4 py-3 ${isUser ? "bg-zinc-800/30" : ""}`}>
      <div className="max-w-3xl mx-auto">
        <div className="text-[10px] uppercase tracking-wider text-zinc-600 mb-1 flex items-center gap-2">
          {isUser ? "You" : "Claude"}
          {message.parentToolUseId && (
            <span className="text-[9px] px-1.5 py-0.5 rounded bg-violet-900/40 text-violet-400 font-medium normal-case tracking-normal">
              sub-agent
            </span>
          )}
        </div>

        {message.thinking && <ThinkingBlock content={message.thinking} />}

        {message.images && message.images.length > 0 && (
          <div className="flex gap-2 flex-wrap my-1">
            {message.images.map((img, i) => (
              <img
                key={i}
                src={`data:image/png;base64,${img}`}
                alt={`Attachment ${i + 1}`}
                className="max-h-48 max-w-xs rounded border border-zinc-700 object-contain"
              />
            ))}
          </div>
        )}

        {!hasActiveAskQuestion && <Markdown content={message.content} />}

        {message.toolCalls.map((tc) =>
          tc.askQuestion ? (
            <AskQuestion
              key={tc.id}
              data={tc.askQuestion}
              onAnswer={(text) => onAnswerQuestion?.(tc.id, text)}
            />
          ) : (
            <ToolCall key={tc.id} tool={tc} />
          ),
        )}

        {message.isStreaming && !message.content && message.toolCalls.length === 0 && (
          <span className="inline-block w-2 h-4 bg-zinc-500 animate-pulse rounded-sm" />
        )}
      </div>
    </div>
  );
}
