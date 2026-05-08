import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";

// Build a single self-contained IIFE bundle for Anki.
// Output: dist/_flashcards.js, dist/_flashcards.css.
// Anki's media folder garbage-collects files whose names don't start with `_`,
// so the leading underscore is required.
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: resolve(__dirname, "../dist"),
    emptyOutDir: true,
    cssCodeSplit: false,
    sourcemap: false,
    target: "es2022",
    chunkSizeWarningLimit: 1500,
    rollupOptions: {
      input: resolve(__dirname, "src/main.tsx"),
      output: {
        format: "es",
        entryFileNames: "_flashcards.js",
        chunkFileNames: "_flashcards-[name].js",
        assetFileNames: (info) =>
          info.name?.endsWith(".css") ? "_flashcards.css" : "_[name][extname]",
        manualChunks: {
          "fc-mermaid": ["mermaid"],
        },
      },
    },
  },
});
