.model small
.stack 100H

.data

; =====================
; BITMAPS/ASCII ART'S
TITULO_JOGO db " __  __                     _____      _             _ ", 13, 10
            db "|  \/  |                   |  __ \    | |           | |", 13, 10
            db "| \  / | ___   ___  _ __   | |__) |_ _| |_ _ __ ___ | |", 13, 10
            db "| |\/| |/ _ \ / _ \| '_ \  |  ___/ _` | __| '__/ _ \| |", 13, 10
            db "| |  | | (_) | (_) | | | | | |  | (_| | |_| | | (_) | |", 13, 10
            db "|_|  |_|\___/ \___/|_| |_| |_|   \__,_|\__|_|  \___/|_|", 13, 10
            db 0

CORACAO_SPRITE db 0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0
             db 0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0
             db 1,1,0,0,1,1,0,0,1,1,1,1,1,1,1,1,1,1
             db 1,1,0,0,1,1,0,0,1,1,1,1,1,1,1,1,1,1
             db 1,1,0,0,1,1,0,0,1,1,1,1,1,1,1,1,1,1
             db 1,1,0,0,1,1,0,0,1,1,1,1,1,1,1,1,1,1
             db 0,0,1,1,0,0,1,1,0,0,1,1,1,1,1,1,0,0
             db 0,0,1,1,0,0,1,1,0,0,1,1,1,1,1,1,0,0
             db 0,0,1,1,0,0,1,1,0,0,1,1,1,1,1,1,0,0
             db 0,0,1,1,0,0,1,1,0,0,1,1,1,1,1,1,0,0
             db 0,0,0,0,1,1,0,0,1,1,0,0,1,1,0,0,0,0
             db 0,0,0,0,1,1,0,0,1,1,0,0,1,1,0,0,0,0
             
RELOGIO_SPRITE db 0, 0, 1, 1, 1, 0, 0   
               db 0, 1, 1, 0, 1, 1, 0   
               db 1, 1, 1, 0, 1, 1, 1  
               db 1, 1, 1, 0, 1, 1, 1   
               db 1, 1, 1, 0, 0, 0, 1   
               db 1, 1, 1, 1, 1, 1, 1   
               db 0, 1, 1, 1, 1, 1, 0   
               db 0, 0, 1, 1, 1, 0, 0   

; =====================
; CORES DOS PIXELS           
COR_TITULO  equ 0AH                 ; verde-claro
COR_BOTAO   equ 0FH                 ; branco
COR_SELEC   equ 0CH                 ; vermelho-claro (opcao selecionada)
COR_CORACAO equ 04H                 ; vermelho
COR_RELOGIO equ 0EH                 ; amarelo

; =====================
; ELEMENTOS B?SICOS DA INTERFACE
LARG_TELA   equ 320
LARGURA     equ 5                   ; largura do glifo (px)
ALTURA      equ 8                   ; altura do glifo (px)

; =====================
; T?TULO 
LARGURA_TITULO     equ 5                   ; largura da celula (avanco em X)
ALTURA_TITULO      equ 8                   ; altura da celula (avanco em Y)
X_INICIAL_TITULO   equ 22                  ; (320 - 55 * 5) / 2
Y_INICIAL_TITULO   equ 10

; =====================
; ?NDICES DOS GLIFOS
G_ESPACO    equ 0
G_CANTO_SE  equ 10                  ; canto superior esquerdo
G_CANTO_SD  equ 11                  ; canto superior direito
G_CANTO_IE  equ 12                  ; canto inferior esquerdo
G_CANTO_ID  equ 13                  ; canto inferior direito
G_HORIZ     equ 14                  ; linha horizontal
G_VERT      equ 15                  ; linha vertical
NUM_GLYPHS  equ 23

COR_ATUAL   db COR_TITULO           ; cor usada por DESENHA_CARACTERE
OPCAO_SEL   db 0

ASCII_X     dw 0
ASCII_Y     dw 0

; =====================
; BOT?O MENU INICIAL
TXT_JOGAR   db "Jogar", 0
TXT_SAIR    db "Sair", 0

BTN_JOGAR_Y equ 100                 ; Y do botao Jogar
BTN_SAIR_Y  equ 140                 ; Y do botao Sair
NUM_OPCOES  equ 2

BTN_X       dw 0
BTN_Y       dw 0
BTN_MEIO    dw 0                    ; celulas entre os cantos (letras + 2)
BTN_TXT     dw 0                    ; endereco do texto do botao

; =====================
; CORA??O
LARGURA_CORACAO  equ 18
ALTURA_CORACAO equ 12

; =====================
; REL?GIO
LARGURA_RELOGIO  equ 7
ALTURA_RELOGIO equ 8

; caractere ASCII de cada glifo, na posicao do seu indice
; (indices 10 a 15 sao de moldura e nao tem ASCII: ficam com 0)
FONTE_CHARS db ' ', 27H, '`', '(', ')', '/', '\', '_', '|', ','
            db 0, 0, 0, 0, 0, 0
            db 'J', 'O', 'G', 'A', 'R', 'S', 'I'

; 8 bytes por glifo (uma linha por byte)
; bit 4 = coluna da esquerda, bit 0 = coluna da direita
FONTE_GLYPHS label byte
db 00H, 00H, 00H, 00H, 00H, 00H, 00H, 00H   ; 0  espaco
db 04H, 04H, 00H, 00H, 00H, 00H, 00H, 00H   ; 1  '
db 08H, 04H, 00H, 00H, 00H, 00H, 00H, 00H   ; 2  `
db 02H, 04H, 08H, 08H, 08H, 08H, 04H, 02H   ; 3  (
db 08H, 04H, 02H, 02H, 02H, 02H, 04H, 08H   ; 4  )
db 01H, 02H, 02H, 04H, 04H, 08H, 08H, 10H   ; 5  /
db 10H, 08H, 08H, 04H, 04H, 02H, 02H, 01H   ; 6  \
db 00H, 00H, 00H, 00H, 00H, 00H, 00H, 1FH   ; 7  _
db 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H   ; 8  |
db 00H, 00H, 00H, 00H, 00H, 04H, 04H, 08H   ; 9  ,
db 00H, 00H, 00H, 07H, 04H, 04H, 04H, 04H   ; 10 canto sup. esq.
db 00H, 00H, 00H, 1CH, 04H, 04H, 04H, 04H   ; 11 canto sup. dir.
db 04H, 04H, 04H, 07H, 00H, 00H, 00H, 00H   ; 12 canto inf. esq.
db 04H, 04H, 04H, 1CH, 00H, 00H, 00H, 00H   ; 13 canto inf. dir.
db 00H, 00H, 00H, 1FH, 00H, 00H, 00H, 00H   ; 14 horizontal
db 04H, 04H, 04H, 04H, 04H, 04H, 04H, 04H   ; 15 vertical

FONTE_LETRAS label byte
db 02H, 02H, 02H, 02H, 12H, 12H, 0CH, 00H   ; 16 J
db 0CH, 12H, 12H, 12H, 12H, 12H, 0CH, 00H   ; 17 O
db 0CH, 12H, 10H, 16H, 12H, 12H, 0CH, 00H   ; 18 G
db 0CH, 12H, 12H, 1EH, 12H, 12H, 12H, 00H   ; 19 A
db 1CH, 12H, 12H, 1CH, 14H, 12H, 12H, 00H   ; 20 R
db 0EH, 10H, 10H, 0CH, 02H, 02H, 1CH, 00H   ; 21 S
db 0EH, 04H, 04H, 04H, 04H, 04H, 0EH, 00H   ; 22 I

.code

;-------------------------------------------------------------------
; MODO_VIDEO: configura o modo grafico 13H (320x200, 256 cores)
; Entrada: nenhuma
;-------------------------------------------------------------------
MODO_VIDEO proc
    mov AX, 0013H                   ; modo 13H: 320x200, 256 cores
    int 10H
    ret
MODO_VIDEO endp

;-------------------------------------------------------------------
; ASCII_PARA_INDICE: converte um caractere ASCII no indice do glifo
;                    (minuscula vira maiuscula; desconhecido vira
;                    espaco)
; Entrada: AL = caractere ASCII
; Saida:   AL = indice do glifo (BX e CX preservados)
;-------------------------------------------------------------------
ASCII_PARA_INDICE proc
    push BX
    push CX

    cmp AL, 'a'                     ; minuscula vira maiuscula
    jb procura
    cmp AL, 'z'
    ja procura
    sub AL, 20H

procura:
    mov BX, offset FONTE_CHARS
    mov CX, NUM_GLYPHS

procura_loop:
    cmp AL, [BX]
    je achou
    inc BX
    loop procura_loop

    mov AL, G_ESPACO                ; nao existe na fonte: espaco
    jmp fim_conversao

achou:
    sub BX, offset FONTE_CHARS      ; BX = indice
    mov AL, BL

fim_conversao:
    pop CX
    pop BX
    ret
ASCII_PARA_INDICE endp

;-------------------------------------------------------------------
; DESENHA_CARACTERE: desenha um glifo da fonte bitmap na VRAM
; Entrada: AL = indice do glifo na tabela
;          ASCII_X, ASCII_Y = posicao do canto superior esquerdo
;          COR_ATUAL = cor; ES = 0A000H
;-------------------------------------------------------------------
DESENHA_CARACTERE proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI
    push BP

    xor AH, AH                      ; AX = indice do glifo
    shl AX, 3                       ; AX = indice * 8
    mov SI, offset FONTE_GLYPHS
    add SI, AX                      ; SI = glifo

    mov AX, ASCII_Y
    mov BX, LARG_TELA
    mul BX                          ; AX = Y * 320
    add AX, ASCII_X
    mov DI, AX                      ; DI = Y * 320 + X

    mov AL, COR_ATUAL               ; AL = cor
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

    pop BP
    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHA_CARACTERE endp

;-------------------------------------------------------------------
; DESENHA_LINHA_BOX: desenha uma linha de celulas (esquerda, meio
;                    repetido e direita), avancando ASCII_X
; Entrada: AL = indice do glifo da esquerda
;          AH = indice do glifo do meio
;          DL = indice do glifo da direita
;          CX = quantidade de celulas do meio
;          ASCII_X, ASCII_Y = posicao inicial; ES = 0A000H
;-------------------------------------------------------------------
DESENHA_LINHA_BOX proc
    push AX
    push CX
    call DESENHA_CARACTERE          ; esquerda
    add ASCII_X, LARGURA
    mov AL, AH                      ; AL = glifo do meio
meio_loop:
    call DESENHA_CARACTERE          ; preserva AX, CX e DX
    add ASCII_X, LARGURA
    loop meio_loop
    mov AL, DL                      ; AL = direita
    call DESENHA_CARACTERE
    add ASCII_X, LARGURA
    pop CX
    pop AX
    ret
DESENHA_LINHA_BOX endp

;-------------------------------------------------------------------
; DESENHA_TEXTO: desenha uma string ASCII terminada em 0, avancando
;                ASCII_X
; Entrada: DS:SI = endereco da string terminada em 0
;          ASCII_X, ASCII_Y = posicao inicial; COR_ATUAL; ES = 0A000H
;-------------------------------------------------------------------
DESENHA_TEXTO proc
    push AX
    push SI
texto_loop:
    lodsb                           ; AL = DS:[SI], SI = SI + 1
    cmp AL, 0
    je texto_fim
    call ASCII_PARA_INDICE          ; AL = indice do glifo
    call DESENHA_CARACTERE
    add ASCII_X, LARGURA
    jmp texto_loop
texto_fim:
    pop SI
    pop AX
    ret
DESENHA_TEXTO endp

;-------------------------------------------------------------------
; DESENHA_BOTAO: desenha um botao de 3 celulas de altura, com moldura
;                e texto, centralizado horizontalmente na tela
; Entrada: SI = endereco do texto terminado em 0
;          DX = Y do canto superior esquerdo do botao
;          COR_ATUAL; ES = 0A000H
;-------------------------------------------------------------------
DESENHA_BOTAO proc
    push AX
    push BX
    push CX
    push DX
    push SI

    mov BTN_TXT, SI                 ; guarda o texto
    mov BTN_Y, DX                   ; guarda o Y

    xor CX, CX                      ; CX = quantidade de letras
    mov BX, SI
conta_letras:
    cmp byte ptr [BX], 0
    je fim_conta
    inc BX
    inc CX
    jmp conta_letras

fim_conta:
    mov AX, CX
    add AX, 4                       ; celulas totais = letras + 4
    mov BX, LARGURA
    mul BX                          ; AX = largura do botao em pixels
    mov BX, AX
    mov AX, LARG_TELA
    sub AX, BX
    shr AX, 1                       ; AX = (320 - largura) / 2
    mov BTN_X, AX

    add CX, 2                       ; celulas entre os cantos
    mov BTN_MEIO, CX

    ; linha de cima
    mov AX, BTN_X
    mov ASCII_X, AX
    mov AX, BTN_Y
    mov ASCII_Y, AX
    mov AL, G_CANTO_SE
    mov AH, G_HORIZ
    mov DL, G_CANTO_SD
    mov CX, BTN_MEIO
    call DESENHA_LINHA_BOX

    ; linha do meio (bordas laterais)
    mov AX, BTN_X
    mov ASCII_X, AX
    add ASCII_Y, ALTURA
    mov AL, G_VERT
    mov AH, G_ESPACO
    mov DL, G_VERT
    mov CX, BTN_MEIO
    call DESENHA_LINHA_BOX

    ; linha de baixo
    mov AX, BTN_X
    mov ASCII_X, AX
    add ASCII_Y, ALTURA
    mov AL, G_CANTO_IE
    mov AH, G_HORIZ
    mov DL, G_CANTO_ID
    mov CX, BTN_MEIO
    call DESENHA_LINHA_BOX

    ; texto na celula 2 da linha do meio
    mov AX, BTN_X
    add AX, 2 * LARGURA
    mov ASCII_X, AX
    mov AX, BTN_Y
    add AX, ALTURA
    mov ASCII_Y, AX
    mov SI, BTN_TXT
    call DESENHA_TEXTO

    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHA_BOTAO endp

;-------------------------------------------------------------------
; DESENHA_MENU: desenha os botoes Jogar e Sair; o botao da opcao
;               selecionada usa COR_SELEC e os demais COR_BOTAO
; Entrada: OPCAO_SEL = opcao selecionada (0 = Jogar, 1 = Sair)
;          ES = 0A000H
;-------------------------------------------------------------------
DESENHA_MENU proc
    push DX
    push SI

    mov COR_ATUAL, COR_BOTAO        ; assume nao selecionado
    cmp OPCAO_SEL, 0
    jne menu_jogar_cor
    mov COR_ATUAL, COR_SELEC        ; Jogar esta selecionado
menu_jogar_cor:
    mov SI, offset TXT_JOGAR
    mov DX, BTN_JOGAR_Y
    call DESENHA_BOTAO

    mov COR_ATUAL, COR_BOTAO
    cmp OPCAO_SEL, 1
    jne menu_sair_cor
    mov COR_ATUAL, COR_SELEC        ; Sair esta selecionado
menu_sair_cor:
    mov SI, offset TXT_SAIR
    mov DX, BTN_SAIR_Y
    call DESENHA_BOTAO

    pop SI
    pop DX
    ret
DESENHA_MENU endp

;-------------------------------------------------------------------
; MENU: desenha o menu e le o teclado; seta para cima e para baixo
;       trocam a opcao, Enter confirma e retorna
; Entrada: ES = 0A000H
; Saida:   OPCAO_SEL = opcao escolhida (0 = Jogar, 1 = Sair)
;-------------------------------------------------------------------
MENU proc
    push AX

menu_desenha:
    call DESENHA_MENU

menu_tecla:
    mov AH, 00H
    int 16H                         ; AH = scan code, AL = ASCII
    cmp AH, 48H                     ; seta para cima
    je menu_cima
    cmp AH, 50H                     ; seta para baixo
    je menu_baixo
    cmp AL, 13                      ; Enter
    je menu_enter
    jmp menu_tecla                  ; outra tecla: ignora

menu_cima:
    cmp OPCAO_SEL, 0                ; ja na primeira opcao
    je menu_tecla
    dec OPCAO_SEL
    jmp menu_desenha

menu_baixo:
    cmp OPCAO_SEL, NUM_OPCOES - 1   ; ja na ultima opcao
    jae menu_tecla
    inc OPCAO_SEL
    jmp menu_desenha

menu_enter:
    pop AX
    ret
MENU endp

;-------------------------------------------------------------------
; DESENHA_ASCII: desenha uma arte ASCII de varias linhas (CR ignorado,
;                LF volta ao X inicial e desce uma linha, 0 encerra)
; Entrada: DS:SI = endereco da string terminada em 0
;          ASCII_X, ASCII_Y = posicao inicial; COR_ATUAL; ES = 0A000H
;          CX = largura da celula (avanco em X por caractere)
;          DX = altura da celula (avanco em Y por linha)
; AX, BX e SI sao preservados; CX e DX nao sao alterados
;-------------------------------------------------------------------
DESENHA_ASCII proc
    push AX
    push BX
    push SI

    mov BX, ASCII_X                 ; BX = X inicial (para o retorno do LF)

exibir:
    lodsb                           ; AL = DS:[SI], SI = SI + 1
    cmp AL, 0
    je fim
    cmp AL, 13                      ; CR: ignora
    je exibir
    cmp AL, 10                      ; LF: proxima linha
    je nova_linha

    call ASCII_PARA_INDICE          ; AL = indice do glifo (preserva BX, CX)
    call DESENHA_CARACTERE          ; preserva todos os registradores
    add ASCII_X, CX                 ; avanca uma celula em X
    jmp exibir

nova_linha:
    mov ASCII_X, BX                 ; X volta ao inicial
    add ASCII_Y, DX                 ; desce uma celula em Y
    jmp exibir

fim:
    pop SI
    pop BX
    pop AX
    ret
DESENHA_ASCII endp

;-------------------------------------------------------------------
; DESENHA_SPRITE: desenha um sprite de bytes (0 = transparente,
;                 diferente de 0 = pixel pintado com COR_ATUAL)
; Entrada: SI = endereco do sprite (uma linha apos a outra)
;          CX = largura do sprite (colunas)
;          DX = altura do sprite (linhas)
;          ASCII_X, ASCII_Y = canto superior esquerdo na tela
;          COR_ATUAL; ES = 0A000H; DF = 0 (CLD)
; Todos os registradores sao preservados
;-------------------------------------------------------------------
DESENHA_SPRITE proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI
    push BP

    mov BX, CX                      ; BX = largura (CX sera o contador)
    mov BP, DX                      ; BP = altura (linhas restantes)

    mov AX, ASCII_Y
    mov DX, LARG_TELA
    mul DX                          ; AX = Y * 320 (DX sobrescrito, ja salvo em BP)
    add AX, ASCII_X
    mov DI, AX                      ; DI = canto superior esquerdo na VRAM

    mov AH, COR_ATUAL               ; AH = cor (AL recebe o pixel do sprite)

spr_linha:
    mov CX, BX                      ; CX = colunas da linha

spr_pixel:
    lodsb                           ; AL = pixel do sprite, SI = SI + 1
    cmp AL, 0
    je spr_vazio
    mov AL, AH                      ; AL = cor
    stosb                           ; ES:[DI] = AL, DI = DI + 1
    jmp spr_proximo

spr_vazio:
    inc DI                          ; pula o pixel sem pintar

spr_proximo:
    loop spr_pixel

    add DI, LARG_TELA               ; desce uma linha...
    sub DI, BX                      ; ...e volta ao X inicial (320 - largura)
    dec BP
    jnz spr_linha

    pop BP
    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHA_SPRITE endp

;-------------------------------------------------------------------
; FINALIZA: espera uma tecla, volta ao modo texto e encerra o programa
; Entrada: nenhuma
;-------------------------------------------------------------------
FINALIZA proc
    mov AH, 00H
    int 16H                         ; espera uma tecla
    mov AX, 0003H
    int 10H                         ; volta ao modo texto
    mov AX, 4C00H
    int 21H                         ; encerra
FINALIZA endp

;-------------------------------------------------------------------
; MENU_INICIAL: desenha o titulo do jogo e o menu, e espera o
;               usuario escolher uma opcao
; Entrada: ES = 0A000H
; Saida:   OPCAO_SEL = opcao escolhida (0 = Jogar, 1 = Sair)
; AX, CX, DX e SI sao preservados
;-------------------------------------------------------------------
MENU_INICIAL proc
    push AX
    push CX
    push DX
    push SI

    mov COR_ATUAL, COR_TITULO       ; titulo em verde-claro
    mov ASCII_X, X_INICIAL_TITULO   ; posicao inicial do titulo
    mov ASCII_Y, Y_INICIAL_TITULO
    mov CX, LARGURA_TITULO          ; avanco em X
    mov DX, ALTURA_TITULO           ; avanco em Y
    mov SI, offset TITULO_JOGO
    call DESENHA_ASCII

    call MENU                       ; desenha os botoes e espera Enter

    pop SI
    pop DX
    pop CX
    pop AX
    ret
MENU_INICIAL endp

INICIA_JOGO proc
    mov COR_ATUAL, COR_CORACAO
    mov ASCII_X, 10                 ; X do canto superior esquerdo
    mov ASCII_Y, 10                 ; Y do canto superior esquerdo
    mov SI, offset CORACAO_SPRITE
    mov CX, LARGURA_CORACAO
    mov DX, ALTURA_CORACAO
    call DESENHA_SPRITE
    
    mov COR_ATUAL, COR_RELOGIO
    mov ASCII_X, 280                 ; X do canto superior esquerdo
    mov ASCII_Y, 10                 ; Y do canto superior esquerdo
    mov SI, offset RELOGIO_SPRITE
    mov CX, LARGURA_RELOGIO
    mov DX, ALTURA_RELOGIO
    call DESENHA_SPRITE
    
    ret
endp

start:
    mov AX, @data
    mov DS, AX
    mov AX, 0A000H
    mov ES, AX                      ; ES = segmento da VRAM
    cld                             ; SI/DI incrementam

    call MODO_VIDEO
menu:
    call MENU_INICIAL               ; titulo + menu: define OPCAO_SEL
    cmp OPCAO_SEL, 0
    jne fim_programa                ; 1 = Sair
    
    call INICIA_JOGO                ; 0 = Jogar
    jmp menu
fim_programa:
    call FINALIZA
end start