#!/bin/bash

echo "🧪 Building all memory model test variants..."
echo

# 1. relaxed (expected to be buggy)
echo "🔧 [1/3] Building: relaxed (⚠️ possible r1==0 && r2==0)"
gcc -g -DO_RELAXED cpu_memory_model_test.c -lpthread -o test_relaxed && echo "Built test_relaxed"
echo

# 2. fence only (may still fail)
echo "🔧 [2/3] Building: with seq_cst fence (⚠️ still racy)"
gcc -g -DDO_FENCE cpu_memory_model_test.c -lpthread -o test_fence && echo "Built test_fence"
echo

# 3. release/acquire (correct and safe)
echo "🔧 [3/3] Building: release/acquire ( safe, no bug)"
gcc -g -DDO_RELEASE_ACQUIRE cpu_memory_model_test.c -lpthread -o test_ra && echo "Built test_ra"
echo

echo "All binaries built successfully:"
echo "   - ./test_relaxed"
echo "   - ./test_fence"
echo "   - ./test_ra"
