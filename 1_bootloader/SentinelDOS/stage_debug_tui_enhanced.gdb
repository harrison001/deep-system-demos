target remote 192.168.1.248:1234
set architecture i8086

# Optional: Load symbols if available
# add-symbol-file stage1.elf 0x1fe00
# add-symbol-file stage2.elf 0x20000

# Enable TUI split view and layout
tui enable
layout split

# Display core segment and general-purpose registers
display/i $pc
display $cs
display $ds
display $es
display $ss
display $sp
display $ax
display $bx
display $si
display $di

# Watch shared memory parameter area
display/x 0x0500
display/x 0x0502
display/x 0x0504

# --- Stage 1 breakpoints ---
b *0x7c00    
b *0x1fe75    
b *0x1fe90     
b *0x1fea2     
b *0x1feb2    

# Before jumping to stage2, print shared memory and regs
b *0x1fed0
commands
silent
printf "\n>>> Jumping to Stage 2 <<<\n"
x/6bx 0x0500
info registers
c
end

# --- Stage 2 breakpoints ---
b *0x20000    
b *0x20072      

# Before validate_password, show password buffer (assuming offset is known)
b *0x2015d
commands
silent
printf "\n>>> Validating password <<<\n"
x/21bx 0x0000  # You may adjust if input_buf is relocated
info registers
c
end