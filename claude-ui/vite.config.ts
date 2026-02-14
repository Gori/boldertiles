import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";

/**
 * Strip attributes from built HTML that break file:// loading in WKWebView.
 * - `crossorigin` triggers CORS preflight on null origin
 * - `type="module"` enforces CORS for script fetches (module scripts always use CORS)
 */
function stripForFileProtocol(): Plugin {
  return {
    name: "strip-for-file-protocol",
    enforce: "post",
    transformIndexHtml(html) {
      return html
        .replace(/ crossorigin/g, "")
        .replace(/<script type="module"/g, "<script defer");
    },
  };
}

export default defineConfig({
  plugins: [react(), stripForFileProtocol()],
  base: "./",
  build: {
    outDir: "../Sources/Bolder/Resources/ClaudeUI",
    emptyOutDir: true,
    modulePreload: false,
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        manualChunks: undefined,
      },
    },
  },
});
