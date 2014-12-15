Unit MultiChn;
{$G+}

Interface


Type
  TChanRec = Record
    PSound, PCur : Pointer;
    Length, LCur : LongInt;
    Volume : Byte;
    Rep : Boolean;
    Owner : Word;
  End;


Const
  ChanCnt = 8;
  MixBufSize = 1024;


Var
  Channels : Array [0..ChanCnt-1] of TChanRec;
  MixBuf : Array [0..MixBufSize-1] of Byte;


Function AddChannel (PSound : Pointer; Length : LongInt;
                     Volume : Byte; Rep : Boolean; Owner : Word) : Word;

Procedure MixChannels;

Procedure SlideChannels;


Implementation


Procedure IncPtr (Var P : Pointer; Offset : LongInt);
Type
  Long = Record
    Lo, Hi : Word
  End;
Var
  NewOffset : LongInt;
  NewSelector : Word;
Begin
  NewOffset := Long(P).Lo;
  Inc (NewOffset, Offset);
  Long(P).Lo := NewOffset;
  If NewOffset >= $10000 then Begin
    NewSelector := Long(P).Hi;
    Inc (NewSelector, Long(NewOffset).Hi*SelectorInc);
    Long(P).Hi := NewSelector
  End
End;

Function AddChannel (PSound : Pointer; Length : LongInt;
                     Volume : Byte; Rep : Boolean; Owner : Word) : Word;
Var I : Byte;
Begin
  I := 0;
  While I < ChanCnt do Begin
    If Channels[I].PSound = Nil then Begin
      Channels[I].PSound := PSound;
      Channels[I].Length := Length;
      Channels[I].Volume := Volume;
      Channels[I].PCur := PSound;
      Channels[I].LCur := Length;
      Channels[I].Rep := Rep;
      Channels[I].Owner := Owner;
      AddChannel := I;
      Exit
    End;
    Inc (I)
  End;
  AddChannel := $FFFF
End;

Procedure MixChannel (Channel : Byte); Assembler;
Asm
  LEA   SI, Channels
  Mov   AL, Channel
  CBW
  Mov   BX, 20                                  { SizeOf (TChanRec) = 18 }
  Mul   BX
  Add   SI, AX                                  { DS:[SI] = ^Channels[I] }
  LES   DI, TChanRec(DS:[SI]).PCur              { ES:[DI] = Channels[I].PCur }
  DB    66h
  Mov   CX, Word(TChanRec(DS:[SI]).LCur)        { ECX = Channels[I].LCur }
  DB    66h
  Cmp   CX, MixBufSize
  DW    0                                       { Cmp ECX, MixBufSize }
  JC    @@1
  Mov   CX, MixBufSize
@@1:                                            { CX = actual data size }
  Mov   BL, TChanRec(DS:[SI]).Volume
  Xor   BH, BH
  ShL   BX, 2                                   { BX = volume * 4 }
  LEA   SI, MixBuf                              { DS:[SI] = ^MixBuf }
@@cycle:
  Mov   AL, ES:[DI]
  Xor   AH, AH
  Sub   AX, 80h
  IMul  BX
  SAR   AX, 7
  Mov   DL, DS:[SI]
  Xor   DH, DH
  Add   AX, DX
  JNS   @@2
  Xor   AL, AL
  Jmp   @@3
@@2:
  Cmp   AH, DH
  JE    @@3
  Mov   AL, 0FFh
@@3:
  Mov   DS:[SI], AL
  Inc   SI
  Inc   DI
  Loop  @@cycle
End;

Procedure MixChannels;
Var I : Byte;
Begin
  FillChar (MixBuf, MixBufSize, $80);
  For I := 0 to ChanCnt-1 do
    If Channels[I].PSound <> Nil then
      MixChannel (I)
End;

Procedure SlideChannels;
Var I : Byte;
Begin
  For I := 0 to ChanCnt-1 do with Channels[I] do Begin
    Dec (LCur, MixBufSize);
    If Lcur <= 0 then Begin
      If Rep then Begin
        PCur := PSound;
        LCur := Length
      End
      Else PSound := Nil
    End
    Else
      IncPtr (Channels[I].PCur, MixBufSize)
  End
End;

Begin
  FillChar (Channels, SizeOf(Channels), 0)
End.
