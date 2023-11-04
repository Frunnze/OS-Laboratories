; M2: Write character

go:
    mov AH, 0aH
    mov AL, 56H
    mov CX, 84

    int 10H

jmp $