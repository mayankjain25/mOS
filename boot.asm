; boot.asm - Enhanced multi-sector bootloader using LBA
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

; Data section for bootloader
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

    ; Set initial color
    mov ah, 0x0B
    mov bh, 0x00
    mov bl, 0x1F    ; White on blue
    int 0x10

    ; Initialize system
    call clear_screen
    mov byte [cursor_x], 0
    mov byte [cursor_y], 0
    
    ; Show banner
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

    mov si, command_buffer
    mov di, cmd_time
    call strcmp
    jc do_time

    mov si, command_buffer
    mov di, cmd_reboot
    call strcmp
    jc do_reboot

    mov si, command_buffer
    mov di, cmd_draw
    call strcmp
    jc do_draw

    mov si, command_buffer
    mov di, cmd_calc
    call strcmp
    jc do_calc

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

do_time:
    ; Get system time
    mov ah, 0x02
    int 0x1A
    push cx         ; Save hours/minutes
    push dx         ; Save seconds
    
    mov si, time_msg
    call print_string
    
    pop dx
    pop cx
    
    ; Print hours
    mov al, ch
    call print_hex_byte
    mov al, ':'
    call print_char
    
    ; Print minutes
    mov al, cl
    call print_hex_byte
    mov al, ':'
    call print_char
    
    ; Print seconds
    mov al, dh
    call print_hex_byte
    
    call print_newline
    jmp main_loop

do_reboot:
    mov si, reboot_msg
    call print_string
    xor ax, ax
    int 0x16        ; Wait for keypress
    int 0x19        ; Reboot system

do_draw:
    call clear_screen
    mov byte [cursor_x], 0
    mov byte [cursor_y], 0
    
    ; Drawing mode
.draw_loop:
    mov ah, 0x00
    int 0x16        ; Get keypress
    
    cmp al, 'q'     ; 'q' to quit
    je .draw_done
    
    cmp al, ' '     ; Space to draw
    je .draw_char
    
    ; Arrow keys navigation
    cmp ah, 0x48    ; Up arrow
    je .move_up
    cmp ah, 0x50    ; Down arrow
    je .move_down
    cmp ah, 0x4B    ; Left arrow
    je .move_left
    cmp ah, 0x4D    ; Right arrow
    je .move_right
    jmp .draw_loop
    
.draw_char:
    mov al, '*'
    call update_cursor
    jmp .draw_loop
    
.move_up:
    dec byte [cursor_y]
    jns .update_pos
    mov byte [cursor_y], 0
    jmp .update_pos
    
.move_down:
    inc byte [cursor_y]
    cmp byte [cursor_y], 24
    jle .update_pos
    mov byte [cursor_y], 24
    jmp .update_pos
    
.move_left:
    dec byte [cursor_x]
    jns .update_pos
    mov byte [cursor_x], 0
    jmp .update_pos
    
.move_right:
    inc byte [cursor_x]
    cmp byte [cursor_x], 79
    jle .update_pos
    mov byte [cursor_x], 79
    
.update_pos:
    mov ah, 0x02
    mov bh, 0
    mov dh, [cursor_y]
    mov dl, [cursor_x]
    int 0x10
    jmp .draw_loop
    
.draw_done:
    call print_newline
    jmp main_loop

do_calc:
    mov si, calc_prompt
    call print_string
    
    ; Get first number
    mov di, number_buffer
    call read_string
    mov si, number_buffer
    call string_to_number
    push ax         ; Save first number
    
    ; Get operator
    mov si, op_prompt
    call print_string
    mov di, number_buffer
    call read_string
    mov al, [number_buffer]
    mov [operator], al
    
    ; Get second number
    mov si, calc_prompt
    call print_string
    mov di, number_buffer
    call read_string
    mov si, number_buffer
    call string_to_number
    mov bx, ax      ; Second number in BX
    pop ax          ; First number in AX
    
    ; Perform calculation
    mov cl, [operator]
    cmp cl, '+'
    je .add
    cmp cl, '-'
    je .subtract
    cmp cl, '*'
    je .multiply
    cmp cl, '/'
    je .divide
    jmp .invalid
    
.add:
    add ax, bx
    jmp .print_result
.subtract:
    sub ax, bx
    jmp .print_result
.multiply:
    mul bx
    jmp .print_result
.divide:
    test bx, bx     ; Check for divide by zero
    jz .div_zero
    xor dx, dx
    div bx
    
.print_result:
    mov si, result_msg
    call print_string
    call print_number
    call print_newline
    jmp main_loop
    
.div_zero:
    mov si, div_zero_msg
    call print_string
    jmp main_loop
    
.invalid:
    mov si, invalid_op_msg
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

print_char:
    push ax
    mov ah, 0x0E
    int 0x10
    pop ax
    ret

print_hex_byte:
    push ax
    push cx
    mov cl, 4
    shr al, cl
    call print_hex_digit
    pop cx
    pop ax
    push ax
    and al, 0x0F
    call print_hex_digit
    pop ax
    ret

print_hex_digit:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 7
.print:
    call print_char
    ret

print_number:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10
    xor cx, cx      ; Digit counter
    
.divide_loop:
    xor dx, dx
    div bx          ; Divide by 10
    push dx         ; Save remainder
    inc cx
    test ax, ax
    jnz .divide_loop
    
.print_loop:
    pop ax
    add al, '0'
    call print_char
    loop .print_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

string_to_number:
    xor ax, ax      ; Result
    xor cx, cx      ; Sign (0 = positive)
    
    cmp byte [si], '-'
    jne .convert
    inc si
    mov cx, 1       ; Negative number
    
.convert:
    mov bl, [si]
    test bl, bl
    jz .done
    
    sub bl, '0'
    jb .error
    cmp bl, 9
    ja .error
    
    imul ax, 10
    add al, bl
    inc si
    jmp .convert
    
.done:
    test cx, cx
    jz .finish
    neg ax          ; Make negative if needed
    
.finish:
    clc             ; Clear carry (success)
    ret
    
.error:
    stc             ; Set carry (error)
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

update_cursor:
    push ax
    push bx
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    inc byte [cursor_x]
    cmp byte [cursor_x], 80
    jl .done
    mov byte [cursor_x], 0
    inc byte [cursor_y]
    cmp byte [cursor_y], 25
    jl .done
    mov byte [cursor_y], 0
.done:
    pop bx
    pop ax
    ret

print_newline:
    push ax
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    pop ax
    ret

; Data section
cursor_x db 0
cursor_y db 0
current_color db 0x1F
operator db 0
number_buffer times 16 db 0

; Command strings
cmd_clear db 'clear', 0
cmd_help db 'help', 0
cmd_color db 'color', 0
cmd_about db 'about', 0
cmd_time db 'time', 0
cmd_reboot db 'reboot', 0
cmd_draw db 'draw', 0
cmd_calc db 'calc', 0

; Messages
banner db '================================', 0x0D, 0x0A
       db '  MyOS v0.0.4 - Basic Command OS  ', 0x0D, 0x0A
       db '================================', 0x0D, 0x0A
       db 'Type "help" for commands', 0x0D, 0x0A, 0

prompt db '> ', 0
unknown_cmd db 'Unknown command. Type "help" for available commands.', 0x0D, 0x0A, 0

help_msg db 'Available commands:', 0x0D, 0x0A
        db '  clear  - Clear screen', 0x0D, 0x0A
        db '  help   - Show this help', 0x0D, 0x0A
        db '  color  - Change text color', 0x0D, 0x0A
        db '  about  - System information', 0x0D, 0x0A
        db '  time   - Show current time', 0x0D, 0x0A
        db '  reboot - Reboot system', 0x0D, 0x0A
        db '  draw   - Simple drawing mode', 0x0D, 0x0A
        db '  calc   - Simple calculator', 0x0D, 0x0A, 0

about_msg db 'MyOS v0.3', 0x0D, 0x0A
         db 'A simple bootable operating system', 0x0D, 0x0A
         db 'Built with NASM', 0x0D, 0x0A, 0

time_msg db 'Current time: ', 0
reboot_msg db 'Press any key to reboot...', 0x0D, 0x0A, 0
calc_prompt db 'Enter number: ', 0
op_prompt db 'Enter operator (+,-,*,/): ', 0
result_msg db 'Result: ', 0
div_zero_msg db 'Error: Division by zero', 0x0D, 0x0A, 0
invalid_op_msg db 'Error: Invalid operator', 0x0D, 0x0A, 0

; Command buffer
command_buffer times 64 db 0

times 2096 -($-$$) db 0 ; Pad to 2KB total (4 sectors)