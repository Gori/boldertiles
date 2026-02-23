import { useState } from "react";
import type { Suggestion, CritiqueContent, CritiqueSeverity } from "../types";

interface Props {
  suggestion: Suggestion;
  onRespond: (text: string) => void;
  onDismiss: () => void;
}

const severityColors: Record<CritiqueSeverity, string> = {
  strong: "#50b050",
  weak: "#e0c060",
  cut: "#e06050",
  rethink: "#c070d0",
};

const quoteStyle: React.CSSProperties = {
  background: "rgba(255,255,255,0.04)",
  borderLeft: "2px solid #444",
  padding: "4px 8px",
  margin: "6px 0",
  fontSize: "11px",
  color: "#999",
  whiteSpace: "pre-wrap",
};

const inputStyle: React.CSSProperties = {
  width: "100%",
  background: "#1a1a1a",
  border: "1px solid #383838",
  borderRadius: "3px",
  color: "#d0d0d0",
  padding: "6px 8px",
  fontSize: "12px",
  fontFamily: "inherit",
  marginTop: "6px",
  outline: "none",
  boxSizing: "border-box",
};

const buttonRow: React.CSSProperties = {
  display: "flex",
  gap: "8px",
  marginTop: "8px",
};

const respondBtn: React.CSSProperties = {
  background: "transparent",
  border: "1px solid #383838",
  borderRadius: "3px",
  color: "#aaa",
  padding: "4px 12px",
  cursor: "pointer",
  fontSize: "11px",
  fontFamily: "inherit",
};

const dismissBtn: React.CSSProperties = {
  background: "transparent",
  border: "1px solid #383838",
  borderRadius: "3px",
  color: "#777",
  padding: "4px 12px",
  cursor: "pointer",
  fontSize: "11px",
  fontFamily: "inherit",
};

export function CritiqueCard({ suggestion, onRespond, onDismiss }: Props) {
  const content = suggestion.content as CritiqueContent;
  const color = severityColors[content.severity] ?? "#888";
  const [showInput, setShowInput] = useState(false);
  const [inputText, setInputText] = useState("");

  return (
    <div style={{ borderLeft: `3px solid ${color}`, paddingLeft: "10px" }}>
      <div
        style={{
          fontSize: "9px",
          fontWeight: "bold",
          textTransform: "uppercase",
          letterSpacing: "1px",
          color,
          marginBottom: "6px",
        }}
      >
        {content.severity}
      </div>
      <div style={{ fontSize: "13px", color: "#d0d0d0", lineHeight: "1.5" }}>
        {content.critiqueText}
      </div>
      {content.targetText && (
        <div style={quoteStyle}>{content.targetText}</div>
      )}
      {!showInput ? (
        <div style={buttonRow}>
          <button style={respondBtn} onClick={() => setShowInput(true)}>
            Respond
          </button>
          <button style={dismissBtn} onClick={onDismiss}>
            Dismiss
          </button>
        </div>
      ) : (
        <div>
          <input
            style={inputStyle}
            placeholder="Your response..."
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && inputText.trim()) {
                onRespond(inputText.trim());
              }
            }}
            autoFocus
          />
        </div>
      )}
    </div>
  );
}
