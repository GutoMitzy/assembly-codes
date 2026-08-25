                        .model small
.stack 100H
.data
    TAM EQU 5  
    ORIGEM dw TAM dup(?)   
    DESTINO dw TAM dup(?)   
    
    CR EQU 0DH  
    LF EQU 0AH
.code 
   
; Escreve na tela um caractere em DL
ESC_CHAR proc 
    push AX
    mov AH, 2
    int 21H   
    pop AX
    ret
    
endp
 

ESC_UINT16 proc   
    push AX
    push BX
    push CX
    push DX
    
    xor CX, CX    ; contador de digitos
    mov BX, 10    ; divisor
    
laco_div: 
    xor DX, DX    ; zerar pela divisao
    div BX        ; divisao para separar o digito em DX
    push DX       ; empilhar o digito
    inc CX        ; incrementa o contador de dígitos  
    test AX, AX
    jnz laco_div    
    
laco_escrita:
    pop DX        ; desempilhar o digito
    add DL, '0'   ; converter o dígito para ASCII
    call ESC_CHAR
    dec CX
    jnz laco_escrita  ; decrementa o contador de digitos
    
    pop DX
    pop CX
    pop BX
    pop AX
    
    ret  
    
endp

;Retorno do caractere em AX
READ_CHAR proc
    mov AH, 7
    int 21H
    ret 
endp

LER_UINT16 proc  
     push BX
     push CX
     push DX  
     
     mov BX, 10
     xor AX, AX
     xor CX, CX  
     
laco_principal:
     push AX
        
laco_ler:
     call READ_CHAR
     cmp AL, CR
     je enter
     
     cmp AL, '0'
     jb laco_ler 
     cmp AL, '9'
     ja laco_ler
     
     mov DL, AL       ; escrita do caractere
     call ESC_CHAR 
                   
     sub DL, '0' 
     mov CL, DL
                   
     pop AX 
     mul BX 
     add AX, CX
     
     jmp laco_principal
     
enter:
     pop AX           ; restaurando o acumulador
     mov DL, CR       ; um enter apos a leitura
     call ESC_CHAR    
     mov DL, LF
     call ESC_CHAR 
     
     pop DX
     pop CX
     pop BX
     
     ret  
endp   

;BX guarda origem
;SI guarda destino   
;CX o numero de elementos
COPIA_VETOR16 proc
    push AX
    push CX   
    push BX
    push SI
     
copia:   
    mov AX, [BX] 
    add BX, 2
    mov [SI], AX
    add SI, 2
    
    loop copia      ; dec CX
    
    pop SI
    pop BX
    pop CX
    pop AX
    
    ret
endp    



start:
  mov AX, @DATA
  mov DS, AX   
         
  ;call LER_UINT16   
  ;call ESC_UINT16
  
; Leitura do vetor
  mov BX, offset ORIGEM
  mov CX, TAM  
  
LEITURA_VETOR:
  call LER_UINT16
  mov [BX], AX  
  add BX, 2 
  loop LEITURA_VETOR
  
   
; Escrita do vetor   
  mov BX, offset ORIGEM  
  mov SI, offset DESTINO
  mov CX, TAM     
  
; Copia vetores  
  call COPIA_VETOR16
            
ESCRITA_VETOR:
  mov AX, [SI]
  call ESC_UINT16 
  add SI, 2 
  mov DL, CR
  call ESC_CHAR
  mov DL, LF
  call ESC_CHAR
  loop ESCRITA_VETOR
  
  
; Termina o programa
  mov AH, 4CH
  int 21H
                      
end start