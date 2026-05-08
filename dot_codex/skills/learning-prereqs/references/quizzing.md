# Diagnostic quizzing

The quiz is the single most important step in this skill. A bad quiz produces
a generic brief that the user could have written themselves. A good quiz
surfaces the exact crack the user is going to fall through when reading the
material.

## What "mid-hard" means

A *warm-up* question is one a competent reader of this material answers in
under 5 seconds. Skip those — they don't discriminate. A *mid-hard* question
takes 30 s – 2 min of real thinking and is one of:

- a *why* (not a *what*) — "why does PPO clip the ratio rather than the loss?"
- a small computation — "compute the KL between N(0,1) and N(1,1)"
- a *spot the wrong claim* — give a 2-line statement and ask which clause is
  wrong
- a *small derivation* — "starting from … in two lines, get to …"
- *predict the output* — show 5 lines of code or a 2x2 matrix transform and
  ask what comes out
- *choose between two definitions* — give two plausible-looking definitions
  and ask which one is the one used in this material

Avoid:

- "What is X?" — too open, lets the user fake it
- yes/no — 50% baseline
- multi-step questions where one early failure hides everything downstream
- questions with hidden ambiguity ("what does X mean?" when X has 3 meanings
  in adjacent fields)

## How many questions

3 if the material has 3 load-bearing prereqs and the rest are easy.
9 if it's a survey-flavored paper that builds on a wide foundation. Most
papers land at 5–7. Don't pad. If you have only 3 real diagnostic targets,
ask 3 questions and move on.

But this only sets **round 1**. The protocol below runs more rounds
adaptively to find each gap's *floor*, not just to detect that a gap exists.

## Multi-round adaptive protocol

A single round of mid-hard questions tells you "above or below assumed
level." That's not enough — two users who both answer "idk" to the same
question can have wildly different floors, and the brief that bridges them
is completely different. The protocol drills down on cold answers and probes
edges of solid ones, until each top-level concept has a concrete floor.

### Round structure

| Round | Purpose | Question count | Targets |
|---|---|---|---|
| 1 | Surface — discriminate at the assumed level | 5–7 mid-hard | every load-bearing concept from the prereq map |
| 2 | Drill — find the floor under each `cold`; verify each `solid` | 3–5 total | for each `cold`: 1–2 sub-concepts one layer down. for each `solid`: 1 edge probe (optional). for each `shaky`: 1 question targeting the specific misunderstanding. |
| 3 | Resolve ambiguities only | 1–3 | only concepts whose floor is still unclear after round 2 |

Hard cap: ~15 questions across all rounds. After round 3, commit even with
imperfect info — more rounds annoy more than they help.

### Building the prereq tree before round 2

For each `cold` concept, sketch (in your head, not in chat) a tiny dependency
tree, 3–5 nodes deep. The leaves are concepts you'd be willing to assume in
the brief without further explanation. Round 2 questions probe nodes a layer
or two beneath the cold concept.

Worked example — concept "msign(M) = M(MᵀM)^{-1/2}":

```
msign
├── SVD shape and properties (M = UΣVᵀ)
│   ├── eigendecomposition of symmetric matrices
│   │   ├── eigenvectors / eigenvalues — what they are geometrically
│   │   └── orthogonal matrices — Qᵀ Q = I
│   └── matrix as linear transform — geometric picture
└── inverse square root of a symmetric PSD matrix
    └── functions of matrices — fᶠ(A) := V f(Λ) Vᵀ for symmetric A
```

If round 1 returned "idk" on msign, round 2 might ask:
- one at SVD-shape level: "what shape is V in M=UΣVᵀ when M ∈ Rⁿˣᵐ?"
- one at eigenvector-of-symmetric level: "for symmetric A, why are
  eigenvectors orthogonal? one sentence."

Their answers split the user into one of:
- knows SVD → brief opens at "msign as Σ→I via SVD"
- knows eigen but not SVD → brief opens by *building* SVD from eigen
- knows orthogonal but not eigen → brief opens further down still
- "idk" both → bridge is too long for one brief; either split into two
  briefs or warn the user the gap is wider than the skill is sized for

### Edge probing for solid

When round 1 answer is right but you can't tell whether it's real
understanding or a confident guess, ask one harder question on the same
concept that requires a second-order property — not the headline definition.

> Example: round 1 answer to "what does power iteration converge to?"
> = "the dominant eigenvector". Edge probe: "what's the convergence rate,
> and what makes it slow?" — getting `|λ₂/λ₁|` is the depth signal.

If round 1 answer was already a derivation or a rich explanation, skip the
edge probe — depth was already demonstrated.

### Targeted shaky questions

Shaky means the user got something specific wrong (sign, definition swap,
wrong direction of an inequality). Round 2 question goes after that exact
nerve. Don't re-ask the same question — that's just punishment. Ask a
sibling question that requires understanding the same distinction.

> Example: round 1 user gets "what does Cholesky QR compute?" half-right
> but says it's stable. Shaky question: "if cond(A) = 10⁶, roughly what's
> cond(AᵀA), and what does that imply for any algorithm that factors AᵀA?"

### Style across rounds

- Tell the user upfront: "I'll do up to ~3 short rounds; this is how the
  briefs end up actually targeted at your level rather than generic."
- Round 2 / 3 are usually fewer questions than round 1.
- Acknowledge what they got right between rounds. "OK, you have eigenvectors
  solid — let me check one layer up."
- Never make a wrong answer feel like a bad answer. The diagnostic value of
  "idk" is high; reward it explicitly the first time it appears.
- If the user says "stop, just give me the briefs" mid-protocol, honor it —
  but mark in the brief that the floor is best-guess, so the user knows the
  targeting may overshoot or undershoot.

### Stopping criteria

Stop earlier than 3 rounds when:

- every cold concept has a concrete floor sentence you could write down
  (e.g. "knows orthogonal matrices, doesn't know SVD"); or
- every solid concept survived its edge probe; or
- the user signals fatigue.

### What to write down at the end

For each top-level concept, one record (kept in working memory, not shown
to the user):

```
concept: <name>
status:  solid | shaky | cold
floor:   "<one-sentence description of what they DO know that's adjacent>"
bridge:  "<2–4 step sketch of how the brief should walk from floor to the
          assumed level>"
```

These records drive the brief outline directly. The brief opens *just above*
the floor and bridges up.

## Templates

### Math / proofs

- "State the form of [lemma] and the one assumption that's easiest to
  forget."
- "In [step from paper], they apply [inequality]. Why does the inequality go
  in *that* direction here?"
- "Quick: is [claim] tight, or does it have slack? If slack, where?"

### ML / RL

- "Compute [a small quantity that the paper assumes you can do mentally]."
  E.g. for PPO: "ratio = π_new(a)/π_old(a) where π_new(a)=0.4, π_old(a)=0.5
  and ε=0.2 — does the clip bind?"
- "In one sentence, why does [technique] *exist* — what failure mode of the
  obvious approach motivated it?" (KL constraint, GAE, target networks…)
- "Spot the wrong claim: [3-clause statement with one subtle error]."

### Systems / CUDA

- "How many threads in a warp on NVIDIA? How many warps in a typical block,
  bounded by what?"
- "If your kernel reads `a[threadIdx.x * 32]`, why is that bad and what's
  the one-word name for it?" (uncoalesced)
- "Predict: a kernel with `__syncthreads()` inside an `if (threadIdx.x <
  16)` branch — what happens?" (deadlock / undefined)

### Physics

- "Spot the wrong claim about [conservation law / equation]: …"
- "Order-of-magnitude: [something you should be able to estimate without a
  calculator if you understand the scaling]."
- "Why does [counterintuitive result] happen? One physical sentence."

## Scoring rubric (same across rounds)

Three buckets only — don't fake granularity:

| Bucket | Signal |
|---|---|
| solid | answer right, reasoning right, no hesitation in wording, *and* round-2 edge probe (if asked) didn't crack it |
| shaky | answer right but rationale wrong / partial; or answer wrong but "close" (sign error, off-by-one, swapped two things) |
| cold | "idk", flat-wrong, or right answer that's clearly a guess (one-word reply when reasoning was asked) |

`idk` is a *good* signal, not a failure. Treat as `cold` and move on; don't
make the user feel bad — and acknowledge the first one explicitly so they
know the channel is safe.

## Grouping cold concepts into briefs

After all rounds, group `cold` concepts whose **floors** are similar — if
three of them all bottom out at "doesn't know SVD shape", they belong in
one foundation brief, not three. Cap at 3 briefs total — past that the user
won't actually read them and the whole skill becomes wallpaper.
