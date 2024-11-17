; boot.asm - A minimal bootloader and kernel
[BITS 16]           ; Start in 16-bit real mode
[ORG 0x7C00]        ; BIOS loads us here

start:
    ; Set up segments
    cli             ; Disable interrupts
    mov ax, 0x0000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00  ; Set stack pointer
    sti             ; Enable interrupts

    ; Print welcome message
    mov si, msg
    call print_string

    ; Infinite loop
    jmp $

; Print string routine
print_string:
    pusha
    mov ah, 0x0E    ; BIOS teletype output
.loop:
    lodsb           ; Load next character
    test al, al     ; Check if end of string (0)
    jz .done
    int 0x10        ; Print character
    jmp .loop
.done:
    popa
    ret

msg db 'Welcome to MyOS!', 0x0D, 0x0A, 0

; Boot sector magic
times 510-($-$$) db 0   ; Pad with zeros
dw 0xAA55              ; Boot signature