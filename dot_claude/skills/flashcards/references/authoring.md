# Flashcard Authoring Playbook

Rules the agent applies when drafting cards. Distilled from SuperMemo's 20 rules
(Wozniak), the Janki Method, and Anki's manual. Use this as a checklist while
producing the draft list — every card must survive these gates before it hits
the user-confirmation step.

## 1. The minimum information principle

One card carries **one** atomic fact, or one tightly coupled fact + cue. Two
short cards beat one dense card every time, because compound cards fail you on
review when only one half is forgotten.

| Avoid | Prefer |
|---|---|
| "List the four MapReduce phases." | Four cards (Map, Shuffle, Sort, Reduce), each asking *what does phase X do*. |
| "Define overfitting and underfitting." | Two cards. |
| "What are the time and space complexity of quicksort?" | Two cards (time → O(n log n) avg / O(n²) worst; space → O(log n) recursion). |

If a card's `Back` has more than one bolded number/term that you also could see
quizzed in isolation, split the card.

## 2. Active recall framing

`Front` is always a **question** or **task** — never a topic title. The user
must be forced to retrieve, not merely recognize.

| Avoid | Prefer |
|---|---|
| "Front: 快速排序。" | "Front: 快速排序的平均时间复杂度？为什么？" |
| "Front: `Result<T,E>`" | "Front: Rust 测试函数返回 `Result<T,E>` 时，如何断言 'expected an Err'？" |

A useful sniff test: if a friend could answer the front without remembering
anything specific, the front is too vague.

## 3. Cloze deletion: when and how

Use `PaperCloze` when:

- A short fixed phrase has one or two missing tokens you want to retrieve.
- You want to drill **the same surrounding context** with multiple deletions.
- The fact is naturally a fill-in (formula constants, syntax keywords, dates).

Cloze syntax: `{{c1::answer}}` or `{{c1::answer::hint}}`. Different `cN` indices
make Anki generate one card per index, all sharing the same context.

| Good cloze | Bad cloze |
|---|---|
| "在 Rust 里，`{{c1::#[test]}}` 标记一个测试函数，`{{c2::#[should_panic]}}` 标记应当 panic 的测试。" | Cloze on a 3-line sentence with 5 deletions — too many concurrent unknowns. |
| "牛顿第二定律：`{{c1::F}} = {{c2::m}} \cdot {{c3::a}}`。" | Cloze on the entire sentence ("hide the sentence") — no retrieval cue left. |

If you find yourself writing cloze for a long prose paragraph, that's a sign
the content should be a Q&A card instead.

## 4. Reversed cards: when to add

Add `Reverse?` (a non-empty marker) on `PaperNotes` when **the relation is
symmetric and both directions are useful to retrieve**:

| Symmetric (use reverse) | One-way (don't reverse) |
|---|---|
| Term ↔ definition | Theorem → its proof |
| Word ↔ translation | Question → its multi-sentence essay answer |
| Function name ↔ signature | Step 3 → step 4 (procedural; reverse breaks the chain) |
| API name ↔ what it does | Bug → fix (the bug is rarely retrievable from the fix) |

Reverse doubles your review load — only opt in when the back→front direction
genuinely earns it.

## 5. Visual concreteness

Replace abstract textual descriptions with diagrams or images when the concept
has a spatial / structural / dynamic component:

- **Structural / flow / state** → `mermaid` block (flowchart, sequenceDiagram,
  stateDiagram, gantt). Renders inline, no media file.
- **Mathematical plot, geometric figure, distribution** → matplotlib PNG via
  the `render-math-png.py` helper (see SKILL.md Building section). Filename
  `flashcards_<sha1>.png`, embedded as `![alt](flashcards_<sha1>.png)`.
- **Real-world object / map / screenshot** → codex MCP image generation, same
  filename convention.

A card without a visual is fine; a card with a *decorative* visual (one that
doesn't carry information) is worse than no visual.

## 6. Source attribution is non-negotiable

`Source` field always populated with something you could grep back to: book
section, paper §, file:line, URL slug. When the card is wrong or stale, you
need this anchor.

## 7. Note-type decision tree

```
Is the content a question with a discrete answer?
├─ yes — and the inverse is also worth recalling?  → PaperNotes + Reverse?=y
├─ yes — one-direction only?                       → PaperNotes
├─ partial fill-in of a phrase / formula / syntax? → PaperCloze
└─ "given a task, write code"?                     → PaperCode
```

## 8. Per-domain playbook

### Math / statistics

- Formulas: `PaperCloze` on constants and operators, not on whole equations.
- Theorems: `PaperNotes` for *statement*; separate cards for *intuition*,
  *proof sketch*, *one canonical example*.
- Distributions / functions: always include a plot — at least axis-labeled
  curve. Use `render-math-png.py` for static plots, mermaid for decision trees.
- Avoid pure prose definitions when a 3-line plot would carry the meaning.

### Programming — knowledge

- Syntax: `PaperCloze` (`{{c1::pub fn}}` etc.).
- Concept Q&A: `PaperNotes`. Reverse only for true name↔definition pairs.
- Complexity / performance: separate cards per metric (time, space, best/worst).
- API surface: card per *capability*, not per *function*. ("How do I drop a
  database table in DuckDB?" beats listing every DuckDB DDL function.)

### Programming — exercise

- `PaperCode` with `Task` (problem statement, may include I/O examples) and
  `Solution` (full working code, auto-collapses if >12 lines).
- `Hint` field optional — short pointer, not a partial solution.
- One card per problem; if the problem has 3 sub-tasks, make 3 cards.
- Mark difficulty in `Source` (e.g. "LeetCode 1, easy") for grading triage.

### Language / vocabulary

- Sentence cloze: `PaperCloze` with the target word elided in a real example
  sentence — never an isolated word.
- Bidirectional: `PaperNotes` with `Reverse?=y` for L1↔L2 word pairs *only when
  the L2 word has one dominant meaning*; for polysemes, do unidirectional cards
  per sense.
- Image when the word names a concrete object.

### History / facts

- Dates: cloze the year, keep the event in context (`{{c1::1969}}` Apollo 11 …).
- People ↔ contributions: `PaperNotes` reversed.
- Periods / dynasties: timeline diagram (mermaid `gantt`).

### Procedures / workflows

- One card per *transition* ("after step 3, what's step 4?") — not one card
  with the whole sequence.
- The whole flow can additionally be one mermaid card for spatial recall.
- Don't reverse procedural cards; backward retrieval is brittle.

### Paper / book reading

- Claim cards: `PaperNotes` ("What does §3 argue and what's the evidence?").
- Definition cards: `PaperCloze` for new terminology introduced in the paper.
- "Reversal" / criticism cards: `PaperNotes` ("What's the strongest objection
  to the §3 argument?") — these force engagement, not just memorization.

## 9. Negative patterns — refuse to draft these

| Smell | Why it fails | Fix |
|---|---|---|
| Front: a topic title, no question | No retrieval cue. | Rewrite as a question. |
| Back: a wall of bullet points | Compound recall, brittle. | Split into N cards. |
| "List X" with no cloze | Forces enumeration without a per-item cue. | Cloze each item, or N Q&A cards. |
| Reverse on essay-style answer | Back→front is unanswerable. | Drop the reverse. |
| Cloze on every word in a sentence | Becomes "fill the sentence", no signal. | Cloze one or two key tokens. |
| Card depends on context the user won't have at review time | Won't recall without the surrounding paragraph. | Inline the minimum needed context. |
| Decorative image | Visual budget wasted, distracts. | Drop or replace with informative diagram. |

If a card the agent drafts trips any of these, rewrite before showing it to the
user — don't ship the smell and rely on review.
