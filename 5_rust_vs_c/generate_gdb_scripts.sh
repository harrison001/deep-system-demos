#!/bin/bash
set -e

modules=("bounds_check" "immutable" "ownership" "pointer" "unsafe_hw")

for module in "${modules[@]}"; do
    mkdir -p "$module"
    for lang in rust c; do
        for mode in debug release; do
            bin="./build/${mode}/${module}_${lang}"
            script="./${module}/${lang}_${mode}.gdb"
            echo "file $bin" > "$script"
            if [ "$lang" = "rust" ]; then
                echo "set substitute-path /rustc/6b00bc3880198600130e1cf62b8f8a93494488cc /usr/src/rustc" >> "$script"
                echo "set debuginfod enabled off" >> "$script"
                echo "break ${module}.rs:17" >> "$script"
                echo "run" >> "$script"
                echo "p " >> "$script"
                echo "context" >> "$script"
            else
                echo "break main" >> "$script"
                echo "run" >> "$script"
                echo "p" >> "$script"
		echo "context" >> "$script"
            fi
        done
    done
done

echo "✅ GDB scripts generated in subfolders."
