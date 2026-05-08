# Systems / GPU / parallel-computing prereqs

When the material discusses CUDA, GPU architecture, parallel runtimes, or
high-performance numerical kernels, these are the concepts authors most
often assume.

## GPU mental model (NVIDIA)

- streaming multiprocessor (SM), CUDA cores, tensor cores
- warp = 32 threads, executed in lockstep (SIMT)
- block / thread block: programmer-visible scheduling unit; bound to one SM
- grid: collection of blocks
- the launch hierarchy `grid → block → warp → thread`
- occupancy: warps-resident-per-SM divided by max-warps-per-SM, and what
  bounds it (registers, shared memory, block size)

## Memory hierarchy

- registers per thread (private), shared memory per block, global memory
- L1 / L2 cache; texture / constant memory (less common in modern code)
- coalesced vs. uncoalesced global access; the 32-byte / 128-byte
  transaction rule
- shared-memory bank conflicts (32 banks, stride patterns)
- pinned (page-locked) host memory for fast H2D / D2H

## Execution

- `__syncthreads()` semantics and the rule that it must be hit by every
  thread in the block (no putting it in a divergent branch)
- warp divergence: threads in a warp taking different `if` branches → both
  paths executed, masked
- atomic ops: speed cost, lock-free patterns
- streams, events, async copies; concurrent kernels
- cooperative groups (modern; replaces some older sync idioms)

## Performance vocabulary

- arithmetic intensity = flops / bytes-moved; the roofline model
- memory-bound vs. compute-bound
- TFLOPS vs. tensor-TFLOPS, fp32 vs. tf32 vs. bf16 vs. fp16 vs. fp8
- HBM bandwidth, NVLink bandwidth, PCIe bandwidth — order of magnitude
  matters more than exact numbers
- kernel launch latency (~5 μs); why fused kernels matter

## Multi-GPU / multi-node

- collectives: all-reduce, all-gather, reduce-scatter, broadcast
- ring vs. tree all-reduce (NCCL)
- data parallel vs. tensor parallel vs. pipeline parallel vs. expert parallel
- ZeRO stages 1/2/3 in shorthand
- bandwidth vs. latency dominance for different collective sizes

## "Always assumed if used"

- the word "warp" with no explanation → SIMT lockstep is being assumed
- "occupancy" → user is expected to know which resource is the binding
  constraint
- `__syncthreads`, `__shfl_sync`, `__ballot_sync` → cooperative-thread
  semantics
- "coalesced" → the 32-byte transaction rule
- "all-reduce" / "ring all-reduce" → collective semantics
- "tensor cores" → mma instructions and shape constraints
- the `nvprof` / `nsight-compute` / `nsys` tooling vocabulary
- `kernel<<<grid, block, shmem, stream>>>(...)` launch syntax

## Cross-vendor notes

- AMD's equivalent: wavefront (64 threads on RDNA1, 32 or 64 on
  RDNA3/CDNA), CU instead of SM, LDS instead of shared memory
- Apple Metal: SIMD-group ≈ warp, threadgroup ≈ block
- These rarely come up unless the paper explicitly targets them
