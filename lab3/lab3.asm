bits 16 ; 16 bit code assembler
org 7c00h ; begin from this address


; --- Bootloader manager --- 
; TASK 0: Load the extra code to the next 512 bytes of the RAM.
mov al, 2 ; number of sectors to read
mov dh, 0 ; head number
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


; --- Main section ---
; TASK 1: write our signatures to the floppy disk.
; repeat frunze's signature 10 times
mov ax, frunze_signature
mov di, buffer
mov dx, 30
mov bx, 10
call repeat_string

; write frunze's extended signature to the first sector
mov al, 1
mov dh, 0
mov ch, 66
mov cl, 13
xor bx, bx
mov es, bx
mov bx, buffer
call write_to_floppy

; write frunze's extended signature to the last sector
mov ch, 68
mov cl, 6
call write_to_floppy

; clear the used part from the next 512 bytes in RAM
mov di, buffer
mov cx, 300
call clear_buffer


; TASK 2.1: KEYBOARD ==> FLOPPY
; write the text from keyboard to ram/buffer;
mov di, buffer
call write

; identify the command: ex. w num num num num "text"
mov si, buffer
call parse_command

mov si, buffer
call print

;mov si, valid
;call print

; get the data that you wrote above in the next 512 bytes of RAM
;mov al, 1
;mov ch, 66
;mov cl, 13
;mov dh, 0
;xor bx, bx
;mov es, bx
;mov bx, buffer + 200h
;call read_from_floppy
;mov si, bx
;call print


; write the text to RAM N times
; find how many sectors are necessary in the floppy
; write the data from RAM to floppy

jmp $


; --- Functions section ---
convert_to_numerical:
    ; parameters
    ; si - address of the string; 
    ; returns ax - number and si - index

    xor ax, ax
    xor bx, bx
    convert_loop:
        cmp byte [si], '0'
        jb unknown_command
        
        cmp byte [si], '9'
        ja unknown_command

        mov bl, [si]
        sub bl, '0'
        mov cl, 10
        mul cl
        add ax, bx

        inc si
        cmp byte [si], ' '
        jne convert_loop
    ret

unknown_command:
    mov byte [valid], 0
    ret

parse_command:
    mov byte [valid], 1

    ;cmp byte [si], 'w'
    ;jne elif_r
    if_w:
        cmp byte [si + 1], ' '
        jne unknown_command

        ; takes the head and converts it to numerical
        add si, 2
        call convert_to_numerical
        cmp byte [valid], 0
        je break
        mov byte [head], al

        ; takes the track and converts it
        inc si
        call convert_to_numerical
        cmp byte [valid], 0
        je break
        mov byte [track], al

        ; takes the sector and converts it to number
        inc si
        call convert_to_numerical
        cmp byte [valid], 0
        je break
        mov byte [sector], al

        ; takes N and converts it to number
        inc si
        call convert_to_numerical
        cmp byte [valid], 0
        je break
        mov byte [N], al

        ; take the text and repeat it in the ram
        inc si
        cmp byte [si], ':' 
        jne unknown_command

        inc si
        xor ax, ax
        mov ax, si
        xor dx, dx
        call get_string_length ; dx
        xor bx, bx
        mov bx, [N]
        mov di, buffer + 200h
        call repeat_string

        ; find the number of sectors needed
        ; t = N * string_length // 512
        xor ax, ax
        mov ax, [N]
        mul dx
        
        mov dx, 0
        mov bx, 512
        div bx ; al - quotient, ah - remainder
        cmp ah, 0
        je write_step
        inc al

        ; take the repeated text and store it to floppy
        write_step:
        mov dh, [head]
        mov ch, [track]
        mov cl, [sector]
        xor bx, bx
        mov es, bx
        mov bx, buffer + 200h
        call write_to_floppy

        ret

get_string_length:
    ; parameters
    ; si - start index of string; dx - counter
    ; returns dx as string length

    cmp byte [si], 0
    je break
    inc dx
    inc si
    jmp get_string_length

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

write_to_floppy:
    ; parameters:
    ; dh - head number; ch - track (0-n): your_sector / 18
    ; cl - starting sector number (1-n): your_sector % 18; bx - buffer start
    ; al - sectors to write

    mov ah, 03h ; command "Write Sectors"
    mov dl, 0 ; driver
    int 13h ; execute the command
    ret

read_from_floppy:
    mov ah, 02h ; command "Read Sectors"
    mov dl, 0 ; driver
    int 13h ; execute the command
    ret

clear_buffer:
    ; parameters:
    ; di - buffer address; cx - buffer length

    mov byte [di], 0 ; clear the byte in di
    inc di ; go to the next cell
    dec cx ; decrease the counter
    cmp cx, 0 ; check if you are at the end of the buffer
    jne clear_buffer ; if cx not 0, then start again
    ret ; else return back to the main section

repeat_string:
    ; parameters: 
    ; ax - string address; di - buffer address; 
    ; dx - string length; bx - times to repeat

    mov cx, dx ; set the string length counter
    mov si, ax ; set SI to the start of the string
    rep movsb ; copy each byte from string to buffer until cx = 0; [DI]←[SI], DI+=1, SI+=1;
    dec bx ; bx - 1 - times remained to repeat the string
    cmp bx, 0 ; if bx is 0 then you've finished repeating the string
    jne repeat_string ; if bx is not 0, proceed from start
    ret ; return back to the main section in case bx is 0

print:
    lodsb ; load the byte at [SI] into AL and increment SI
    or al, al ; check if the AL is zero (Zero Flag is set to 1 if AL is zero)
    jz break ; if AL is zero (zero flag is 1) then you finished printing the string
    mov ah, 0x0E ; says to write the char as TTY
    int 0x10 ; interrupt to print out the char from AL
    jmp print ; go print the next char in string

break:
    ret ; pop the call address, and go there


; --- Data section ---
frunze_signature db "@@@FAF-212 Vladislav FRUNZE###", 0
chiper_signature db "@@@FAF-212 Andreea CHIPER###", 0
manole_signature db "@@@FAF-212 Andreea MANOLE###", 0
buffer dw 7e00h + 200h + 200h
valid db 1, 0
head db 0
track db 0
sector db 0
N db 0
prompt db '>', 0