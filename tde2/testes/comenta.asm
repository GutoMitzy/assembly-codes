.code

;-------------------------------------------------------------------
; MODO_VIDEO: configura o modo grafico 13H.
;-------------------------------------------------------------------
MODO_VIDEO proc
    mov AX, 0013H                            ; modo 13H: 320x200, 256 cores
    int 10H
    ret
MODO_VIDEO endp

;-------------------------------------------------------------------
; ASCII_PARA_INDICE: converte ASCII no indice do glifo.
; Entrada: AL = caractere ASCII
; Saida:   AL = indice do glifo (desconhecido = G_ESPACO)
;-------------------------------------------------------------------
ASCII_PARA_INDICE proc
    push BX
    push CX

    cmp AL, 'a'                              ; min?scula vira mai?scula
    jb  procura
    cmp AL, 'z'
    ja  procura
    sub AL, 20H

procura:
    mov BX, offset FONTE_CHARS
    mov CX, NUM_GLYPHS

procura_loop:
    cmp AL, [BX]
    je  achou
    inc BX
    loop procura_loop

    mov AL, G_ESPACO                         ; n?o existe na fonte: espa?o
    jmp fim_conversao

achou:
    sub BX, offset FONTE_CHARS               ; BX = ?ndice
    mov AL, BL

fim_conversao:
    pop CX
    pop BX
    ret
ASCII_PARA_INDICE endp

;-------------------------------------------------------------------
; CONTAGEM_TEMPO: atualiza a contagem com base nos ticks do BIOS.
; Entrada: TEMPO_DECORRIDO = referencia do ultimo intervalo
;          TEMPO_INICIAL = segundos restantes
; Saida:   AL = 1 se decrementou o tempo; 0 caso contrario
;          TEMPO_TEXTO = dois digitos atualizados se decrementou
;-------------------------------------------------------------------
CONTAGEM_TEMPO proc
    push BX
    push DX

    mov AL, 0

    mov AH, 00H
    int 1AH

    mov BX, DX
    sub BX, TEMPO_DECORRIDO

    cmp BX, 18                               ; Aguarda o intervalo de ticks usado como um segundo.
    jb contagem_fim

    add TEMPO_DECORRIDO, 18                  ; Avanca a referencia de ticks sem descartar o excedente.

    dec TEMPO_INICIAL

    mov AX, TEMPO_INICIAL
    xor DX, DX
    mov BX, 10
    div BX                                   ; Separa dezenas e unidades para exibir dois digitos.

    add AL, '0'
    mov TEMPO_TEXTO[0], AL

    add DL, '0'
    mov TEMPO_TEXTO[1], DL

    mov AL, 1

    cmp TEMPO_INICIAL, 0
    jne contagem_fim

    ; Retorna com AL indicando se o tempo mudou neste ciclo.
contagem_fim:
    pop DX
    pop BX
    ret
CONTAGEM_TEMPO endp

;-------------------------------------------------------------------
; ATUALIZA_TEMPO: apaga e redesenha o tempo na tela.
; Entrada: TEMPO_TEXTO = dois caracteres numericos terminados em 0
; Saida:   ASCII_X, ASCII_Y = posicao final do texto
;-------------------------------------------------------------------
ATUALIZA_TEMPO proc
    push AX
    push CX
    push DX
    push DI
    push SI

    mov ASCII_X, 300
    mov ASCII_Y, 6

    mov AL, COR_FUNDO
    mov CX, 2 * (LARGURA + 1)
    mov DX, ALTURA
    call PREENCHER_LINHAS

    mov ASCII_X, 300
    mov ASCII_Y, 6
    mov SI, offset TEMPO_TEXTO
    mov DI, offset COR_TEMPO
    mov CX, 6
    mov DX, 8
    call ESCREVER_TEXTO

    pop SI
    pop DI
    pop DX
    pop CX
    pop AX
    ret
ATUALIZA_TEMPO endp

;-------------------------------------------------------------------
; TRATA_TECLADO: registra pressionamento e soltura das setas.
; Entrada: codigo de varredura lido da porta 60H
;          OLD_INT09_OFF, OLD_INT09_SEG = vetor anterior
; Saida:   TECLA_ESQ, TECLA_DIR = estado das setas
;-------------------------------------------------------------------
TRATA_TECLADO proc far
    push AX
    push DS

    mov AX, @data
    mov DS, AX

    in AL, 60H                               ; Le o scan code disponibilizado pelo controlador.

    cmp AL, 4BH
    je tecla_esq_press

    cmp AL, 0CBH
    je tecla_esq_solto

    cmp AL, 4DH
    je tecla_dir_press

    cmp AL, 0CDH
    je tecla_dir_solto

    jmp teclado_fim

tecla_esq_press:
    mov TECLA_ESQ, 1
    jmp teclado_fim

tecla_esq_solto:
    mov TECLA_ESQ, 0
    jmp teclado_fim

tecla_dir_press:
    mov TECLA_DIR, 1
    jmp teclado_fim

tecla_dir_solto:
    mov TECLA_DIR, 0

teclado_fim:
    pop DS
    pop AX

    push OLD_INT09_SEG                       ; Empilha segmento e offset para transferir ao handler anterior.
    push OLD_INT09_OFF
    retf

TRATA_TECLADO endp

;-------------------------------------------------------------------
; DESENHA_CARACTERE: desenha um glifo usando a fonte bitmap.
; Entrada: AL = indice do glifo
;          DI = endereco da paleta (cor em [DI + 1])
;          ASCII_X, ASCII_Y = posicao inicial do glifo
;-------------------------------------------------------------------
DESENHA_CARACTERE proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI
    push BP

    xor AH, AH                               ; AX = ?ndice do glifo
    shl AX, 3                                ; AX = ?ndice * 8
    mov SI, offset FONTE_GLYPHS
    add SI, AX                               ; SI = glifo

    mov AX, ASCII_Y
    mov BX, LARG_TELA
    mul BX                                   ; AX = Y * 320
    add AX, ASCII_X
    mov BH, [DI + 1]                         ; BH = cor (entrada 1 da paleta em DI)
    mov DI, AX                               ; DI = Y * 320 + X

    mov AL, BH                               ; AL = cor
    mov BP, ALTURA                           ; contador de linhas
proxima_linha:
    mov BL, [SI]                             ; BL = linha do glifo
    inc SI
    mov CX, LARGURA                          ; 5 colunas

proximo_pixel:
    test BL, 10H                             ; bit 4 = pixel mais ? esquerda
    jz   pixel_vazio
    stosb                                    ; ES:[DI] = AL, DI = DI + 1
    jmp  proximo_bit

pixel_vazio:
    inc DI                                   ; pula o pixel sem pintar

proximo_bit:
    shl BL, 1
    loop proximo_pixel

    add DI, LARG_TELA - LARGURA              ; desce uma linha, mesma coluna inicial
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
; LIMPAR_TELA: limpa toda a tela com a cor zero.
; Saida:   AX = 0; CX = 0; DI = 64000; ES = 0A000H
;-------------------------------------------------------------------
LIMPAR_TELA proc
    mov AX, 0A000h      ; Segmento da mem?ria de v?deo
    mov ES, AX
    xor DI, DI

    xor AX, AX
    mov cx, 32000       ; 32000 words * 2 bytes = 64000 bytes (tamanho da tela)

    cld
    rep stosw
    ret
LIMPAR_TELA endp

;-------------------------------------------------------------------
; PREENCHER_LINHAS: preenche um retangulo com uma unica cor.
; Entrada: AL = cor (byte, nao indice da paleta)
;          CX = largura em pixels
;          DX = quantidade de linhas (0 nao desenha)
;          ASCII_X, ASCII_Y = canto superior esquerdo
;-------------------------------------------------------------------
PREENCHER_LINHAS proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI

    mov SI, DX                      ; SI = linhas restantes (MUL sobrescreve DX)
    cmp SI, 0
    je  preencher_fim               ; nada a desenhar

    mov BH, AL                      ; BH = cor
    mov AX, ASCII_Y
    mov DX, LARG_TELA
    mul DX                          ; AX = Y * 320
    add AX, ASCII_X
    mov DI, AX                      ; DI = canto superior esquerdo na VRAM
    mov AL, BH                      ; AL = cor (usada pelo stosb)
    mov BX, CX                      ; BX = largura

preencher_linha:
    mov CX, BX                      ; CX = pixels da linha
    rep stosb                       ; escreve a linha e avanca DI
    add DI, LARG_TELA               ; desce uma linha...
    sub DI, BX                      ; ...e volta ao X inicial
    dec SI
    jnz preencher_linha

preencher_fim:
    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
PREENCHER_LINHAS endp

;-------------------------------------------------------------------
; ESCREVER_TEXTO: desenha texto com a fonte bitmap.
; Entrada: SI = endereco do texto terminado em 0
;          DI = endereco da paleta de cor
;          CX = avanco horizontal por caractere
;          DX = avanco vertical por quebra de linha
;          ASCII_X, ASCII_Y = posicao inicial
; Saida:   ASCII_X, ASCII_Y = posicao apos o texto
;-------------------------------------------------------------------
ESCREVER_TEXTO proc
    push AX
    push BX
    push SI

    mov BX, ASCII_X                          ; BX = X inicial (para o LF)

texto_exibe:
    lodsb                                    ; AL = DS:[SI], SI = SI + 1
    cmp AL, 0
    je  texto_fim
    cmp AL, 13                               ; CR: ignora
    je  texto_exibe
    cmp AL, 10                               ; LF: proxima linha
    je  texto_nova_linha

    call ASCII_PARA_INDICE                   ; AL = indice do glifo
    call DESENHA_CARACTERE                   ; preserva todos os registradores
    add ASCII_X, CX                          ; avanca uma celula em X
    jmp texto_exibe

texto_nova_linha:
    mov ASCII_X, BX                          ; X volta ao inicial
    add ASCII_Y, DX                          ; desce uma celula em Y
    jmp texto_exibe

texto_fim:
    pop SI
    pop BX
    pop AX
    ret
ESCREVER_TEXTO endp

;-------------------------------------------------------------------
; DESENHAR_CAIXA: desenha a moldura de um botao.
; Entrada: CX = numero de celulas entre os cantos
;          DI = endereco da paleta de cor
;          ASCII_X, ASCII_Y = canto superior esquerdo
; Saida:   ASCII_X, ASCII_Y preservados
;-------------------------------------------------------------------
DESENHAR_CAIXA proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push BP

    mov SI, ASCII_X                          ; SI = X inicial de cada linha
    mov DX, CX                               ; DX = celulas do meio
    mov BX, offset CAIXA_GLIFOS              ; BX = glifos da linha atual
    mov BP, 3                                ; 3 linhas de celulas

caixa_linha:
    mov AL, [BX]                             ; glifo da esquerda
    call DESENHA_CARACTERE
    add ASCII_X, LARGURA

    mov AL, [BX + 1]                         ; glifo do meio
    mov CX, DX                               ; CX = repeticoes do meio

caixa_meio:
    call DESENHA_CARACTERE
    add ASCII_X, LARGURA
    loop caixa_meio

    mov AL, [BX + 2]                         ; glifo da direita
    call DESENHA_CARACTERE

    mov ASCII_X, SI                          ; volta ao X inicial
    add ASCII_Y, ALTURA                      ; desce uma linha de celulas
    add BX, 3                                ; proximos 3 glifos da tabela
    dec BP
    jnz caixa_linha

    sub ASCII_Y, 3 * ALTURA                  ; restaura o Y inicial

    pop BP
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHAR_CAIXA endp

;-------------------------------------------------------------------
; DESENHA_ASCII_PALETA: desenha sprite com cores indexadas por paleta.
; Entrada: SI = endereco do sprite
;          BX = endereco da paleta
;          CX = largura do sprite em pixels
;          DX = altura do sprite em linhas
;          ASCII_X, ASCII_Y = canto superior esquerdo
;-------------------------------------------------------------------
DESENHA_ASCII_PALETA proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI
    push BP

    mov BP, DX                               ; Mantem a altura porque a multiplicacao altera DX.
    mov AX, ASCII_Y
    mov DX, LARG_TELA
    mul DX
    add AX, ASCII_X
    mov DI, AX
    mov DX, CX

    ; Reinicia a largura para a proxima linha do bitmap.
paleta_linha:
    mov CX, DX

    ; Cada caractere representa um indice na paleta.
paleta_pixel:
    lodsb
    sub AL, '0'
    cmp AL, 0
    je  paleta_vazio
    xlat
    stosb
    jmp paleta_proximo

    ; Indice zero nao sobrescreve o fundo.
paleta_vazio:
    inc DI

paleta_proximo:
    loop paleta_pixel

    add DI, LARG_TELA
    sub DI, DX
    dec BP
    jnz paleta_linha

    pop BP
    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHA_ASCII_PALETA endp

;-------------------------------------------------------------------
; RECORTA_X: limita um trecho horizontal a largura da tela.
; Entrada: AX = coordenada X inicial (com sinal)
;          CX = largura original
; Saida:   AX = primeira coordenada X visivel
;          CX = largura visivel (0 se fora da tela)
;-------------------------------------------------------------------
RECORTA_X proc
    push BX

    cmp AX, 0
    jge recorta_dir
    mov BX, AX
    neg BX                           ; BX = colunas cortadas a esquerda
    cmp BX, CX
    jae recorta_nada                 ; tudo fora pela esquerda
    sub CX, BX                       ; colunas restantes
    xor AX, AX                       ; primeira coluna visivel = 0

recorta_dir:
    mov BX, LARG_TELA
    sub BX, AX                       ; BX = colunas ate a borda direita
    jle recorta_nada                 ; tudo fora pela direita
    cmp CX, BX
    jbe recorta_fim
    mov CX, BX                       ; corta o excesso a direita
    jmp recorta_fim

recorta_nada:
    xor CX, CX

recorta_fim:
    pop BX
    ret
RECORTA_X endp

;-------------------------------------------------------------------
; APAGAR_SPRITE: apaga a area visivel de um sprite.
; Entrada: AL = cor usada para apagar
;          CX = largura do sprite
;          DX = altura do sprite
;          ASCII_X, ASCII_Y = posicao original do sprite
;-------------------------------------------------------------------
APAGAR_SPRITE proc
    push AX
    push BX
    push CX
    push DX
    push ASCII_X

    mov BL, AL                       ; BL = cor
    mov AX, ASCII_X
    call RECORTA_X                   ; AX = X visivel, CX = largura visivel
    jcxz apagar_fim                  ; nada visivel
    mov ASCII_X, AX
    mov AL, BL                       ; AL = cor
    call PREENCHER_LINHAS

apagar_fim:
    pop ASCII_X
    pop DX
    pop CX
    pop BX
    pop AX
    ret
APAGAR_SPRITE endp

;-------------------------------------------------------------------
; DESENHA_SPRITE_RECORTADO: desenha apenas a parte visivel do sprite.
; Entrada: SI = endereco do sprite
;          BX = endereco da paleta
;          CX = largura original do sprite
;          DX = altura do sprite
;          ASCII_X, ASCII_Y = posicao original (X com sinal)
;-------------------------------------------------------------------
DESENHA_SPRITE_RECORTADO proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI
    push BP
    push ASCII_X
    push ASCII_Y

    mov BP, DX                       ; BP = linhas restantes
    mov DI, CX                       ; DI = largura total (passo de linha)
    mov AX, ASCII_X
    call RECORTA_X                   ; AX = X visivel, CX = largura visivel
    jcxz recortado_fim               ; nada visivel

    mov DX, AX
    sub DX, ASCII_X                  ; DX = colunas cortadas a esquerda
    add SI, DX                       ; pula essas colunas na 1a linha
    mov ASCII_X, AX                  ; desenha a partir da 1a coluna visivel
    mov DX, 1                        ; uma linha por chamada

    ; A rotina de paleta recebe uma linha por chamada.
recortado_linha:
    call DESENHA_ASCII_PALETA
    add SI, DI                       ; proxima linha do sprite
    inc ASCII_Y
    dec BP
    jnz recortado_linha

recortado_fim:
    pop ASCII_Y
    pop ASCII_X
    pop BP
    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHA_SPRITE_RECORTADO endp

;-------------------------------------------------------------------
; MOVER_SPRITE: apaga, desloca e redesenha um sprite.
; Entrada: AX = deslocamento horizontal (com sinal)
;          DI = MODO_REAPARECE ou MODO_SOME
;          SI = endereco do sprite; BX = endereco da paleta
;          CX = largura; DX = altura
;          ASCII_X, ASCII_Y = posicao atual
;          FUNDO_COR = cor usada para apagar
; Saida:   ASCII_X = nova posicao horizontal
;          CF = 0 se visivel; 1 se saiu no MODO_SOME
;-------------------------------------------------------------------
MOVER_SPRITE proc
    push AX
    push BX
    push CX
    push DX
    push BP

    mov BP, AX                       ; BP = deslocamento
    mov AL, FUNDO_COR
    call APAGAR_SPRITE               ; apaga na posicao atual

    mov AX, ASCII_X
    add AX, BP                       ; AX = novo X
    mov ASCII_X, AX

    cmp BP, 0
    jl  mover_esquerda

    cmp AX, LARG_TELA                ; indo para a direita
    jl  mover_visivel                ; ainda aparece
    cmp DI, MODO_SOME                        ; Decide entre desaparecer e reaparecer no lado oposto.
    je  mover_some_dir

    sub AX, PERIODO_TELA             ; volta um periodo, preservando o excesso
    mov ASCII_X, AX                  ; reaparece pela esquerda
    jmp mover_visivel

mover_some_dir:
    mov ASCII_X, LARG_TELA           ; fica fora, a direita
    jmp mover_fora

    ; Testa a borda esquerda usando a largura negativa do sprite.
mover_esquerda:
    mov BP, CX
    neg BP                           ; BP = -largura
    cmp AX, BP
    jg  mover_visivel                ; ainda aparece
    cmp DI, MODO_SOME
    je  mover_some_esq
    add AX, PERIODO_TELA             ; avanca um periodo, preservando o excesso
    mov ASCII_X, AX                  ; reaparece pela direita
    jmp mover_visivel

mover_some_esq:
    mov ASCII_X, BP                  ; fica fora, a esquerda
    jmp mover_fora

    ; Redesenha o sprite na posicao calculada.
mover_visivel:
    call DESENHA_SPRITE_RECORTADO    ; desenha na nova posicao
    clc                              ; CF = 0
    jmp mover_fim

mover_fora:
    stc                              ; CF = 1: nada a desenhar

mover_fim:
    pop BP
    pop DX
    pop CX
    pop BX
    pop AX
    ret
MOVER_SPRITE endp

;-------------------------------------------------------------------
; ESPERA_RETRACO: aguarda o proximo retraco vertical.
;-------------------------------------------------------------------
ESPERA_RETRACO proc
    push AX
    push DX

    mov DX, 3DAH                     ; porta de status do VGA

retraco_sai:
    in AL, DX
    test AL, 08H                     ; bit 3 = retraco em andamento
    jnz retraco_sai                  ; espera terminar o atual

retraco_entra:
    in AL, DX
    test AL, 08H
    jz  retraco_entra                ; espera o proximo comecar

    pop DX
    pop AX
    ret
ESPERA_RETRACO endp

;-------------------------------------------------------------------
; MOVER_SPRITES_MENU: desloca as tres naves e o jipe do menu.
; Entrada: AX = deslocamento horizontal comum
;          SPRITES_MENU_X = posicoes atuais dos quatro sprites
; Saida:   SPRITES_MENU_X = posicoes atualizadas
;          ASCII_X, ASCII_Y e FUNDO_COR alterados
;-------------------------------------------------------------------
MOVER_SPRITES_MENU proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI

    mov FUNDO_COR, COR_FUNDO         ; fundo do menu e preto
    mov ASCII_Y, 100                 ; linha dos sprites do menu
    mov DI, MODO_REAPARECE

    mov DX, SPRITES_MENU_X[0]
    mov ASCII_X, DX
    mov SI, offset NAVES_SPRITE
    mov BX, offset NAVE_PALETA
    mov CX, LARGURA_NAVE
    mov DX, ALTURA_NAVE
    call MOVER_SPRITE                        ; Apaga, desloca e redesenha usando a mesma rotina.
    mov DX, ASCII_X                  ; novo X devolvido por MOVER_SPRITE
    mov SPRITES_MENU_X[0], DX

    mov DX, SPRITES_MENU_X[2]
    mov ASCII_X, DX
    mov SI, offset NAVES_SPRITE + TAM_NAVE
    mov DX, ALTURA_NAVE
    call MOVER_SPRITE
    mov DX, ASCII_X
    mov SPRITES_MENU_X[2], DX

    mov DX, SPRITES_MENU_X[4]
    mov ASCII_X, DX
    mov SI, offset NAVES_SPRITE + 2 * TAM_NAVE
    mov DX, ALTURA_NAVE
    call MOVER_SPRITE
    mov DX, ASCII_X
    mov SPRITES_MENU_X[4], DX

    mov DX, SPRITES_MENU_X[6]
    mov ASCII_X, DX
    mov SI, offset JIPE_SPRITE
    mov BX, offset JIPE_PALETA
    mov CX, LARGURA_JIPE
    mov DX, ALTURA_JIPE
    call MOVER_SPRITE
    mov DX, ASCII_X
    mov SPRITES_MENU_X[6], DX

    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
MOVER_SPRITES_MENU endp

;-------------------------------------------------------------------
; DESENHAR_BOTOES: desenha e controla a selecao do menu.
; Entrada: OPCAO_SEL = indice inicialmente selecionado
;          BOTOES_TXT, BOTOES_Y = textos e posicoes dos botoes
; Saida:   OPCAO_SEL = indice confirmado com Enter
;-------------------------------------------------------------------
DESENHAR_BOTOES proc
    push AX
    push BX
    push CX
    push DX
    push SI
    push DI
    push BP

    ; Recomeca o desenho para atualizar o destaque da opcao.
botoes_redesenha:
    xor BP, BP                               ; BP = indice da opcao

botoes_proximo:
    mov DI, offset COR_BOTAO                 ; paleta: nao selecionado
    mov AX, BP
    cmp AL, OPCAO_SEL
    jne botoes_cor
    mov DI, offset COR_SELEC                 ; esta e a opcao selecionada

botoes_cor:
    mov BX, BP
    shl BX, 1                                ; BX = indice * 2 (tabelas de words)
    mov SI, BOTOES_TXT[BX]                   ; SI = texto do botao
    mov DX, BOTOES_Y[BX]                     ; DX = Y do botao
    mov BTN_TXT, SI
    mov BTN_Y, DX

    xor CX, CX                               ; CX = quantidade de letras
    mov BX, SI

    ; Conta os caracteres para centralizar a moldura.
botoes_conta:
    cmp byte ptr [BX], 0
    je  botoes_fim_conta
    inc BX
    inc CX
    jmp botoes_conta

botoes_fim_conta:
    mov AX, CX
    add AX, 4                                ; celulas totais = letras + 4
    mov BX, LARGURA
    mul BX                                   ; AX = largura do botao em pixels
    mov BX, AX
    mov AX, LARG_TELA
    sub AX, BX
    shr AX, 1                                ; AX = (320 - largura) / 2
    mov BTN_X, AX

    add CX, 2                                ; celulas entre os cantos
    mov AX, BTN_X
    mov ASCII_X, AX
    mov AX, BTN_Y
    mov ASCII_Y, AX
    call DESENHAR_CAIXA

    mov AX, BTN_X                            ; texto na celula 2 da linha do meio
    add AX, 2 * LARGURA
    mov ASCII_X, AX
    mov AX, BTN_Y
    add AX, ALTURA
    mov ASCII_Y, AX
    mov CX, LARGURA
    mov DX, ALTURA
    mov SI, BTN_TXT
    call ESCREVER_TEXTO

    inc BP
    cmp BP, NUM_OPCOES
    jae botoes_tecla                         ; todos desenhados: le o teclado
    jmp botoes_proximo                       ; salto longo: jb direto sairia do alcance

    ; Atualiza a animacao enquanto aguarda entrada do teclado.
botoes_tecla:
    call ESPERA_RETRACO              ; 1 quadro por retraco (~60 por segundo)
    mov AX, 2                        ; deslocamento por quadro (direita)
    call MOVER_SPRITES_MENU

    mov AH, 01H
    int 16H                          ; ZF = 1 se nao ha tecla (nao espera)
    jz  botoes_tecla                 ; sem tecla: proximo quadro
    mov AH, 00H
    int 16H                          ; consome a tecla: AH = scan code, AL = ASCII

    cmp AH, 48H                      ; seta para cima
    je  botoes_cima
    cmp AH, 50H                      ; seta para baixo
    je  botoes_baixo
    cmp AL, 13                       ; Enter
    je  botoes_enter
    jmp botoes_tecla                 ; outra tecla: ignora

botoes_cima:
    cmp OPCAO_SEL, 0                 ; ja na primeira opcao
    je  botoes_tecla
    dec OPCAO_SEL
    jmp botoes_redesenha

botoes_baixo:
    cmp OPCAO_SEL, NUM_OPCOES - 1    ; ja na ultima opcao
    jae botoes_tecla
    inc OPCAO_SEL
    jmp botoes_redesenha

botoes_enter:
    pop BP
    pop DI
    pop SI
    pop DX
    pop CX
    pop BX
    pop AX
    ret
DESENHAR_BOTOES endp

;-------------------------------------------------------------------
; GAME_OVER: mostra a tela de fim de jogo e aguarda uma tecla.
; Entrada: TITULO_GAMEOVER = desenho do titulo
;          TXT_GAMEOVER = instrucao de continuidade
;          TXT_SCORE, SCORE_INICIAL = pontuacao exibida
; Saida:   ASCII_X, ASCII_Y e registradores de desenho alterados
;-------------------------------------------------------------------
GAME_OVER proc
    call LIMPAR_TELA

    mov DI, offset COR_GAMEOVER
    mov ASCII_X, X_INICIAL_TITULO              ; posi??o inicial do t?tulo
    add ASCII_X, 70                            ; offset extra pelas 2 linhas
    mov ASCII_Y, Y_INICIAL_TITULO
    mov CX, LARGURA_GAMEOVER                   ; avan?o em X
    mov DX, ALTURA_GAMEOVER                    ; avan?o em Y
    mov SI, offset TITULO_GAMEOVER
    call ESCREVER_TEXTO

    mov ASCII_X, 50
    mov ASCII_Y, 170
    mov CX, LARGURA
    mov DX, ALTURA
    mov SI, offset TXT_GAMEOVER
    call ESCREVER_TEXTO

    mov DI, offset COR_SCORE
    mov ASCII_X, 135                           ; (320 - 10 * 5) / 2: centraliza "SCORE 0000"
    mov ASCII_Y, 120                           ; logo acima do texto de continuar (Y = 150)
    mov CX, LARGURA
    mov DX, ALTURA
    mov SI, offset TXT_SCORE
    call ESCREVER_TEXTO                        ; "SCORE " (ASCII_X fica no fim do texto)
    mov SI, offset SCORE_INICIAL
    call ESCREVER_TEXTO                        ; valor logo em seguida

    mov AH, 00H
    int 16H                                  ; espera uma tecla

    ret
GAME_OVER endp

;-------------------------------------------------------------------
; DESENHA_CORACOES: desenha a quantidade atual de vidas.
; Entrada: VIDAS = quantidade de coracoes (1 a 3)
; Saida:   ASCII_X, ASCII_Y = posicao do desenho
;-------------------------------------------------------------------
DESENHA_CORACOES proc
    push BX
    push CX
    push DX
    push SI

    mov BL, VIDAS
    xor BH, BH
    dec BX
    shl BX, 1                        ; BX = (VIDAS - 1) * 2 (tabelas de words)
    mov SI, CORACOES[BX]             ; sprite com essa quantidade
    mov CX, CORACAO_LARG[BX]         ; largura desse sprite
    mov ASCII_X, X_CORACAO
    mov ASCII_Y, Y_CORACAO
    mov BX, offset COR_CORACAO
    mov DX, ALTURA_CORACAO
    call DESENHA_ASCII_PALETA

    pop SI
    pop DX
    pop CX
    pop BX
    ret
DESENHA_CORACOES endp

;-------------------------------------------------------------------
; DEC_CORACAO: remove uma vida e atualiza os coracoes.
; Entrada: VIDAS = quantidade atual de vidas
; Saida:   CF = 0 se removeu uma vida
;          CF = 1 se restava apenas uma vida
;          VIDAS decrementado apenas se CF = 0
;-------------------------------------------------------------------
DEC_CORACAO proc
    cmp VIDAS, 1
    ja  dec_remove                   ; ainda ha mais de um coracao
    stc                              ; era o ultimo: sinaliza o fim
    ret

dec_remove:
    push AX
    push CX
    push DX

    dec VIDAS
    mov ASCII_X, X_CORACAO
    mov ASCII_Y, Y_CORACAO
    mov AL, COR_FUNDO                ; cor com que o fundo e apagado
    mov CX, CORACAO_LARG[4]          ; largura maxima (3 coracoes)
    mov DX, ALTURA_CORACAO
    call PREENCHER_LINHAS            ; apaga o desenho atual
    call DESENHA_CORACOES            ; desenha com um a menos

    pop DX
    pop CX
    pop AX
    clc                              ; CF = 0 (os pop nao alteram as flags)
    ret
DEC_CORACAO endp

;-------------------------------------------------------------------
; MENU_INICIAL: desenha o menu e aguarda a escolha.
; Entrada: OPCAO_SEL = opcao inicialmente selecionada
; Saida:   OPCAO_SEL = 0 para Jogar; 1 para Sair
;-------------------------------------------------------------------
MENU_INICIAL proc
    push AX
    push CX
    push DX
    push SI

    mov DI, offset COR_TITULO
    mov ASCII_X, X_INICIAL_TITULO            ; posi??o inicial do t?tulo
    mov ASCII_Y, Y_INICIAL_TITULO
    mov CX, LARGURA_TITULO                   ; avan?o em X
    mov DX, ALTURA_TITULO                    ; avan?o em Y
    mov SI, offset TITULO_JOGO
    call ESCREVER_TEXTO

    xor AX, AX                       ; deslocamento 0: so desenha nos X atuais
    call MOVER_SPRITES_MENU

    call DESENHAR_BOTOES

    pop SI
    pop DX
    pop CX
    pop AX
    ret
MENU_INICIAL endp

;-------------------------------------------------------------------
; EXIBE_STATUS: desenha vidas, pontuacao e relogio.
; Entrada: VIDAS = quantidade de vidas
;          SCORE_INICIAL = texto da pontuacao
;          TEMPO_TEXTO = texto do tempo restante
; Saida:   ASCII_X, ASCII_Y alterados
;-------------------------------------------------------------------
EXIBE_STATUS proc
    call DESENHA_CORACOES

    mov ASCII_X, (LARG_TELA - 4 * (LARGURA + 1)) / 2
    mov SI, offset SCORE_INICIAL
    mov DI, offset COR_SCORE
    mov CX, 6
    mov DX, 8
    call ESCREVER_TEXTO

    mov ASCII_X, 290
    mov ASCII_Y, 5
    mov SI, offset RELOGIO_SPRITE
    mov BX, offset COR_RELOGIO
    mov CX, LARGURA_RELOGIO
    mov DX, ALTURA_RELOGIO
    call DESENHA_ASCII_PALETA

    add ASCII_X, 10
    add ASCII_Y, 1
    mov SI, offset TEMPO_TEXTO
    mov DI, offset COR_TEMPO
    mov CX, 6
    mov DX, 8
    call ESCREVER_TEXTO

    ret
EXIBE_STATUS endp

;-------------------------------------------------------------------
; INICIA_JOGO: inicializa a partida e executa o loop principal.
; Entrada: sprites, paletas e configuracoes da partida
;          TECLA_ESQ, TECLA_DIR = estados das setas
; Saida:   JIPE_X, JIPE_VEL e VIDAS atualizados
;          TEMPO_INICIAL, TEMPO_DECORRIDO = controle de tempo
;          Retorna quando Esc e pressionado ou o tempo acaba
;-------------------------------------------------------------------
INICIA_JOGO proc
    call LIMPAR_TELA
    mov JIPE_X, 10
    mov VIDAS, 3

    call EXIBE_STATUS

    mov ASCII_X, 0
    mov ASCII_Y, Y_LONGE
    mov SI, offset TERRENO_LONGE_SPRITE
    mov BX, offset TERRENO_LONGE_PALETA
    mov CX, LARG_TELA
    mov DX, LINHAS_ASCII
    call DESENHA_ASCII_PALETA

    add ASCII_Y, LINHAS_ASCII
    mov AL, [TERRENO_LONGE_PALETA + 1]
    mov CX, LARG_TELA
    mov DX, PREENCHE_LONGE
    call PREENCHER_LINHAS

    mov ASCII_X, 0
    mov ASCII_Y, Y_PERTO
    mov SI, offset TERRENO_PERTO_SPRITE
    mov BX, offset TERRENO_PERTO_PALETA
    mov CX, LARG_TELA
    mov DX, LINHAS_ASCII
    call DESENHA_ASCII_PALETA

    add ASCII_Y, LINHAS_ASCII
    mov AL, [TERRENO_PERTO_PALETA + 1]       ; Usa a cor da camada proxima ao apagar o jipe.
    mov CX, LARG_TELA
    mov DX, PREENCHE_PERTO
    call PREENCHER_LINHAS

    mov ASCII_Y, Y_SUPERFICIE
    mov AL, COR_SUPERFICIE
    mov CX, LARG_TELA
    mov DX, ALTURA_SUPERFICIE
    call PREENCHER_LINHAS

    mov ASCII_X, 10
    sub ASCII_Y, ALTURA_JIPE
    mov SI, offset JIPE_SPRITE
    mov BX, offset JIPE_PALETA
    mov CX, LARGURA_JIPE
    mov DX, ALTURA_JIPE
    call DESENHA_ASCII_PALETA

    mov AH, 00H
    int 1AH
    mov TEMPO_DECORRIDO, DX

    ; Sincroniza cada iteracao com o retraco vertical.
jogo_loop:
    call ESPERA_RETRACO                      ; Evita atualizar em frequencia superior ao ciclo vertical.

    call CONTAGEM_TEMPO                      ; Verifica se houve atualizacao do segundo exibido.
    cmp AL, 1
    jne verifica_teclado

    cmp TEMPO_INICIAL, 0
    je jogo_fim

    call ATUALIZA_TEMPO

    ; Le Esc sem bloquear a animacao.
verifica_teclado:

    mov AH, 01H
    int 16H
    jz  atualiza_jipe

    mov AH, 00H
    int 16H
    cmp AL, 1BH
    je  jogo_fim
    ; Escolhe a velocidade conforme o estado atual das setas.
atualiza_jipe:

    mov JIPE_VEL, 1

    cmp TECLA_ESQ, 1
    jne verifica_direita
    mov JIPE_VEL, -1
verifica_direita:

    cmp TECLA_DIR, 1
    jne move_jipe
    mov JIPE_VEL, 2
    ; Verifica os limites permitidos antes de mover.
move_jipe:
    mov AX, JIPE_VEL

    mov DX, JIPE_X
    add DX, AX

    cmp DX, 0
    jl  jogo_volta

    cmp DX, X_MAX_JIPE                       ; nao cruza a metade da tela
    jg  jogo_volta

    push AX

    mov AX, JIPE_X
    mov ASCII_X, AX
    mov ASCII_Y, JIPE_Y
    mov SI, offset JIPE_SPRITE
    mov BX, offset JIPE_PALETA
    mov CX, LARGURA_JIPE
    mov DX, ALTURA_JIPE

    mov AL, [TERRENO_PERTO_PALETA + 1]
    mov FUNDO_COR, AL

    pop AX
    call MOVER_SPRITE                        ; Apaga, desloca e redesenha usando a mesma rotina.

    mov AX, ASCII_X
    mov JIPE_X, AX

jogo_volta:
    jmp jogo_loop

    ; Sai do loop e retorna ao fluxo principal.
jogo_fim:
    ret

INICIA_JOGO endp

; ---------------------------------------------------------------------
; START: prepara segmentos, instala o teclado e controla menu e partida.
; ---------------------------------------------------------------------
start:
    mov AX, @data
    mov DS, AX

    mov AX, 0A000H
    mov ES, AX                               ; ES = segmento da VRAM
    cld                                      ; SI/DI incrementam

    mov AX, 3509H                            ; Consulta o endereco atual da interrupcao de teclado.
    int 21H

    mov OLD_INT09_OFF, BX                    ; Guarda o offset do handler anterior.
    mov OLD_INT09_SEG, ES                    ; Guarda o segmento do handler anterior.

    push DS
    mov DX, offset TRATA_TECLADO
    mov AX, SEG TRATA_TECLADO
    mov DS, AX
    mov AX, 2509H                            ; Instala TRATA_TECLADO como novo handler da INT 09H.
    int 21H
    pop DS

    call MODO_VIDEO
    ; Reconstroi o menu apos cada partida.
menu:
    call LIMPAR_TELA
    call MENU_INICIAL                        ; t?tulo + menu: define OPCAO_SEL
    cmp OPCAO_SEL, 0
    jne fim_programa                         ; 1 = Sair
    call INICIA_JOGO                         ; 0 = Jogar
    call GAME_OVER                           ; Exibe a tela final antes de retornar ao menu.
    jmp menu

    ; Restaura o modo texto e termina a execucao.
fim_programa:
    mov AX, 0003H
    int 10H                                  ; volta ao modo texto
    mov AX, 4C00H
    int 21H                                  ; encerra

end start
