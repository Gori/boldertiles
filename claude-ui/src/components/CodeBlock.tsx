import { useState, useCallback } from "react";

interface Props {
  language: string;
  code: string;
}

export function CodeBlock({ language, code }: Props) {
  const [copied, setCopied] = useState(false);

  const copy = useCallback(() => {
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    });
  }, [code]);

  return (
    <div className="my-2 rounded-md border border-zinc-700 bg-zinc-950 overflow-hidden text-[13px]">
      <div className="flex items-center justify-between px-3 py-1 bg-zinc-800/60 border-b border-zinc-700">
        <span className="text-zinc-500 text-xs">{language || "text"}</span>
        <button
          onClick={copy}
          className="text-xs text-zinc-500 hover:text-zinc-300 transition-colors"
        >
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
      <pre className="p-3 overflow-x-auto">
        <code className="text-zinc-300 whitespace-pre">{code}</code>
      </pre>
    </div>
  );
}
