; Method1: Write character as TTY
bits 16
org 0x7c00

go:
    mov AH, 0eH
    mov AL, 57H
    int 10H

jmp $

times 510 - ($ - $$) db 0
dw 0xAA55