#!/bin/bash

echo "[*] Compiling classic_reorder_test..."
gcc -o classic_reorder_test classic_reorder_test.c -lpthread -O2

echo "[*] Running classic_reorder_test..."
./classic_reorder_test 500000  
