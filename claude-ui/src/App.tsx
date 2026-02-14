import { useChat } from "./hooks/useChat";
import { StatusBar } from "./components/StatusBar";
import { MessageList } from "./components/MessageList";
import { InputArea } from "./components/InputArea";
import { ErrorBoundary } from "./components/ErrorBoundary";

export function App() {
  const [state, actions] = useChat();

  return (
    <div className="flex flex-col h-screen bg-zinc-900 text-zinc-100">
      <StatusBar state={state} onToggleAutoApprove={actions.setAutoApprove} />

      {state.error && (
        <div className="px-4 py-2 bg-red-950/40 border-b border-red-900/50 text-red-400 text-xs shrink-0">
          {state.error}
        </div>
      )}

      {state.deniedTools.length > 0 && (
        <div className="px-4 py-2 bg-amber-950/30 border-b border-amber-900/40 text-amber-400 text-xs shrink-0 flex items-center gap-2 flex-wrap">
          <span>Tools denied:</span>
          {state.deniedTools.map((t) => (
            <button
              key={t.name}
              onClick={() => actions.addAllowedTool(t.name)}
              className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-amber-900/40 hover:bg-amber-800/50 transition-colors"
            >
              {t.name}
              <span className="text-[10px] text-amber-300">Allow</span>
            </button>
          ))}
        </div>
      )}

      <ErrorBoundary name="MessageList">
        <MessageList messages={state.messages} isLoading={state.model === null} onAnswerQuestion={actions.answerQuestion} />
      </ErrorBoundary>

      <InputArea
        isStreaming={state.isStreaming}
        onSend={actions.sendPrompt}
        onCancel={actions.cancel}
      />
    </div>
  );
}
