import { useEffect, useRef, useState } from "react";

type MermaidBlockProps = { source: string };

let idCounter = 0;
const nextId = () => `paper-mermaid-${++idCounter}`;

export function MermaidBlock({ source }: MermaidBlockProps) {
  const [svg, setSvg] = useState<string>("");
  const [error, setError] = useState<string>("");
  const idRef = useRef(nextId());

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { default: mermaid } = await import("mermaid");
        mermaid.initialize({
          startOnLoad: false,
          theme: "neutral",
          securityLevel: "strict",
          fontFamily:
            '"Source Serif Pro", "Iowan Old Style", Georgia, serif',
        });
        const { svg } = await mermaid.render(idRef.current, source);
        if (!cancelled) setSvg(svg);
      } catch (err) {
        if (!cancelled) setError(String(err));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [source]);

  if (error) {
    return (
      <figure className="paper-mermaid paper-mermaid--error">
        <figcaption>mermaid 渲染失败</figcaption>
        <pre>{error}</pre>
        <pre>{source}</pre>
      </figure>
    );
  }

  return (
    <figure
      className="paper-mermaid"
      // mermaid returns sanitized SVG; securityLevel: 'strict' strips scripts.
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}
