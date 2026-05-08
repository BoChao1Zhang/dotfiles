import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkMath from "remark-math";
import rehypeKatex from "rehype-katex";
import rehypeRaw from "rehype-raw";
import { CollapsibleCode } from "./CollapsibleCode";
import { MermaidBlock } from "./MermaidBlock";
import "katex/dist/katex.min.css";

type MarkdownProps = { source: string };

export function Markdown({ source }: MarkdownProps) {
  return (
    <div className="paper-md">
      <ReactMarkdown
        remarkPlugins={[remarkGfm, remarkMath]}
        rehypePlugins={[rehypeRaw, rehypeKatex]}
        components={{
          code({ className, children, ...rest }) {
            const text = String(children).replace(/\n$/, "");
            const langMatch = /language-(\w+)/.exec(className ?? "");
            const lang = langMatch?.[1];

            // Inline code: no language fence and no newline.
            const inline = !lang && !text.includes("\n");
            if (inline) {
              return (
                <code className="paper-md__inline-code" {...rest}>
                  {children}
                </code>
              );
            }

            if (lang === "mermaid") {
              return <MermaidBlock source={text} />;
            }

            return <CollapsibleCode language={lang ?? "text"} code={text} />;
          },
          // ReactMarkdown wraps code in <pre>; we render the wrapper ourselves
          // inside CollapsibleCode, so strip the outer <pre>.
          pre({ children }) {
            return <>{children}</>;
          },
          a({ href, children, ...rest }) {
            return (
              <a
                href={href}
                target="_blank"
                rel="noreferrer noopener"
                {...rest}
              >
                {children}
              </a>
            );
          },
        }}
      >
        {source}
      </ReactMarkdown>
    </div>
  );
}
