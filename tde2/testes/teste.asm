.model small
.stack 100H   ; define uma pilha de 256 bytes (100H)

.data 
    GAME_TITLE db "                              ___      _             _ ", 13, 10
       db "  /\/\   ___   ___  _ __     / _ \__ _| |_ _ __ ___ | |", 13, 10
       db " /    \ / _ \ / _ \| '_ \   / /_)/ _` | __| '__/ _ \| |", 13, 10
       db "/ /\/\ \ (_) | (_) | | | | / ___/ (_| | |_| | | (_) | |", 13, 10
       db "\/    \/\___/ \___/|_| |_| \/    \__,_|\__|_|  \___/|_|", 13, 10
       db 0
    
    ASCII_X dw 0
    ASCII_Y dw 0
    ASCII_COR db 15

.code 

;DEFINE O V?DEO PARA 320X200px (64000 bytes)
;USA MEM?RIA EM A000:0000
MODO_VIDEO proc
    mov AX, 13H
    int 10H
    ret
endp

; Entrada:
;  CX = coordenada X
;  DX = coordenada Y
;  AL = cor
;endereco = A000H:(CX + DX * 320)
DESENHA_PIXEL proc
    mov BL, AL          ; Guarda a cor em BL

    mov AX, DX          ; AX = Y
    mov DX, 320         ; DX = 320
    mul DX              ; DX:AX = Y * 320

    add AX, CX          ; AX = Y * 320 + X

    mov DI, AX          ; DI = offset do pixel

    mov AL, BL          ; Recupera a cor

    mov ES:[DI], AL     ; Escreve a cor do pixel na mem?ria de v?deo

    ret              

endp

DESENHA_ASCII proc
exibir:
    lodsb               ;DS:SI ? AL
    
    cmp AL, 0           ;Fim da string
    je fim

    cmp AL, 13          ;CR
    je exibir

    cmp AL, 10          ;LF
    je nova_linha
    
    cmp AL, ' '             ; Espa?o n?o desenha
    je proximo_caractere

    mov CX, ASCII_X         ; CX = X
    mov DX, ASCII_Y         ; DX = Y
    mov AL, ASCII_COR       ; AL = cor
    call DESENHA_PIXEL

proximo_caractere:
    add ASCII_X, 3        
    jmp exibir
    
nova_linha:
    mov ASCII_X, 0          ; Volta para o in?cio da linha
    add ASCII_Y, 3             ; Pr?xima linha
    jmp exibir

fim:
    ret
endp

; Aguarda uma tecla e retorna ao modo texto.
FINALIZA proc
    mov AH, 00h          ; Fun??o BIOS para esperar uma tecla
    int 16h              ; Aguarda o usu?rio pressionar uma tecla

    mov AX, 0003h        ; Seleciona o modo texto 80x25
    int 10h              ; Volta para o modo texto

    ;Encerra o programa
    mov AX, 4C00h     
    int 21h              

FINALIZA endp

start:
    mov AX, @data
    mov DS, AX
    
    mov AX, 0A000H
    mov ES, AX          ;Endere?o base do modo de v?deo
    
    call MODO_VIDEO
    
    mov SI, offset GAME_TITLE
    mov CX, 20
    mov DX, 50
    call DESENHA_ASCII

    call FINALIZA
end start