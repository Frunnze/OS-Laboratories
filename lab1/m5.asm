; M5: Display character + attribute & update cursor

; sets the origin of the program to address 0x7C00
org 7c00H
    
; Register initialization         
mov BH, 0  
mov AX, 0H
mov ES, AX 

; Memory address initialization:
mov BP, msg

; Character output
mov AL, 1  
mov CX, 5                
mov DH, 0                
mov DL, 0         

mov AX, 1303H
int 10H

; jump to itself
jmp $                    

; Data
msg db 'M', 01H, 'e', 02H, 'l', 03H, 'l', 04H, 'o', 05H