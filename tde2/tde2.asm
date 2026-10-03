.model small
.stack 100H

.data

GAME_TITLE db " __  __                     _____      _             _ ", 13, 10
           db "|  \/  |                   |  __ \    | |           | |", 13, 10
           db "| \  / | ___   ___  _ __   | |__) |_ _| |_ _ __ ___ | |", 13, 10
           db "| |\/| |/ _ \ / _ \| '_ \  |  ___/ _` | __| '__/ _ \| |", 13, 10
           db "| |  | | (_) | (_) | | | | | |  | (_| | |_| | | (_) | |", 13, 10
           db "|_|  |_|\___/ \___/|_| |_| |_|   \__,_|\__|_|  \___/|_|", 13, 10
           db 0

COR_TITULO  equ 0AH                 ; verde-claro
LARG_TELA   equ 320
LARGURA     equ 5                   ; largura da celula (avanco em X)
ALTURA      equ 8                   ; altura da celula (avanco em Y)
X_INICIAL   equ 22                  ; (320 - 55 * 5) / 2
Y_INICIAL   equ 10                  ; (200 - 6 * 8) / 2
NUM_CHARS   equ 10

ASCII_X     dw X_INICIAL
ASCII_Y     dw Y_INICIAL

FONTE_CHARS db " '`()/\_|,"

; 8 bytes por glifo (uma linha por byte)
; bit 4 = coluna da esquerda, bit 0 = coluna da direita
FONTE_GLYPHS label byte
db 00H, 00H, 00H, 00H, 00H, 00H, 00H, 00H   ; espaco
db 04H, 04H, 00H, 00H, 00H, 00H, 00H, 00H   ; '
db 08H, 04H, 00H, 00H, 00H, 00H, 00H, 00H   ; `
db 02H, 04H, 08H, 08H, 08H, 08H, 04H, 02H   ; (
db 08H, 04H, 02H, 02H, 02H, 02H, 04H, 08H   ; )
db 01H, 02H, 02H, 04H, 04H, 08H, 08H, 10H   ; /
db 10H, 08H, 08H, 04H, 04H, 02H, 02H, 01H   ; \
db 00H, 00H, 00H, 00H, 00H, 00H, 00H, 1FH   ; _
db 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H   ; |
db 00H, 00H, 00H, 00H, 00H, 04H, 04H, 08H   ; ,

.code

MODO_VIDEO proc
    mov AX, 0013H                   ; modo 13H: 320x200, 256 cores
    int 10H
    ret
MODO_VIDEO endp

; Entrada: AL = caractere; usa ASCII_X, ASCII_Y e ES = 0A000H
DESENHA_CARACTERE proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI
    push BP

    mov DL, AL                      ; DL = caractere procurado
    mov SI, offset FONTE_CHARS
    xor BX, BX                      ; BX = indice

procura_caractere:
    cmp DL, [SI + BX]
    je encontrou_caractere
    inc BX
    cmp BX, NUM_CHARS
    jb procura_caractere
    jmp fim_caractere               ; nao existe na fonte

encontrou_caractere:
    mov AX, BX
    shl AX, 3                       ; AX = indice * 8
    mov SI, offset FONTE_GLYPHS
    add SI, AX                      ; SI = glifo

    mov AX, ASCII_Y
    mov BX, LARG_TELA
    mul BX                          ; AX = Y * 320
    add AX, ASCII_X
    mov DI, AX                      ; DI = Y * 320 + X

    mov AL, COR_TITULO              ; AL = cor
    mov BP, ALTURA                  ; contador de linhas

proxima_linha:
    mov BL, [SI]                    ; BL = linha do glifo
    inc SI
    mov CX, LARGURA                 ; 5 colunas

proximo_pixel:
    test BL, 10H                    ; bit 4 = pixel mais a esquerda
    jz pixel_vazio
    stosb                           ; ES:[DI] = AL, DI = DI + 1
    jmp proximo_bit

pixel_vazio:
    inc DI                          ; pula o pixel sem pintar

proximo_bit:
    shl BL, 1
    loop proximo_pixel

    add DI, LARG_TELA - LARGURA     ; desce uma linha, mesma coluna inicial
    dec BP
    jnz proxima_linha

fim_caractere:
    pop BP
    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHA_CARACTERE endp

; Entrada: DS:SI = string terminada em 0
DESENHA_ASCII proc
exibir:
    lodsb                           ; AL = DS:[SI], SI = SI + 1
    cmp AL, 0
    je fim
    cmp AL, 13                      ; CR: ignora
    je exibir
    cmp AL, 10                      ; LF: proxima linha
    je nova_linha

    call DESENHA_CARACTERE
    add ASCII_X, LARGURA
    jmp exibir

nova_linha:
    mov ASCII_X, X_INICIAL          ; X volta ao inicio
    add ASCII_Y, ALTURA
    jmp exibir

fim:
    ret
DESENHA_ASCII endp

FINALIZA proc
    mov AH, 00H
    int 16H                         ; espera uma tecla
    mov AX, 0003H
    int 10H                         ; volta ao modo texto
    mov AX, 4C00H
    int 21H                         ; encerra
FINALIZA endp

start:
    mov AX, @data
    mov DS, AX
    mov AX, 0A000H
    mov ES, AX                      ; ES = segmento da VRAM
    cld                             ; SI/DI incrementam

    call MODO_VIDEO

    mov SI, offset GAME_TITLE
    call DESENHA_ASCII

    call FINALIZA
end start