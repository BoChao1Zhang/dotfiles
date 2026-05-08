import { useMemo, useState } from "react";
import { highlight } from "../lib/highlight";

type CollapsibleCodeProps = {
  language: string;
  code: string;
};

const COLLAPSE_THRESHOLD = 12;

export function CollapsibleCode({ language, code }: CollapsibleCodeProps) {
  const lineCount = code.split("\n").length;
  const collapsible = lineCount > COLLAPSE_THRESHOLD;
  const [open, setOpen] = useState(!collapsible);
  const html = useMemo(() => highlight(code, language), [code, language]);

  return (
    <figure className={`paper-code ${open ? "is-open" : "is-collapsed"}`}>
      <figcaption className="paper-code__head">
        <span className="paper-code__lang">{language}</span>
        <span className="paper-code__meta">{lineCount} 行</span>
        {collapsible && (
          <button
            type="button"
            className="paper-code__toggle"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
          >
            {open ? "收起" : "展开"}
          </button>
        )}
      </figcaption>
      <pre className="paper-code__pre">
        <code
          className={`hljs language-${language}`}
          dangerouslySetInnerHTML={{ __html: html }}
        />
      </pre>
    </figure>
  );
}
