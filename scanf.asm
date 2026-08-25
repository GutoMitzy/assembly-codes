.model small
.stack 100H
.data  
  CR EQU 0DH  
  LF EQU 0AH
 
.code 

;Retorno do caractere em AL
READ_CHAR proc
    mov AH, 7
    int 21H
    ret 
endp

LER_UINT16 proc 
     
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
     pop AX  
     mov DL, LF
     call ESC_CHAR    
     mov DL,CR
     call ESC_CHAR
     ret  
endp

start:
  mov AX, @DATA
  mov DS, AX   
             
  call LER_UINT16
                    
  mov AH, 4CH
  int 21H 
  
end start