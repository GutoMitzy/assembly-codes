- **Bitmaps do terreno:** copie do seu arquivo atual os blocos `TERRENO_LONGE_SPRITE` e `TERRENO_PERTO_SPRITE` (sem alterar) e cole no marcador `>>> COLE AQUI <<<` da secao de sprites. Se cortar as linhas finais que sao so `1`, ajuste `ALT_BITMAP_LONGE` e `ALT_BITMAP_PERTO` (o resto se recalcula).
- **Rolagem do relevo:** a faixa de terreno roda com `movsb` e o pixel que sai pela esquerda volta pela direita. Para nao aparecer emenda, a primeira e a ultima coluna dos bitmaps devem se encaixar.
- **Arquitetura:** crateras, rochas, naves e o jipe sao "classes" (um descritor em `.data` + procs genericas). Todo sprite que se move salva o fundo antes de desenhar e restaura depois, entao nada e apagado com cor chapada.

```asm
.model small
.stack 200H

.data

; ===================================================================
; CONSTANTES DE HARDWARE E SISTEMA
; ===================================================================
SEG_VGA            equ 0A000H       ; segmento da memoria de video (modo 13H)
MODO_GRAFICO       equ 0013H        ; INT 10H: modo 13H (320x200, 256 cores)
MODO_TEXTO         equ 0003H        ; INT 10H: modo texto 80x25
FIM_PROGRAMA       equ 4C00H        ; INT 21H: encerra com codigo 0
VETOR_GET_TECLADO  equ 3509H        ; INT 21H: le o vetor da INT 09H
VETOR_SET_TECLADO  equ 2509H        ; INT 21H: grava o vetor da INT 09H
PORTA_VGA_STATUS   equ 3DAH         ; porta de status da VGA
BIT_RETRACO        equ 08H          ; bit 3 = retraco vertical em andamento
PORTA_TECLADO      equ 60H          ; porta de dados do teclado
PORTA_CTRL_TEC     equ 61H          ; porta de controle do teclado
BIT_ACK_TEC        equ 80H          ; bit de reconhecimento do teclado
PORTA_PIC          equ 20H          ; porta do controlador de interrupcoes
CMD_EOI            equ 20H          ; comando de fim de interrupcao
PORTA_PIT_CMD      equ 43H          ; comando do temporizador 8253
PORTA_PIT_CNT      equ 40H          ; contador 0 do temporizador 8253
BASE_DEC           equ 10           ; base decimal (conversao de numeros)
TICKS_POR_SEG      equ 18           ; ticks da BIOS por segundo (aprox. de 18,2)
TAM_PALAVRA        equ 2            ; bytes de uma palavra (dw)

; codigos de varredura do teclado
SC_ESC             equ 01H
SC_ENTER           equ 1CH
SC_ESPACO          equ 39H
SC_CIMA            equ 48H
SC_BAIXO           equ 50H
SC_ESQ             equ 4BH
SC_DIR             equ 4DH
BIT_SOLTA_TEC      equ 80H          ; bit 7 do scan code = tecla solta
MASCARA_SCAN       equ 7FH          ; remove o bit de soltura

; caracteres especiais
ASCII_CR           equ 13           ; retorno de carro
ASCII_LF           equ 10           ; nova linha
ASCII_ZERO         equ '0'          ; digito zero
DIF_MAIUSCULA      equ 20H          ; diferenca entre minuscula e maiuscula

; gerador aleatorio (xorshift de 16 bits)
XORSHIFT_A         equ 7
XORSHIFT_B         equ 9
XORSHIFT_C         equ 8
SEMENTE_PADRAO     equ 0ACE1H       ; semente usada se a mistura der zero

; ===================================================================
; TELA, CORES E FONTE
; ===================================================================
LARG_TELA          equ 320          ; largura da tela (px)
ALT_TELA           equ 200          ; altura da tela (px)
TAM_TELA_WORDS     equ LARG_TELA * ALT_TELA / 2   ; words da VRAM inteira

; cores da paleta VGA padrao
VERDE_CLARO        equ 0AH
VERDE              equ 02H
AMARELO            equ 0EH
MARROM             equ 06H
VERMELHO           equ 04H
VERMELHO_CLARO     equ 0CH
BRANCO             equ 0FH
AZUL               equ 01H
AZUL_CLARO         equ 09H
COR_FUNDO          equ 0            ; preto: fundo da tela, HUD e menu

; fonte bitmap: 5 colunas x 8 linhas, 1 byte por linha
LARG_GLIFO         equ 5            ; largura do glifo (px)
ALT_GLIFO          equ 8            ; altura do glifo (px)
SHIFT_GLIFO        equ 3            ; 8 bytes por glifo = deslocar 3 bits
BIT_ESQ_GLIFO      equ 10H          ; bit da coluna mais a esquerda
IDX_COR_TEXTO      equ 1            ; cor do texto = entrada 1 da paleta
NUM_GLYPHS         equ 42           ; glifos da fonte
G_ESPACO           equ 0
G_CANTO_SE         equ 10
G_CANTO_SD         equ 11
G_CANTO_IE         equ 12
G_CANTO_ID         equ 13
G_HORIZ            equ 14
G_VERT             equ 15

; ===================================================================
; DIMENSOES DOS SPRITES
; ===================================================================
LARGURA_JIPE       equ 20
ALTURA_JIPE        equ 10
TAM_JIPE           equ LARGURA_JIPE * ALTURA_JIPE
LARGURA_NAVE       equ 14
ALTURA_NAVE        equ 14
TAM_NAVE           equ LARGURA_NAVE * ALTURA_NAVE
LARGURA_CRATERA    equ 14
ALTURA_CRATERA     equ 7
TAM_CRATERA        equ LARGURA_CRATERA * ALTURA_CRATERA
LARGURA_ROCHA      equ 12
ALTURA_ROCHA       equ 10
TAM_ROCHA          equ LARGURA_ROCHA * ALTURA_ROCHA
LARGURA_RELOGIO    equ 7
ALTURA_RELOGIO     equ 8
ALTURA_CORACAO     equ 12
LARG_CORACAO_MAX   equ 18           ; largura do sprite de 3 coracoes

; ===================================================================
; CENARIO
; ===================================================================
ALTURA_SUPERFICIE  equ 7            ; faixa amarela do chao
Y_SUPERFICIE       equ ALT_TELA - ALTURA_SUPERFICIE
ALTURA_REGIAO      equ 95           ; altura da regiao montanhosa
Y_LONGE            equ ALT_TELA - ALTURA_REGIAO
ALTURA_TERRENO     equ 60           ; altura do terreno proximo
Y_PERTO            equ ALT_TELA - ALTURA_TERRENO
ALT_BITMAP_LONGE   equ 42           ; linhas do bitmap do terreno longe
ALT_BITMAP_PERTO   equ 42           ; linhas do bitmap do terreno perto
COR_PREENCHE_LONGE equ AZUL         ; cor abaixo do bitmap longe
COR_PREENCHE_PERTO equ VERDE_CLARO  ; cor abaixo do bitmap perto
COR_SUPERFICIE     equ AMARELO
PREENCHE_LONGE     equ ALT_TELA - (Y_LONGE + ALT_BITMAP_LONGE)
PREENCHE_PERTO     equ ALT_TELA - (Y_PERTO + ALT_BITMAP_PERTO)
BANDA_Y            equ Y_LONGE      ; 1a linha da faixa que rola
BANDA_ALT          equ Y_PERTO + ALT_BITMAP_PERTO - Y_LONGE   ; linhas que rolam
VEL_CHAO           equ 1            ; px de rolagem por quadro

; ===================================================================
; BARRA DE STATUS (score a esquerda, vidas no centro, relogio a direita)
; ===================================================================
Y_HUD              equ 1            ; linha superior da barra
HUD_MARGEM         equ 2            ; folga nas bordas esquerda e direita
LEN_ROTULO_SCORE   equ 6            ; tamanho de "SCORE "
NUM_DIGITOS_SCORE  equ 4
SCORE_MAX          equ 9999
COLS_SCORE         equ LEN_ROTULO_SCORE + NUM_DIGITOS_SCORE
X_SCORE            equ HUD_MARGEM
NUM_DIGITOS_TEMPO  equ 2
AVANCO_TEMPO       equ LARG_GLIFO + 1            ; avanco entre digitos do tempo
LARG_TEXTO_TEMPO   equ NUM_DIGITOS_TEMPO * AVANCO_TEMPO
ESPACO_RELOGIO     equ 3            ; folga entre icone e numeros
X_TEXTO_TEMPO      equ LARG_TELA - HUD_MARGEM - LARG_TEXTO_TEMPO
X_RELOGIO          equ X_TEXTO_TEMPO - ESPACO_RELOGIO - LARGURA_RELOGIO
X_CORACAO_MAX      equ (LARG_TELA - LARG_CORACAO_MAX) / 2
VIDAS_INICIAIS     equ 3
TEMPO_JOGO         equ 60           ; segundos de partida
PAUSA_COLISAO      equ 40           ; quadros de pausa apos perder vida

; ===================================================================
; TITULO, MENU E GAME OVER
; ===================================================================
COLS_TITULO        equ 55           ; colunas da arte do titulo
X_TITULO           equ (LARG_TELA - COLS_TITULO * LARG_GLIFO) / 2
Y_TITULO           equ 10
AVANCO_X_GAMEOVER  equ 4            ; avanco da arte do Game Over
AVANCO_Y_GAMEOVER  equ 7
COLS_GAMEOVER      equ 32
X_GAMEOVER         equ (LARG_TELA - COLS_GAMEOVER * AVANCO_X_GAMEOVER) / 2
Y_GAMEOVER         equ 10
COLS_CONTINUAR     equ 42           ; "Pressione qualquer tecla..."
X_CONTINUAR        equ (LARG_TELA - COLS_CONTINUAR * LARG_GLIFO) / 2
Y_CONTINUAR        equ 170
X_SCORE_FIM        equ (LARG_TELA - COLS_SCORE * LARG_GLIFO) / 2
Y_SCORE_FIM        equ 120
NUM_OPCOES         equ 2
OPCAO_JOGAR        equ 0
BOTAO_Y_JOGAR      equ 130
BOTAO_Y_SAIR       equ 160
CAIXA_LINHAS       equ 3            ; linhas de celulas da moldura
CAIXA_COLUNAS      equ 3            ; glifos por linha da moldura
CEL_EXTRA          equ 4            ; celulas alem das letras (bordas e folgas)
CEL_MEIO_EXTRA     equ 2            ; celulas entre os cantos alem das letras
CEL_TEXTO          equ 2            ; celula onde comeca o texto
MENU_Y_SPRITES     equ 100          ; linha da animacao do menu
MENU_VEL           equ 2            ; px por quadro (esquerda para direita)
MENU_X_NAVE0       equ 140
MENU_ESPACO_NAVES  equ 30
MENU_X_JIPE        equ 110

; ===================================================================
; JIPE, SALTO E TIROS
; ===================================================================
X_JIPE_INICIAL     equ 0            ; coluna 0 apos iniciar ou perder vida
X_MAX_JIPE         equ LARG_TELA / 2 - LARGURA_JIPE   ; metade esquerda
VEL_JIPE_ESQ       equ -1           ; px por quadro com seta esquerda
VEL_JIPE_DIR       equ 2            ; px por quadro com seta direita
Y_JIPE_CHAO        equ Y_SUPERFICIE - ALTURA_JIPE
RODA_FIM_JIPE      equ 17           ; ultima coluna do sprite com roda
PERIODO_TELA       equ LARG_TELA + LARGURA_JIPE   ; volta do MODO_REAPARECE
SALTO_ALTURA       equ 15           ; altura do topo (px)
SALTO_VEL          equ 3            ; px por quadro na subida e na descida
SALTO_TOPO_PX      equ 5            ; px de rolagem que o salto fica no topo
FASE_CHAO          equ 0
FASE_SOBE          equ 1
FASE_TOPO          equ 2
FASE_DESCE         equ 3

COR_TIRO_CIMA      equ AMARELO
COR_TIRO_FRENTE    equ VERMELHO
COR_TIRO_ALIEN     equ BRANCO
LARG_TIRO_CIMA     equ 2
ALT_TIRO_CIMA      equ 4
LARG_TIRO_FRENTE   equ 4
ALT_TIRO_FRENTE    equ 2
LARG_TIRO_ALIEN    equ 2
ALT_TIRO_ALIEN     equ 4
VEL_TIRO_CIMA      equ 4
VEL_TIRO_FRENTE    equ 5
VEL_TIRO_ALIEN     equ 2
Y_LIMITE_TIRO      equ 15           ; linha onde o tiro superior some
ALCANCE_TIRO       equ 50           ; px que o tiro frontal percorre
CANHAO_CIMA_X      equ 12           ; coluna do canhao superior no jipe
CANHAO_FRENTE_Y    equ 4            ; linha do canhao frontal no jipe
FOLGA_TIRO_FRENTE  equ 2            ; px entre o jipe e o tiro frontal
LIM_TIRO_ALIEN     equ Y_SUPERFICIE - ALT_TIRO_ALIEN
TAM_BUF_TIRO       equ 8            ; maior area de tiro (4x2 e 2x4)

; registro de tiro (words + buffer de fundo)
T_ATIVO            equ 0            ; 0 = livre, 1 = em voo
T_X                equ 2
T_Y                equ 4
T_LIM              equ 6            ; limite: X max, Y min ou Y max
T_DX               equ 8            ; deslocamento em X por quadro
T_DY               equ 10           ; deslocamento em Y por quadro
T_LARG             equ 12
T_ALT              equ 14
T_COR              equ 16
T_FUNDO            equ 18           ; buffer com o fundo salvo
TAM_TIRO           equ T_FUNDO + TAM_BUF_TIRO
TIRO_CIMA_IDX      equ 0            ; posicao de cada tiro no bloco TIROS
TIRO_FRENTE_IDX    equ 1
TIRO_ALIEN_IDX     equ 2