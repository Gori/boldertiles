interface Props {
  visible: boolean;
  onClick: () => void;
}

export function ScrollToBottom({ visible, onClick }: Props) {
  if (!visible) return null;

  return (
    <button
      onClick={onClick}
      className="absolute bottom-20 right-4 w-8 h-8 rounded-full bg-zinc-700 hover:bg-zinc-600 text-zinc-300 flex items-center justify-center shadow-lg transition-colors z-10"
      aria-label="Scroll to bottom"
    >
      &#8595;
    </button>
  );
}
