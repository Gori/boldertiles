import { createContext, useContext, useCallback, useRef, type ReactNode } from "react";
import type { BridgeEvent, BridgeMessage } from "./protocol";
import type { Suggestion } from "../types";

type EventListener = (event: BridgeEvent) => void;

interface BridgeContextValue {
  subscribe: (fn: EventListener) => () => void;
  postMessage: (msg: BridgeMessage) => void;
  suggestions: Suggestion[];
}

const BridgeCtx = createContext<BridgeContextValue | null>(null);

// Global listener set + event buffer — installed at module scope so
// __bolder__ is available before React mounts (WKWebView's didFinish
// fires before the React tree exists).
const globalListeners = new Set<EventListener>();
let eventBuffer: BridgeEvent[] = [];

(window as unknown as Record<string, unknown>).__bolder__ = {
  onEvent(event: BridgeEvent) {
    if (globalListeners.size === 0) {
      // No subscribers yet (React hasn't mounted) — buffer for replay
      eventBuffer.push(event);
    } else {
      for (const fn of globalListeners) {
        fn(event);
      }
    }
  },
};

export function BridgeProvider({ children }: { children: ReactNode }) {
  const suggestionsRef = useRef<Suggestion[]>([]);

  const subscribe = useCallback((fn: EventListener) => {
    globalListeners.add(fn);
    // Replay any buffered events to the first subscriber
    if (eventBuffer.length > 0) {
      const buffered = eventBuffer;
      eventBuffer = [];
      for (const event of buffered) {
        for (const listener of globalListeners) {
          listener(event);
        }
      }
    }
    return () => {
      globalListeners.delete(fn);
    };
  }, []);

  const postMessage = useCallback((msg: BridgeMessage) => {
    const wk = (
      window as unknown as {
        webkit?: {
          messageHandlers?: {
            bolder?: { postMessage: (m: BridgeMessage) => void };
          };
        };
      }
    ).webkit;
    wk?.messageHandlers?.bolder?.postMessage(msg);
  }, []);

  const value: BridgeContextValue = {
    subscribe,
    postMessage,
    suggestions: suggestionsRef.current,
  };

  return <BridgeCtx.Provider value={value}>{children}</BridgeCtx.Provider>;
}

export function useBridgeContext(): BridgeContextValue {
  const ctx = useContext(BridgeCtx);
  if (!ctx) throw new Error("useBridgeContext must be used within BridgeProvider");
  return ctx;
}
