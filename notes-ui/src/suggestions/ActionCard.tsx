import type { Suggestion, PromoteContent, AdvancePhaseContent } from "../types";

interface Props {
  suggestion: Suggestion;
  onAccept: () => void;
  onDismiss: () => void;
}

const primaryBtn: React.CSSProperties = {
  background: "#1a3a5a",
  border: "1px solid #2a5a8a",
  borderRadius: "3px",
  color: "#80b8e8",
  padding: "6px 16px",
  cursor: "pointer",
  fontSize: "12px",
  fontFamily: "inherit",
  fontWeight: "bold",
};

const dismissBtn: React.CSSProperties = {
  background: "transparent",
  border: "1px solid #383838",
  borderRadius: "3px",
  color: "#777",
  padding: "6px 12px",
  cursor: "pointer",
  fontSize: "11px",
  fontFamily: "inherit",
};

export function ActionCard({ suggestion, onAccept, onDismiss }: Props) {
  const content = suggestion.content;

  let title: string;
  let subtitle: string;

  if (content.type === "promote") {
    const c = content as PromoteContent;
    title = "Promote to Feature";
    subtitle = `${c.title}: ${c.description}`;
  } else {
    const c = content as AdvancePhaseContent;
    title = `Advance to ${c.nextPhase.toUpperCase()}`;
    subtitle = c.reasoning;
  }

  return (
    <div>
      <div
        style={{
          fontSize: "10px",
          color: "#5a8ab8",
          marginBottom: "4px",
          textTransform: "uppercase",
          letterSpacing: "0.5px",
        }}
      >
        {content.type === "promote" ? "Feature" : "Phase"}
      </div>
      <div style={{ fontSize: "13px", color: "#c0d8f0", marginBottom: "4px" }}>
        {title}
      </div>
      <div style={{ fontSize: "11px", color: "#888", marginBottom: "10px", lineHeight: "1.4" }}>
        {subtitle}
      </div>
      <div style={{ display: "flex", gap: "8px" }}>
        <button style={primaryBtn} onClick={onAccept}>
          {content.type === "promote" ? "Promote" : "Advance"}
        </button>
        <button style={dismissBtn} onClick={onDismiss}>
          Dismiss
        </button>
      </div>
    </div>
  );
}
