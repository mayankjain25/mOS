; boot.asm - Fixed multi-sector bootloader using LBA
[BITS 16]
[ORG 0x7C00]

KERNEL_OFFSET equ 0x7E00  ; Load kernel right after bootloader

start:
    ; Set up segments
    cli             
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti             

    ; Save boot drive
    mov [boot_drive], dl

    ; Print loading message
    mov si, load_msg
    call print_string

    ; Try to use extended read
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc use_basic_load    ; If extended read not supported, use basic

    ; Use extended read (LBA)
    mov si, dap          ; Load using disk address packet
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    jmp load_success

use_basic_load:
    ; Reset disk system
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Load using CHS
    mov bx, KERNEL_OFFSET
    mov ah, 0x02
    mov al, 3            ; Read 3 sectors
    mov ch, 0            ; Cylinder 0
    mov cl, 2            ; Start from sector 2
    mov dh, 0            ; Head 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

load_success:
    ; Print success message
    mov si, ok_msg
    call print_string

    ; Jump to kernel
    jmp KERNEL_OFFSET

disk_error:
    mov si, disk_err_msg
    call print_string
    mov ah, 0x01        ; Get disk error status
    int 0x13
    mov al, ah          ; Display error code
    call print_hex
    jmp $

; Print hex value in AL
print_hex:
    pusha
    mov cx, 2
.loop:
    mov al, [esp + 8]   ; Get original AL value
    rol al, cl
    and al, 0x0F
    cmp al, 10
    jge .alpha
    add al, '0'
    jmp .print
.alpha:
    add al, 'A'-10
.print:
    mov ah, 0x0E
    int 0x10
    dec cl
    dec cl
    jns .loop
    
    ; Print newline
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret

; Print string routine
print_string:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

; Data
boot_drive db 0
disk_err_msg db 'Disk error! Code: ', 0
load_msg db 'Loading kernel...', 0x0D, 0x0A, 0
ok_msg db 'Kernel loaded successfully!', 0x0D, 0x0A, 0

; Disk Address Packet (DAP)
dap:
    db 0x10      ; DAP size (16 bytes)
    db 0         ; Always 0
    dw 3         ; Number of sectors to read
    dw KERNEL_OFFSET  ; Offset to load to
    dw 0         ; Segment to load to
    dq 1         ; LBA to load from (start from sector 1)

times 510-($-$$) db 0
dw 0xAA55

; ===========================================
; Kernel starts here (loaded at KERNEL_OFFSET)
; ===========================================

kernel_start:
    ; Set video mode
    mov ah, 0x00
    mov al, 0x03    ; 80x25 text mode
    int 0x10

    ; Set color
    mov ah, 0x0B
    mov bh, 0x00
    mov bl, 0x1F    ; White on blue
    int 0x10

    ; Clear screen and show banner
    call clear_screen
    mov si, banner
    call print_string

main_loop:
    mov si, prompt
    call print_string

    ; Get command
    mov di, command_buffer
    call read_string

    ; Compare commands
    mov si, command_buffer
    
    mov di, cmd_clear
    call strcmp
    jc do_clear

    mov si, command_buffer
    mov di, cmd_help
    call strcmp
    jc do_help

    mov si, command_buffer
    mov di, cmd_color
    call strcmp
    jc do_color

    mov si, command_buffer
    mov di, cmd_about
    call strcmp
    jc do_about

    ; Unknown command
    mov si, unknown_cmd
    call print_string
    jmp main_loop

; Command handlers
do_clear:
    call clear_screen
    jmp main_loop

do_help:
    mov si, help_msg
    call print_string
    jmp main_loop

do_color:
    call change_color
    jmp main_loop

do_about:
    mov si, about_msg
    call print_string
    jmp main_loop

; Utility functions
clear_screen:
    pusha
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    popa
    ret

change_color:
    mov ah, 0x0B
    mov bh, 0x00
    mov bl, [current_color]
    inc byte [current_color]
    and byte [current_color], 0x0F
    int 0x10
    ret

; Read string (from keyboard)
read_string:
    pusha
.loop:
    mov ah, 0x00
    int 0x16
    
    cmp al, 0x0D
    je .done
    
    cmp al, 0x08
    je .backspace
    
    mov ah, 0x0E
    int 0x10
    
    stosb
    jmp .loop

.backspace:
    cmp di, command_buffer
    je .loop
    dec di
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop

.done:
    mov al, 0
    stosb
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret

; String comparison
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
    clc
    ret
.equal:
    popa
    stc
    ret

; Data section
banner db '================================', 0x0D, 0x0A
      db '  MyOS v0.3 - Basic Command OS  ', 0x0D, 0x0A
      db '================================', 0x0D, 0x0A
      db 'Type "help" for commands', 0x0D, 0x0A, 0

prompt db '> ', 0
unknown_cmd db 'Unknown command. Type "help" for available commands.', 0x0D, 0x0A, 0
help_msg db 'Available commands:', 0x0D, 0x0A
        db '  clear  - Clear screen', 0x0D, 0x0A
        db '  help   - Show this help', 0x0D, 0x0A
        db '  color  - Change text color', 0x0D, 0x0A
        db '  about  - System information', 0x0D, 0x0A, 0

about_msg db 'MyOS v0.3', 0x0D, 0x0A
         db 'A simple bootable operating system', 0x0D, 0x0A
         db 'Built with NASM', 0x0D, 0x0A, 0

cmd_clear db 'clear', 0
cmd_help db 'help', 0
cmd_color db 'color', 0
cmd_about db 'about', 0

current_color db 0x1F
command_buffer times 64 db 0

times 2048-($-$$) db 0  ; Pad to 4 sectors total