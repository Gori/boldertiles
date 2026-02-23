import type { ReactNode } from "react";
import type { Suggestion } from "../types";

interface Props {
  suggestion: Suggestion;
  children: ReactNode;
}

const cardStyle: React.CSSProperties = {
  background: "#212121",
  border: "1px solid #383838",
  borderRadius: "4px",
  padding: "12px 14px",
  margin: "6px 0",
  fontFamily: "'JetBrains Mono', ui-monospace, monospace",
  fontSize: "13px",
  lineHeight: "1.5",
  color: "#d0d0d0",
  animation: "fadeIn 200ms ease-out",
};

const reasoningStyle: React.CSSProperties = {
  fontSize: "11px",
  color: "#777",
  marginTop: "8px",
  lineHeight: "1.4",
  cursor: "pointer",
};

export function SuggestionCard({ suggestion, children }: Props) {
  return (
    <div style={cardStyle}>
      {children}
      {suggestion.reasoning && (
        <details>
          <summary style={reasoningStyle}>{suggestion.reasoning}</summary>
        </details>
      )}
      <style>{`
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(-4px); }
          to { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
}
