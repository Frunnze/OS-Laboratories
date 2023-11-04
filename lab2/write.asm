bits 16 ; 16 bit code assembler
org 0x7c00 ; begin from this address
  

main:
    mov di, buffer ; load the memory address into destination index (DI)
    call write ; call for keyboard input


functions_section:
    write:
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
            call new_line
            cmp bx, 0 ; check if we are at the first column
            je loop ; if we are then go to the main loop

            print_buffer:
                mov si, buffer ; give to the SI pointer the start of buffer
                call print ; print what is in the buffer

            call new_line

            mov di, buffer ; initialize the di with the start of the buffer
            clear_buffer:
                mov byte [di], 0 ; zero the cell
                inc di ; go to the next cell
                cmp di, buffer + 255 ; check if you are at the end of the buffer
                jne clear_buffer ; if not the end still clear the buffer

                xor bx, bx ; clear the char counter
                mov di, buffer ; give the start of the buffer to DI

                jmp loop


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

    print:
        lodsb ; load the byte at [SI] into AL and increment SI
        or al, al ; check if the AL is zero (Zero Flag is set to 1 if AL is zero)
        jz break ; if AL is zero (zero flag is 1) then you finished printing the string
        mov ah, 0x0E ; says to write the char as TTY
        int 0x10 ; interrupt to print out the char from AL
        jmp print ; go print the next char in string

    break:
        ret ; pop the call address, and go there

    new_line:
        mov ah, 0x0E ; TTY write
        mov al, 0x0D ; go to the start of line
        int 0x10 ; interrupt

        mov al, 0x0A ; of the next line
        int 0x10 ; interrupt
        ret


data_section:
    ; Establishing the limit of 256 chars.
    buffer times 256 db 0


times (510 - ($ - $$)) db 0x00 ; padd the .bin to 512 bytes
; signature to indicate that the bootloader is valid
; and should be loaded and executed by the system's BIOS
dw 0xAA55