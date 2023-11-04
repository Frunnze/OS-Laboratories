; M8(optional): Print directly to video memory

org 7c00H

start:
    mov DI, 0
    ; Set BX to 0xb800, the video memory segment
    mov BX, 0xb800
    ; Set ES (extra segment) to the video memory segment
    mov ES, BX
    mov AH, 02H 
    ; Initialize SI register to 0 (index)
    mov SI, 0

if_cond:
    ; Compare the byte at [SI + msg] with 0 (end of string)
    cmp byte [SI + msg], 0
    ; If it's 0 jump to the end
    je end

    loop:
        ; Load the byte from [SI + msg] into AL (ASCII character)
        mov AL, [SI + msg]
        ; Store the word (character and attribute) in video memory
        ; and moves to the next position
        stosw
        inc SI          
        jmp if_cond

end:
jmp $            

msg db "method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8 method 8"

times 510 - ($ - $$) db 0
dw 0xAA55