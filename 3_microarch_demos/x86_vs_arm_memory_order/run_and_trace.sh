#!/bin/bash

# Build binaries first
./build.sh

echo "======================================="
echo "[*] Running test_relaxed (no fence, relaxed)"
perf record -o perf.data.relaxed ./test_relaxed
perf report -i perf.data.relaxed --stdio > report.relaxed.txt
echo "  ✅ Output: report.relaxed.txt"

echo "======================================="
echo "[*] Running test_fence (with seq_cst fence)"
perf record -o perf.data.fence ./test_fence
perf report -i perf.data.fence --stdio > report.fence.txt
echo "  ✅ Output: report.fence.txt"

echo "======================================="
echo "[*] Running test_ra (release/acquire)"
perf record -o perf.data.ra ./test_ra
perf report -i perf.data.ra --stdio > report.ra.txt
echo "  ✅ Output: report.ra.txt"

echo "======================================="
echo "[*] All tests completed. Summary of reports:"
echo "   - report.relaxed.txt"
echo "   - report.fence.txt"
echo "   - report.ra.txt"
