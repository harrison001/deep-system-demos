#!/bin/bash
set -e

# === 1. Build Debug ===
cat <<'EOD' > build_debug.sh
#!/bin/bash
set -e
mkdir -p build/debug

echo "🔧 Building Rust (debug)..."
cd src/rust
for f in *.rs; do
    fname="\${f%.*}"
    rustc --crate-type=bin -g "\$f" -C debuginfo=2 -o "../../build/debug/\${fname}_rust"
done
cd ../..

echo "🔧 Building C (debug)..."
cd src/c
for f in *.c; do
    fname="\${f%.*}"
    gcc -g "\$f" -o "../../build/debug/\${fname}_c"
done
cd ../..

echo "✅ Debug build complete."
EOD
chmod +x build_debug.sh

# === 2. Build Release ===
cat <<'EOR' > build_release.sh
#!/bin/bash
set -e
mkdir -p build/release

echo "🚀 Building Rust (release)..."
cd src/rust
for f in *.rs; do
    fname="\${f%.*}"
    rustc --crate-type=bin -C opt-level=3 -C debuginfo=1 "\$f" -o "../../build/release/\${fname}_rust"
done
cd ../..

echo "🚀 Building C (release)..."
cd src/c
for f in *.c; do
    fname="\${f%.*}"
    gcc -O3 -g "\$f" -o "../../build/release/\${fname}_c"
done
cd ../..

echo "✅ Release build complete."
EOR
chmod +x build_release.sh

# === 3. GDB script generator ===
cat <<'EOG' > generate_gdb_scripts.sh
#!/bin/bash
set -e

modules=("bounds_check" "immutable" "ownership" "pointer" "unsafe_hw")

for module in "\${modules[@]}"; do
    mkdir -p "\$module"
    for lang in rust c; do
        for mode in debug release; do
            bin="./build/\${mode}/\${module}_\${lang}"
            script="./\${module}/\${lang}_\${mode}.gdb"
            echo "file \$bin" > "\$script"
            echo "break main" >> "\$script"
            echo "run" >> "\$script"
            echo "layout split" >> "\$script"
        done
    done
done

echo "✅ GDB scripts generated in subfolders."
EOG
chmod +x generate_gdb_scripts.sh

echo "🎉 All setup scripts generated!"
echo "✅ Next steps:"
echo "  ./build_debug.sh"
echo "  ./build_release.sh"
echo "  ./generate_gdb_scripts.sh"
