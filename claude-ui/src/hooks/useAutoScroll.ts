import { useRef, useEffect, useCallback, useState } from "react";

/**
 * Auto-scrolls a container to the bottom when content changes,
 * but only if the user hasn't scrolled up manually.
 */
export function useAutoScroll(dep: unknown) {
  const ref = useRef<HTMLDivElement>(null);
  const stickRef = useRef(true);
  const [isAtBottom, setIsAtBottom] = useState(true);

  const onScroll = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    const gap = el.scrollHeight - el.scrollTop - el.clientHeight;
    const atBottom = gap < 40;
    stickRef.current = atBottom;
    setIsAtBottom((prev) => (prev !== atBottom ? atBottom : prev));
  }, []);

  useEffect(() => {
    if (stickRef.current && ref.current) {
      ref.current.scrollTop = ref.current.scrollHeight;
    }
  }, [dep]);

  /** Programmatically scroll to bottom and re-enable auto-scroll. */
  const scrollToBottom = useCallback(() => {
    if (ref.current) {
      ref.current.scrollTop = ref.current.scrollHeight;
      stickRef.current = true;
      setIsAtBottom(true);
    }
  }, []);

  return { ref, onScroll, isAtBottom, scrollToBottom };
}
