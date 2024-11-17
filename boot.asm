; boot.asm - Compact bootloader and kernel with command prompt
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
    mov si, welcome_msg
    call print_string

main_loop:
    ; Print prompt
    mov si, prompt
    call print_string

    ; Get command input
    mov di, command_buffer
    call read_string

    ; Compare with 'cls' command
    mov si, command_buffer
    mov di, cmd_cls
    call strcmp
    jc clear_screen

    ; Unknown command
    mov si, unknown_cmd
    call print_string
    jmp main_loop

; Clear screen command
clear_screen:
    mov ah, 0x00    ; Set video mode
    mov al, 0x03    ; Text mode 80x25
    int 0x10
    jmp main_loop

; Print string routine (SI = string pointer)
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

; Read string from keyboard (DI = buffer pointer)
read_string:
    pusha
.loop:
    mov ah, 0x00    ; Read keyboard input
    int 0x16        ; BIOS keyboard services
    
    cmp al, 0x0D    ; Check for Enter key
    je .done
    
    cmp al, 0x08    ; Check for Backspace
    je .backspace
    
    mov ah, 0x0E    ; Echo character
    int 0x10
    
    stosb           ; Store character in buffer
    jmp .loop

.backspace:
    cmp di, command_buffer  ; Check if at start
    je .loop
    dec di          ; Remove last character
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop

.done:
    mov al, 0       ; Null terminate string
    stosb
    mov ah, 0x0E    ; New line
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret

; String comparison (SI, DI = strings to compare)
strcmp:
    pusha
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    inc si
    inc di
    jmp .loop
.not_equal:
    popa
    clc             ; Clear carry flag
    ret
.equal:
    popa
    stc             ; Set carry flag
    ret

; Data section
welcome_msg db 'MyOS v0.2', 0x0D, 0x0A, 0
prompt db '> ', 0
unknown_cmd db 'Unknown command', 0x0D, 0x0A, 0
cmd_cls db 'cls', 0

command_buffer times 32 db 0   ; Command input buffer

; Boot sector magic
times 510-($-$$) db 0   ; Pad with zeros
dw 0xAA55              ; Boot signature