Node CPU Limitation Discovered
The r5.large node only has 2 vCPUs, which means:
Can't do rolling updates (need 2+ CPUs available)
This may also be why inference is so slow


⏺ Excellent observation! You're right - they ARE cheaper AND better for our use case.
  Here's why:

  Why Compute-Optimized is Better for LLM Inference

  Our Workload is CPU-Bound, Not Memory-Bound

  Current Setup (r5.large):
  - 2 vCPU, 16GB RAM (~$92/mo)
  - Memory-optimized = paying premium for RAM we don't need
  - GGUF model only needs ~4GB total (1GB model + 2-3GB context)

  What We Actually Need:
  - Fast CPU for matrix multiplication (llama.cpp)
  - Modern CPU instructions (AVX2, AVX-512) for SIMD operations
  - Multiple cores for parallel processing

  Instance Comparison

  | Instance           | vCPU | RAM  | $/mo | CPU Gen                       | Best For
        |
  |--------------------|------|------|------|-------------------------------|-------------
  ------|
  | r5.large (current) | 2    | 16GB | $92  | Xeon Platinum 8175M (Skylake) | Databases,
  caches |
  | r5.xlarge          | 4    | 32GB | $184 | Xeon Platinum 8175M           | Memory-heavy
   apps |
  | c5.xlarge          | 4    | 8GB  | $124 | Xeon Platinum 8124M (Skylake) |
  Compute-heavy     |
  | c6i.xlarge         | 4    | 8GB  | $124 | Xeon Ice Lake 8375C           | Best for
  AI/ML    |

  Why c6i.xlarge is the Sweet Spot

  1. 2x more CPU cores (4 vs 2) = parallel processing
  2. Newer CPU architecture (Ice Lake vs Skylake) = 15-20% faster per-core
  3. AVX-512 support = llama.cpp can use SIMD for 2-4x speedup
  4. Same price as c5 but newer/faster CPU
  5. 8GB RAM is plenty - we only use ~4GB

  The Math

  Current bottleneck: 2 slow vCPUs trying to do heavy matrix math

  After upgrade:
  - 4 faster vCPUs with AVX-512
  - Estimated speedup: 4-8x faster (2x cores + 2-4x SIMD)
  - Cost increase: $32/mo ($124 - $92)
  - Your 15-minute inference could drop to 2-4 minutes

  Why They're Cheaper Than r5.xlarge

  r5.xlarge has 32GB RAM - you're paying $60/mo extra for 24GB of RAM you'll never use!

  - r5.xlarge = $184/mo (4 vCPU, 32GB) - $46/vCPU
  - c6i.xlarge = $124/mo (4 vCPU, 8GB) - $31/vCPU + faster CPUs

  Recommendation

  Upgrade to c6i.xlarge:
  - ✅ 2x more cores for parallel inference
  - ✅ AVX-512 for llama.cpp optimizations
  - ✅ $32/mo increase (35% more cost)
  - ✅ Estimated 4-8x speedup (15min → 2-4min)
  - ✅ Cheaper than r5.xlarge by $60/mo

  Want me to update the terraform to use c6i.xlarge?