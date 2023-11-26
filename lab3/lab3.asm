bits 16 ; 16 bit code assembler
org 7c00h ; begin from this address


; --- Bootloader manager --- 
; TASK 0: Load the extra code to the next 512 bytes of the RAM.
mov al, 3 ; number of sectors to read
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
mov di, buffer ; page 4
mov dx, 30
mov bx, 10
call repeat_string
; write frunze's extended signature to the first sector
mov al, 1
mov dh, 0
mov ch, 66 ; 1201//18=66
mov cl, 13 ; 1201%18=13
xor bx, bx
mov es, bx
mov bx, buffer
call write_to_floppy
; write frunze's extended signature to the last sector
mov ch, 68 ; 1230//18=68
mov cl, 6 ; 1230%18=6
call write_to_floppy

; clear the used part from the next 512 bytes in RAM
mov di, buffer
mov cx, 300
call clear_buffer

; repeat chiper's signature 10 times
mov ax, chiper_signature
mov di, buffer ; page 4
mov dx, 28
mov bx, 10
call repeat_string
; write chiper's extended signature to the first sector
mov al, 1
mov dh, 0
mov ch, 60 ; 1081//18=60
mov cl, 1 ; 1081%18=1
xor bx, bx
mov es, bx
mov bx, buffer
call write_to_floppy
; write chiper's extended signature to the last sector
mov ch, 61 ; 1110//18=61
mov cl, 12 ; 1110%18=12
call write_to_floppy

; clear the used part from the next 512 bytes in RAM
mov di, buffer
mov cx, 300
call clear_buffer

; repeat manole's signature 10 times
mov ax, manole_signature
mov di, buffer ; page 4
mov dx, 28
mov bx, 10
call repeat_string
; write manole's extended signature to the first sector
mov al, 1
mov dh, 0
mov ch, 75 ; 1351/18=75
mov cl, 1 ; 1351%18=1
xor bx, bx
mov es, bx
mov bx, buffer
call write_to_floppy
; write manole's extended signature to the last sector
mov ch, 76 ; 1380//18=76
mov cl, 12 ; 1380%18=12
call write_to_floppy


; TASK 2.1: KEYBOARD ==> FLOPPY
; write the text from keyboard to ram/buffer;
main_loop:
    ; clear the prompt page (4th page)
    mov di, buffer
    mov cx, 512
    call clear_buffer

    ; print the command prompt '>'
    mov si, prompt
    call print

    ; write the command to the 4th page
    mov di, buffer
    call write

    ; execute the command
    mov si, buffer
    call execute_command

    ; print if the command is valid
    cmp byte [valid], "F"
    jne main_loop
    mov si, error
    call print
    call new_line

    jmp main_loop      

jmp $


; --- Functions section ---
execute_command:
    mov byte [valid], "T"
    mov byte [head], 0
    mov byte [track], 0
    mov byte [sector], 0
    mov word [N], 0
    mov word [temp], 0 
    mov word [address1], 0
    mov word [address2], 0  

    cmp byte [si], 'w'
    jne elif_r
    if_w:
        cmp byte [si + 1], 0
        jne unknown_command

        call input_head
        cmp byte [valid], "F"
        je break

        call input_track
        cmp byte [valid], "F"
        je break

        call input_sector
        cmp byte [valid], "F"
        je break

        call input_N
        cmp byte [valid], "F"
        je break

        ; print text label
        mov si, textLabel
        call print
        ; input the text
        mov si, di ; text start
        call write
        ; display empty line and the prompt text
        mov [text_start_index], si ; save prompt text start
        call new_line
        call print
        call new_line

        ; move to si the beginning of the text in the prompt
        mov si, [text_start_index]
        ; move to di the start of 512 bytes of the next page (after prompt page) in RAM
        mov di, buffer+200h 
        copy_to_floppy_loop:
            ; copy each byte from [si] and move it to [di]
            mov al, [si]
            mov [di], al

            ; increase si (si until end of text in prompt)
            ; you move si to the start of text if si is at end of text
            inc si
            cmp byte [si], 0
            jne continue_copy_to_floppy
                ; if [si] == 0
                ; substract 1 from N if equal
                xor dx, dx
                mov dx, [N]
                sub dx, 1
                mov [N], dx
                ; move si at the text start
                mov si, [text_start_index]

                ; continue until N is zero 
                cmp word [N], 0
                je insert_to_floppy_step

            continue_copy_to_floppy:
                ; if [si] != 0
                ; increase di until 512 bytes are written to the page (if)
                inc di
                cmp di, buffer+200h+200h
                jne copy_to_floppy_loop
                    ; == - if di is at the start of the next page (512 bytes are filled)
                    insert_to_floppy_step:
                        ; save si
                        mov word [si_saver], si

                        ; if the 512 bytes are filled move them to the floppy
                        call insert_data_to_one_fd_sector

                        ; clear this page in ram of 512 bytes that were used
                        mov di, buffer+200h
                        mov cx, 512
                        call clear_buffer

                        ; display and check error code
                        cmp ah, 0
                        je check_N
                            ; != then display error and break
                            call display_error
                            jmp break
                        check_N:
                            ; == then check if N is zero
                            cmp word [N], 0 
                            jne set_the_write_vars
                                ; if [N] == 0, display error and break
                                call display_error
                                jmp break
                        
                                ; if [N] != 0
                                set_the_write_vars:
                                    ; give to di and si the addresses
                                    mov di, buffer+200h
                                    mov si, word [si_saver]

                                    ; increase +1 the number of the sector (if 18 then 1)
                                    mov bx, 0
                                    mov bl, [sector]
                                    cmp bl, 18
                                    jne increase_sector_by_one
                                        ; if [sector] == 18
                                        mov byte [sector], 1

                                        ; change track when 18 sectors (if 80 tracks then head = 1)
                                        mov bl, byte [track]
                                        cmp bl, 79
                                        jne track_not_79
                                            ; if [track] == 79
                                            cmp byte [head], 0
                                            jne head_is_one
                                                ; if [head] == 0
                                                mov byte [track], 0
                                                mov byte [head], 1
                                                jmp copy_to_floppy_loop
                                            head_is_one:
                                                ; if [head] == 1
                                                inc bl
                                                mov [track], bl
                                                jmp copy_to_floppy_loop
                                        track_not_79:
                                            ; if [track] != 79
                                            inc bl
                                            mov [track], bl
                                            jmp copy_to_floppy_loop

                                    increase_sector_by_one:
                                        ; if [sector] != 18
                                        inc bl
                                        mov byte [sector], bl
                                        jmp copy_to_floppy_loop
        ret

    elif_r:
        cmp byte [si], 'r'
        jne elif_m
        cmp byte [si + 1], 0
        jne unknown_command

        call input_head
        cmp byte [valid], "F"
        je break

        call input_track
        cmp byte [valid], "F"
        je break

        call input_sector
        cmp byte [valid], "F"
        je break

        call input_N
        cmp byte [valid], "F"
        je break

        call input_A1
        cmp byte [valid], "F"
        je break
        mov word [address1], ax ; for es later

        call input_A2
        cmp byte [valid], "F"
        je break
        mov word [address2], ax

        ; read from floppy to ram
        mov bx, word [address1]
        mov es, bx
        mov bx, word [address2]
        mov al, [N]
        mov dh, [head]
        mov ch, [track]
        mov cl, [sector]
        call read_from_floppy

        mov bx, 0
        mov es, bx

        ; error code
        mov cl, ah
        mov si, errorCodeLabel
        call print

        mov ah, cl
        call convert_2hex_to_str
        mov si, errorCode
        call print
        call new_line

        ; print string from ram
        mov bx, word [address1]
        mov es, bx
        mov bx, word [address2]
        call new_line
        mov ax, 0
        print_from_ram_loop:
            mov al, [es:bx]
            cmp al, 0
            je finish_printing_to_ram
            mov ah, 0x0E
            int 0x10

            inc bx
            cmp bx, 0xFFFF
            jne print_from_ram_loop
                ; if bx == FFFF
                mov bx, 0
                mov bx, es
                inc bx
                mov es, bx
                mov bx, 0
                jmp print_from_ram_loop

        finish_printing_to_ram:
        mov bx, 0
        mov es, bx
        call new_line

        ret

    elif_m:
        cmp byte [si], 'm'
        jne unknown_command
        cmp byte [si + 1], 0
        jne unknown_command

        call input_head
        cmp byte [valid], "F"
        je break

        call input_track
        cmp byte [valid], "F"
        je break

        call input_sector
        cmp byte [valid], "F"
        je break

        call input_N
        cmp byte [valid], "F"
        je break

        call input_A1
        cmp byte [valid], "F"
        je break
        mov word [address1], ax ; for es later

        call input_A2
        cmp byte [valid], "F"
        je break
        mov word [address2], ax

        ret

    input_head:
        ; parameters: di - the start where to write
        ; returns: head - 1 byte variable

        ; print head label
        mov si, headLabel
        call print
        ; obtain the head and convert it to decimal
        mov si, di
        call write
        mov dl, 0 ; end converting when there is nothing
        call convert_to_numerical
        cmp byte [valid], "F"
        je break
        mov byte [head], al ; values 1/0
        ret

    input_track:
        ; print track
        mov si, trackLabel
        call print
        ; takes the track and converts it to decimal
        mov si, di
        call write
        mov dl, 0
        call convert_to_numerical
        cmp byte [valid], "F"
        je break
        mov byte [track], al ; interval [0, 79]
        ret

    input_sector:
        ; print sector
        mov si, sectorLabel
        call print
        ; takes the sector and converts it to decimal
        mov si, di
        call write
        mov dl, 0
        call convert_to_numerical
        cmp byte [valid], "F"
        je break
        mov byte [sector], al ; interval [1, 18]
        ret

    input_N:
        ; print N
        mov si, NLabel
        call print
        ; takes N and converts it to decimal
        mov si, di
        call write
        mov dl, 0
        call convert_to_numerical
        cmp byte [valid], "F"
        je break
        cmp ax, 0
        je unknown_command
        mov word [N], ax ; interval [1, 30000]
        ret

    insert_data_to_one_fd_sector:
        mov al, 1
        mov dh, [head]
        mov ch, [track]
        mov cl, [sector]
        xor bx, bx
        mov es, bx
        mov bx, buffer+200h
        call write_to_floppy
        ret

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

    input_A1:
        mov si, A1Label
        call print
        ; write A1
        mov si, di
        call write
        call convert_ascii_hex_to_numerical_hex ; returns ax
        cmp byte [valid], "F"
        je break
        ret

    input_A2:
        mov si, A2Label
        call print
        ; write A2
        mov si, di
        call write
        call convert_ascii_hex_to_numerical_hex ; returns ax
        cmp byte [valid], "F"
        je break
        ret

convert_ascii_hex_to_numerical_hex:
    ; parameters: si - start of hex string
    ; returns: ax - hex number

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

convert_2hex_to_str:
    ; parameters: ah - hex number of 2 digits; 
    ; returns: errorCode

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

convert_to_numerical:
    ; parameters
    ; si - address of the string; dl - delimiter
    ; returns ax - number and si - index

    mov ax, 0
    mov bx, 0
    mov cx, 10
    convert_loop:
        cmp byte [si], '0'
        jb unknown_command
        
        cmp byte [si], '9'
        ja unknown_command

        mov bl, [si]
        sub bl, '0'
        mul cx
        add ax, bx

        inc si
        cmp byte [si], dl
        jne convert_loop
    ret

unknown_command:
    mov byte [valid], "F"
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

print_char:
    ; parameters: al - register
    mov ah, 0x0E
    int 10h
    ret


; --- Data section ---
frunze_signature db "@@@FAF-212 Vladislav FRUNZE###", 0
chiper_signature db "@@@FAF-212 Andreea CHIPER###", 0
manole_signature db "@@@FAF-212 Andreea MANOLE###", 0
valid db "T", 0
error db "Invalid command", 0
head db 0, 0
track db 0, 0
sector db 0, 0
N dw 0, 0
prompt db '>', 0
errorCodeLabel db "Error code: ", 0
errorCode db 0, 0, "H", 0

headLabel db "Head:", 0
trackLabel db "Track:", 0
textLabel db "Text:", 0
sectorLabel db "Sector:", 0
A1Label db "A1:", 0
A2Label db "A2:", 0
NLabel db "N:", 0
text_start_index dw 0
si_saver dw 0
temp dw 0
address1 dw 0
address2 dw 0
buffer dw 7c00h+200h+200h+200h+200h

times (2048 - ($ - $$)) db 0x00