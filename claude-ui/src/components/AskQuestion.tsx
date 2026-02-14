import { useState } from "react";
import type { AskQuestionData } from "../types/state";

interface Props {
  data: AskQuestionData;
  onAnswer: (text: string) => void;
}

export function AskQuestion({ data, onAnswer }: Props) {
  const [selected, setSelected] = useState<Record<number, Set<string>>>({});

  if (data.answered) {
    return (
      <div className="my-2 rounded-md border border-zinc-700 bg-zinc-900/50 px-3 py-2 text-[13px] text-zinc-500 italic">
        Question answered
      </div>
    );
  }

  function handleSelect(qIdx: number, label: string, multi?: boolean) {
    setSelected((prev) => {
      const cur = prev[qIdx] ?? new Set<string>();
      const next = new Set(cur);
      if (multi) {
        if (next.has(label)) next.delete(label);
        else next.add(label);
      } else {
        next.clear();
        next.add(label);
      }
      return { ...prev, [qIdx]: next };
    });
  }

  function handleSubmit() {
    const parts: string[] = [];
    for (let i = 0; i < data.questions.length; i++) {
      const q = data.questions[i]!;
      const sel = selected[i];
      if (sel && sel.size > 0) {
        parts.push(`${q.question} ${[...sel].join(", ")}`);
      }
    }
    if (parts.length > 0) {
      onAnswer(parts.join("\n"));
    }
  }

  const anySelected = Object.values(selected).some((s) => s.size > 0);

  return (
    <div className="my-2 rounded-md border border-indigo-800/50 bg-indigo-950/20 text-[13px]">
      {data.questions.map((q, qIdx) => (
        <div key={qIdx} className="px-3 py-2">
          <div className="text-zinc-300 mb-2">{q.question}</div>
          <div className="flex flex-wrap gap-1.5">
            {q.options.map((opt) => {
              const isSelected = selected[qIdx]?.has(opt.label) ?? false;
              return (
                <button
                  key={opt.label}
                  onClick={() => handleSelect(qIdx, opt.label, q.multiSelect)}
                  className={`px-2.5 py-1 rounded text-xs border transition-colors ${
                    isSelected
                      ? "bg-indigo-600 border-indigo-500 text-white"
                      : "bg-zinc-800/60 border-zinc-700 text-zinc-300 hover:border-zinc-500"
                  }`}
                  title={opt.description}
                >
                  {opt.label}
                </button>
              );
            })}
          </div>
        </div>
      ))}
      <div className="px-3 py-2 border-t border-indigo-800/30">
        <button
          onClick={handleSubmit}
          disabled={!anySelected}
          className="px-3 py-1 rounded text-xs bg-indigo-600 text-white hover:bg-indigo-500 disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          Send
        </button>
      </div>
    </div>
  );
}
