; set the offset and the segment
pop bx
pop ax
mov ds, ax

division_loop:
    ; print the conditions
    lea si, [interval+bx]
    call print

    ; initialization
    mov word [dividend+bx], 0
    mov word [divisor+bx], 0
    mov word [result+bx], 0
    mov word [remainder+bx], 0

    lea di, [tempBuffer+bx]
    mov cx, 7
    call clear_buffer
    lea di, [dividendString+bx]
    mov cx, 7
    call clear_buffer
    lea di, [divisorString+bx]
    mov cx, 7
    call clear_buffer

    ; Print the dividend label
    lea si, [dividendLabel+bx]
    call print
    ; Input the dividend
    lea di, [dividendString+bx]
    push bx
    call write
    pop bx

    ; Print the divisor label
    lea si, [divisorLabel+bx]
    call print
    ; Input the divisor
    lea di, [divisorString+bx]
    push bx
    call write
    pop bx

    unsigned_division:
        ; Convert the dividend string to decimal
        lea si, [dividendString+bx]
        push bx
        call convert_to_decimal ; ax
        pop bx
        mov [dividend+bx], ax
        
        ; Converte the divisor string to decimal
        lea si, [divisorString+bx]
        push bx
        call convert_to_decimal ; ax
        pop bx
        mov word [divisor+bx], ax
        cmp ax, 0
        je invalid_number2

        ; divide
        mov dx, 0
        mov ax, word [dividend+bx]
        mov cx, word [divisor+bx]
        div cx ; ax - quotient, dx - remainder
        mov word [result+bx], ax
        mov word [remainder+bx], dx

        ; print quotient
        call new_line
        lea si, [resultLabel+bx]
        call print

        mov ax, word [result+bx]
        lea di, [tempBuffer+bx+1]
        call convert_to_ascii_decimal ; tempBuffer

        dec di
        call print_backwards

        ; clear temp buffer
        lea di, [tempBuffer+bx]
        mov cx, 7
        call clear_buffer

        ; print remainder
        call new_line
        lea si, [remainderLabel+bx]
        call print

        mov ax, word [remainder+bx]
        lea di, [tempBuffer+bx+1]
        call convert_to_ascii_decimal ; tempBuffer

        dec di
        call print_backwards

        retf

; Functions
print_backwards:
    ; parameters: di

    mov al, [di]
    dec di

    cmp al, 0
    je break

    mov ah, 0x0E
    int 0x10

    jmp print_backwards

convert_to_ascii_decimal:
    ; parameters: 
    ;   ax - number to convert (no sign)
    ;   di - buffer
    ; changed registers: dx, cx, di, ax
    ; return: tempBuffer

    mov dx, 0
    mov cx, 10
    ; get the last digit and store it
    div cx
    add dl, '0'
    mov [di], dl
    inc di
    ; check the break point
    cmp ax, 0
    je break
    jmp convert_to_ascii_decimal 

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
    ; returns: 
    ;   ax - decimal, si - end of number (0 byte)
    ; changed registers: ax, bx, cx, si

    mov ax, 0
    mov bx, 0
    mov cx, 10
    convert_to_decimal_loop:
        cmp byte [si], '0'
        jb invalid_number
        
        cmp byte [si], '9'
        ja invalid_number

        mov bl, [si]
        sub bl, '0'
        mul cx
        jo invalid_number
        add ax, bx
        jc invalid_number

        inc si
        cmp byte [si], 0
        jne convert_to_decimal_loop
    ret

invalid_number:
    pop bx
    pop bx
    lea si, [error+bx]
    call print
    call new_line
    jmp division_loop

invalid_number2:
    lea si, [error+bx]
    call print
    call new_line
    jmp division_loop

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

        cmp bx, 5 ; check if 5 chars are written
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


; Data section
dividend dw 0
divisor dw 0
result dw 0
remainder dw 0
dividendLabel db "Dividend:", 0
divisorLabel db "Divisor:", 0
resultLabel db "Quotient:", 0
remainderLabel db "Remainder:", 0
error db "Invalid numbers!", 0x0D, 0x0A, 0
interval db "Allowed interval: [0, 65535]", 0x0D, 0x0A, 0
dividendString times 7 db 0
divisorString times 7 db 0
tempBuffer times 7 db 0

; Signature
db 0xA7