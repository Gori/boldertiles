import { useState, useEffect } from "react";
import type { ChatMessage } from "../types/state";
import { Message } from "./Message";
import { ScrollToBottom } from "./ScrollToBottom";
import { ErrorBoundary } from "./ErrorBoundary";
import { useAutoScroll } from "../hooks/useAutoScroll";

interface Props {
  messages: ChatMessage[];
  isLoading: boolean;
  onAnswerQuestion?: (toolId: string, text: string) => void;
}

export function MessageList({ messages, isLoading, onAnswerQuestion }: Props) {
  const { ref, onScroll, isAtBottom, scrollToBottom } = useAutoScroll(messages);

  const [showSpinner, setShowSpinner] = useState(isLoading);

  useEffect(() => {
    if (!isLoading) {
      setShowSpinner(false);
      return;
    }
    const timer = setTimeout(() => setShowSpinner(false), 8000);
    return () => clearTimeout(timer);
  }, [isLoading]);

  return (
    <div className="relative flex-1 min-h-0">
      <div
        ref={ref}
        onScroll={onScroll}
        className="h-full overflow-y-auto scrollbar-thin"
      >
        {messages.length === 0 ? (
          <div className="flex flex-col justify-end h-full px-4 pb-4">
            <div className="max-w-3xl mx-auto w-full">
              <h1 className="text-2xl font-bold text-zinc-100">Hello there!</h1>
              <p className="text-lg text-zinc-500 mt-1">How can I help you today?</p>
              {showSpinner && (
                <div className="flex items-center gap-2 mt-4 text-zinc-600">
                  <svg className="animate-spin h-3.5 w-3.5" viewBox="0 0 24 24" fill="none">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2.5" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  <span className="text-xs">Starting session&hellip;</span>
                </div>
              )}
            </div>
          </div>
        ) : (
          <>
            {messages.map((msg) => (
              <ErrorBoundary key={msg.id} name="Message">
                <Message message={msg} onAnswerQuestion={onAnswerQuestion} />
              </ErrorBoundary>
            ))}
            <div className="h-4" />
          </>
        )}
      </div>
      <ScrollToBottom
        visible={!isAtBottom && messages.length > 0}
        onClick={scrollToBottom}
      />
    </div>
  );
}
