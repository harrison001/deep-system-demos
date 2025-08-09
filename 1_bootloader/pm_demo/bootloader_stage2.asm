[bits 16]
[org 0x0]                  ; IP starts from 0, but CS=0x6000

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
   
   ;-------------------------------------------- 统一的保护模式入口 ----------------------------------------
   ; 根据配置选择不同的实现方法
   
   %if PM_ENTRY_MODE == 1
   ; Method B: 间接跳转方式 (使用farptr)
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
   ; Method A: 需要运行时修补GDT
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
   or al, 1
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
    mov dword [0xb8000], 0x2F412F41   ; 'A' 两次，看到就说明已到 pm32
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
    
    ; Infinite loop - no more interrupts
.halt:
    jmp .halt                       ; Simple infinite loop, no hlt

;----------------------------------------
; Setup IDT
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

;----------------------------------------
; IDT Table and Descriptor
;----------------------------------------
align 8
idt_table:
    times 256 dq 0      ; 256 IDT entries, 8 bytes each

idt_descriptor:
    dw 0                ; IDT limit (filled at runtime)
    dd 0                ; IDT base address (filled at runtime)
