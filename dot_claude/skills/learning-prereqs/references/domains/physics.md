# Physics prereqs commonly hand-waved

Use when the material is a physics paper / textbook chapter / blog post
and the author leans on results from a different sub-area without
restating them.

## Classical mechanics

- Newton's laws + their reformulation as Euler–Lagrange equations
- principle of stationary action; what the action S is
- Hamiltonian H = pq̇ − L; phase space; Hamilton's equations
- Noether's theorem (continuous symmetry → conservation law); the three
  cardinal cases: time → energy, space → momentum, rotation → angular
  momentum
- canonical transformations; Poisson brackets

## Statistical mechanics / thermo

- microcanonical / canonical / grand-canonical ensembles
- Boltzmann distribution e^{−βE}/Z, partition function Z
- entropy as S = −Σ p ln p (Gibbs) and S = k_B ln Ω (Boltzmann); when each
  is the right form
- free energies F = U − TS, G = U − TS + pV, and which is minimized
  under which boundary conditions
- equipartition (½kT per quadratic DoF) and where it fails
- fluctuation–dissipation theorem (response function ↔ equilibrium
  fluctuation)

## E&M

- Maxwell's equations in differential and integral form; the
  ε₀, μ₀, c relation
- gauge freedom in (φ, A); Lorenz vs. Coulomb gauge
- Poynting vector S = E×H/μ₀; energy density (ε₀E² + B²/μ₀)/2
- multipole expansion: monopole / dipole / quadrupole and their fall-offs
- retarded potentials, Liénard–Wiechert (only if radiation comes up)

## Quantum

- Schrödinger picture vs. Heisenberg picture (vs. Dirac/interaction)
- bra-ket notation; |ψ⟩, ⟨ψ|, ⟨ψ|H|ψ⟩
- canonical commutator [x,p] = iℏ; uncertainty principle as a consequence
- harmonic oscillator: ladder operators a, a†, n = a†a; this is the engine
  of half of QFT
- perturbation theory at first and second order; degenerate case
- Pauli matrices σ_x, σ_y, σ_z; spin-½ tricks
- density matrix ρ; pure vs. mixed; partial trace for reduced states
- entanglement entropy S = −Tr(ρ log ρ)

## Relativity (special)

- four-vectors x^μ, p^μ; metric η = diag(−,+,+,+) or (+,−,−,−); pick one
  and stick with it
- Lorentz transformations; rapidity additivity instead of velocity
- E² = (pc)² + (mc²)²; massless limit and the photon
- proper time τ; γ = 1/√(1−v²/c²)
- relativistic Doppler

## Numerical / order-of-magnitude reflexes

- Fermi-style estimation; checking against dimensional analysis before
  trusting an algebra step
- the Π-theorem (Buckingham): how many dimensionless groups govern a
  problem
- common orders: ℏ ≈ 10⁻³⁴ J·s, k_B ≈ 1.4×10⁻²³ J/K, c ≈ 3×10⁸ m/s,
  e ≈ 1.6×10⁻¹⁹ C, mₑc² ≈ 511 keV. Authors often expect these to be
  cached.

## "Always assumed if used"

- "by Noether"
- "in natural units" → set ℏ = c = 1, sometimes k_B = 1
- "minimal coupling" → replace ∂_μ → ∂_μ + iqA_μ
- "in the rest frame" → boost; usually a γ-factor follows
- "to leading order in v/c" or "to one loop" → which expansion is happening
- "Wick rotation" → t → iτ
- "the system thermalizes" → Boltzmann distribution
