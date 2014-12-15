.386

LOCALS  @@

CODE    SEGMENT PUBLIC USE16
ASSUME  CS:CODE, DS:CODE

EXTRN   Screen1 : DWORD
EXTRN   Screen2 : DWORD
EXTRN   SegA000 : WORD

PUBLIC  OUTNEW

OUTNEW  PROC NEAR
        Push     DS
        Push     BP
        Mov      FS, SegA000    ;SCREEN SEGMENT
        CLD
        Mov      CX, 16000      ;16000 doublewords = all screen
        LES      DI, Screen1    ;POINTER TO THE PREVIOUS FRAME
        LDS      SI, Screen2    ;POINTER TO THE CURRENT FRAME
        Mov      BP, ES         ;PREVIOUS FRAME SEGMENT
@@CYCLE:
        RepE     CMPSD          ;COMPARING FRAMES...
        JE       @@END          ;WE DON'T NEED TO READRAW ANYTHING
        Inc      CX             ;correct CX
        Sub      SI, 4          ;correct SI
        Mov      DI, SI         ;correct DI
        Mov      BX, SI         ;save ofs
        Mov      AX, CX
        RepNE    CMPSD          ;COMPARING FRAMES...
        JNE      @@ALL          ;REDRAW ALL!
        Inc      CX             ;correct CX
        Sub      SI, 4          ;correct SI
        Mov      DX, CX         ;save size of data that not compared yet
        Mov      CX, SI
        Sub      CX, BX         ;CX=size of different data
        Mov      SI, BX
        Mov      DI, SI
        Mov      AX, FS
        Mov      ES, AX         ;ES:DI = ^Screen
        Shr      CX, 2          ;doublewords!
        Rep      MOVSD          ;PART REDRAWN
        Mov      ES, BP
        Mov      CX, DX         ;restore size of data that not compared yet
        JCXZ     @@END
        Jmp      @@CYCLE        ;CYCLING
@@ALL:
        Mov      SI, BX
        Mov      DI, SI
        Mov      CX, AX
        Mov      AX, FS
        Mov      ES, AX
        Rep      MOVSD          ;ALL REDRAWN
@@END:
        Pop      BP
        Pop      DS
        Xchg     EAX, Screen1   ;\
        Xchg     EAX, Screen2   ; } XCHANGE VIRTUAL PAGES
        Xchg     EAX, Screen1   ;/
        Ret
OUTNEW  ENDP

CODE    ENDS

END
