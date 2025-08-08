[bits 16]
[org 0x0]                  ; IP starts from 0, but CS=0x2000

;----------------------------------------
; Stage 2 - Simplified 16-bit loader with integrated 32-bit protected mode
;----------------------------------------
stage2_start:
    ; Initialize segment registers
    mov ax, cs            ; CS is already 0x2000
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00
    mov es, ax

    ; Show success message
    mov si, stage2_msg
    call print_string
    
    ; Enter protected mode
    mov si, entering_pm_msg
    call print_string
    
    cli                     ; Disable interrupts
    
    ; Calculate correct GDT physical address at runtime
    mov ax, cs              ; CS = 0x2000
    mov dx, 16
    mul dx                  ; AX = CS * 16 = 0x20000
    add ax, gdt_start       ; Add GDT offset
    adc dx, 0               ; Handle carry
    
    ; Store in GDT descriptor
    mov [gdt_descriptor + 2], ax    ; Low word
    mov [gdt_descriptor + 4], dx    ; High word
    
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Enter protected mode
    mov eax, cr0
    or al, 1
    mov cr0, eax
    
    ; Jump to 32-bit code
    jmp 0x08:pm_start_32

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

;----------------------------------------
; Simple GDT
;----------------------------------------
align 8
gdt_start:
    ; Null descriptor
    dd 0, 0
    
    ; Code segment (0x08) - base=0x20000 where stage2 is loaded
    dw 0xFFFF       ; limit low
    dw 0x0000       ; base low (0x20000 & 0xFFFF)
    db 0x02         ; base mid (0x20000 >> 16)
    db 10011010b    ; access
    db 11001111b    ; flags + limit high
    db 0x00         ; base high (0x20000 >> 24)
    
    ; Data segment (0x10) - FLAT model base=0
    dw 0xFFFF       ; limit low
    dw 0x0000       ; base low = 0
    db 0x00         ; base mid = 0
    db 10010010b    ; access
    db 11001111b    ; flags + limit high
    db 0x00         ; base high = 0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0                          ; Address calculated at runtime

;----------------------------------------
; 32-bit protected mode code
;----------------------------------------
[bits 32]
pm_start_32:
    ; Set up data segments immediately
    mov eax, 0x10
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax
    mov esp, 0x90000     ; Set stack
    
    ; Clear screen first for clean display
    mov edi, 0xb8000
    mov eax, 0x07200720  ; Spaces with light gray on black
    mov ecx, 2000        ; 80*25 characters
    rep stosd
    
    ; Display "PROTECTED MODE + IDT" at top of screen
    mov word [0xb8000], 0x0F50      ; 'P' white on black
    mov word [0xb8002], 0x0F52      ; 'R' white on black
    mov word [0xb8004], 0x0F4F      ; 'O' white on black
    mov word [0xb8006], 0x0F54      ; 'T' white on black
    mov word [0xb8008], 0x0F45      ; 'E' white on black
    mov word [0xb800a], 0x0F43      ; 'C' white on black
    mov word [0xb800c], 0x0F54      ; 'T' white on black
    mov word [0xb800e], 0x0F45      ; 'E' white on black
    mov word [0xb8010], 0x0F44      ; 'D' white on black
    mov word [0xb8012], 0x0F20      ; ' ' space
    mov word [0xb8014], 0x0F2B      ; '+' yellow
    mov word [0xb8016], 0x0F20      ; ' ' space
    mov word [0xb8018], 0x0F49      ; 'I' white on black
    mov word [0xb801a], 0x0F44      ; 'D' white on black
    mov word [0xb801c], 0x0F54      ; 'T' white on black
    
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
    sti
    
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
    
    ; Trigger custom interrupt 0x30 ONCE
    int 0x30
    
    ; Disable interrupts after demo
    cli
    
    ; Disable PIC (Programmable Interrupt Controller) to stop all hardware interrupts
    mov al, 0xFF        ; Mask all interrupts
    out 0x21, al        ; Master PIC
    out 0xA1, al        ; Slave PIC
    
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
    
    ; Setup interrupt 0x30 - FIXED address calculation
    mov eax, custom_interrupt_handler   ; Get handler offset (GDT base handles physical address)
    
    ; Set up IDT entry for interrupt 0x30
    mov ebx, idt_table
    add ebx, (0x30 * 8)                 ; Point to entry 0x30
    
    ; Low 32 bits: offset[15:0] + segment selector
    mov [ebx], ax                       ; offset[15:0]
    mov word [ebx + 2], 0x08           ; code segment selector
    
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