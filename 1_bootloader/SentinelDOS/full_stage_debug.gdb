target remote 192.168.1.248:1234
set architecture i8086

# Load symbol for stage1 
add-symbol-file stage1.elf 00007c00

# Load symbol for stage2 (if ELF available)
add-symbol-file stage2.elf 0x20000

# ---- Stage 1 breakpoints ----
b *0x1fe5a     # check_partition
b *0x1fe75     # active_part
watch *(uint16_t*)0x0500  # watch cylinder/sector param
watch *(uint16_t*)0x0502  # watch head param
watch *(uint8_t*)0x0504   # watch drive param
b *0x1ff02     # load_error (optional)

# ---- Stage 2 breakpoints ----
b *0x20000     # stage2_start
b *0x20072     # show_params
b *0x200f5     # authenticate
b *0x2015d     # validate_password (estimated offset)