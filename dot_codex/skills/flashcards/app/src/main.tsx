import { StrictMode } from "react";
import { createRoot, type Root } from "react-dom/client";
import { Card } from "./components/Card";
import "./styles.css";

// Anki replaces card HTML in-place when flipping front<->back, but ES modules
// only execute once per document. Expose mount() globally so the template can
// re-invoke it after each side swap.
let currentRoot: Root | null = null;

function mount(): void {
  const root = document.getElementById("fc-root");
  if (!root) return;

  const side = (root.dataset.side === "back" ? "back" : "front") as
    | "front"
    | "back";
  const source = root.dataset.source ?? "";
  const front = readMarkdown("fc-front");
  const back = readMarkdown("fc-back");

  if (currentRoot) {
    try {
      currentRoot.unmount();
    } catch {
      // old DOM already detached by Anki; nothing to clean up.
    }
  }
  currentRoot = createRoot(root);
  currentRoot.render(
    <StrictMode>
      <Card side={side} source={source} front={front} back={back} />
    </StrictMode>,
  );
}

function readMarkdown(id: string): string {
  const el = document.getElementById(id);
  if (!el) return "";
  // Anki stores field newlines as literal `<br>` / `<div>` markup and replaces
  // raw `<>&` with HTML entities. The <script> tag preserves these as text, so
  // we reverse the encoding before handing the result to the markdown parser.
  let text = el.textContent ?? "";
  text = text
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/div>\s*<div[^>]*>/gi, "\n")
    .replace(/<\/?div[^>]*>/gi, "")
    .replace(/&nbsp;/gi, " ");
  const ta = document.createElement("textarea");
  ta.innerHTML = text;
  return ta.value.trim();
}

(window as unknown as { __fc__?: { mount: () => void } }).__fc__ = { mount };
mount();
