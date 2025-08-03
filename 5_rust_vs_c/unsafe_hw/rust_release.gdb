file ./build/release/unsafe_hw_rust
set substitute-path /rustc/6b00bc3880198600130e1cf62b8f8a93494488cc /usr/src/rustc
set debuginfod enabled off
break unsafe_hw.rs:17
run
p 
context
