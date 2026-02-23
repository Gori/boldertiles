import { useState } from "react";
import type { Suggestion, QuestionContent } from "../types";

interface Props {
  suggestion: Suggestion;
  onChoose: (index: number) => void;
  onRespond: (text: string) => void;
  onDismiss: () => void;
}

const questionStyle: React.CSSProperties = {
  color: "#e0c070",
  fontSize: "13px",
  marginBottom: "10px",
  lineHeight: "1.5",
};

const chipRow: React.CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: "6px",
  marginBottom: "8px",
};

const chipStyle: React.CSSProperties = {
  background: "#2a2a20",
  border: "1px solid #4a4a30",
  borderRadius: "12px",
  color: "#d0c090",
  padding: "4px 12px",
  cursor: "pointer",
  fontSize: "12px",
  fontFamily: "inherit",
  transition: "background 150ms",
};

const writeOwnStyle: React.CSSProperties = {
  fontSize: "11px",
  color: "#777",
  cursor: "pointer",
  border: "none",
  background: "none",
  padding: "2px 0",
  fontFamily: "inherit",
  textDecoration: "underline",
  textDecorationColor: "#555",
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

const dismissBtn: React.CSSProperties = {
  background: "transparent",
  border: "1px solid #383838",
  borderRadius: "3px",
  color: "#777",
  padding: "4px 12px",
  cursor: "pointer",
  fontSize: "11px",
  fontFamily: "inherit",
  marginTop: "8px",
};

export function QuestionCard({ suggestion, onChoose, onRespond, onDismiss }: Props) {
  const content = suggestion.content as QuestionContent;
  const [showInput, setShowInput] = useState(false);
  const [inputText, setInputText] = useState("");

  return (
    <div>
      <div style={questionStyle}>{content.text}</div>
      <div style={chipRow}>
        {content.choices.map((choice, i) => (
          <button
            key={i}
            style={chipStyle}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = "#3a3a28";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = "#2a2a20";
            }}
            onClick={() => onChoose(i)}
          >
            {choice}
          </button>
        ))}
      </div>
      {!showInput ? (
        <button style={writeOwnStyle} onClick={() => setShowInput(true)}>
          Write my own...
        </button>
      ) : (
        <div>
          <input
            style={inputStyle}
            placeholder="Type your answer..."
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
      <div>
        <button style={dismissBtn} onClick={onDismiss}>
          Dismiss
        </button>
      </div>
    </div>
  );
}
