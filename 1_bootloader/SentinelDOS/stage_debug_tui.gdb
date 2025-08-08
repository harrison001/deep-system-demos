target remote 192.168.1.248:1234
set architecture i8086

# Optional: Load symbols if available
# add-symbol-file stage1.elf 0x1fe00
# add-symbol-file stage2.elf 0x20000

# Set layout and enable TUI split view
tui enable
layout split

# Monitor critical segment and general-purpose registers
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

# Set key stage1 breakpoints
 # check_partition
b *0x1fe5a   
# active_part 
b *0x1fe75     
 # write to 0x0500
b *0x1fe90    
# write to 0x0502
b *0x1fea2   
# write to 0x0504  
b *0x1feb2    
 # jump to stage2 
b *0x1fed0    

# Set key stage2 breakpoints
# stage2_start
b *0x20000  
# show_params   
b *0x20072     
  # authenticate
b *0x200f5   
# validate_password
b *0x2015d     