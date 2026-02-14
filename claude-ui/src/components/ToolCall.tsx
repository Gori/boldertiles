import { useState } from "react";
import type { ToolCall as ToolCallType } from "../types/state";

interface Props {
  tool: ToolCallType;
}

export function ToolCall({ tool }: Props) {
  const [open, setOpen] = useState(false);

  const statusIcon = tool.result === undefined ? "\u2026" : tool.isError ? "\u2717" : "\u2713";
  const statusColor =
    tool.result === undefined
      ? "text-yellow-500"
      : tool.isError
        ? "text-red-400"
        : "text-green-400";

  return (
    <div className="my-2 rounded-md border border-zinc-700 bg-zinc-900/50 text-[13px]">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-2 w-full px-3 py-1.5 text-left hover:bg-zinc-800/40 transition-colors"
      >
        <span className={statusColor}>{statusIcon}</span>
        <span className="text-zinc-400 font-medium">{tool.name}</span>
        <span
          className="ml-auto text-[9px] text-zinc-600 transition-transform"
          style={{ transform: open ? "rotate(90deg)" : undefined }}
        >
          &#9654;
        </span>
      </button>
      {open && (
        <div className="border-t border-zinc-700 px-3 py-2 space-y-2">
          {Object.keys(tool.input).length > 0 && (
            <div>
              <div className="text-[10px] uppercase tracking-wider text-zinc-600 mb-1">Input</div>
              <pre className="text-xs text-zinc-400 whitespace-pre-wrap break-all overflow-x-auto">
                {JSON.stringify(tool.input, null, 2)}
              </pre>
            </div>
          )}
          {tool.result !== undefined && (
            <div>
              <div className="text-[10px] uppercase tracking-wider text-zinc-600 mb-1">
                {tool.isError ? "Error" : "Output"}
              </div>
              <pre
                className={`text-xs whitespace-pre-wrap break-all overflow-x-auto ${tool.isError ? "text-red-400" : "text-zinc-400"}`}
              >
                {tool.result}
              </pre>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
