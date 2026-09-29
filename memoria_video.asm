.model small

.stack 100H

.data
    CR EQU 13
    LF EQU 10

    LINHAS  equ 25           ; quantidade de linhas da tela
    COLUNAS equ 80           ; caracteres por linha
    BYTES_LINHA equ 160      ; 80 caracteres * 2 bytes (char + atributo)
    ATRIBUTO equ 07H         ; atributo: texto cinza claro sobre fundo preto

.code

;-------------------------------------------------------------------
; PREENCHE_LINHAS: Preenche linhas da tela (modo texto 80x25) com um
;                  caractere, escrevendo direto na memória de vídeo
; Entrada:  AL = número da linha inicial (1 a 25)
;           AH = caractere a ser escrito
;           BL = quantidade de linhas a preencher
; Saída:    nenhuma (nenhum registrador é alterado)
;-------------------------------------------------------------------
PREENCHE_LINHAS proc
    push AX            ; salvar registradores utilizados na proc
    push BX
    push CX
    push DX
    push DI
    push ES

    ; --- validação dos parâmetros ---
    cmp AL, 1          ; linha inicial < 1: nada a fazer
    jb  FIM_PREENCHE
    cmp AL, LINHAS     ; linha inicial > 25: nada a fazer
    ja  FIM_PREENCHE
    test BL, BL        ; zero linhas: nada a fazer
    jz  FIM_PREENCHE

    mov DH, AH         ; DH = caractere (AH será usado nas multiplicações)
    mov DL, AL         ; DL = linha inicial

    ; --- limitar a quantidade de linhas para não passar da linha 25 ---
    mov CL, LINHAS + 1 ; 26
    sub CL, DL         ; CL = linhas disponíveis a partir da linha inicial
    cmp BL, CL
    jbe QTD_OK         ; se BL <= disponíveis, mantém
    mov BL, CL         ; senão, preenche só até o fim da tela

QTD_OK:
    ; --- offset inicial: DI = (linha - 1) * 160 ---
    mov AL, DL
    dec AL             ; a primeira linha é 1, mas o offset começa em 0
    mov CL, BYTES_LINHA
    mul CL             ; AX = AL * 160
    mov DI, AX

    ; --- quantidade de words a escrever: CX = BL * 80 ---
    mov AL, BL
    mov CL, COLUNAS
    mul CL             ; AX = BL * 80
    mov CX, AX

    ; --- ES aponta para a memória de vídeo ---
    mov AX, 0B800H
    mov ES, AX

    mov AL, DH         ; AL = caractere
    mov AH, ATRIBUTO   ; AH = atributo
    cld                ; DF = 0

    rep stosw          ; repete CX vezes: mov [ES:DI], AX ; add DI, 2

FIM_PREENCHE:
    pop ES             ; restaurar registradores
    pop DI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
endp

INICIO:
    ; Configuração do DS
    mov AX, @DATA
    mov DS, AX

    mov AL, 5          ; a partir da linha 5
    mov AH, '*'        ; caractere '*'
    mov BL, 3          ; preenche 3 linhas (5, 6 e 7)
    call PREENCHE_LINHAS

    ; espera uma tecla para você poder ver a tela
    mov AH, 7
    int 21H

    mov AH, 4CH
    int 21h
 end INICIO