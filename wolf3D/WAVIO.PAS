Unit WAVIO;                             { Compile/Target.../Protected :-) }

Interface

Type
  TRIFFChunk = Record
    rID : Array [0..3] of Char;         { 'RIFF' }
    rLen : LongInt;                     { Length of data }
  End;                                  { Data }
  TWAVEChunk = Record
    wfID : Array [0..7] of Char;        { 'WAVEfmt ' }
    fLen : LongInt;                     { Length of format chunk data 12/16 }
  End;
  TFmt12Chunk = Record
    FormatTag,                          { Samples format = 1 }
    Channels,                           { Mono/Stereo }
    SamplesPerSec,                      { Sample frequency }
    AvgBytesPerSec,                     { Bytes per sec }
    SampleSize,                         { 1-8bit Mono, 2-16bitM/8bitS, 4-16bit Stereo}
    BitsPerSample : Word                { 8 - 8 bit,  16 - 16 bit, etc }
  End;
  TFmt16Chunk = Record
    FormatTag,                          { Samples format = 1 }
    Channels        : Word;             { Mono/Stereo }
    SamplesPerSec,                      { Sample frequency }
    AvgBytesPerSec  : LongInt;          { Bytes per sec }
    SampleSize,                         { 1-8bit Mono, 2-16bitM/8bitS, 4-16bit Stereo}
    BitsPerSample : Word                { 8 - 8 bit,  16 - 16 bit, etc }
  End;
  TDataChunk = Record
    dID : Array [0..3] of Char;         { 'data' }
    dLen : LongInt                      { Length of audio data }
  End;                                  { Audio data }

Procedure LoadWAVas8bit (Name : String; Var P : Pointer; Var Size : LongInt;
                   Var Channels : Word; Var Frequency, BytesPerSec : LongInt;
                   Var BitsPerSample, Error : Word);
Procedure SaveWAVas8bit (Name : String; P : Pointer; Size : LongInt;
                   Channels : Word; Frequency : LongInt; Var Error : Word);
{    Error messages:    }
{ 0 Ok (no error)       }
{ 1 File not found      }
{ 2 Unknown file format }
{ 3 Not enough memory   }
{ 4 File i/o error      }

Implementation

Uses
  WinAPI;

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

Procedure Shrink16to8 (Var Buf32K); Assembler;
Asm
  Push  DS
  LDS   SI, Buf32K
  Mov   DI, SI
  Push  DS
  Pop   ES
  Mov   CX, 16384
  CLD
@cycle:
  LODSW
  Mov   AL, AH
  Sub   AL, 80h
  STOSB
  Loop  @cycle
  Pop   DS
End;

Procedure LoadWAVas8bit (Name : String; Var P : Pointer; Var Size : LongInt;
                   Var Channels : Word; Var Frequency, BytesPerSec : LongInt;
                   Var BitsPerSample, Error : Word);
Var
  RC : TRIFFChunk;
  WC : TWAVEChunk;
  DC : TDataChunk;
  F12C : TFmt12Chunk;
  F16C : TFmt16Chunk;
  F : File;
  PL : Pointer;
  FSize, Ofs, R : LongInt;
  PBuf : Pointer;
Label
  LUF, LIO, LIOF;
Begin
  {$I-}
  Assign (F, Name);
  Reset (F, 1);
  If IOResult <> 0 then Begin
    Error := 1;                                 { File not found }
    Exit
  End;
  BlockRead (F, RC, SizeOf(RC));
  If IOResult <> 0 then Begin
LIO:
    Close (F);
    Error := 4;
    Exit
  End;
  If RC.rID <> 'RIFF' then Goto LUF;
  BlockRead (F, WC, SizeOf(WC)); If WC.wfID <> 'WAVEfmt ' then Goto LUF;
  If IOResult <> 0 then Goto LIO;
  If WC.fLen = 12 then
    Begin
      BlockRead (F, F12C, SizeOf(F12C));
      If IOResult <> 0 then Goto LIO;
      If F12C.FormatTag <> 1 then Goto LUF;
      Channels := F12C.Channels;
      Frequency := F12C.SamplesPerSec;
      BytesPerSec := F12C.AvgBytesPerSec;
      BitsPerSample := F12C.BitsPerSample
    End
  Else If WC.fLen >= 16 then
    Begin
      BlockRead (F, F16C, SizeOf(F16C));
      If IOResult <> 0 then Goto LIO;
      If F16C.FormatTag <> 1 then Goto LUF;
      Channels := F16C.Channels;
      Frequency := F16C.SamplesPerSec;
      BytesPerSec := F16C.AvgBytesPerSec;
      BitsPerSample := F16C.BitsPerSample;
      Seek (F, FilePos(F)+WC.fLen-16);
      If IOResult <> 0 then Goto LIO;
    End
  Else
    Begin
LUF:
      Close (F);
      Error := 2;                               { Unknown file format }
      Exit
    End;
  Repeat
    BlockRead (F, DC, SizeOf(DC));
    If IOResult <> 0 then Goto LIO;
    If DC.dID <> 'data' then Begin
      Seek (F, FilePos(F)+DC.dLen);
      If IOResult <> 0 then Goto LIO
    End
    Else Break
  Until EOF(F);
  If DC.dID <> 'data' then Goto LUF;

  FSize := DC.dLen;
  Size := FSize;
  If BitsPerSample = 16 then Size := Size shr 1;
  P := GlobalAllocPtr (gmem_fixed, Size);
  If P = Nil then Begin
    Close (F);
    Error := 3;                                 { Not enough memory }
    Exit
  End;
  PL := P;
  Ofs := 0;
  R := 0;
  PBuf := GlobalAllocPtr (gmem_moveable, 32768);
  If PBuf = Nil then Begin
    GlobalFreePtr (P);
    Close (F);
    Error := 3;                                 { Not enough memory }
    Exit
  End;
  While Ofs < FSize do Begin
    If FSize-Ofs >= 32768 then Begin
      BlockRead (F, PBuf^, 32768, Word(R));
      If IOResult <> 0 then Begin
LIOF:
        GlobalFreePtr (P);
        GlobalFreePtr (PBuf);
        Goto LIO
      End
    End
    Else Begin
      BlockRead (F, PBuf^, FSize-Ofs, Word(R));
      If IOResult <> 0 then Goto LIOF
    End;
    Case BitsPerSample of
      16 : Begin Shrink16to8 (PBuf^); Move (PBuf^, PL^, R shr 1) End;
      Else Move (PBuf^, PL^, R);
    End;
    Inc (Ofs, R);
    If BitsPerSample = 16 then
      IncPtr (PL, R shr 1)
    Else
      IncPtr (PL, R);
  End;
  Close (F);
  If BitsPerSample = 16 then Begin
    BytesPerSec := BytesPerSec shr 1;
  End;
  GlobalFreePtr (PBuf);
  Error := 0                                    { No error }
{$I+}
End;

Procedure SaveWAVas8bit (Name : String; P : Pointer; Size : LongInt;
                   Channels : Word; Frequency : LongInt;
                   Var Error : Word);
Var
  RC : TRIFFChunk;
  WC : TWAVEChunk;
  DC : TDataChunk;
  F16C : TFmt16Chunk;
  F : File;
  Ofs, WS : LongInt;
Label LIO;
Begin
{$I-}
  Assign (F, Name);
  Rewrite (F, 1);
  If IOResult <> 0 then Begin
LIO:
    Close (F);
    Error := 4;
    Exit
  End;
  with RC do Begin
    rID := 'RIFF';
    rLen := SizeOf(TWaveChunk) + SizeOf(TFmt16Chunk) + SizeOf(TDataChunk) +
            Size;
  End;
  BlockWrite (F, RC, SizeOf(RC));
  If IOResult <> 0 then Goto LIO;
  with WC do Begin
    wfID := 'WAVEfmt ';
    fLen := 16;
  End;
  BlockWrite (F, WC, SizeOf(WC));
  If IOResult <> 0 then Goto LIO;
  F16C.FormatTag := 1;
  F16C.Channels := Channels;
  F16C.SamplesPerSec := Frequency;
  F16C.BitsPerSample := 8;
  F16C.SampleSize := (F16C.BitsPerSample shr 3) * Channels;
  F16C.AvgBytesPerSec := F16C.SampleSize;
  F16C.AvgBytesPerSec := F16C.AvgBytesPerSec * Frequency;
  BlockWrite (F, F16C, SizeOf(F16C));
  If IOResult <> 0 then Goto LIO;
  with DC do Begin
    dID := 'data';
    dLen := Size
  End;
  BlockWrite (F, DC, SizeOf(DC));
  If IOResult <> 0 then Goto LIO;
  Ofs := 0;
  WS := 0;
  While Ofs < Size do Begin
    If Size-Ofs >= 32768 then Begin
      BlockWrite (F, P^, 32768, Word(WS));
      If IOResult <> 0 then Goto LIO
    End
    Else Begin
      BlockWrite (F, P^, Size-Ofs, Word(WS));
      If IOResult <> 0 then Goto LIO
    End;
    Inc (Ofs, WS);
    IncPtr (P, 32768)
  End;
  Close (F);
  Error := 0;
{$I+}
End;

End.
