.model small
.stack 100H
.data
    TAM EQU 5  
    VETOR8 db TAM dup(?)       
    
    CR EQU 0DH  
    LF EQU 0AH
.code 
   
; Escreve na tela um caractere em DL
ESC_CHAR proc
    mov AH, 2
    int 21H
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
    div BX        ; AX = quociente, DX = resto , 1passo
    push DX       ; empilhar o digito
    inc CX        ; incrementa o contador de dígitos  
    test AX, AX
    jnz laco_div    
    
laco_escrita:
    pop DX        ; desempilhar o digito
    add DL, '0'   ; converter o dígito para ASCII
    call ESC_CHAR
    dec CX
    jnz laco_escrita  ; decrementa o contador de dígitos
    
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

start:
  mov AX, @DATA
  mov DS, AX   
         
  ;call LER_UINT16   
  ;call ESC_UINT16
  
  mov BX, offset VETOR8
  mov CX, TAM  
  
LEITURA_VETOR:
  call LER_UINT16
  mov [BX], AL
  inc BX
  loop LEITURA_VETOR
   
  ; Escrita do vetor     
  mov SI, offset VETOR8
  mov CX, TAM
  xor AX, AX
            
ESCRITA_VETOR:
  mov AL, [SI]
  call ESC_UINT16 
  inc SI
  loop ESCRITA_VETOR
  
  
; Termina o programa
  mov AH, 4CH
  int 21H
                      
end start