#!/bin/bash
set -e
mkdir -p build/release

echo "🚀 Building Rust (release)..."
cd src/rust
for f in *.rs; do
    fname="${f%.*}"
    rustc --crate-type=bin -C opt-level=3 -C debuginfo=1 "$f" -o "../../build/release/${fname}_rust"
done
cd ../..

echo "🚀 Building C (release)..."
cd src/c
for f in *.c; do
    fname="${f%.*}"
    gcc -O3 -g "$f" -o "../../build/release/${fname}_c"
done
cd ../..

echo "✅ Release build complete."
