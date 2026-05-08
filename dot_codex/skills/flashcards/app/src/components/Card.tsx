import { Markdown } from "./Markdown";

type Side = "front" | "back";

type CardProps = {
  side: Side;
  source: string;
  front: string;
  back: string;
};

export function Card({ side, source, front, back }: CardProps) {
  return (
    <div className="paper-card">
      <div className="paper-card__binding" aria-hidden="true" />

      <article className="paper-card__body">
        <header className="paper-card__head">
          <span className="paper-card__face-label">Q</span>
          {source && <span className="paper-card__source">{source}</span>}
        </header>

        <section className="paper-card__front">
          <Markdown source={front} />
        </section>

        {side === "back" && (
          <>
            <hr className="paper-card__divider" />
            <header className="paper-card__head paper-card__head--answer">
              <span className="paper-card__face-label paper-card__face-label--answer">
                A
              </span>
            </header>
            <section className="paper-card__back">
              <Markdown source={back} />
            </section>
          </>
        )}
      </article>
    </div>
  );
}
