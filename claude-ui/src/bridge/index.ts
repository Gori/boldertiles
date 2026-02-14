import type { BridgeEvent } from "../types/events";
import type { BridgeMessage } from "../types/messages";

type Listener = (event: BridgeEvent) => void;

const listeners = new Set<Listener>();

/** Register window.__bolder__.onEvent so Swift can push events into React. */
function install() {
  (window as unknown as Record<string, unknown>).__bolder__ = {
    onEvent(event: BridgeEvent) {
      for (const fn of listeners) {
        fn(event);
      }
    },
  };
}

/** Subscribe to bridge events. Returns an unsubscribe function. */
export function subscribe(fn: Listener): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/** Send a message from JS to Swift via WKWebView message handler. */
export function postMessage(msg: BridgeMessage) {
  const wk = (
    window as unknown as {
      webkit?: {
        messageHandlers?: {
          claude?: { postMessage: (m: BridgeMessage) => void };
        };
      };
    }
  ).webkit;
  wk?.messageHandlers?.claude?.postMessage(msg);
}

// Install immediately so Swift can call onEvent before React mounts.
install();
