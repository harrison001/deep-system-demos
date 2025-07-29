#!/bin/bash

echo "[*] Building without fence..."
gcc -O2 -g cpu_memory_model_test.c -o cpu_memory_model_test_nofence -lpthread

echo "[*] Building with fence..."
gcc -O2 -g -DDO_FENCE cpu_memory_model_test.c -o cpu_memory_model_test_fence -lpthread
