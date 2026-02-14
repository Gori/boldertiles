import { useState } from "react";

interface Props {
  content: string;
}

export function ThinkingBlock({ content }: Props) {
  const [open, setOpen] = useState(false);

  if (!content) return null;

  return (
    <div className="my-2 border-l-2 border-indigo-500/40 rounded">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1.5 px-2 py-1 text-xs text-zinc-500 hover:text-zinc-300 transition-colors w-full text-left"
      >
        <span
          className="inline-block transition-transform text-[9px]"
          style={{ transform: open ? "rotate(90deg)" : undefined }}
        >
          &#9654;
        </span>
        Thinking
      </button>
      {open && (
        <div className="px-3 py-2 text-xs text-zinc-500 whitespace-pre-wrap border-t border-zinc-800">
          {content}
        </div>
      )}
    </div>
  );
}
