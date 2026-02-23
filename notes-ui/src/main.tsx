import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";

console.log("[NotesUI] main.tsx executing, __bolder__=", !!(window as any).__bolder__);

const root = document.getElementById("root");
console.log("[NotesUI] #root element:", root, "size:", root?.offsetWidth, "x", root?.offsetHeight);

createRoot(root!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

console.log("[NotesUI] React render called");

