[bits 16]
[org 0x0]                  ; IP starts from 0, but CS=0x6000

; ===== Feature toggles =====
; Use command line switches to enable features:
; nasm -dENABLE_EXC       : Exception vector handling (0-19)
; nasm -dENABLE_PIC       : PIC remapping + IRQ0 timer interrupt
; nasm -dENABLE_INTEGRITY : GDT/IDT 16-bit checksum verification

;----------------------------------------
; Configuration - Use METHOD_A or METHOD_B
; Define via command line: nasm -dMETHOD_A or nasm -dMETHOD_B
;----------------------------------------
%ifndef METHOD_A
    %ifndef METHOD_B
        %define METHOD_A        ; Default to METHOD_A if neither defined
    %endif
%endif

;----------------------------------------
; Method-specific constants and macros
;----------------------------------------
%ifdef METHOD_A
    %define PM_CODE_SEL   SEL_CODEA     ; Use runtime-patched segment (0x08)
    %define PM_ENTRY_MODE 0             ; 0 = immediate jump, 1 = indirect jump
    %define HANDLER_ADDR_MODE 0         ; 0 = offset only, 1 = linear address
    %define METHOD_NAME "Method A (Runtime GDT patch)"
%endif

%ifdef METHOD_B  
    %define PM_CODE_SEL   SEL_CODEB     ; Use flat segment (0x10)
    %define PM_ENTRY_MODE 1             ; 0 = immediate jump, 1 = indirect jump  
    %define HANDLER_ADDR_MODE 1         ; 0 = offset only, 1 = linear address
    %define METHOD_NAME "Method B (Flat addressing)"
%endif

;----------------------------------------
; Stage 2 - Simplified 16-bit loader with integrated 32-bit protected mode
;----------------------------------------
stage2_start:
    ;Initialize segment registers
    mov ax, cs            ; CS is already 0x6000
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00
    mov es, ax

    ;Show success message
    mov si, stage2_msg
    call print_string
    
    ;Enter protected mode
    mov si, entering_pm_msg
    call print_string
    
    cli                     ; Disable interrupts
    
    ;Calculate correct GDT physical address at runtime
    mov ax, cs              ; CS 
    mov dx, 16
    mul dx                  ; AX = CS * 16 
    add ax, gdt_start       ; Add GDT offset
    adc dx, 0               ; Handle carry
    
    ;Store in GDT descriptor
    mov [gdt_descriptor + 2], ax    ; Low word
    mov [gdt_descriptor + 4], dx    ; High word
   
   ;-------------------------------------------- Unified Protected Mode Entry ----------------------------------------
   ; Choose different implementation methods based on configuration
   
   %if PM_ENTRY_MODE == 1
   ; Method B: Indirect jump method (using farptr)
   ;compute target linear = (CS<<4) + pm_start_32  
   xor  eax, eax
   mov  ax, cs
   shl  eax, 4
   add  eax, pm_start_32        ; EAX = target address (linear for Method B)

   ; Store target address and selector
   mov  [farptr+0], eax         ; Store target address
   mov  word [farptr+4], PM_CODE_SEL   ; Store code selector
   %endif
   
   %if PM_ENTRY_MODE == 0
   ; Method A: Requires runtime GDT patching
   ; Calculate BASE = (CS << 4) → result in DX:AX
   mov  ax, cs
   mov  dx, 16
   mul  dx                  ; DX:AX = CS * 16 (segment base address)

   ; DI points to the code segment descriptor (skip null descriptor)
   mov  di, gdt_start
   add  di, 8

   ; Write base_low (bytes 2..3)
   mov  [di+2], ax          ; write 2 bytes (word)

   ; Write base_mid (byte 4) = BASE[16..23] = low 8 bits of DX
   mov  [di+4], dl          ; write 1 byte

   ; Write base_high (byte 7) = BASE[24..31] = high 8 bits of DX
   mov  [di+7], dh          ; for 0x60000 this will be 0   
   %endif
   
   ; Load GDT (common for both methods)
   lgdt [gdt_descriptor]

   ; Enter protected mode (common for both methods)
   mov eax, cr0
   or eax, 1
   mov cr0, eax   

   ; Jump to 32-bit code - method specific
   %if PM_ENTRY_MODE == 0
   jmp PM_CODE_SEL:pm_start_32      ; Direct immediate jump
   %endif
   %if PM_ENTRY_MODE == 1  
   jmp far dword [farptr]           ; Indirect jump via farptr
   %endif
    ;-----------------------------------------------------------------------------------------------------

;----------------------------------------
; 16-bit print function
;----------------------------------------
print_string:
    mov ah, 0x0e
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

;----------------------------------------
; Data
;----------------------------------------
stage2_msg db "Stage2 simplified loader started!", 13, 10, 0
entering_pm_msg db "Entering protected mode...", 13, 10, 0

; =========================
; GDT table (32-bit pmode)
; NASM syntax
; =========================

farptr: dd 0, 0
temp_jump_addr: dd 0, 0
; ------- selectors (index<<3 | TI=0 | RPL=0) -------
SEL_NULL   equ 0x00        ; index 0
SEL_CODEA  equ 0x08        ; index 1 → for Scheme A (runtime base patch)
SEL_CODEB  equ 0x10        ; index 2 → for Scheme B (flat base=0)
SEL_DATA   equ 0x18        ; index 3 → flat data

; ------- helper macro: build one 8-byte descriptor -------
; use: DESC base, limit, access, flags
; access (typical): code=10011010b, data=10010010b
; flags  (typical): 11001111b  ; G=1, D=1, L=0, AVL=0, limit_high=0xF
%macro DESC 4
    ; limit low
    dw  (%2) & 0xFFFF
    ; base low
    dw  (%1) & 0xFFFF
    ; base mid
    db  ((%1) >> 16) & 0xFF
    ; access
    db  %3
    ; flags + limit high
    db  (((%2) >> 16) & 0x0F) | ((%4) & 0xF0)
    ; base high
    db  ((%1) >> 24) & 0xFF
%endmacro

; ------- common encodings -------
ACC_CODE32  equ 10011010b   ; present, DPL=0, code, readable
ACC_DATA32  equ 10010010b   ; present, DPL=0, data, writable
FLG_GRAN4K  equ 11000000b   ; G=1, D=1, L=0, AVL=0 (upper nibble) => 0xC0
LIM_4GB     equ 0x000FFFFF  ; with G=1 → ~4GB

align 8
gdt_start:
    ; 0) Null descriptor
    dd 0, 0

    ; 1) CodeA (for Scheme A): base placeholder=0 (will be patched at runtime to CS<<4)
    ;    limit=4GB (with G=1), access=code, flags=G=1,D=1
    DESC 0x00000000, LIM_4GB, ACC_CODE32, FLG_GRAN4K

    ; 2) CodeB (for Scheme B): flat base=0
    DESC 0x00000000, LIM_4GB, ACC_CODE32, FLG_GRAN4K

    ; 3) Data (flat base=0)
    DESC 0x00000000, LIM_4GB, ACC_DATA32, FLG_GRAN4K
gdt_end:

; 16-bit LGDT uses 6-byte pseudo-descriptor: limit(2) + base(4, low 24 used)
gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0                          ; Address calculated at runtime

;----------------------------------------
; 32-bit protected mode code
;----------------------------------------
[bits 32]
pm_start_32:
    ; Set up data segments immediately
    mov ax, 0x18
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000     ; Set stack
    
    ; Clear screen first for clean display
    mov edi, 0xb8000
    mov eax, 0x07200720  ; Spaces with light gray on black
    mov ecx, 1000        ; 80*25 characters
    rep stosd
    
    ; Display method info at top of screen
    %ifdef METHOD_A
    ; Display "METHOD A + IDT" 
    mov word [0xb8000], 0x0F4D      ; 'M' white on black
    mov word [0xb8002], 0x0F45      ; 'E' white on black  
    mov word [0xb8004], 0x0F54      ; 'T' white on black
    mov word [0xb8006], 0x0F48      ; 'H' white on black
    mov word [0xb8008], 0x0F4F      ; 'O' white on black
    mov word [0xb800a], 0x0F44      ; 'D' white on black
    mov word [0xb800c], 0x0F20      ; ' ' white on black
    mov word [0xb800e], 0x0F41      ; 'A' white on black
    mov word [0xb8010], 0x0F20      ; ' ' space
    mov word [0xb8012], 0x0F2B      ; '+' yellow
    mov word [0xb8014], 0x0F20      ; ' ' space
    mov word [0xb8016], 0x0F49      ; 'I' white on black
    mov word [0xb8018], 0x0F44      ; 'D' white on black
    mov word [0xb801a], 0x0F54      ; 'T' white on black
    %endif
    %ifdef METHOD_B
    ; Display "METHOD B + IDT"
    mov word [0xb8000], 0x0F4D      ; 'M' white on black
    mov word [0xb8002], 0x0F45      ; 'E' white on black  
    mov word [0xb8004], 0x0F54      ; 'T' white on black
    mov word [0xb8006], 0x0F48      ; 'H' white on black
    mov word [0xb8008], 0x0F4F      ; 'O' white on black
    mov word [0xb800a], 0x0F44      ; 'D' white on black
    mov word [0xb800c], 0x0F20      ; ' ' white on black
    mov word [0xb800e], 0x0F42      ; 'B' white on black
    mov word [0xb8010], 0x0F20      ; ' ' space
    mov word [0xb8012], 0x0F2B      ; '+' yellow  
    mov word [0xb8014], 0x0F20      ; ' ' space
    mov word [0xb8016], 0x0F49      ; 'I' white on black
    mov word [0xb8018], 0x0F44      ; 'D' white on black
    mov word [0xb801a], 0x0F54      ; 'T' white on black
    %endif
    
    ; Setup IDT
    call setup_idt
    
    ; Display message about IDT setup
    mov word [0xb8160], 0x0E49      ; 'I' yellow (row 1, col 0)
    mov word [0xb8162], 0x0E44      ; 'D' yellow
    mov word [0xb8164], 0x0E54      ; 'T' yellow
    mov word [0xb8166], 0x0E20      ; ' ' yellow
    mov word [0xb8168], 0x0E53      ; 'S' yellow
    mov word [0xb816a], 0x0E45      ; 'E' yellow
    mov word [0xb816c], 0x0E54      ; 'T' yellow
    mov word [0xb816e], 0x0E55      ; 'U' yellow
    mov word [0xb8170], 0x0E50      ; 'P' yellow
    
    ; Perform integrity checking using SGDT/SIDT
    %ifdef ENABLE_INTEGRITY
    
    ; Use SGDT to get current GDT info directly from CPU
    sgdt [current_gdt_desc]
    
    ; Calculate GDT checksum using CPU-reported address
    movzx ecx, word [current_gdt_desc]  ; limit from SGDT
    inc ecx                             ; size = limit + 1
    mov esi, [current_gdt_desc+2]       ; base address from SGDT
    call checksum16
    mov [gdt_cksum], ax

    ; Use SIDT to get current IDT info directly from CPU  
    sidt [current_idt_desc]
    
    ; Calculate IDT checksum using CPU-reported address
    movzx ecx, word [current_idt_desc]  ; limit from SIDT
    inc ecx                             ; size = limit + 1
    mov esi, [current_idt_desc+2]       ; base address from SIDT
    call checksum16
    mov [idt_cksum], ax

    ; Display integrity info at row 1, middle (col 30)
    ; "GDT:" label
    mov word [0xb81bc], 0x0B47      ; 'G' cyan (row 1, col 30)
    mov word [0xb81be], 0x0B44      ; 'D' cyan
    mov word [0xb81c0], 0x0B54      ; 'T' cyan
    mov word [0xb81c2], 0x0B3A      ; ':' cyan
    
    ; Display GDT checksum
    movzx eax, word [gdt_cksum]
    mov edi, 0xb81c4
    call print_hex16_at_edi
    
    
    ; " IDT:" label
    mov word [0xb81cc], 0x0B20      ; ' ' cyan
    mov word [0xb81ce], 0x0B49      ; 'I' cyan
    mov word [0xb81d0], 0x0B44      ; 'D' cyan
    mov word [0xb81d2], 0x0B54      ; 'T' cyan
    mov word [0xb81d4], 0x0B3A      ; ':' cyan
    
    ; Display IDT checksum
    movzx eax, word [idt_cksum]
    mov edi, 0xb81d6
    call print_hex16_at_edi
    %endif
    
    ; Enable interrupts
    ; sti
    
    ; Display trigger message BEFORE interrupt
    mov word [0xb8320], 0x0C49      ; 'I' red (row 2)
    mov word [0xb8322], 0x0C4E      ; 'N' red
    mov word [0xb8324], 0x0C54      ; 'T' red
    mov word [0xb8326], 0x0C20      ; ' ' red
    mov word [0xb8328], 0x0C30      ; '0' red
    mov word [0xb832a], 0x0C78      ; 'x' red
    mov word [0xb832c], 0x0C33      ; '3' red
    mov word [0xb832e], 0x0C30      ; '0' red
    mov word [0xb8330], 0x0C20      ; ' ' red
    mov word [0xb8332], 0x0C54      ; 'T' red
    mov word [0xb8334], 0x0C52      ; 'R' red
    mov word [0xb8336], 0x0C49      ; 'I' red
    mov word [0xb8338], 0x0C47      ; 'G' red
    mov word [0xb833a], 0x0C47      ; 'G' red
    mov word [0xb833c], 0x0C45      ; 'E' red
    mov word [0xb833e], 0x0C52      ; 'R' red
    mov word [0xb8340], 0x0C45      ; 'E' red
    mov word [0xb8342], 0x0C44      ; 'D' red
   
    ;.haltone:
    ;jmp .haltone  
    ; Trigger custom interrupt 0x30 ONCE
    int 0x30
    
    ; Optional exception trigger (uncomment to test exception handling)
    %ifdef ENABLE_EXC
    ; Trigger #DE (Divide Error): uncomment to test
    ; xor edx, edx
    ; mov eax, 1234
    ; div edx
    %endif
    
    ; Optional self-tampering demonstration (uncomment to test integrity detection)
    %ifdef ENABLE_INTEGRITY
    ; Example: modify IDT entry 0x30's attribute byte and recalculate
    ; mov byte [idt_table + 0x30*8 + 5], 0xEF   ; modify type/attr high byte
    ; 
    ; ; Recalculate IDT checksum and display change
    ; movzx ecx, word [idt_descriptor]
    ; inc ecx
    ; mov esi, [idt_descriptor+2]
    ; call checksum16
    ; ; Compare with stored value and display difference...
    %endif
    
    ; Disable interrupts after demo
    ;cli
    
    ; Disable PIC (Programmable Interrupt Controller) to stop all hardware interrupts
   ; mov al, 0xFF        ; Mask all interrupts
   ; out 0x21, al        ; Master PIC
   ; out 0xA1, al        ; Slave PIC
    
    ; Display completion message
    mov word [0xb86a0], 0x0B44      ; 'D' cyan (row 4)
    mov word [0xb86a2], 0x0B4F      ; 'O' cyan
    mov word [0xb86a4], 0x0B4E      ; 'N' cyan
    mov word [0xb86a6], 0x0B45      ; 'E' cyan
    mov word [0xb86a8], 0x0B20      ; ' ' cyan
    mov word [0xb86aa], 0x0B2D      ; '-' cyan
    mov word [0xb86ac], 0x0B20      ; ' ' cyan
    mov word [0xb86ae], 0x0B53      ; 'S' cyan
    mov word [0xb86b0], 0x0B54      ; 'T' cyan
    mov word [0xb86b2], 0x0B4F      ; 'O' cyan
    mov word [0xb86b4], 0x0B50      ; 'P' cyan
    mov word [0xb86b6], 0x0B50      ; 'P' cyan
    mov word [0xb86b8], 0x0B45      ; 'E' cyan
    mov word [0xb86ba], 0x0B44      ; 'D' cyan
    
    ; Infinite loop with conditional interrupt handling
.halt:
    %ifdef ENABLE_PIC
        sti                         ; Enable interrupts if PIC is enabled
    %else
        cli                         ; Disable interrupts if PIC not enabled
    %endif
    hlt                             ; Halt and wait for interrupt
    jmp .halt

;----------------------------------------
; Setup IDT
; 
; Important: The IDT offset field is semantically a "segment offset". When using
; flat segments (base=0), the segment offset value equals the linear address value,
; making it appear as if we're using "linear addresses", but the semantic meaning
; remains "segment offset". Method A uses runtime GDT base patching, while Method B
; uses flat segments (base=0). Both approaches are correct.
;----------------------------------------
setup_idt:
    ; Clear IDT (256 entries * 8 bytes = 2048 bytes)
    mov edi, idt_table
    xor eax, eax
    mov ecx, 512        ; 2048/4 = 512 dwords
    rep stosd
    
    ; Setup interrupt 0x30 - Universal address calculation
    %if HANDLER_ADDR_MODE == 0
    ; Method A: Use offset only (GDT base will be added by hardware)
    mov eax, custom_interrupt_handler   ; Handler offset
    %endif
    %if HANDLER_ADDR_MODE == 1
    ; Method B: Calculate linear address (flat model, base=0)
    mov eax, 0x60000                   ; Our segment base (CS << 4)
    add eax, custom_interrupt_handler   ; Add handler offset -> linear address
    %endif
    
    ; Set up IDT entry for interrupt 0x30
    mov ebx, idt_table
    add ebx, (0x30 * 8)                 ; Point to entry 0x30
    
    ; Low 32 bits: offset[15:0] + segment selector
    mov [ebx], ax                       ; offset[15:0]
    mov word [ebx + 2], PM_CODE_SEL    ; code segment selector (method-specific)
    
    ; High 32 bits: attributes + offset[31:16]
    shr eax, 16
    mov [ebx + 6], ax                   ; offset[31:16]
    mov word [ebx + 4], 0x8E00         ; interrupt gate, DPL=0, present
    
    ; Install exception handlers (vectors 0-19)
    %ifdef ENABLE_EXC
    %define IDT_ATTR 0x8E00
    %define KCODE    PM_CODE_SEL     ; Code segment selector (Method A=0x08, Method B=0x10)

    ; Install exception handlers using manual setup (avoiding macro issues)
    call install_exception_handlers
    ; Vector 15 is reserved and skipped
    %endif

    ; Install PIC handlers and remap
    %ifdef ENABLE_PIC
    ; Install IRQ0 (Timer) -> vector 0x20
    call install_irq0_handler

    ; Remap PIC and enable IRQ0
    call pic_remap
    %endif

    ; Load IDT
    mov word [idt_descriptor], (256 * 8) - 1    ; IDT limit
    mov eax, idt_table
    mov [idt_descriptor + 2], eax               ; IDT base
    lidt [idt_descriptor]
    
    ret

;----------------------------------------
; Custom interrupt handler (INT 0x30) - SIMPLIFIED
;----------------------------------------
custom_interrupt_handler:
    ; Display simple handler message at row 3 - minimal writes
    mov word [ds:0xb84e0], 0x0A48   ; 'H' green (row 3)
    mov word [ds:0xb84e2], 0x0A41   ; 'A' green  
    mov word [ds:0xb84e4], 0x0A4E   ; 'N' green
    mov word [ds:0xb84e6], 0x0A44   ; 'D' green
    mov word [ds:0xb84e8], 0x0A4C   ; 'L' green
    mov word [ds:0xb84ea], 0x0A45   ; 'E' green
    mov word [ds:0xb84ec], 0x0A52   ; 'R' green
    
    iret                ; Return from interrupt immediately

;=============== Exception Vector Handling (0-19) ===============
%ifdef ENABLE_EXC

; Common ISR macros
; ISR without error code: push dummy 0, then vector number
%macro ISR_NOERR 1
isr_%1:
    push dword 0          ; dummy error code
    push dword %1         ; vector number
    jmp isr_common_noerr
%endmacro

; ISR with error code: CPU already pushed error code, just push vector number
%macro ISR_ERR 1
isr_%1:
    push dword %1         ; vector number
    jmp isr_common_err
%endmacro

; Macro to set IDT entry: index, handler, selector, type_attr
%macro SET_IDT 4
    ; ebx = idt_table + idx*8
    mov ebx, idt_table
    add ebx, (%1)*8

    ; Calculate handler address based on method
    %if HANDLER_ADDR_MODE == 0
    ; Method A: Use offset only (GDT base will be added by hardware)
    mov eax, %2           ; Handler offset
    %endif
    %if HANDLER_ADDR_MODE == 1
    ; Method B: Calculate linear address (flat model, base=0)
    mov eax, 0x60000      ; Our segment base (CS << 4)
    add eax, %2           ; Add handler offset -> linear address
    %endif
    
    mov [ebx], ax         ; offset low
    mov word [ebx+2], %3  ; selector
    shr eax, 16
    mov [ebx+6], ax       ; offset high
    mov word [ebx+4], %4  ; type/attr (0x8E00 = 32-bit interrupt gate, DPL=0, P=1)
%endmacro

; Common handler for exceptions without error code
; Stack layout when entering isr_common_noerr:
;   [esp+0]  vector number (we pushed)
;   [esp+4]  dummy error code 0 (we pushed)
; After pusha: vector at [esp+36], error code at [esp+32]
isr_common_noerr:
    pusha
    mov ax, 0x18          ; kernel data segment
    mov ds, ax
    mov es, ax

    mov eax, [esp+36]     ; vector number
    mov ebx, [esp+32]     ; error code (0)
    
    ; Display exception info at row 3 (0xb84e0 + offset)
    ; "EXC:" at start of row 3
    mov word [ds:0xb84e0], 0x0C45   ; 'E' red
    mov word [ds:0xb84e2], 0x0C58   ; 'X' red
    mov word [ds:0xb84e4], 0x0C43   ; 'C' red
    mov word [ds:0xb84e6], 0x0C3A   ; ':' red
    
    ; Display vector number in hex
    push eax
    mov edi, 0xb84e8      ; position after "EXC:"
    call print_hex8_at_edi
    pop eax

    popa
    add esp, 8            ; remove our pushed values
    iretd

; Common handler for exceptions with error code
; Stack layout when entering isr_common_err:
;   [esp+0]  vector number (we pushed)
;   CPU already pushed: EIP, CS, EFLAGS, error code
; After pusha: vector at [esp+36], error code at [esp+40]
isr_common_err:
    pusha
    mov ax, 0x18
    mov ds, ax
    mov es, ax

    mov eax, [esp+36]     ; vector number
    mov ebx, [esp+40]     ; actual error code from CPU
    
    ; Display exception info at row 3
    mov word [ds:0xb84e0], 0x0C45   ; 'E' red
    mov word [ds:0xb84e2], 0x0C58   ; 'X' red
    mov word [ds:0xb84e4], 0x0C43   ; 'C' red
    mov word [ds:0xb84e6], 0x0C3A   ; ':' red
    
    ; Display vector number
    push eax
    mov edi, 0xb84e8
    call print_hex8_at_edi
    pop eax
    
    ; Display " ERR:" 
    mov word [ds:0xb84f0], 0x0C20   ; ' ' red
    mov word [ds:0xb84f2], 0x0C45   ; 'E' red
    mov word [ds:0xb84f4], 0x0C52   ; 'R' red
    mov word [ds:0xb84f6], 0x0C52   ; 'R' red
    mov word [ds:0xb84f8], 0x0C3A   ; ':' red
    
    ; Display error code
    mov eax, ebx
    mov edi, 0xb84fa
    call print_hex8_at_edi

    popa
    add esp, 4            ; remove only our pushed vector number
    iretd

; Exception vectors without error code: 0,1,2,3,4,5,6,7,9,16,18,19
ISR_NOERR 0    ; Divide Error
ISR_NOERR 1    ; Debug Exception
ISR_NOERR 2    ; NMI Interrupt
ISR_NOERR 3    ; Breakpoint
ISR_NOERR 4    ; Overflow
ISR_NOERR 5    ; BOUND Range Exceeded
ISR_NOERR 6    ; Invalid Opcode
ISR_NOERR 7    ; Device Not Available
ISR_NOERR 9    ; Coprocessor Segment Overrun
ISR_NOERR 16   ; x87 FPU Floating-Point Error
ISR_NOERR 18   ; Machine Check
ISR_NOERR 19   ; SIMD Floating-Point Exception

; Exception vectors with error code: 8,10,11,12,13,14,17
ISR_ERR 8      ; Double Fault
ISR_ERR 10     ; Invalid TSS
ISR_ERR 11     ; Segment Not Present
ISR_ERR 12     ; Stack Fault
ISR_ERR 13     ; General Protection
ISR_ERR 14     ; Page Fault
ISR_ERR 17     ; Alignment Check

; Install all exception handlers
install_exception_handlers:
    push eax
    push ebx
    
    ; Install handlers for vectors 0-19 (skip 15 as it's reserved)
    
    ; Vector 0: Divide Error
    mov ebx, idt_table
    add ebx, 0*8
    %if HANDLER_ADDR_MODE == 0
    mov eax, isr_0
    %else
    mov eax, 0x60000
    add eax, isr_0
    %endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    ; Vector 1: Debug Exception
    mov ebx, idt_table
    add ebx, 1*8
    %if HANDLER_ADDR_MODE == 0
    mov eax, isr_1
    %else
    mov eax, 0x60000
    add eax, isr_1
    %endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    ; Vector 2: NMI
    mov ebx, idt_table
    add ebx, 2*8
    %if HANDLER_ADDR_MODE == 0
    mov eax, isr_2
    %else
    mov eax, 0x60000
    add eax, isr_2
    %endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    ; Vector 13: General Protection (most common)
    mov ebx, idt_table
    add ebx, 13*8
    %if HANDLER_ADDR_MODE == 0
    mov eax, isr_13
    %else
    mov eax, 0x60000
    add eax, isr_13
    %endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00

    ; Add more vectors as needed - keeping minimal for now
    
    pop ebx
    pop eax
    ret

%endif ; ENABLE_EXC

;=============== PIC Remapping + IRQ0 Timer Interrupt ===============
%ifdef ENABLE_PIC

; PIC constants
PIC1_CMD   equ 0x20
PIC1_DATA  equ 0x21
PIC2_CMD   equ 0xA0
PIC2_DATA  equ 0xA1
EOI        equ 0x20

; Remap PIC to vectors 0x20-0x2F
pic_remap:
    ; Save current interrupt masks
    in   al, PIC1_DATA
    push eax
    in   al, PIC2_DATA
    push eax

    ; Send ICW1: start initialization sequence (edge triggered, cascade, ICW4 needed)
    mov al, 0x11
    out PIC1_CMD, al
    out PIC2_CMD, al

    ; Send ICW2: set interrupt vector offsets
    mov al, 0x20      ; master PIC base = 0x20 (IRQ0-7 -> INT 0x20-0x27)
    out PIC1_DATA, al
    mov al, 0x28      ; slave PIC base = 0x28 (IRQ8-15 -> INT 0x28-0x2F)
    out PIC2_DATA, al

    ; Send ICW3: set cascade connections
    mov al, 0x04      ; master has slave on IRQ2
    out PIC1_DATA, al
    mov al, 0x02      ; slave cascade identity
    out PIC2_DATA, al

    ; Send ICW4: set mode (8086 mode, normal EOI)
    mov al, 0x01
    out PIC1_DATA, al
    out PIC2_DATA, al

    ; Restore masks, but only enable IRQ0 (timer)
    pop eax
    mov al, 0xFF      ; disable all slave PIC interrupts
    out PIC2_DATA, al

    pop eax
    mov al, 0xFE      ; enable only IRQ0 on master PIC (bit0=0)
    out PIC1_DATA, al
    ret

; IRQ0 (Timer) interrupt handler
isr_irq0:
    pusha
    mov ax, 0x18
    mov ds, ax
    mov es, ax

    ; Increment tick counter
    inc dword [irq0_ticks]

    ; Display tick count at top-right corner (row 0, col 70)
    ; "TICKS:" label
    mov word [ds:0xb808c], 0x0E54   ; 'T' yellow (row 0, col 70)
    mov word [ds:0xb808e], 0x0E49   ; 'I' yellow
    mov word [ds:0xb8090], 0x0E43   ; 'C' yellow
    mov word [ds:0xb8092], 0x0E4B   ; 'K' yellow
    mov word [ds:0xb8094], 0x0E53   ; 'S' yellow
    mov word [ds:0xb8096], 0x0E3A   ; ':' yellow

    ; Display tick count in hex
    mov eax, [irq0_ticks]
    and eax, 0xFF     ; show only low byte for simplicity
    mov edi, 0xb8098  ; position after "TICKS:"
    call print_hex8_at_edi

    ; Send EOI to master PIC
    mov al, EOI
    out PIC1_CMD, al

    popa
    iretd

; Install IRQ0 handler
install_irq0_handler:
    push eax
    push ebx
    
    ; Install IRQ0 (Timer) -> vector 0x20
    mov ebx, idt_table
    add ebx, 0x20*8
    %if HANDLER_ADDR_MODE == 0
    mov eax, isr_irq0
    %else
    mov eax, 0x60000
    add eax, isr_irq0
    %endif
    mov [ebx], ax
    mov word [ebx+2], PM_CODE_SEL
    shr eax, 16
    mov [ebx+6], ax
    mov word [ebx+4], 0x8E00
    
    pop ebx
    pop eax
    ret

; IRQ0 tick counter
irq0_ticks: dd 0

%endif ; ENABLE_PIC

;=============== GDT/IDT Integrity Checking ===============
%ifdef ENABLE_INTEGRITY

; Calculate 16-bit checksum of memory region
; Input:  ESI = base address, ECX = size in bytes
; Output: AX = 16-bit checksum
checksum16:
    push ebx
    push edx
    xor eax, eax        ; clear checksum accumulator
    test ecx, ecx       ; check for zero size
    jz .done
.ck_loop:
    movzx edx, byte [esi]   ; load byte and zero-extend to 32-bit
    add ax, dx              ; add to 16-bit checksum
    inc esi
    dec ecx
    jnz .ck_loop
.done:
    pop edx
    pop ebx
    ret

; Storage for checksums
gdt_cksum: dw 0
idt_cksum: dw 0

; Storage for SGDT/SIDT results
current_gdt_desc: dw 0, 0, 0    ; 6 bytes: limit(2) + base(4)
current_idt_desc: dw 0, 0, 0    ; 6 bytes: limit(2) + base(4)

%endif ; ENABLE_INTEGRITY

;----------------------------------------
; Print Utility Functions
;----------------------------------------

; Print 8-bit value in hex at specific VGA location
; Input: AL = value to print, EDI = VGA memory address
; Modifies: EAX, EBX, EDI
print_hex8_at_edi:
    push eax
    push ebx
    
    ; Print high nibble
    mov bl, al
    shr bl, 4
    and bl, 0x0F
    cmp bl, 9
    jbe .high_digit
    add bl, 'A' - 10 - '0'
.high_digit:
    add bl, '0'
    mov bh, 0x0C    ; red attribute
    mov [edi], bx
    add edi, 2
    
    ; Print low nibble
    mov bl, al
    and bl, 0x0F
    cmp bl, 9
    jbe .low_digit
    add bl, 'A' - 10 - '0'
.low_digit:
    add bl, '0'
    mov bh, 0x0C    ; red attribute
    mov [edi], bx
    add edi, 2      ; Move to next character position
    
    pop ebx
    pop eax
    ret

; Print 16-bit value in hex at specific VGA location
; Input: AX = value to print, EDI = VGA memory address
; Modifies: EAX, EBX, EDI
print_hex16_at_edi:
    push ebx
    mov bx, ax      ; Save original value in BX
    
    ; Print high byte
    mov al, bh      ; Get high byte
    call print_hex8_at_edi
    ; EDI is already moved by print_hex8_at_edi, no need to add
    
    ; Print low byte
    mov al, bl      ; Get low byte from saved value
    call print_hex8_at_edi
    
    pop ebx
    ret

;----------------------------------------
; IDT Table and Descriptor
;----------------------------------------
align 8
idt_table:
    times 256 dq 0      ; 256 IDT entries, 8 bytes each

idt_descriptor:
    dw 0                ; IDT limit (filled at runtime)
    dd 0                ; IDT base address (filled at runtime)
