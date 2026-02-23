import { useEffect } from "react";
import { useBridgeContext } from "./BridgeContext";
import type { BridgeEvent } from "./protocol";

/**
 * Subscribe to bridge events from Swift.
 * The callback fires for every event; filter by event.type as needed.
 */
export function useBridge(handler: (event: BridgeEvent) => void) {
  const { subscribe } = useBridgeContext();

  useEffect(() => {
    return subscribe(handler);
  }, [subscribe, handler]);
}
