.386

LOCALS  @@

CODE    SEGMENT PUBLIC USE16
ASSUME  CS:CODE, DS:CODE

;COMMON AND SLIVER RENDERING EXTERNALS
EXTRN   Render_VSeg:WORD
EXTRN   Render_Transparent:BYTE
EXTRN   Render_Screen_X:WORD
EXTRN   Render_Texture:DWORD
EXTRN   Render_Texture_X:WORD
EXTRN   Render_Sliver_H:WORD
EXTRN   Render_Shade:BYTE

;FLOOR RENDERING EXTERNALS
EXTRN   Render_Screen_Y:WORD
EXTRN   Render_Floor_Start_X:DWORD
EXTRN   Render_Floor_Start_Y:DWORD
EXTRN   Render_Floor_DX:DWORD
EXTRN   Render_Floor_DY:DWORD

;FLOOR AND CEILING RENDERING EXTERNALS
EXTRN   Render_Start_X:DWORD
EXTRN   Render_Start_Y:DWORD
EXTRN   Render_DX:DWORD
EXTRN   Render_DY:DWORD
EXTRN   Render_Y:WORD
EXTRN   Render_Map_Ofs:WORD
EXTRN   Textures_Table_Ofs:WORD

EXTRN   Textures_Ptrs:DWORD

PUBLIC  Render_Sliver
PUBLIC  Render_Floor
PUBLIC  Render_Both
PUBLIC  Render_Both2
PUBLIC  Render_SliverS
PUBLIC  Render_Both2S

Render_Sliver PROC FAR
  Xor   EBX, EBX
  Mov   BX, Render_Sliver_H
  Or    BX, BX
  JZ    @@end
  Mov   EAX, 400000h                    ; 64*2^16
  CDQ
  Div   EBX
  Mov   ESI, EAX                        ; ESI = EAX = K
  Cmp   BX, 200
  JG    @@run_out
  Mov   CX, BX                          ; CX = pixel count = H
  Xor   EDX, EDX                        ; EDX = Yt = 0
  ShR   BX, 1
  Sub   BX, 100
  Neg   BX                              ; BX = Y = 100 - H/2
  Jmp   @@at_screen                     ; Y >= 0
@@run_out:
  Mov   CX, 200                         ; CX = pixel count = 200
  ShR   BX, 1
  Sub   BX, 100
  Mul   EBX
  Mov	EDX, EAX                        ; EDX = Yt = | Y*K |
  Xor   BX, BX                          ; BX = Y = 0
@@at_screen:
  Mov   ES, Render_VSeg
  ShL   BX, 6
  Mov   DI, BX
  ShL   BX, 2
  Add   DI, BX
  Add   DI, Render_Screen_X             ; ES:DI = ^screen[Y,X]
  Mov   EBX, EDX                        ; EBX = Yt !
  Mov   EDX, ESI                        ; EDX = K !
  LFS   SI, Render_Texture              ; FS:SI = ^texture
  Add   SI, 4                           ; Skip texture sizes
  Add   SI, Render_Texture_X            ; FS:SI = ^texture[Yt,Xt]
  Push  BP
@@cycle:
  Mov   EBP, EBX
  ShR   EBP, 10
  And   BP, 0FFC0h
  Mov   AL, FS:[SI+BP]
  Cmp   AL, Render_Transparent
  JE    @@skip
  Mov   ES:[DI], AL
@@skip:
  Add   EBX, EDX
  Add   DI, 320
  Loop  @@cycle
  Pop   BP
@@end:
  Ret
Render_Sliver ENDP

Render_Floor  PROC FAR
  Push  BP
  Mov   ES, Render_VSeg
  Xor   DI, DI
  Mov   BX, Render_Screen_Y
  ShL   BX, 6
  Mov   DI, BX
  ShL   BX, 2
  Add   DI, BX

  LFS   SI, Render_Texture
  Add   SI, 4

  Mov   EBX, Render_Floor_Start_X
  Mov   EDX, Render_Floor_Start_Y
  Mov   CX, 320
@@cycle:
  Mov   EBP, EDX
  Shr   EBP, 6
  And   BP, 0FC0h
  Mov   EAX, EBX
  Shr   EAX, 12
  And   AX, 3Fh
  Add   BP, AX

  Mov   AL, FS:[SI+BP]
  Mov   ES:[DI], AL

  Inc   DI
  Add   EBX, Render_Floor_DX
  Add   EDX, Render_Floor_DY
  Loop  @@cycle
  Pop   BP
  Ret
Render_Floor  ENDP

Render_Both PROC FAR
  Push  BP
  Mov   ES, Render_VSeg
  Mov   BX, Render_Y
  ShL   BX, 6
  Mov   DI, BX
  ShL   BX, 2
  Add   DI, BX                  ; ES:[DI] -> ^Screen

  Mov   EBX, Render_Start_X
  Mov   EDX, Render_Start_Y
  Xor   CX, CX
@@cycle:
  Mov   EBP, EDX
  Shr   EBP, 6
  And   BP, 0FC0h
  Mov   EAX, EBX
  Shr   EAX, 12
  And   AX, 3Fh
  Add   BP, AX                  ; BP -> Offset at texture for current pixel

  Push  BP
  Mov   EBP, EDX
  Shr   EBP, 12
  And   BP, 0FFC0h              ; BP = Cell_Y*64
  Mov   EAX, EBX
  Shr   EAX, 18                 ; AX = Cell_X
  Add   BP, AX                  ; BP = Offset at Floor/Ceil table for pixel
  Add   BP, Render_Map_Ofs      ; BP = Offset in memory
  Push  BP
  Mov   AL, DS:[BP]
  Dec   AL
  Xor   AH, AH
  Shl   AX, 2
  Add   AX, Textures_Table_Ofs
  Mov   BP, AX
  LFS   SI, DS:[BP]
  Add   SI, 4
  Pop   BP
  Pop   BP
  Mov   AL, FS:[SI+BP]
  Mov   ES:[DI], AL

  Sub   SP, 4
  Pop   BP
  Mov   AL, DS:[BP+64*64]
  Or    AL, AL
  JNZ   @@no_sky
  Pop   BP
  Jmp   @@sky
@@no_sky:
  Dec   AL
  Xor   AH, AH
  Shl   AX, 2
  Add   AX, Textures_Table_Ofs
  Mov   BP, AX
  LFS   SI, DS:[BP]
  Add   SI, 4
  Pop   BP
  Mov   AL, FS:[SI+BP]
  Push  DI
  Sub   DI, 199*320
  Neg   DI
  Add   DI, CX
  Add   DI, CX
  Mov   ES:[DI], AL
  Pop   DI
@@sky:
  Inc   DI
  Add   EBX, Render_DX
  Add   EDX, Render_DY
  Inc   CX
  Cmp   CX, 320
  JNE   @@cycle
  Pop   BP
  Ret
Render_Both ENDP

Render_Both2 PROC FAR
  Push  BP
  Mov   ES, Render_VSeg
  Mov   BX, Render_Y
  ShL   BX, 6
  Mov   DI, BX
  ShL   BX, 2
  Add   DI, BX                  ; ES:[DI] -> ^Screen

  Mov   EBX, Render_Start_X
  Mov   EDX, Render_Start_Y
  Xor   CX, CX
@@cycle:
  Push  CX

  Mov   EBP, EDX
  Shr   EBP, 6
  And   BP, 0FC0h
  Mov   EAX, EBX
  Shr   EAX, 12
  And   AX, 3Fh
  Add   BP, AX
  Mov   CX, BP                  ; CX -> Offset at texture for current pixel

  Mov   EBP, EDX
  Shr   EBP, 9
;  And   BP, 0FE00h              ; BP = Cell_Y*64*4
  And   BP, 7E00h               ; Truncate Cell_Y maximum to 63
  Mov   EAX, EBX
  Shr   EAX, 15                 ; AX = Cell_X*4
;  And   AX, 0FFF8h
  And   AX, 1F8h                ; Truncate Cell_X maximum to 63
  Add   BP, AX                  ; BP = Offset at Floor/Ceil ptr-table

  LGS   SI, DS:[Textures_Ptrs]
  Add   BP, SI
  LFS   SI, GS:[BP]
  Add   SI, CX
  Mov   AL, FS:[SI+4]
  Mov   ES:[DI], AL

  LFS   SI, GS:[BP+4]
  Mov   AX, FS
  Or    AX, AX
  JNE   @@sky
  Pop   CX
  Jmp   @@no_sky
@@sky:
  Add   SI, CX
  Pop   CX
  Mov   BP, DI
  Sub   DI, 199*320
  Neg   DI
  Add   DI, CX
  Add   DI, CX
  Mov   AL, FS:[SI+4]
  Cmp   AL, Render_Transparent
  JE    @@nosky2
  Mov   ES:[DI], AL
@@nosky2:
  Mov   DI, BP
@@no_sky:
  Inc   DI
  Add   EBX, Render_DX
  Add   EDX, Render_DY
  Inc   CX
  Cmp   CX, 320
  JNE   @@cycle
  Pop   BP
  Ret
Render_Both2 ENDP

Render_SliverS PROC FAR
  Xor   EBX, EBX
  Mov   BX, Render_Sliver_H
  Or    BX, BX
  JZ    @@end
  Mov   EAX, 400000h                    ; 64*2^16
  CDQ
  Div   EBX
  Mov   ESI, EAX                        ; ESI = EAX = K
  Cmp   BX, 200
  JG    @@run_out
  Mov   CX, BX                          ; CX = pixel count = H
  Xor   EDX, EDX                        ; EDX = Yt = 0
  ShR   BX, 1
  Sub   BX, 100
  Neg   BX                              ; BX = Y = 100 - H/2
  Jmp   @@at_screen                     ; Y >= 0
@@run_out:
  Mov   CX, 200                         ; CX = pixel count = 200
  ShR   BX, 1
  Sub   BX, 100
  Mul   EBX
  Mov	EDX, EAX                        ; EDX = Yt = | Y*K |
  Xor   BX, BX                          ; BX = Y = 0
@@at_screen:
  Mov   ES, Render_VSeg
  ShL   BX, 6
  Mov   DI, BX
  ShL   BX, 2
  Add   DI, BX
  Add   DI, Render_Screen_X             ; ES:DI = ^screen[Y,X]
  Mov   EBX, EDX                        ; EBX = Yt !
  Mov   EDX, ESI                        ; EDX = K !
  LFS   SI, Render_Texture              ; FS:SI = ^texture
  Add   SI, 4                           ; Skip texture sizes
  Add   SI, Render_Texture_X            ; FS:SI = ^texture[Yt,Xt]
  Push  BP
@@cycle:
  Mov   EBP, EBX
  ShR   EBP, 10
  And   BP, 0FFC0h
  Mov   AL, FS:[SI+BP]
  Cmp   AL, Render_Transparent
  JE    @@skip
  Mov   AH, AL
  And   AH, 0Fh
  Add   AH, Render_Shade
  Cmp   AH, 16
  JC    @@shading
  Xor   AL, AL                          ;Black
  Jmp   @@put
@@shading:
  And   AL, 0F0h
  Or    AL, AH
@@put:
  Mov   ES:[DI], AL
@@skip:
  Add   EBX, EDX
  Add   DI, 320
  Loop  @@cycle
  Pop   BP
@@end:
  Ret
Render_SliverS ENDP

Render_Both2S PROC FAR
  Push  BP
  Mov   ES, Render_VSeg
  Mov   BX, Render_Y
  ShL   BX, 6
  Mov   DI, BX
  ShL   BX, 2
  Add   DI, BX                  ; ES:[DI] -> ^Screen

  Mov   EBX, Render_Start_X
  Mov   EDX, Render_Start_Y
  Xor   CX, CX
@@cycle:
  Push  CX

  Mov   EBP, EDX
  Shr   EBP, 6
  And   BP, 0FC0h
  Mov   EAX, EBX
  Shr   EAX, 12
  And   AX, 3Fh
  Add   BP, AX
  Mov   CX, BP                  ; CX -> Offset at texture for current pixel

  Mov   EBP, EDX
  Shr   EBP, 9
;  And   BP, 0FE00h              ; BP = Cell_Y*64*4
  And   BP, 7E00h               ; Truncate Cell_Y maximum to 63
  Mov   EAX, EBX
  Shr   EAX, 15                 ; AX = Cell_X*4
;  And   AX, 0FFF8h
  And   AX, 1F8h                ; Truncate Cell_X maximum to 63
  Add   BP, AX                  ; BP = Offset at Floor/Ceil ptr-table

  LGS   SI, DS:[Textures_Ptrs]
  Add   BP, SI
  LFS   SI, GS:[BP]
  Add   SI, CX
  Mov   AL, FS:[SI+4]

  Mov   AH, AL
  And   AH, 0Fh
  Add   AH, Render_Shade
  Cmp   AH, 16
  JC    @@fshading
  Xor   AL, AL                          ;Black
  Jmp   @@fput
@@fshading:
  And   AL, 0F0h
  Or    AL, AH
@@fput:
  Mov   ES:[DI], AL

  LFS   SI, GS:[BP+4]
  Mov   AX, FS
  Or    AX, AX
  JNE   @@sky
  Pop   CX
  Jmp   @@no_sky
@@sky:
  Add   SI, CX
  Pop   CX
  Mov   BP, DI
  Sub   DI, 199*320
  Neg   DI
  Add   DI, CX
  Add   DI, CX
  Mov   AL, FS:[SI+4]
  Cmp   AL, Render_Transparent
  JE    @@nosky2
  Mov   AH, AL
  And   AH, 0Fh
  Add   AH, Render_Shade
  Cmp   AH, 16
  JC    @@cshading
  Xor   AL, AL                          ;Black
  Jmp   @@cput
@@cshading:
  And   AL, 0F0h
  Or    AL, AH
@@cput:
  Mov   ES:[DI], AL
@@nosky2:
  Mov   DI, BP
@@no_sky:
  Inc   DI
  Add   EBX, Render_DX
  Add   EDX, Render_DY
  Inc   CX
  Cmp   CX, 320
  JNE   @@cycle
  Pop   BP
  Ret
Render_Both2S ENDP

CODE    ENDS

END
