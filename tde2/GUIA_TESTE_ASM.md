# Moon Patrol em Assembly — guia de estudo do tde2.asm

Um quadro da partida reúne três coisas que avançam em ritmos diferentes. A BIOS acumula eventos de teclado; o jogo muda posições uma vez por quadro; o relógio fornece ticks para medir segundos. É por isso que manter uma seta pressionada no chão, deslocar o jipe durante o salto e esperar o cronômetro diminuir produzem comportamentos diferentes. O guia acompanha as 56 rotinas do fonte na ordem em que ajudam a explicar a partida.

**Roteiro de leitura.** Abra o [fonte](tde2.asm) ao lado deste guia. Comece em `start`, próximo ao fim do arquivo. Siga os `CALL` do menu até a partida. Quando chegar a `jogo_loop`, use a seção 5 como mapa. Os nomes entre crases são identificadores que você pode procurar diretamente no editor.

## 1. Do executável DOS à primeira tela

`end start` informa ao montador o ponto de entrada do módulo. O ligador usa essa informação para construir o executável. Quando o DOS o carrega, a execução começa em `start`, mesmo que dezenas de procedimentos estejam escritos acima dele. Declarar `MODO_VIDEO proc` define o endereço de uma rotina. Ela só executa quando o fluxo chega lá, por exemplo, por `call MODO_VIDEO`.

~~~text
start → MODO_VIDEO → configura repetição do teclado
  └─ menu → LIMPAR_TELA → MENU_INICIAL
               ├─ Jogar → INICIA_ALEATORIO → NOVO_JOGO → INICIA_JOGO
               │                                          ↓
               │                                       GAME_OVER → menu
               └─ Sair → restaura repetição padrão → modo texto → DOS
~~~

### Como ler os endereços e registradores

O jogo usa x86 de 16 bits em modo real. Um endereço tem **segmento e deslocamento**. O processador forma o endereço físico deslocando o segmento quatro bits à esquerda e somando o deslocamento. Assim, `A000h:0000h` aponta para `A0000h`. Um deslocamento de 16 bits vai de 0 a 65.535. Isso explica a organização das imagens: um quadro de 64.000 bytes cabe em um segmento, mas esse quadro e um panorama de 32.000 bytes juntos ultrapassam o alcance de um único deslocamento.

| Registrador | Como aparece no jogo |
|---|---|
| `CS:IP` | Identifica a próxima instrução. Saltos, chamadas e retornos mudam o fluxo. |
| `DS` e `ES` | `DS` normalmente aponta para os dados do jogo. `ES` seleciona o destino gráfico. No menu é a memória VGA; na partida, em geral, é o quadro em RAM. |
| `SS:SP` | Identifica o topo da pilha. `.stack 100h` reserva 256 bytes. `PUSH` de uma word diminui `SP` em dois e guarda o valor. `POP` recupera-o e avança `SP`. |
| `AX` e `DX` | Servem para cálculos, cores e serviços do sistema. `AH` e `AL` são as metades alta e baixa de `AX`. Uma multiplicação de 16 bits pode usar `DX:AX` para o resultado de 32 bits. |
| `BX` e `BP` | `BX` frequentemente endereça uma tabela, paleta ou registro de tiro. `BP` também serve de contador. Uma referência com `[BP]` usa `SS` por padrão; por isso o código muitas vezes transfere o índice para `DI` antes de endereçar dados. |
| `CX` | Guarda larguras, limites do sorteio e contagens. `LOOP` decrementa `CX` e desvia se ele ainda for diferente de zero. `REP` consome `CX` nas instruções de string. |
| `SI` e `DI` | Selecionam posições dentro dos buffers. `LODSB` lê de `DS:SI` para `AL`; `STOSB` escreve `AL` em `ES:DI`; `MOVSW` copia uma word de `DS:SI` para `ES:DI`. |

`.model small` estabelece o modelo usual de código e dados próximos. O fonte declara ainda segmentos separados para `PIXELS_QUADRO` e `PIXELS_LUA`. Em `start`, `mov AX,@data` seguido de `mov DS,AX` instala o segmento dos dados. **Valor, endereço e tamanho são coisas diferentes:** `mov AX,JIPE_X` lê a posição guardada; `mov BX,offset TIRO_CIMA` obtém o deslocamento do registro; `SEG PIXELS_QUADRO` obtém seu segmento. `EQU` dá nome a uma expressão de montagem. `DB`, `DW` e `DUP` aparecem quando é preciso reservar bytes, words de dois bytes ou várias entradas iguais.

### O que as primeiras instruções preparam

~~~asm
mov AX, @data
mov DS, AX
mov AX, 0A000H
mov ES, AX
call MODO_VIDEO
~~~

`@data` fornece o valor do segmento do grupo de dados. `AX` serve de intermediário porque a instrução `MOV` para um registrador de segmento aceita um registrador ou uma posição de memória como origem. A primeira cópia deixa `DS` pronto para ler variáveis como `JIPE_X`. Reutilizar `AX` na linha seguinte não altera a cópia que ficou em `DS`.

Em `0A000H`, o sufixo `H` indica hexadecimal e o zero inicial faz o literal começar com um algarismo, como exige essa sintaxe quando o primeiro dígito significativo seria uma letra. O valor é A000 hexadecimal. No modo 13h, a VGA expõe os pixels a partir do endereço físico `A0000h`. Por isso `ES=A000h` seleciona a região que o processador alcança com `ES:DI`. Configurar `ES` escolhe um destino de memória. A troca efetiva de modo acontece em `MODO_VIDEO` por meio da BIOS.

O `CLD` desta versão fica em `LIMPAR_TELA`, antes do primeiro `REP STOSW`. Ele zera `DF`, a flag de direção. Com `DI=0`, as primeiras words são gravadas nos deslocamentos 0, 2 e 4. Com `DF=1` seriam 0, FFFEh e FFFCh, pois o deslocamento de 16 bits daria a volta. Isso explica por que retirar um `CLD` de `start` pode produzir a mesma imagem: o fluxo passa por `LIMPAR_TELA` antes de começar o desenho. Com `DF=0`, `LODSB` e `STOSB` também avançam seus índices em um byte e `MOVSW` avança os dois índices em dois bytes.

Um `CALL` próximo empilha o endereço da próxima instrução; `RET` o recupera. Em um procedimento que precisa reutilizar o `BX` do chamador, `PUSH BX` antes do cálculo e `POP BX` no retorno preservam seu valor. Já `INT` usa o vetor do serviço para transferir o controle, salvando flags e endereço de retorno. O jogo usa `INT 10h` para vídeo, `INT 16h` para teclado, `INT 1Ah` para ticks da BIOS e `INT 21h` para terminar no DOS.

### Teclado da BIOS e acesso a portas

Em `start`, `AX=0305h` seleciona `AH=03h` e a subfunção `AL=05h` de `INT 16h`. `XOR BX,BX` zera as duas metades de `BX`. Em um teclado AT compatível, `BH=0` solicita o menor atraso inicial, aproximadamente 250 ms, e `BL=0` a repetição mais rápida, cerca de 30 eventos por segundo. Isso explica o padrão “um passo, pausa, depois vários passos”. O primeiro pressionamento gera um evento. A configuração atua sobre as repetições de uma tecla mantida pressionada. O resultado observado também depende do emulador e da frequência dos quadros.

Neste fonte, o teclado do jogo é lido pelo buffer da BIOS. Se você estudou a versão que guardava `OLD_INT09_OFF` e `OLD_INT09_SEG`, aquelas duas words representavam o deslocamento e o segmento do tratador anterior da IRQ de teclado. A versão atual deixa o atendimento dessa interrupção a cargo do sistema. Em `fim_programa`, a chamada `AX=0300h` solicita a configuração **padrão** de repetição; o programa não registra uma configuração personalizada anterior.

`IN` e `OUT` acessam o espaço de portas de entrada e saída do processador. Em `ESPERA_RETRACO`, `IN AL,DX` lê um byte da porta cujo número está em `DX`. Em `INICIA_ALEATORIO`, `OUT 43h,AL` envia um comando ao temporizador e `IN AL,40h` lê sua resposta. Essa distinção vale também para o exemplo estudado de `IN AL,60h`: ele leria um byte oferecido pelo controlador de teclado; `MOV AL,60h` apenas colocaria o número 60h em `AL`. O caminho atual de entrada do jogador passa por `INT 16h`.

**`MODO_VIDEO`** usa `AX=0013h` e `INT 10h` para selecionar o modo 13h. **`LIMPAR_TELA`** carrega `ES=A000h`, zera `DI` e `AX`, põe 32.000 em `CX` e executa `REP STOSW`. Cada word zero apaga dois pixels. No total são 320 × 200 = 64.000 pixels de um byte. A posição `(100,10)` usa o deslocamento `10 × 320 + 100 = 3300 = 0CE4h`. O último pixel, `(319,199)`, usa 63.999. Esse mesmo cálculo vale para desenhar num quadro em RAM; muda o segmento que contém os pixels.

### Como reconhecer decisões e contas no Assembly

| Operação | Que informação produz | Exemplo no jogo |
|---|---|---|
| `CMP a,b` e salto | Compara por meio das flags, preservando os operandos. `JE/JNE` testam igualdade; `JL/JG` consideram sinal; `JB/JA` comparam sem sinal. | Um X negativo é normal durante o recorte à esquerda. Já o índice de uma variante é contado a partir de zero. |
| `TEST`, `AND`, `OR`, `XOR` | `TEST` consulta bits sem gravar o resultado. `AND` isola ou limpa, `OR` liga, `XOR` alterna os bits diferentes. | A abertura de cratera usa flags de sobrevoo e pontuação. `XOR BX,BX` zera tanto `BH` quanto `BL`. |
| `SHL`, `SHR`, `ADC` | Os deslocamentos multiplicam ou dividem potências de dois em valores sem sinal. O bit que sai vai para `CF`; `ADC` inclui esse carry na soma. | Na cópia do panorama, a divisão por dois conta words e o carry permite copiar um byte restante. |
| `MUL` e `DIV` com operando word | `MUL` usa `AX` e entrega o produto em `DX:AX`. `DIV` divide `DX:AX`, deixando quociente em `AX` e resto em `DX`. | No cálculo de um endereço de bitmap é preciso guardar qualquer altura ainda necessária em `DX`. Na formatação decimal, zera-se `DX` para dividir apenas o valor de `AX`. |
| `STC`, `CLC`, `JC`, `JNC` | As duas primeiras instruções fixam `CF` em 1 ou 0; as outras desviam conforme seu valor. | Em colisões, carry ligado representa impacto. Na busca de uma vaga, representa falha. O significado vem do contrato da rotina. |

## 2. O menu e as rotinas gráficas que ele ensina

**`MENU_INICIAL`** escolhe o texto e a paleta verde-clara do título, posiciona a origem e chama `ESCREVER_TEXTO`. Depois chama `MOVER_SPRITES_MENU` com passo zero para o primeiro desenho. `DESENHAR_BOTOES` assume o laço interativo e retorna quando o jogador confirma a opção.

### Da string ao pixel

1. **`ESCREVER_TEXTO`** recebe `SI` apontando para a string terminada em zero, `DI` para a paleta, `CX` para o avanço horizontal e `DX` para o vertical. Guarda o X inicial em `BX`. Cada `LODSB` traz um caractere. Zero encerra, 13 (CR) é ignorado e 10 (LF) restaura o X inicial e soma o passo a Y. Para um caractere comum, a rotina desenha o glifo e avança X. Isso permite escrever o prefixo do score e, em outra chamada, continuar com os dígitos no cursor já avançado.
2. **`ASCII_PARA_INDICE`** converte uma minúscula no intervalo de `a` a `z` subtraindo `20h`. Depois percorre `FONTE_CHARS`. Quando encontra o caractere, subtrai do endereço corrente a base da tabela. Como cada entrada tem um byte, a diferença é o número do glifo. Se a busca de `NUM_GLYPHS` entradas acabar, devolve o índice do espaço em `AL`.
3. **`DESENHA_CARACTERE`** usa oito bytes por glifo, um por linha. Zera `AH` e desloca `AX` três bits à esquerda: multiplicar o índice por oito localiza o primeiro byte em `FONTE_GLYPHS`. Em cada linha, `TEST BL,10h` examina o bit 4, o primeiro dos cinco pixels. Se estiver ligado, `STOSB` pinta a cor obtida de `[DI+1]` da paleta original. Se estiver desligado, só avança o destino. `SHL BL,1` traz o próximo bit para a posição de teste. Ao final dos cinco pixels, somar `320−5` a `DI` alinha a próxima linha.

Há duas representações gráficas no mesmo projeto. A fonte compacta vários pixels em bits de um byte. As naves, o jipe e o terreno usam **um caractere de paleta por pixel**. Na segunda representação, **`DESENHA_ASCII_PALETA`** lê um dígito com `LODSB` e subtrai o código de `'0'`. O caractere `'2'` vira o índice 2. `XLAT` lê a cor em `DS:[BX+AL]` e a devolve em `AL` para `STOSB`. O índice zero faz `DI` avançar sem escrever: a paisagem continua visível pelos espaços transparentes do sprite.

### Deslocar, recortar e apagar

**`MOVER_SPRITES_MENU`** percorre três bitmaps de nave. `BP` avança de dois em dois para buscar as coordenadas X, que são words; `SI` avança `TAM_NAVE = 14 × 14 = 196` bytes para selecionar a arte seguinte. O jipe ocupa a quarta posição na tabela de X e usa sua própria paleta e dimensões. As quatro chamadas reutilizam **`MOVER_SPRITE`**, passando em `AX` o passo horizontal com sinal. Durante a animação, `VEL_MENU=2`.

`MOVER_SPRITE` guarda o passo em `BP` antes de reutilizar `AX`. No menu apaga a posição anterior, soma o passo a `ASCII_X` e desenha a nova posição. `MODO_REAPARECE` corrige X usando `PERIODO_TELA = 320+20` quando o objeto completa a saída. Na partida, `MODO_SOME` dispensa o apagamento individual porque o fundo do quadro foi recomposto. Ao cruzar o limite de saída nesse modo, a rotina devolve `CF=1` para o chamador liberar o slot. À esquerda, a condição de saída completa é `X ≤ −largura`.

**`RECORTA_X`** recebe a coluna em `AX` e a largura em `CX`. Para uma nave de largura 14 em `X=−3`, descarta três colunas: devolve início zero e largura 11. Em `X=315`, restam cinco colunas de tela; em `X=320`, nenhuma. A primeira comparação considera o sinal porque coordenadas fora da borda esquerda são negativas. O chamador pode usar `JCXZ` para pular todo o desenho quando a largura é zero.

**`DESENHA_SPRITE_RECORTADO`** desenha o bitmap inteiro de uma vez se couber na horizontal. Na borda, calcula quantas colunas iniciais da origem ignorar, ajusta `SI` e chama o desenho de paleta linha por linha. No exemplo de `X=−3`, desenha 11 colunas, mas o começo da próxima linha do bitmap continua **14 bytes** depois do começo equivalente da linha anterior. A rotina recorta X; cabe ao chamador fornecer uma faixa vertical válida.

**`APAGAR_SPRITE`** guarda a cor de `AL` antes de usar `AX` para recortar X. Havendo largura visível, chama **`PREENCHER_LINHAS`**. Esta calcula `DI=Y×320+X`, preserva a largura em `BX` e a contagem de linhas em `SI`. Para cada linha, recarrega `CX` e usa `REP STOSB`. Como `DI` avançou pela largura pintada, acrescenta `320−largura` para chegar ao mesmo X na linha seguinte. A cor é um valor VGA já pronto. Essa rotina também serve a tiros, à pista e à limpeza do campo de score.

**Uma constante, três usos diferentes.** Para uma nave, `LARGURA_NAVE=14` é o número de colunas a percorrer, `ALTURA_NAVE=14` é o número de linhas e `TAM_NAVE=196` é a distância em bytes entre dois bitmaps consecutivos. Para um glifo de fonte, os argumentos de `ESCREVER_TEXTO` têm outro significado: `LARGURA_TITULO` e `ALTURA_TITULO` são os avanços do cursor. No Game Over, avanços de 4 e 7 aproximam os glifos, embora o desenho de cada glifo continue usando a matriz de 5 × 8.

### Selecionar Jogar ou Sair

**`DESENHAR_BOTOES`** usa `BP` como índice da opção, busca por word o ponteiro do texto e sua altura na tela, conta os caracteres até o zero e calcula a largura da caixa. Se o rótulo tem `n` caracteres, a caixa ocupa `(n+4) × LARGURA` pixels. Dividir a largura sobrando na tela por dois centraliza o botão. A opção selecionada recebe a paleta vermelho-clara; as outras recebem branco.

**`DESENHAR_CAIXA`** lê três trios da tabela de glifos, um para cada linha da moldura. Desenha a ponta esquerda, repete o elemento central `CX` vezes e desenha a ponta direita. Recupera o X inicial e desce uma altura de glifo para a próxima linha. Ao terminar, restaura a origem, permitindo posicionar o texto em relação à mesma caixa.

**`ESPERA_RETRACO`** consulta a porta VGA `3DAh`. Primeiro espera o bit 3 baixar, para sair de um retraço que já esteja em andamento; depois espera que suba, indicando o começo do próximo. É uma espera ativa. No menu, após essa espera o código anima os sprites e consulta `INT 16h` com `AH=01h`. `ZF=1` significa buffer vazio e a animação continua. Se há tecla, `AH=00h` a consome. As setas alteram `OPCAO_SEL` dentro dos limites, e Enter devolve a seleção a `start`.

**Cor e geometria são parâmetros separados.** `COR_TITULO` associa os bits ativos dos glifos a `VERDE_CLARO=0Ah`. `COR_SELEC` usa `VERMELHO_CLARO=0Ch` para a seleção e `COR_BOTAO` usa `BRANCO=0Fh` para a outra opção. `CAIXA_GLIFOS` reúne os índices `G_CANTO_SE`, `G_CANTO_SD`, `G_CANTO_IE`, `G_CANTO_ID`, `G_HORIZ` e `G_VERT`. Assim, a mesma rotina desenha as duas molduras, trocando posição, largura e paleta. `NUM_OPCOES=2` limita os índices a 0 e 1.

## 3. Ao escolher Jogar: sorteio e preparação do cenário

**`INICIA_ALEATORIO`** mistura duas leituras de tempo. A BIOS fornece os ticks em `CX:DX` via `INT 1Ah`. O programa combina as duas metades por `XOR` e trava uma amostra do canal 0 do temporizador escrevendo na porta `43h`. Duas leituras da porta `40h` entram na mistura. Se o valor combinado der zero, usa `0ACE1h`. O motivo aparece em **`ALEATORIO`**: seu gerador xorshift desloca uma cópia do estado e combina-a com o original. Partindo de zero, qualquer deslocamento e qualquer XOR nesse cálculo continuariam dando zero.

A transformação de 16 bits equivale, na ordem, a `x ^= x << 7`, `x ^= x >> 9` e `x ^= x << 8`, desprezando bits fora da word. `ALEATORIO` guarda o novo estado completo em `SEMENTE`. Só depois recupera o limite pedido em `CX`, zera `DX` e divide `DX:AX` por `CX`. O resto em `DX` pertence a `0..CX−1` e é copiado para `AX` na saída. Por exemplo, para sortear uma quantidade de 1 a 3 o chamador passa 3 e soma 1. Uma mesma semente e a mesma sequência de chamadas reproduzem os resultados. O limite deve ser positivo.

**`NOVO_JOGO`** reinicia as três vidas, os quatro caracteres de `SCORE_INICIAL`, a referência e a fração do relógio. Carrega `DURACAO_JOGO=60` em `TEMPO_INICIAL` e chama **`FORMATA_TEMPO`**. A divisão decimal por dez produz dezenas no quociente e unidades no resto; somar `'0'` converte, por exemplo, 6 e 0 em `"60"`.

**`INICIA_JOGO`** passa `ES` para o segmento de `PIXELS_QUADRO`, limpa o quadro em RAM e inicializa a origem da Lua. O primeiro jipe da partida começa em `X=10`, no chão. Os dois tiros do jogador começam inativos. Três chamadas preparam as tabelas:

- **`INICIA_CRATERAS`** grava `CRATERA_LIVRE=8000h` nas três posições X, zera `CRATERA_GERADA` e sorteia a primeira distância em `0..99` pixels.
- **`INICIA_ROCHAS`** marca as três vagas com `ROCHA_LIVRE` e programa a primeira tentativa para `60..159` pixels. A criação ainda depende de uma cratera anterior e de espaço.
- **`INICIA_ALIENS`** desativa cada nave e seu registro de tiro. `BX` anda dois bytes por nave porque a atividade é uma word; `BP` anda `TAM_TIRO` bytes porque cada projétil é um registro inteiro. `ALIEN_ATRASO` recebe 30 quadros e a indicação de acerto no jipe começa em zero.

A paisagem é composta de trás para frente. O bitmap distante começa em `Y_LONGE=100`. São 42 linhas, seguidas de `200−(100+42)=58` linhas de preenchimento. A camada próxima começa em `Y_PERTO=140`, também com 42 linhas, e recebe mais 18 linhas de preenchimento. A transparência de cada bitmap deixa aparecer as partes necessárias do fundo. Por último, uma faixa amarela de 320 × 7 ocupa as linhas 193 a 199. O jipe de 20 × 10, em repouso, tem o topo em `JIPE_Y=193−10=183` e a última linha em 192.

**Como ler as declarações dos buffers.** Em `QUADRO_RAM segment para private 'FAR_DATA'`, `segment` abre um segmento nomeado, `para` pede alinhamento de parágrafo (16 bytes), `private` o mantém separado de outros segmentos na ligação e `'FAR_DATA'` é a classe atribuída a ele. `PIXELS_QUADRO db LARG_TELA * ALT_TELA dup (?)` reserva 64.000 posições de um byte. O `?` indica conteúdo inicial não especificado; por isso o programa faz a limpeza antes de usar o quadro. `ends` encerra a definição. A mesma leitura de `PANORAMA_RAM` dá 320 × (200 − 100) = 32.000 bytes. Os dois buffers somam 96.000 bytes, mas cada acesso continua cabendo num deslocamento de 16 bits graças à separação em segmentos.

A imagem inferior pronta vira uma **fonte permanente de pixels do cenário**. Para guardá-la, `INICIA_JOGO` salva `DS` e `ES`, aponta `DS` para o quadro construído, `ES` para `PIXELS_LUA` e `SI` para o byte `100×320`. Copia 16.000 words e restaura os segmentos. O panorama guarda apenas as 100 linhas inferiores. A leitura seguinte da BIOS estabelece a referência inicial do relógio da partida.

## 4. Como uma paisagem de 320 colunas parece continuar indefinidamente

**`PREPARA_QUADRO`** soma `VEL_CHAO=1` a `ORIGEM_LUA`. Ao chegar a 320, subtrai 320. Esse valor é a coluna do panorama que deve aparecer na borda esquerda. Limpa as 100 linhas do céu com `REP STOSW` e, para cada linha inferior, copia duas fatias contíguas da origem para um destino contínuo.

| Se a origem horizontal vale 317 | Colunas do panorama | Colunas no quadro |
|---|---|---|
| Primeira fatia | 317, 318, 319 | 0, 1, 2 |
| Segunda fatia | 0 até 316 | 3 até 319 |

No primeiro trecho, `CX=320−317=3`. `SHR CX,1` deixa uma word para copiar e põe o bit ímpar em `CF`. `REP MOVSW` copia dois bytes e termina com `CX=0`, preservando esse carry. `ADC CX,0` recupera a sobra de um byte, e `REP MOVSB` o copia. Na segunda fatia repete-se a mesma técnica. `DS:SI` lê o panorama; `ES:DI` escreve o quadro. Ao final das duas fatias, `DI` está no início da linha seguinte e `SI` é ajustado para recomeçar na linha correta da origem. O resultado é equivalente a buscar `(origem + x) módulo 320` para cada pixel, evitando dividir a cada coluna.

**`APRESENTA_QUADRO`** só é chamada depois de desenhar objetos e status. Aguarda `RETRACOS_POR_PASSO` inícios de retraço, salva os segmentos, usa o quadro como `DS:SI` e a VGA como `ES:DI` e executa `REP MOVSW` para 32.000 words. Assim o monitor recebe a composição de um quadro já preparado. O custo por atualização inclui 32.000 bytes de céu, 32.000 bytes de panorama e 64.000 bytes de apresentação, além dos objetos. Esperar um retraço sincroniza o início da transferência; o FPS efetivo também depende do tempo que o emulador gasta executando o quadro.

## 5. Um quadro completo em jogo_loop

A ordem importa. Um tiro novo, um tiro já em voo e uma colisão do jipe não são tratados todos no mesmo ponto.

| Ordem | Operação | Por que ocorre aqui |
|---|---|---|
| 1 | `PREPARA_QUADRO` | Recupera o céu e a paisagem limpa. Os objetos móveis do quadro anterior deixam de fazer parte da imagem. |
| 2 | `VERIFICA_TIRO_ROCHAS` e `VERIFICA_TIRO_CIMA_ALIENS` | Testam os projéteis já ativos contra as posições atuais dos alvos, antes do próximo deslocamento. |
| 3 | `ATUALIZA_TIRO` para cima e para frente | Reutiliza o mesmo procedimento com `BX` apontando para registros diferentes. Move ou encerra cada tiro. |
| 4 | `ROLA_CRATERAS`, `ROLA_ROCHAS` e `ROLA_ALIENS` | Atualizam posições, geram objetos quando permitido e desenham os que continuam em jogo. |
| 5 | `CONTAGEM_TEMPO` | Atualiza o tempo real da partida. Se o último segundo acabou, o fluxo sai. |
| 6 | Teclado, `DISPARAR` e `MOVER_JIPE` | Esc encerra, espaço tenta os canhões e seta para cima inicia um salto se o jipe estiver no chão. O jogo consome os eventos pendentes e aplica uma vez o deslocamento escolhido para o quadro. |
| 7 | `ATUALIZA_TIROS_ALIENS` e `ATIRA_ALIENS` | Os tiros existentes comparam sua posição com o jipe já deslocado. Em seguida, as naves elegíveis podem lançar novos tiros. |
| 8 | `VERIFICA_SALTO_CRATERAS`, `VERIFICA_ROCHAS` e `ALIEN_HIT_FLAG` | Qualquer impacto leva ao mesmo caminho de perda de vida. |
| 9 | `EXIBE_STATUS` e `APRESENTA_QUADRO` | Sem colisão nem término, compõem a barra, exibem o quadro e voltam à etapa 1. |

**Duas escalas de tempo.** Movimento e espera entre grupos usam quadros. O relógio usa ticks da BIOS. Se o desenho ficar mais caro, um objeto de 1 px por quadro percorre menos pixels por segundo, embora o contador continue acompanhando os ticks entre chamadas. A pausa de colisão também é especial: o programa espera os retraços e redefine a referência de ticks ao voltar, descontando a pausa da duração jogável.

### Traçando a entrada de teclado de um quadro

No rótulo `verifica_teclado`, o jogo zera `JIPE_VEL` **uma vez por quadro**. Em `le_tecla_jogo`, `AH=01h` consulta o buffer; `JZ aplica_movimento` segue se `ZF=1`, inclusive quando nenhuma tecla chegou. Se existe evento, `AH=00h` o retira e devolve `AL` com o caractere e `AH` com o código de varredura. O laço compara `AL` com Esc (1Bh) e espaço (20h); para as setas, compara `AH` com 4Bh (esquerda), 4Dh (direita) e 48h (cima). Depois de tratar um evento, volta à **consulta**, sem zerar novamente a velocidade.

| Momento, partindo de X=40 e do chão | O que é lido ou calculado | Estado ao final |
|---|---|---|
| Chegam direita e cima no mesmo quadro | Direita grava +2 em `JIPE_VEL` e `SALTO_VX`. Cima inicia a fase 1. | Uma chamada a `MOVER_JIPE` leva a X=42 e altura=3. A ordem inversa desses dois eventos produz o mesmo primeiro passo. |
| Quadro seguinte sem evento | `JIPE_VEL` começa em zero, mas `aplica_movimento` vê que o jipe está no ar e recupera +2 de `SALTO_VX`. | X=44 e altura=6, mesmo sem repetição da tecla. |
| Chega esquerda ainda no ar | A leitura troca as duas velocidades para −2. | X=42 e altura=9. A mudança lateral não reinicia a subida. |

No chão, vários eventos de direita num mesmo quadro definem a mesma velocidade e resultam em **um passo**. Se o buffer estiver vazio, o jipe fica parado naquele quadro. A BIOS entrega pressionamentos e repetições; buffer vazio não revela se a seta já foi solta. Por isso a direção lateral gravada no chão também pode ser aproveitada em um salto posterior, mesmo depois de uma pausa. Uma repetição de cima só inicia outro salto se `SALTO_FASE` tiver voltado a zero. Espaço também pode ser tratado no mesmo quadro das setas, respeitando a disponibilidade dos registros de tiro.

`SALTO_VX` é uma word inicializada com zero na declaração. O código a zera na aterrissagem e no reaparecimento, mas não a reinicializa expressamente na entrada de `INICIA_JOGO`. Se uma partida termina com direção memorizada, um salto no início da seguinte pode herdar esse valor até chegar outra seta lateral. É uma diferença entre a inicialização dos dados ao carregar o executável e a reinicialização da partida dentro do mesmo programa.

## 6. Objetos do cenário e formação das naves

### Obstáculos: posições, vagas e distância percorrida

Uma **vaga** ou **slot** é uma entrada reutilizável nas tabelas. Para crateras e rochas, o X `8000h` significa livre. Em complemento de dois, essa word representa −32.768 quando comparada com sinal; fica fora de qualquer X usado no desenho. Há **três slots** para rochas, embora existam **quatro tipos visuais**: número de instâncias e número de variantes são conceitos separados.

**`ESPACO_LIVRE`** percorre primeiro as coordenadas das crateras e depois as das rochas. Se algum X for maior que `320−DIST_ENTRE_OBST=220`, devolve `CF=1`. Uma vaga livre passa pelo teste porque `JG` interpreta os valores com sinal. **`BUSCA_SLOT_LIVRE`** recebe a tabela em `DS:BX` e sua contagem em `CX`. Testa a word em `[BX]`, soma dois a `BX` e usa `LOOP` até encontrar o marcador ou esgotar a tabela. Devolve o endereço da vaga e `CF=0` no sucesso ou `CF=1` quando cheia.

**`ROLA_CRATERAS`** subtrai o passo do chão de `CRATERA_PROX`. Quando vence a distância, chama **`CRIA_CRATERA`**. Esta verifica a borda, procura uma vaga, grava `X=320` e sorteia um dos três tipos. A primeira criação libera futuras rochas por `CRATERA_GERADA`. Só após o sucesso a rolagem rearma o contador: `DIST_MIN_CRATERA = 150 + 14 = 164` mais um sorteio de 0 a 99. A diferença mínima de 164 entre origens deixa 150 pixels livres entre as bordas. Se a criação falhar por falta de espaço, uma atualização seguinte pode tentar novamente.

Para mover uma cratera ativa, a rotina guarda o índice, separa o tipo com `MASCARA_TIPO=03h`, multiplica o tipo por `TAM_CRATERA=98` e soma o resultado à base dos bitmaps. Usa `MOVER_SPRITE` com passo −1 e `MODO_SOME`. Se `CF` indicar saída completa pela esquerda, volta a marcar aquele X como livre. O `PUSH BX` permite usar `BX` temporariamente como ponteiro da paleta e recuperar o índice da posição depois.

**`ROLA_ROCHAS`** segue o mesmo princípio. Após criar uma rocha, a próxima distância tentada é `DIST_MIN_ROCHA=110` mais 0 a 99. O desenho começa em `Y_ROCHA=183`, usa bitmap de 12 × 10, e cada variante começa 120 bytes após a anterior. **`CRIA_ROCHA`** acrescenta condições próprias: precisa já existir uma primeira cratera gerada e restar até a próxima pelo menos `DIST_ENTRE_OBST + LARGURA_ROCHA = 112` pixels no contador. Só então confere a borda e procura uma vaga. A escrita do novo tipo também limpa as flags da ocupante anterior.

### Grupos de naves: reservar espaço antes de sortear

**`ROLA_ALIENS`** começa procurando uma nave ativa. Enquanto houver pelo menos uma, percorre os slots ativos, escolhe o sprite pelo tipo, conserva Y e desloca X para a esquerda. **No fonte documentado, `VEL_ALIEN=1` e o passo é fixo.** Cada saída completa limpa `ALIENS_ATIVO`. Somente uma passagem que encontra todos os slots livres decrementa `ALIEN_ATRASO`. Ao vencer o intervalo, chama **`CRIA_GRUPO_ALIENS`**.

A criação sorteia o tipo uma única vez e o conserva em `SI`. Sorteia 1 a 3 para `BP`, a quantidade do grupo. `DI` é o número da nave; `BX` é o deslocamento em bytes nas tabelas de words. O mínimo do primeiro X é 320. Para as demais, o mínimo é `X_anterior + 14 + 30`. O limite superior da última origem é `320+160−14=466`. A cada sorteio o código desconta desse máximo **44 pixels para cada nave que ainda falta**, de modo que sempre exista uma posição válida para completar a formação. Como o gerador devolve menos que o limite, o número de resultados possíveis é `máximo−mínimo+1`.

Por exemplo, em um grupo de três, o primeiro X fica entre 320 e 378. Se sair 360, o segundo pode ir de 404 a 422. Se sair 410, o terceiro fica entre 454 e 466. A formação nasce fora da tela e entra progressivamente pelo lado direito. Cada Y é sorteado entre 15 e `100−14=86`, independentemente dos outros Y. Uma nave que nasce em 86 ocupa até a linha 99. As origens X já garantem o vão horizontal de 30 pixels mesmo quando duas naves têm o mesmo Y.

## 7. Jipe, salto e colisões com obstáculos

**`MOVER_JIPE`** recebe em `AX` o deslocamento com sinal. O laço principal começa a velocidade do quadro em zero, aplica `−VEL_JIPE` para a esquerda ou `+VEL_JIPE` para a direita, com módulo 2. Se o buffer contiver eventos das duas setas laterais, vale a direção do último evento lateral consumido. Durante o salto, o laço recupera o passo guardado em `SALTO_VX`. A rotina soma esse passo a `JIPE_X` e limita o resultado entre zero e `X_MAX_JIPE = 320/2−20 = 140`. Em X=140, o último pixel do jipe fica em 159. Em seguida avança o salto e desenha na linha `JIPE_Y−JIPE_ALT`. Assim, aumentar a altura física diminui a coordenada de tela.

**`ATUALIZA_SALTO`** é uma máquina de estados: a próxima operação depende de `SALTO_FASE`, que persiste entre chamadas.

| Fase | Atualização | Transição |
|---|---|---|
| 0 — chão | Mantém a posição vertical. | Seta para cima coloca a fase em 1. |
| 1 — subida | Soma 3 a `JIPE_ALT` por quadro. | Em cinco passos chega a 15, fixa a altura e zera `SALTO_PX`. |
| 2 — topo | Acumula `VEL_CHAO` em `SALTO_PX`. | Ao acumular 5 pixels de cenário, muda para 3. A descida começa na chamada seguinte. |
| 3 — descida | Subtrai 3 da altura. | Ao alcançar o solo, zera a altura e `SALTO_VX` e volta à fase 0. |

No topo, o jipe está parado **verticalmente**. O movimento lateral continua ativo. Mesmo sem pressionar direita, o contador do topo avança pela rolagem do chão.

**`ACHA_BURACO`** recebe em `AL` o tipo de cratera e encontra seu bitmap por `tipo × 98`. `DH` percorre colunas e `DL` controla as sete linhas. O caractere `'3'` identifica abertura. Entre todos esses pixels, guarda a menor coluna em `BH` e a maior em `BL`. O valor inicial `FFh` da menor coluna sinaliza que nenhuma abertura foi encontrada. No sucesso, devolve os extremos inclusivos em `AL` e `AH` com `CF=0`.

**`VERIFICA_SALTO_CRATERAS`** soma o X da cratera a esses extremos locais. Compara o intervalo da abertura com `[JIPE_X, JIPE_X+RODA_FIM_JIPE]`, onde o último deslocamento é 17. Havendo sobreposição com `JIPE_ALT=0`, devolve colisão em `CF`. No ar, marca `FLAG_SOBREVOADA`. Quando a abertura fica inteiramente atrás das rodas, a combinação de sobrevoada e ainda não pontuada rende 50 pontos. `OR` liga `FLAG_PONTUADA` sem apagar o tipo; `TEST` consulta a marca nos quadros seguintes.

**`VERIFICA_ROCHAS`** faz primeiro um teste barato: os intervalos horizontais da rocha e do jipe se cruzam? Se a rocha já passou, verifica a marca de sobrevoo e concede os 50 pontos uma vez. Se está à frente, passa à próxima. Uma candidata com sobreposição segue para **`COLISAO_BITMAP_ROCHA`**, que considera o contorno real.

Nessa rotina, `BP=10−JIPE_ALT` dá a quantidade de linhas potencialmente comuns. Se o valor for zero ou negativo, o jipe passou por cima. Caso contrário, `SI` aponta para a variante da rocha e `BX` para a primeira linha do jipe que alcança a altura dela. A diferença `X_rocha−X_jipe` determina quantas colunas pular em um dos dois bitmaps. Só a faixa horizontal comum precisa ser lida. Se os dois caracteres da mesma coordenada são diferentes de `'0'`, a rotina devolve `CF=1`. Ao terminar uma linha, cada ponteiro avança pela largura **do seu próprio bitmap**, compensando os pixels já comparados. Isso permite saltar uma rocha baixa sem colidir com as linhas transparentes acima dela.

## 8. Do disparo à pontuação

### Um registro por projétil

Os projéteis compartilham um formato em memória. `BX` aponta para a primeira word de um tiro; expressões como `[BX+T_X]` acessam campos por deslocamento em **bytes**. Isso permite usar a mesma rotina com o tiro superior, o frontal ou um tiro alienígena.

| Offset | Campo | O que representa |
|---:|---|---|
| 0 | `T_ATIVO` | Zero libera o registro; um indica voo. |
| 2, 4 | `T_X`, `T_Y` | Coordenadas do canto superior esquerdo. |
| 6 | `T_LIM` | Linha limite do tiro superior ou coluna final do frontal. |
| 8, 10 | `T_DX`, `T_DY` | Deslocamentos por atualização. |
| 12, 14 | `T_LARG`, `T_ALT` | Dimensões usadas para desenho e colisão. |
| 16 | `T_COR` | Cor VGA. O desenho lê seu byte baixo. |

Cada registro ocupa `TAM_TIRO=18` bytes. A terceira nave tem o índice 2. Sua posição em `ALIENS_X` fica a 4 bytes do início; seu tipo em `ALIENS_TIPO` fica a 2 bytes; seu projétil em `TIROS_ALIENS` fica a 36 bytes. Confundir o número do slot com o deslocamento em bytes selecionaria campos de outro objeto.

**`DISPARAR`** testa os canhões separadamente a cada evento de espaço. Se o superior está livre, lança um tiro amarelo de 2 × 4 em `X=JIPE_X+12`, imediatamente acima do topo do jipe. Se o frontal está livre, lança um tiro vermelho de 4 × 2 em `X=JIPE_X+20` e `Y=JIPE_Y+4−JIPE_ALT`. Guarda em `T_LIM` a coluna de lançamento mais 50. Um registro ocupado só impede a criação de outro tiro daquele canhão. **`DESENHA_TIRO`** lê posição, largura, altura e cor do registro e repassa esses dados a `PREENCHER_LINHAS`. Desenhar não decide se houve impacto.

**`ATUALIZA_TIRO`** ignora um tiro inativo e soma `T_DX` e `T_DY` às coordenadas de um ativo. No superior, `T_DX=0` e `T_DY=−4`. Se a nova linha chega a 15 ou a ultrapassa para cima, desativa o registro sem desenhar ali. O teste contra naves do laço principal ocorreu na posição anterior ao avanço. No frontal, `T_DX=5`. Se o passo chega ao limite, a rotina fixa X na coluna final e ainda testa uma rocha nessa posição. Um erro ao fim desse percurso limpa as sequências de acertos nas rochas.

### Qual geometria define um acerto?

**`TIRO_COLIDE_RETANGULO`** é o teste comum aos tiros. `BX` aponta para o projétil; `CX` e `DX` dão as bordas esquerda e direita do alvo; `SI` e `AX` dão topo e base. Direita e base são **exclusivas**. Dados o tiro `[x,x+w) × [y,y+h)` e o alvo `[L,R) × [T,B)`, há sobreposição quando as quatro condições são verdadeiras:

~~~text
x + w > L       x < R
y + h > T       y < B
~~~

O Assembly verifica o inverso: qualquer separação basta para sair cedo com `CLC`. Se nenhuma das quatro comparações separar os objetos, executa `STC`. Por exemplo, um tiro que começa em 100 e tem largura 4 ocupa os pixels 100 a 103. Um alvo que começa em 104 está apenas encostado no limite aritmético; começar em 103 produz uma coluna comum. `CMP` faz internamente uma subtração para atualizar flags sem alterar os operandos. `JLE` e `JGE` avaliam a ordem com sinal; `JC` e `JNC`, usados pelo chamador depois de `STC` ou `CLC`, leem o resultado lógico da rotina.

**`VERIFICA_TIRO_CIMA_ALIENS`** usa internamente o registro `TIRO_CIMA` e percorre apenas naves ativas. Para cada uma, monta o retângulo de 14 × 14. O primeiro acerto consome o tiro, libera o slot da nave e soma `SCORE_ALIEN=100`. Uma nave destruída deixa de se mover e disparar. Um projétil que ela já lançou continua com o próprio estado de atividade.

**`VERIFICA_TIRO_ROCHAS`** testa o tiro frontal contra os retângulos de 12 × 10 das rochas ativas. Todo acerto consome o projétil. Depois separa o tipo dos demais bits com `AND 03h`:

| Tipo interno | Rocha do enunciado | Efeito |
|---:|---|---|
| 0 | 1 | Permanece no slot mesmo atingida. |
| 1 ou 2 | 2 ou 3 | Libera o slot e soma 50 pontos. |
| 3 | 4 | O primeiro acerto liga `FLAG_ATINGIDA=20h`. O segundo consecutivo destrói a rocha e soma 50. |

**`LIMPA_ACERTOS_ROCHAS`** percorre os slots de trás para frente e aplica uma máscara que zera só o bit `20h`. Os bits do tipo e da pontuação sobrevivem. No acerto, o código guarda o byte da rocha atingida, limpa as marcas e restaura o byte daquela rocha. Assim, o primeiro impacto na mesma rocha continua valendo para o segundo, mas acertar outra interrompe a sequência. Um tiro frontal que esgota o alcance sem acertar também a interrompe. Repare na escolha de geometria: o tiro usa o retângulo da rocha; o choque entre jipe e rocha usa pixels opacos.

**`ATIRA_ALIENS`** exige nave ativa, inteiramente na tela e com o registro de tiro correspondente livre. A condição horizontal é `X≥0` e `X+14≤320`. O tiro branco de 2 × 4 nasce em `X_nave+(14−2)/2`, portanto seis pixels depois da borda esquerda. Seu topo fica em `Y_nave+14+1`, deixando uma linha de intervalo sob a nave.

**`ATUALIZA_TIROS_ALIENS`** percorre os registros ativos, soma `VEL_TIRO_ALIEN=2` à coordenada Y e testa primeiro o retângulo atual do jipe, cujo topo é `JIPE_Y−JIPE_ALT`. No impacto, desativa o tiro e grava `ALIEN_HIT_FLAG=1`. Caso contrário, calcula o último pixel do tiro, `Y+altura−1`. Se chegar a `Y_SUPERFICIE=193`, encerra o voo; se ainda estiver acima, redesenha. A rotina também devolve o acerto em `CF`. O laço principal consulta a cópia em memória mais tarde porque chamadas intermediárias podem modificar as flags do processador.

### Converter pontos em texto

**`SOMAR_SCORE`** recebe em `AX` os pontos do evento e guarda o incremento em `SI`. O placar persistente é uma string de quatro dígitos. Para lê-la, repete `acumulado = acumulado × 10 + (caractere − '0')`. Soma os pontos, limita o resultado a 9999 e divide repetidamente por 10. Cada resto fornece um dígito a gravar da direita para a esquerda. Por exemplo, `"0090"` mais 50 resulta em 140 e volta à memória como `"0140"`. A tela só será atualizada quando o status for composto.

## 9. Relógio, vidas e saída da partida

**`CONTAGEM_TEMPO`** consulta `INT 1Ah` com `AH=00h`. A BIOS devolve os ticks desde a meia-noite em `CX:DX`, e `AL` informa a passagem de dia conforme o serviço. O jogo guarda somente a word baixa anterior em `TEMPO_DECORRIDO` e subtrai esse valor do `DX` atual. A diferença de dois contadores de 16 bits funciona inclusive ao passar de `FFFFh` para zero entre consultas próximas. A virada diária da BIOS tem um ajuste separado: o fonte soma `00B0h`, a word baixa do período diário `0018:00B0h`, quando a BIOS indica virada.

O relógio da BIOS avança aproximadamente 18,2 ticks por segundo. Descontar um segundo a cada 18 ticks descartaria a parte fracionária. Aqui cada tick acrescenta 1000 unidades a `TEMPO_FRACAO`. Ao alcançar `FRACAO_SEGUNDO=18207`, o código subtrai esse limiar e desconta um segundo. Por exemplo, 19 ticks partindo de zero somam 19.000; o jogo desconta um segundo e guarda 793 para a próxima atualização. Pode processar vários ticks entre dois quadros. `FORMATA_TEMPO` atualiza os caracteres apenas quando o contador de segundos muda. `AL=1` indica essa mudança ao chamador; `AL=0` permite continuar a partida sem testar um novo resultado de contagem.

**`EXIBE_STATUS`** chama **`DESENHA_CORACOES`** e **`DESENHA_SCORE`**, depois desenha o relógio e o texto do tempo. Para três vidas, o índice da tabela de ponteiros de corações é `(3−1)×2=4` bytes. `DESENHA_CORACOES` lê o endereço da variante e desenha seu quadro de 18 × 11. `DESENHA_SCORE` preenche o campo e desenha `"SCORE "` seguido dos quatro dígitos. O relógio de 7 × 8 usa a rotina de paleta. O texto do tempo usa a fonte de glifos.

**`DEC_CORACAO`** executa `DEC VIDAS`. Se o resultado for zero, retorna com `STC`; se ainda houver vidas, retorna com `CLC`. Em `colidiu`, `JNC reinicia_jipe` segue para o reaparecimento. O jipe volta a X=0, altura zero, fase de solo e `SALTO_VX=0`. A pausa usa `PAUSA_COLISAO_Q=40` retraços; ao terminar, a referência de ticks é renovada. As tabelas de naves, projéteis e obstáculos conservam o estado. Com a última vida consumida, com tempo esgotado ou com Esc, `INICIA_JOGO` restaura `ES=A000h` e retorna.

**`GAME_OVER`** limpa a VGA, centraliza horizontalmente a arte pela expressão `(320−32×LARGURA_GAMEOVER)/2` e desenha as duas palavras, a instrução e o score final. Aqui a leitura `INT 16h/AH=00h` é bloqueante por intenção: a próxima tela só começa depois de uma tecla. De volta ao menu, escolher Sair leva a `fim_programa`. O jogo solicita a repetição padrão do teclado com `INT 16h/AX=0300h`, seleciona modo texto `03h` por `INT 10h` e termina com `INT 21h`, `AH=4Ch`, `AL=0`. O comentário em `start` que menciona restaurar um vetor ficou desatualizado em relação às instruções de `fim_programa`.

## 10. Perguntas de defesa oral, com respostas

### 1. Por que a execução começa em start, e qual é a função de DS e ES logo na entrada?

**Resposta.** O montador e o ligador usam `end start` para definir a entrada do executável. As declarações `PROC` colocam rotinas em endereços que o programa pode chamar. Em `start`, `DS` recebe o segmento dos dados e `ES` recebe A000h para endereçar a VGA. Só depois são chamados os serviços que ativam o modo gráfico e configuram a repetição de teclado. Ao iniciar uma partida, o programa pode trocar `ES` pelo segmento do quadro em RAM e continuar consultando posições e paletas por `DS`. Isso separa a origem dos dados do destino dos desenhos.

### 2. Como pintar o pixel (100,10) tanto no quadro em RAM quanto na tela? Por que mudar apenas DI seria insuficiente?

**Resposta.** A posição relativa nas duas imagens é `10×320+100=3300=0CE4h`. Carregamos esse valor em `DI` e a cor de um byte em `AL`. `STOSB` escreve em `ES:DI`. Com `ES` apontando para `PIXELS_QUADRO`, muda o quadro em construção; com `ES=A000h`, muda o vídeo. `DI` seleciona um deslocamento de 16 bits dentro do segmento escolhido. A separação permite compor os objetos e depois levar a imagem pronta à VGA com uma cópia sequencial.

### 3. O jogador pressiona direita, cima e espaço. Como o programa consegue andar, saltar e atirar no mesmo quadro? E se soltar a seta no ar?

**Resposta.** `AH=01h` verifica se há evento e `AH=00h` consome um. A rotina repete o par até esvaziar o buffer. A seta lateral registra +2 em `JIPE_VEL` e `SALTO_VX`, a seta para cima inicia a fase de subida se o jipe estiver no chão e espaço tenta disparar os dois canhões. Depois dos eventos, uma única chamada a `MOVER_JIPE` atualiza X e a altura. No ar, o movimento recupera `SALTO_VX` mesmo sem eventos novos. Soltar a seta não gera nessa interface um comando de parada: a direção se mantém até outra seta lateral, a aterrissagem ou o reaparecimento. A repetição rápida configurada no início ajuda no chão, onde é preciso receber novos eventos para dar novos passos.

### 4. Se a origem do panorama for 317, como a rolagem evita uma emenda errada na memória? Qual é o papel de CF?

**Resposta.** Em cada linha copiam-se as colunas 317–319 e depois 0–316, preenchendo exatamente 320 pixels do destino. O primeiro trecho tem três bytes. `SHR CX,1` deixa uma word em `CX` e a sobra em `CF`. `REP MOVSW` copia dois bytes e zera o contador sem alterar o carry; `ADC CX,0` recupera a sobra e `REP MOVSB` copia o terceiro byte. Os ajustes de `SI` fazem a origem voltar ao começo da mesma linha antes da segunda fatia. O destino avança continuamente. A continuidade visual também depende de a arte nas extremidades combinar.

### 5. Por que a primeira nave de um grupo de três não pode ser sorteada em qualquer X entre 320 e 466?

**Resposta.** A última origem permitida é 466 para que os 14 pixels de largura ainda caibam na faixa de formação de meia tela. Depois da primeira nave faltam duas. Cada uma exige 14 pixels da anterior e 30 livres, totalizando 44 pixels entre origens. O máximo da primeira é `466−2×44=378`. Se for sorteada exatamente em 378, as próximas ainda cabem em 422 e 466. Reservar a distância antes do sorteio evita repetir tentativas aleatórias até encontrar uma combinação possível. O teste de atividade dos slots impede a criação desse grupo enquanto houver nave viva do anterior.

### 6. Por que uma rocha pode ser atingida por um tiro que passou por um canto transparente, mas não destruir o jipe pelo mesmo canto?

**Resposta.** São testes diferentes. O tiro usa o retângulo de 12 × 10 da rocha e compara limites exclusivos. Qualquer pixel comum aos retângulos basta para o acerto, inclusive numa posição transparente da arte. Para o jipe, o teste retangular horizontal só seleciona candidatos; `COLISAO_BITMAP_ROCHA` calcula a área comum e lê os dois bitmaps. Só há impacto se ambos tiverem um caractere diferente de `'0'` na mesma posição. Isso permite que o contorno irregular e a altura visual da rocha façam diferença durante o salto.

### 7. Como um único byte consegue guardar o tipo de uma rocha, o primeiro tiro recebido e a informação de que ela foi sobrevoada?

**Resposta.** Os dois bits inferiores guardam o tipo e outros bits independentes guardam eventos. Uma rocha do tipo interno 3, já atingida uma vez e sobrevoada, pode ter `03h OR 20h OR 04h = 27h`. `AND 03h` em uma cópia recupera 3 para selecionar o bitmap. `TEST` verifica uma marca sem modificar o byte; `OR` liga uma marca sem apagar as demais. Para interromper a sequência de tiros, `LIMPA_ACERTOS_ROCHAS` limpa somente `20h`: `27h` passa a `07h`. O tipo e o sobrevoo continuam disponíveis para decisões posteriores.

### 8. O que acontece com o salto e o relógio se o emulador passar a desenhar menos quadros por segundo?

**Resposta.** O salto avança uma etapa de movimento por chamada. São cinco passos de 3 pixels na subida, um topo cuja duração é medida pelos 5 pixels avançados pelo cenário e passos de 3 na descida. Com menos quadros por segundo, o salto tende a durar mais tempo real. Já `CONTAGEM_TEMPO` mede a diferença entre leituras do relógio da BIOS e processa todos os ticks decorridos. Pode descontar mais tempo numa única atualização. O mostrador muda quando se compõe o quadro seguinte, mas o cálculo não pressupõe um número fixo de quadros por segundo.

### 9. Como um tiro alienígena continua em voo depois da destruição da nave que o lançou?

**Resposta.** A nave e o projétil ocupam estruturas distintas. A atividade da nave fica em `ALIENS_ATIVO`; o tiro tem seu próprio `T_ATIVO` em `TIROS_ALIENS`. Destruir a nave desativa o slot de nave e o tiro superior do jipe que a atingiu. `ATUALIZA_TIROS_ALIENS` percorre os registros de projéteis independentemente de a nave estar viva. O tiro existente continua descendo até atingir o jipe ou a superfície. O slot de nave determina se é possível lançar; o slot de projétil determina se já existe algo em voo.

### 10. Uma colisão acontece quando resta uma vida. Qual é o caminho até o DOS, e o que muda se ainda houver duas vidas?

**Resposta.** Com uma vida, `DEC_CORACAO` reduz `VIDAS` a zero e devolve `CF=1`. O laço encerra a partida, devolve o destino gráfico à VGA e retorna ao chamador. `GAME_OVER` exibe o score e aguarda uma tecla; o jogador volta ao menu. Só a escolha Sair encaminha o fluxo para restaurar a repetição padrão do teclado, selecionar modo texto e terminar pelo DOS. Com duas vidas antes do impacto, a rotina deixa uma e devolve `CF=0`. O mesmo chamador segue para `reinicia_jipe`, coloca o jipe na coluna zero, aguarda a pausa e retoma o quadro com as tabelas da fase preservadas.
