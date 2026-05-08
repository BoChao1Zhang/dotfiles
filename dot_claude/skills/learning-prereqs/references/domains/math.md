# Math prereqs commonly cited in proofs without restatement

Lemmas, inequalities, and small techniques that papers and theorem-proving
texts treat as "you obviously know this." When a derivation jumps a step
without justification, the missing step is usually one of these.

## Inequalities (the big six)

- **Cauchy–Schwarz**: |⟨x,y⟩| ≤ ‖x‖·‖y‖ (vector / function / random-variable
  forms; equality iff colinear)
- **Jensen's**: for convex f, f(E[X]) ≤ E[f(X)]; reversed for concave. The
  most-cited inequality in ML proofs.
- **Markov**: P(X ≥ a) ≤ E[X]/a for non-negative X. Foundation of the rest.
- **Chebyshev**: P(|X − μ| ≥ kσ) ≤ 1/k². Markov applied to (X−μ)².
- **Hoeffding** (and Bernstein, Azuma): tail bounds for bounded /
  martingale-difference sums; used everywhere in concentration arguments.
- **Triangle inequality** in its various dressings (norm, expectation,
  metric).

## Common manipulation tricks

- **Add and subtract zero**: turns a − c into (a − b) + (b − c), then bound
  each piece. Key in error-decomposition proofs.
- **Multiply by 1**: ratio tricks like a/b = (a/c)·(c/b) — backbone of
  importance-sampling derivations.
- **AM–GM**: (a+b)/2 ≥ √(ab), the discrete cousin of Jensen for log.
- **Telescoping sums** Σ(a_{k+1} − a_k) = a_n − a_0 — appears anywhere a
  step-by-step bound has to become a one-shot bound.
- **Union bound**: P(∪Aᵢ) ≤ Σ P(Aᵢ); cheap, often tight enough.

## Linear algebra reflexes

- spectral theorem for symmetric matrices: orthogonal eigenbasis; eigenvalues
  real
- positive (semi-)definite ⇔ all eigenvalues > 0 (≥ 0)
- SVD as the universal factorization; truncated SVD is the optimal low-rank
  approximation under Frobenius norm (Eckart–Young)
- determinant as product of eigenvalues; trace as sum
- woodbury identity (rank-k update of an inverse)
- the matrix derivatives ∂(x'Ax)/∂x = (A+A')x and friends

## Calculus / analysis reflexes

- chain rule (multivariate), Jacobian, gradient
- Taylor expansion to 2nd order; the Hessian as the local-quadratic head
- integration by parts in 1D and ∫_Ω (∇·F) = ∫_∂Ω F·n in n-D
- dominated / monotone convergence (when can you swap limit and integral)
- L'Hôpital, but more often the right move is "rewrite and Taylor-expand"

## Probability reflexes

- law of total probability / total expectation: E[X] = E[E[X|Y]]
- independence ⇒ E[XY] = E[X]E[Y] (not iff)
- variance Var(aX+bY) = a²Var(X) + b²Var(Y) + 2ab·Cov(X,Y)
- characteristic / moment-generating functions; their use in proving CLT
- Borel–Cantelli (when do infinitely many events happen)
- Slutsky's theorem (combining convergence in distribution with constants)

## Convex analysis (when the paper says "by convexity…")

- subgradient, subdifferential
- convex conjugate (Legendre–Fenchel)
- KKT conditions
- Bregman divergence (mirror descent / natural gradient territory)

## "If you see this, the author is assuming you know the lemma"

- "by Jensen's inequality" → flag for diagnosis
- "by Cauchy–Schwarz"
- "after a change of variable" / "integration by parts"
- "WLOG assume X" — *why* is it WLOG? often the harder step
- "this is standard" / "well-known" / "trivially" → almost certainly
  non-trivial for the reader
- "by a standard concentration argument" → Hoeffding / Bernstein hiding
- "follows from the spectral theorem"
- "applying the chain rule" when the chain has > 2 links → Jacobian
  composition
