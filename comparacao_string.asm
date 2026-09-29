.model small

.stack 100H

.data
    CR EQU 13
    LF EQU 10

    STR1  db 'ABC$'
    STR2  db 'ABC$'

.code

;-------------------------------------------------------------------
; COMPARA_STR: Compara dois strings terminados em '$'
; Entrada:  DS:SI = endereço do primeiro string
;           ES:DI = endereço do segundo string
; Saída:    AL =  0 se os strings são iguais
;           AL = -1 (FFh) se o string em DS:SI é menor
;           AL =  1 se o string em DS:SI é maior
;-------------------------------------------------------------------
COMPARA_STR proc
    push SI            ; salvar registradores modificados pela proc
    push DI

    cld                ; DF = 0 (SI e DI incrementam)

LACO_COMPARA:
    lodsb              ; AL = [DS:SI] ; SI = SI + 1
    mov AH, ES:[DI]    ; AH = caractere do segundo string
    inc DI             ; avança para o próximo caractere

    cmp AL, AH         ; compara o caractere do string 1 com o do string 2
    jb  MENOR          ; string 1 < string 2 (comparação sem sinal)
    ja  MAIOR          ; string 1 > string 2

    ; caracteres iguais: se for o '$', os dois strings terminaram juntos
    cmp AL, '$'
    jne LACO_COMPARA   ; ainda não chegou ao fim, continua comparando

IGUAIS:
    xor AL, AL         ; AL = 0
    jmp FIM_COMPARA

MENOR:
    mov AL, -1         ; AL = -1 (FFh)
    jmp FIM_COMPARA

MAIOR:
    mov AL, 1          ; AL = 1

FIM_COMPARA:
    pop DI             ; restaurar registradores
    pop SI
    ret
endp

INICIO:
    ; Configuração de DS e ES
    mov AX, @DATA
    mov DS, AX
    mov ES, AX

    mov SI, offset STR1    ; DS:SI -> primeiro string
    mov DI, offset STR2    ; ES:DI -> segundo string
    call COMPARA_STR       ; AL = resultado da comparação

    mov AH, 4CH
    int 21h
 end INICIO