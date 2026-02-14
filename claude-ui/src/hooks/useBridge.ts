import { useEffect } from "react";
import { subscribe } from "../bridge";
import type { ChatAction } from "../state/actions";

/** Subscribes to bridge events and forwards them as dispatch actions. */
export function useBridge(dispatch: React.Dispatch<ChatAction>) {
  useEffect(() => {
    return subscribe((event) => dispatch(event));
  }, [dispatch]);
}
