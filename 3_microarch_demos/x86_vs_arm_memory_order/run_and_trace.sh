#!/bin/bash

./build.sh

echo "[*] Running without fence..."
perf record -o perf.data.nofence ./cpu_memory_model_test_nofence
perf report -i perf.data.nofence --stdio > report.nofence.txt

echo "[*] Running with fence..."
perf record -o perf.data.fence ./cpu_memory_model_test_fence
perf report -i perf.data.fence --stdio > report.fence.txt

echo "[*] Done. See report.nofence.txt and report.fence.txt"
