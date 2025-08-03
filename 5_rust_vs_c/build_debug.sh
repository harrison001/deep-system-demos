#!/bin/bash
set -e
mkdir -p build/debug

echo "🔧 Building Rust (debug)..."
cd src/rust
for f in *.rs; do
    fname="${f%.*}"
    rustc --crate-type=bin -g "$f" -C debuginfo=2 -o "../../build/debug/${fname}_rust"
done
cd ../..

echo "🔧 Building C (debug)..."
cd src/c
for f in *.c; do
    fname="${f%.*}"
    gcc -g "$f" -o "../../build/debug/${fname}_c"
done
cd ../..

echo "✅ Debug build complete."
