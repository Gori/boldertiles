import type { Suggestion, AppendContent, InsertContent } from "../types";

interface Props {
  suggestion: Suggestion;
  onAccept: () => void;
  onReject: () => void;
}

const textStyle: React.CSSProperties = {
  background: "rgba(80, 180, 80, 0.10)",
  color: "#90d090",
  padding: "6px 8px",
  borderRadius: "3px",
  whiteSpace: "pre-wrap",
  fontSize: "12px",
  lineHeight: "1.5",
  borderLeft: "2px solid #4a8a4a",
};

const buttonRow: React.CSSProperties = {
  display: "flex",
  gap: "8px",
  marginTop: "10px",
};

const acceptBtn: React.CSSProperties = {
  background: "#2a5a2a",
  border: "1px solid #3a7a3a",
  borderRadius: "3px",
  color: "#90d090",
  padding: "4px 12px",
  cursor: "pointer",
  fontSize: "11px",
  fontFamily: "inherit",
};

const rejectBtn: React.CSSProperties = {
  background: "#3a2a2a",
  border: "1px solid #5a3a3a",
  borderRadius: "3px",
  color: "#c08080",
  padding: "4px 12px",
  cursor: "pointer",
  fontSize: "11px",
  fontFamily: "inherit",
};

export function AppendCard({ suggestion, onAccept, onReject }: Props) {
  const content = suggestion.content as AppendContent | InsertContent;
  const label = content.type === "append" ? "Append" : "Insert";

  return (
    <div>
      <div
        style={{
          fontSize: "10px",
          color: "#666",
          marginBottom: "6px",
          textTransform: "uppercase",
          letterSpacing: "0.5px",
        }}
      >
        {label}
      </div>
      <div style={textStyle}>{content.text}</div>
      <div style={buttonRow}>
        <button style={acceptBtn} onClick={onAccept}>
          Accept
        </button>
        <button style={rejectBtn} onClick={onReject}>
          Reject
        </button>
      </div>
    </div>
  );
}
