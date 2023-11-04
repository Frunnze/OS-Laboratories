; M4: Display character + attribute

; sets the origin of the program to address 0x7C00
org 7c00H
    
; Register initialization         
mov BH, 0  
mov AX, 0H
mov ES, AX 

; Memory address initialization:
mov BP, msg

; Character output 
mov CX, 6            
mov DH, 0               
mov DL, 0      

mov AX, 1302H
int 10H

jmp $       

; Data
msg db 'M', 01H, 'e', 02H, 'l', 03H, 'l', 04H, 'o', 05H

times 510 - ($ - $$) db 0
dw 0xAA55