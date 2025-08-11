#intel mac
#target remote 192.168.1.248:1234
#m1-mac
target remote 192.168.1.148:1234
set architecture i8086
set disassembly-flavor intel
# add symbol file as needed
#add-symbol-file stage1.elf 0x7c00

# --- Stage1 key breakpoints ---
#_start
b *0x7c00
#shared date to stage2    
#watch *0x0500
#watch *0x0502
#watch *0x0504
#watch point can also help you to find the instructions in the memory.

#loader partition record
set $hitonce = 0
break *0x27a3e if $cs==0x1fe0 && $hitonce == 0
#commands
#  set $hitonce = 1
#end

# Check partition
set $hitonce = 0
break *0x27a44 if $cs==0x1fe0 && $hitonce == 0
#commands
#  set $hitonce = 1
#end

#load stage2 to 0x2000
set $hitonce = 0
break *0x27ad4 if $cs==0x1fe0 && $hitonce == 0
#commands
#  set $hitonce = 1
#end

#jump to stage2
set $hitonce = 0
break *0x20000 if $cs == 0x2000 && $hitonce == 0
#commands
#  set $hitonce = 1
#end


layout asm
layout regs

echo ✅Usage: r2a [offset] or r2a cs offset – show physical address.\n
define r2a
  if $argc == 0
    printf "cs:eip = 0x%x:0x%x -> physical = 0x%x\n", $cs, $eip, $cs * 0x10 + $eip
  end
  if $argc == 1
    printf "cs:eip = 0x%x:0x%x -> physical = 0x%x\n", $cs, $arg0, $cs * 0x10 + $arg0
  end
  if $argc == 2
    printf "cs:eip = 0x%x:0x%x -> physical = 0x%x\n", $arg0, $arg1, $arg0 * 0x10 + $arg1
  end
end

#use the script to locate the code by condition
define wait_until_condition
  set logging file /dev/null
  set logging redirect on
  set logging on
  while 1
    stepi
    if ($es == 0x2000 && $ah == 0x02 && $al == 0x02 && $dh == 0 && $cl == 2)
      set logging off
      set logging redirect off
      printf "✅ All conditions met at EIP = 0x%x, CS=0x%x\n", $eip,$cs
      #break
      return
    end
  end
end

#discover the instructions in the memory to help you locate the functions
# x/100i 0x27a00 #as it copied the code from 000:0x7c00 to cs:0x7c00
