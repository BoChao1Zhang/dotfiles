# ML / RL prereqs commonly hand-waved by papers

Concept inventory the agent should consider when scanning ML/RL material.
Not every paper assumes all of these — the value of this list is that it
flags concepts that *would* be assumed if they were used, so the agent
notices them in the prereq map step.

## Probability / information

- log-prob, KL divergence (forward vs. reverse, why they're not symmetric)
- entropy, cross-entropy, mutual information
- importance sampling and the variance-blowup of long ratios
- reparameterization vs. score-function (REINFORCE) gradient estimators
- Jensen's inequality (everywhere — ELBO, KL, expected log)

## Optimization

- SGD, Adam, AdamW (and *why* AdamW exists vs. Adam+L2)
- learning-rate schedules: warmup + cosine, why warmup matters with Adam
- gradient clipping by global norm, why
- second-order intuition: natural gradient, Fisher info matrix (TRPO needs this)
- trust regions in general (KL ball, line search)

## Supervised learning shapes

- softmax + cross-entropy = the canonical pair, why the gradient is just
  `(p − y)`
- label smoothing
- distillation temperature

## RL specifics

- MDP tuple, return, discount γ; why discounting in continuing tasks
- value functions V, Q, advantage A = Q − V
- policy gradient theorem (the proof in 4 lines, not 4 pages)
- on-policy vs. off-policy: what makes an algorithm one or the other
- importance sampling correction in off-policy estimators
- actor-critic: baseline as variance reduction, not bias correction
- GAE: λ trades bias and variance, what λ=0 and λ=1 collapse to
- target networks and why SGD is unstable without them in DQN-style
- replay buffer and the implicit i.i.d. assumption
- TRPO → PPO: trust-region constraint replaced by clipped surrogate
- entropy bonus, exploration-exploitation tension

## Modern transformer / LLM

- attention as a soft dictionary; QKV intuition
- positional encoding: absolute vs. RoPE vs. ALiBi
- layer-norm placement (pre-LN vs. post-LN)
- causal masking, KV cache
- LoRA / QLoRA at the math level (low-rank delta)
- RLHF flow: SFT → reward model → policy optimization (PPO/DPO/GRPO)

## "Always assumed if used" red flags

If the paper uses any of these without redefining, treat as candidate prereq:

- "GAE estimator" / "generalized advantage estimation"
- "trust region"
- "natural gradient"
- "Fisher information"
- "importance ratio" / "importance weight"
- "reparameterization trick"
- "Bellman equation"
- the symbol `λ` in an RL context with no explanation
- the symbol `β` in an RLHF context (KL coefficient)
