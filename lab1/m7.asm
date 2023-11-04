; M7: Display string & update cursor

org 7c00H

go: 
    mov AX, 1301H
    mov BH, 0
    mov BL, 02H
    mov CX, 5
    mov DH, 0
    mov DL, 0
    mov BP, msg

    int 10H

jmp $

; Data
msg db 'Hello'