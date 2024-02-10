bits 16 ; 16 bit code assembler (real mode)
org 7c00h ; begin from this address


; Load extra code -----------------------------------------------------
mov al, 3 ; number of sectors to read
mov dh, 0 ; side number
mov ch, 0 ; track
mov cl, 2 ; sector
xor bx, bx ; clear bx
mov es, bx ; clear es
mov bx, 7e00h ; the address of the next 512 byte of RAM
mov ah, 02h ; command "Read Sectors"
mov dl, 0 ; driver
int 13h ; execute the command
jmp 7e00h
times (510 - ($ - $$)) db 0x00
dw 0xAA55


; Greet the user.
mov si, greet
call print
call new_line

; Give the floppy address to load the kernel.
main_loop:
    ; initialize
    mov byte [valid], "T"
    mov byte [side], 0
    mov byte [track], 0
    mov byte [sector], 0
    mov word [address2], 0
    mov word [address1], 0  
    mov di, buffer
    call new_line

    ; clean the buffer
    mov cx, 512
    call clear_buffer
    mov cx, 0
    mov di, buffer

    ; print side label
    mov si, sideLabel
    call print ; changed registers: SI, AL, AH
    ; obtain the side number
    mov si, di ; si remains at the start of number
    call write ; changed registers: bx, ax, di, dx;
    ; convert the side number to decimal
    call convert_to_decimal ; ret AX, changed registers: ax, bx, cx, si, dx
    cmp byte [valid], "F"
    je invalid_input
    mov byte [side], al

    ; print track label
    mov si, trackLabel
    call print
    ; obtain the track number
    mov si, di
    call write
    ; convert track to decimal
    call convert_to_decimal ; ret the decimal in AX
    cmp byte [valid], "F"
    je invalid_input
    mov byte [track], al

    ; print sector label
    mov si, sectorLabel
    call print
    ; obtain sector number
    mov si, di
    call write
    ; convert sector to decimal
    call convert_to_decimal
    cmp byte [valid], "F"
    je invalid_input
    mov byte [sector], al

    ; asses if the memory is allowed (track * 36 + sector)
    mov ax, 0
    mov al, byte [track]
    mov cx, 36
    mul cx
    jo restricted_memory
    mov cx, 0
    mov cl, byte [sector]
    add ax, cx
    jc restricted_memory
    cmp ax, 1201
    jb restricted_memory
    cmp ax, 1230
    ja restricted_memory

    ; print segment label
    mov si, segmentLabel
    call print
    ; obtain the hex ascii number
    mov si, di
    call write
    ; convert segment to hex
    call convert_ascii_hex_to_numerical_hex ; ax - hex
    cmp byte [valid], "F"
    je invalid_input
    mov word [address1], ax

    ; print offset label
    mov si, offsetLabel
    call print
    ; obtain the hex ascii number
    mov si, di
    call write
    ; convert offset to hex
    call convert_ascii_hex_to_numerical_hex ; ax - hex
    cmp byte [valid], "F"
    je invalid_input
    mov word [address2], ax

    ; read from floppy to ram
    mov bx, word [address1]
    mov word [temp_a1], bx
    mov bx, word [address2]
    mov word [temp_a2], bx
    floppy_to_ram_loop:
        ; read from floppy
        mov bx, word [temp_a1]
        mov es, bx
        mov bx, word [temp_a2]
        mov al, 1
        mov dh, [side]
        mov ch, [track]
        mov cl, [sector]
        mov ah, 02h ; command "Read Sectors"
        mov dl, 0 ; driver
        int 13h ; execute the command
        mov bx, 0
        mov es, bx

        ; display the error
        cmp ah, 0
        je no_error
            ; if error display and break
            call display_error
            jmp main_loop
        no_error:
            ; if there is no error
            ; check for break point by looking for the signature
            mov bx, word [temp_a1]
            mov es, bx

            mov si, word [temp_a2]
            mov bx, 512
            search_for_signature:
                cmp byte [es:si], 0xA7
                je running_step
                inc si
                dec bx
                cmp bx, 0
                je prepare_for_reading
                jmp search_for_signature
            prepare_for_reading:
                ; set the vars
                mov bx, word [temp_a2]
                add bx, 512
                jnc no_ram_overflow
                    ; if overflow
                    mov bx, word [temp_a1]
                    inc bx
                    mov word [temp_a1], bx
                    mov bx, 0
                    mov word [temp_a2], bx
                    jmp init_variables
                no_ram_overflow:
                    ; if not overflow
                    mov word [temp_a2], bx
                init_variables:
                    ; increase +1 the number of the sector
                    mov bx, 0
                    mov bl, [sector]
                    cmp bl, 18
                    jne increase_sector_by_one2
                        ; if [sector] == 18 ;
                        mov byte [sector], 1
                        cmp byte [side], 1
                        jne side_is_zero2
                            ; if [side] == 1 - move to next track
                            mov bl, byte [track]   
                            inc bl
                            mov byte [track], bl
                            mov byte [side], 0
                            jmp check_memory_limit
                        side_is_zero2:
                            ; if [side] == 0 - move to the other side
                            mov byte [side], 1
                            jmp check_memory_limit
                    increase_sector_by_one2:
                        ; if [sector] != 18
                        inc bl
                        mov byte [sector], bl

                ; check if the next sector is allowed
                check_memory_limit:
                    mov dx, 0
                    mov ax, 0
                    mov al, byte [track]
                    mov cx, 36
                    mul cx
                    jo reached_limit
                    mov cx, 0
                    mov cl, byte [sector]
                    add ax, cx
                    jc reached_limit
                    cmp ax, 1230
                    ja reached_limit
                    jmp floppy_to_ram_loop
        
    running_step:
        call display_error
        ; ask to run
        call new_line
        mov si, runQuestion
        call print
        run_program:    
            ; wait for enter
            mov ah, 0
            int 16h
            cmp al, "y"
            je execute_program
            cmp al, "n"
            je main_loop
            jmp run_program
            execute_program:
                ; add to stack the address of "after_executing"
                push cs
                push after_executing
                ; add to stack the address of the program and go there
                mov bx, word [address1]
                mov es, bx
                mov bx, word [address2]
                push es
                push bx
                push es
                push bx
                retf
            after_executing:
                mov bx, 0
                mov ds, bx
                mov es, bx
                call new_line
                mov si, runQuestion
                call print
                jmp run_program

    ; invalid input
    invalid_input:
        mov si, invalidInput
        call print
        jmp main_loop

    restricted_memory:
        mov si, restrictedMemory
        call print
        jmp main_loop

    reached_limit:
        mov si, reachedLimit
        call print
        jmp main_loop


; Functions section --------------------------------------------------
display_error:
    mov cl, ah
    mov si, errorCodeLabel
    call print
    mov ah, cl
    call convert_2hex_to_str
    mov si, errorCode
    call print
    call new_line
    ret

convert_2hex_to_str:
    ; parameters: ah - hex number of 2 digits; 
    ; returns: [errorCode]
    ; changed registers: bx, ax

    xor bl, bl
    ; add first hex digit to buffer
    mov bl, ah
    and bl, 0xF0 ; 11110000
    shr bl, 4
    add bl, '0'
    mov byte [errorCode], bl
    ; add second hex digit to buffer
    mov bl, ah
    and bl, 0x0F
    add bl, '0'
    mov byte [errorCode + 1], bl
    ret

convert_ascii_hex_to_numerical_hex:
    ; parameters: si - start of hex string
    ; returns: ax - hex number
    ; changed registers: ax, cx, si

    mov ax, 0
    mov cx, 0
    convert_ascii_hex_to_numerical_hex_loop:
        mov cx, 0
        mov cl, byte [si]  ; Load ASCII character
        cmp cl, 0
        je break 
        cmp byte [si], '0'
        jb unknown_command
        cmp byte [si], '9'
        jbe convert_0_9_byte ; between 0-9
        cmp byte [si], 'a'
        jb unknown_command
        cmp byte [si], 'f'
        ja unknown_command
        convert_a_f_byte:
            sub cl, 87
            shl ax, 4
            add ax, cx
            inc si   
            jmp convert_ascii_hex_to_numerical_hex_loop
        convert_0_9_byte:
            sub cl, '0'
            shl ax, 4
            add ax, cx
            inc si 
            jmp convert_ascii_hex_to_numerical_hex_loop


clear_buffer:
    ; parameters:
    ;   di - buffer address; 
    ;   cx - buffer length
    ; returns: nothing
    ; changed registers: di, cx

    mov byte [di], 0 ; clear the byte in di
    inc di ; go to the next cell
    dec cx ; decrease the counter
    cmp cx, 0 ; check if you are at the end of the buffer
    jne clear_buffer ; if cx not 0, then start again
    ret ; else return back to the main section

convert_to_decimal:
    ; parameters:
    ;   si - address of the string (number in ascii);
    ;   [valid] - "T"
    ; returns: 
    ;   ax - decimal, si - end of number (0 byte)
    ; changed registers: ax, bx, cx, si, dx

    mov ax, 0
    mov bx, 0
    mov cx, 10
    mov dx, 0
    convert_to_decimal_loop:
        cmp byte [si], '0'
        jb unknown_command
        
        cmp byte [si], '9'
        ja unknown_command

        mov bl, [si]
        sub bl, '0'
        mul cx
        add ax, bx

        inc si
        cmp byte [si], 0
        jne convert_to_decimal_loop
    ret

unknown_command:
    mov byte [valid], "F"
    ret

write:
    ; description: writes to the buffer and displays from keyboard;
    ; parameters: di - memory to write to;
    ; returns: nothing
    ; changed registers: bx, ax, di, dx;

    xor bx, bx ; clear the BX register for counting chars
    loop:
        mov ah, 0 ; initialize the AH part of register
        int 0x16 ; wait for keypress

        cmp al, 0x08 ; check if the backspace is pressed
        je backspace ; if the backspace is pressed

        cmp al, 0x0D ; check if enter is pressed
        je enter ; if the enter is pressed

        cmp bx, 256 ; check if 256 chars are written
        je loop ; if true allow only backspace and enter

        mov ah, 0x0E ; says to write the char as TTY
        int 0x10 ; print the char

        stosb ; store char into the buffer, and increment DI (destination index)
        inc bx ; the counter of chars
        jmp loop ; back from the start
    enter:
        cmp bx, 0
        je loop
        call new_line
        ret
    backspace:
        cmp bx, 0 ; check if there are no chars printed
        je loop ; if there aren't ignore the key

        ; delete the char from buffer
        dec di ; go back one position in the buffer
        mov byte [di], 0 ; delete the char by zeroing it
        dec bx ; substract 1 from the counter of chars

        ; get the cursor's row and column
        mov ah, 03h ; instruction to query the cursor position
        mov bh, 0 ; video page number
        int 0x10 ; interrupt to execute the instruction

        cmp dl, 0 ; compare if we are at the first column
        jne erase_char ; if not jump to the usual removal  
        erase_last_char:
            ; set cursor position at the last column of the previous row
            mov ah, 02h ; instruction to set cursor position
            mov bh, 0 ; video page number
            dec dh ; get to the previous row
            mov dl, 79 ; the last column
            int 0x10 ; interrupt to execute the above instruction

            ; will eliminate visually the previous letter
            mov ah, 0aH ; says to write the char
            mov al, ' ' ; substitute the letter with space
            int 0x10 ; display the space instead of the letter

            jmp loop ; go back to the main loop 
        erase_char:
            ; will "print" the backspace where the cursor is
            ; the cursor is moved back one position
            mov ah, 0x0E ; says to write the char as TTY
            mov al, 0x08 ; add to AL the backspace address
            int 0x10 ; display backspace on the screen and move cursor to the left

            ; will eliminate visually the previous letter
            ; where the cursor is right now
            mov ah, 0aH
            mov al, ' ' ; substitute the letter with space
            int 0x10 ; display the space instead of the letter

            jmp loop ; go back to the main loop 
    new_line:
        mov ah, 0x0E ; TTY write
        mov al, 0x0D ; go to the start of line
        int 0x10 ; interrupt

        mov al, 0x0A ; of the next line
        int 0x10 ; interrupt
        ret


print:
    ; description: displays chars until null byte
    ; parameters:
    ;   SI - the start address of the string to print
    ; returns: nothing
    ; changed registers: SI, AL, AH

    lodsb ; load the byte at [SI] into AL and increment SI
    or al, al ; check if the AL is zero (Zero Flag is set to 1 if AL is zero)
    jz break ; if AL is zero (zero flag is 1) then you finished printing the string
    mov ah, 0x0E ; says to write the char as TTY
    int 0x10 ; interrupt to print out the char from AL
    jmp print ; go print the next char in string

    break:
        ret

print_char:
    ; parameters: al - register
    mov ah, 0x0E
    int 10h
    ret


; Data Section -------------------------------------------------------
greet db "Hello, I am Frunze Vladislav from FAF-212!", 0
sideLabel db "Side [0-1]:", 0
side db 0

trackLabel db "Track [0-79]:", 0
track db 0

sectorLabel db "Sector [1-18]:", 0
sector db 0

segmentLabel db "Segment:", 0
address1 dw 0
temp_a1 dw 0

offsetLabel db "Offset:", 0
address2 dw 0
temp_a2 dw 0

invalidInput db "Invalid input!", 0
runQuestion db "Run? (y/n)", 0x0D, 0x0A, 0

errorCodeLabel db "Error code: ", 0
errorCode db 0, 0, "H", 0
restrictedMemory db "Restricted memory!", 0
reachedLimit db "Error: end of the block", 0

valid db "T", 0
buffer dw 7c00h+200h+200h+200h+200h

times (2048 - ($ - $$)) db 0x00