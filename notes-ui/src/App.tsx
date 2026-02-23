import { BridgeProvider } from "./bridge/BridgeContext";
import { NotesEditor } from "./editor/NotesEditor";

export function App() {
  return (
    <BridgeProvider>
      <NotesEditor />
    </BridgeProvider>
  );
}
