; M6: Display string

org 7c00H

go: 
    mov AX, 0H
    mov ES, AX

    mov AX, 1300H
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