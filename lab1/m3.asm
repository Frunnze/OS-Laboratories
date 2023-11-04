; M3: Write character/attribute

go:
    mov AH, 09H
    mov AL, 55H
    mov BL, 02H
    mov CX, 1
    int 10H

jmp $