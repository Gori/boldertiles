import type { ChatState } from "../types/state";

interface Props {
  state: ChatState;
  onToggleAutoApprove: (enabled: boolean) => void;
}

function formatCost(cost: number): string {
  if (cost === 0) return "";
  return `$${cost.toFixed(4)}`;
}

export function StatusBar({ state, onToggleAutoApprove }: Props) {
  return (
    <div className="flex items-center justify-between px-3 py-1.5 bg-zinc-950 border-b border-zinc-800 text-[11px] select-none shrink-0">
      <div className="flex items-center gap-3">
        {state.cwd && (
          <span className="text-zinc-600" title={state.cwd}>
            {state.cwd.split("/").pop() || state.cwd}
          </span>
        )}
        {state.model && <span className="text-zinc-500">{state.model}</span>}
        {state.sessionId && (
          <span className="text-zinc-700 truncate max-w-[120px]" title={state.sessionId}>
            {state.sessionId.slice(0, 8)}
          </span>
        )}
        {state.totalCost > 0 && (
          <span className="text-zinc-600">{formatCost(state.totalCost)}</span>
        )}
      </div>
      <div className="flex items-center gap-3">
        {state.planMode && (
          <span className="text-indigo-400/80 font-medium">PLAN</span>
        )}
        {state.autoApprove && (
          <span className="text-amber-500/80 font-medium">AUTO</span>
        )}
        <label className="flex items-center gap-1.5 text-zinc-600 cursor-pointer">
          <input
            type="checkbox"
            checked={state.autoApprove}
            onChange={(e) => onToggleAutoApprove(e.target.checked)}
            className="accent-indigo-500"
          />
          Auto-approve
        </label>
      </div>
    </div>
  );
}
