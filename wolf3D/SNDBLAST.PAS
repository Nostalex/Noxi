Unit SndBlast;
{$G+}
Interface

Type
  TDMAPorts = Record
    PPage,
    PAddr,
    PLen,
    PMask,
    PMode,
    PClear : Word
  End;

Const
  DMAPorts : Array [0..7] of TDMAPorts = (
    (PPage:$87;PAddr:0;PLen:1;PMask:$A;PMode:$B;PClear:$C),
    (PPage:$83;PAddr:2;PLen:3;PMask:$A;PMode:$B;PClear:$C),
    (PPage:$81;PAddr:4;PLen:5;PMask:$A;PMode:$B;PClear:$C),
    (PPage:$82;PAddr:6;PLen:7;PMask:$A;PMode:$B;PClear:$C),
    (PPage:$8F;PAddr:$C0;PLen:$C2;PMask:$D4;PMode:$D6;PClear:$D8),
    (PPage:$8B;PAddr:$C4;PLen:$C6;PMask:$D4;PMode:$D6;PClear:$D8),
    (PPage:$89;PAddr:$C8;PLen:$CA;PMask:$D4;PMode:$D6;PClear:$D8),
    (PPage:$8A;PAddr:$CC;PLen:$CE;PMask:$D4;PMode:$D6;PClear:$D8));

  DMA_Transferring : Boolean = False;   { DMA I/O on flag }
  Long_Back_On : Boolean = False;       { Play/Rec sound on flag }

  SB_Base : Word  = 0;
  SB_IRQ  : Byte  = 0;
  SB_DMA  : Byte  = 0;                  { SB main info! }

  DSP_Reset       =  6;
  DSP_Read_Data   = $A;
  DSP_Write_Data  = $C;
  DSP_Write_Status= $C;
  DSP_Data_Avail  = $E;
  DSP_Mixer_Index =  4;
  DSP_Mixer_Data  =  5;                 { Offsets from the base SB port }

  Source_Mic1     =  0;
  Source_CD       =  2;
  Source_Mic2     =  4;
  Source_Line     =  6; { One of these consts used in SelectInput proc }

Function CheckEnvironment : Boolean;    { Run 1-st to check environment vars }
Function ResetSB : Boolean;             { Run 2-nd to check SB workablility }
Procedure Set_DMA_End_Handler;          { Run 3-rd if u want to know when play/rec ends :-) }
Procedure Restore_DMA_End_Handler;      { Run last - after plays/recs }

Procedure WriteDSP (Value : Byte);
Function ReadDSP : Byte;
Procedure WriteDAC (Level : Byte);
Function ReadDAC : Byte;
Procedure SpeakerOn;                                    { :-) }
Procedure SpeakerOff;                                   { :-) }
Procedure StopDMA;                                      { Stop sound }
Procedure ContinueDMA;                                  { Continue sound }

Procedure ResetMixer;
Procedure SetMixerReg (Index, Value : Byte);
Function GetMixerReg (Index : Word) : Byte;
Procedure SelectInput (Source : Byte);
Procedure SetStereoIO (Stereo : Boolean);               { Stereo/Mono I/O }
Procedure SetMasterVolume (LeftVol, RightVol : Byte);   { ---------------- }
Procedure SetVoiceVolume (LeftVol, RightVol : Byte);    { You can      :-) }
Procedure SetFMVolume (LeftVol, RightVol : Byte);       {   write a        }
Procedure SetCDVolume (LeftVol, RightVol : Byte);       {     Get*Volume   }
Procedure SetLineVolume (LeftVol, RightVol : Byte);     { :-)   functions! }
Procedure SetMicVolume (Volume : Byte);                 { ---------------- }

(* These are the coolest procedures (Long*back).         Work in *)
(* both modes (real & protected). Here is no range on sound data *)
(* size (only free memory :-)). COOL!!!                          *)

Procedure LongPlayback (PSound : Pointer; Size, Frequency : LongInt);
Procedure LongRecordback (PSound : Pointer; Size, Frequency : LongInt);

Function LongRecordLen : LongInt; { Returns how much recorded by }
                                  { the LongRecordback procedure }

{$IFDEF DPMI}
Procedure FreeDOSBuf;           { Call at the end of program! if DPMI }
{$ENDIF}

Implementation

{$IFNDEF DPMI}
Uses CRT, DOS;

{$ELSE}
Uses CRT, DOS, WinAPI;

Var
  PDOSBuf : Pointer;
  PDOSBufHandler,
  PDOSBufPhys : LongInt;
{$ENDIF}

Const
  Long_Play : Boolean = True;           { Play / Record flag for Long*backs }
  Long_Record_Len : LongInt = 0;        { Recorde Len (see LongRecordBack) }

Var
  Old_DMA_End_Handler : Pointer;
  Long_Frequency : LongInt;
  Long_Ptr : Pointer;
  Long_Size : LongInt;

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

Function CheckEnvironment : Boolean;
Var
  Res : Boolean;
  S, SS : String;
  I : Byte;
  E : Integer;
Label
  LEnd;
Begin
  S := GetEnv('BLASTER');
  Res := S <> '';
  If not Res then Goto LEnd;
  I := Pos('A', S);
  SS := '$'; Inc (I);
  While (S[I] in ['0'..'9']) and (I <= Length(S)) do Begin
    SS := SS+S[I];
    Inc (I)
  End;
  Val (SS, SB_Base, E);

  I := Pos('I', S);
  SS := '$'; Inc (I);
  While (S[I] in ['0'..'9']) and (I <= Length(S)) do Begin
    SS := SS+S[I];
    Inc (I)
  End;
  Val (SS, SB_IRQ, E);

  I := Pos('D', S);
  SS := '$'; Inc (I);
  While (S[I] in ['0'..'9']) and (I <= Length(S)) do Begin
    SS := SS+S[I];
    Inc (I)
  End;
  Val (SS, SB_DMA, E);
LEnd:
  CheckEnvironment := Res
End;

Function ResetSB : Boolean;
Begin
  Port[SB_Base+DSP_Reset] := 1;
  Delay (10);
  Port[SB_Base+DSP_Reset] := 0;
  Delay (10);
  If (Port[SB_Base+DSP_Data_Avail] and $80 = $80) and
     (Port[SB_Base+DSP_Read_Data] = $AA) then
    ResetSB := True
  Else
    ResetSB := False
End;

Procedure WriteDSP (Value : Byte);
Begin
  While Port[SB_Base+DSP_Write_Status] and $80 <> 0 do;
  Port[SB_Base+DSP_Write_Data] := Value
End;

Function ReadDSP : Byte;
Begin
  While Port[SB_Base+DSP_Data_Avail] and $80 = 0 do;
  ReadDSP := Port[SB_Base+DSP_Read_Data]
End;

Procedure WriteDAC (Level : Byte);
Begin
  WriteDSP ($10);
  WriteDSP (Level)
End;

Function ReadDAC : Byte;
Begin
  WriteDSP ($20);
  ReadDAC := ReadDSP
End;

Procedure SpeakerOn;
Begin
  WriteDSP ($D1)
End;

Procedure SpeakerOff;
Begin
  WriteDSP ($D3)
End;

Procedure StopDMA;
Begin
  WriteDSP ($D0);
  DMA_Transferring := False
End;

Procedure ContinueDMA;
Begin
  WriteDSP ($D4);
  DMA_Transferring := True
End;

{$IFNDEF DPMI}
Procedure Playback (PSound : Pointer; Size : Word; Frequency : LongInt);
Var
  Time_Constant,
  Page, Offset : Word;
Begin
  SpeakerOn;
  Dec (Size);
  { Set up the DMA chip }
  Offset := Seg(PSound^) Shl 4 + Ofs(PSound^);
  Page := (Seg(PSound^) + Ofs(PSound^) shr 4) shr 12;
  With DMAPorts[SB_DMA] do Begin
    Port[PMask] := SB_DMA or 4;
    Port[PClear] := 0;
    Port[PMode] := $48 or (SB_DMA and 3);
    Port[PAddr] := Lo(Offset);
    Port[PAddr] := Hi(Offset);
    Port[PPage] := Page;
    Port[PLen] := Lo(Size);
    Port[PLen] := Hi(Size);
    Port[PMask] := SB_DMA and 3
  End;
  DMA_Transferring := True;
  { Set the playback frequency }
  Time_Constant := 256 - 1000000 div Frequency;
  WriteDSP ($40);
  WriteDSP (Time_Constant);
  { Set the playback type (8-bit) }
  WriteDSP ($14);
  WriteDSP (Lo(Size));
  WriteDSP (Hi(Size))
End;
{$ENDIF}

Procedure PlaybackPhys (PhysAddr : LongInt; Size : Word; Frequency : LongInt);
Var
  Time_Constant : Word;
  PA : Array [0..3] of Byte absolute PhysAddr;
Begin
  SpeakerOn;
  Dec (Size);
  { Set up the DMA chip }
  With DMAPorts[SB_DMA] do Begin
    Port[PMask] := SB_DMA or 4;
    Port[PClear] := 0;
    Port[PMode] := $48 or (SB_DMA and 3);
    Port[PAddr] := PA[0];
    Port[PAddr] := PA[1];
    Port[PPage] := PA[2];
    Port[PLen] := Lo(Size);
    Port[PLen] := Hi(Size);
    Port[PMask] := SB_DMA and 3;
  End;
  DMA_Transferring := True;
  { Set the playback frequency }
  Time_Constant := 256 - 1000000 div Frequency;
  WriteDSP ($40);
  WriteDSP (Time_Constant);
  { Set the playback type (8-bit) }
  WriteDSP ($14);
  WriteDSP (Lo(Size));
  WriteDSP (Hi(Size))
End;

{$IFNDEF DPMI}
Procedure Recordback (PSound : Pointer; Size : Word; Frequency : LongInt);
Var
  Time_Constant,
  Page, Offset : Word;
Begin
  Dec (Size);
  { Set up the DMA chip }
  Offset := Seg(PSound^) Shl 4 + Ofs(PSound^);
  Page := (Seg(PSound^) + Ofs(PSound^) shr 4) shr 12;
  With DMAPorts[SB_DMA] do Begin
    Port[PMask] := SB_DMA or 4;
    Port[PClear] := 0;
    Port[PMode] := $44 or (SB_DMA and 3);
    Port[PAddr] := Lo(Offset);
    Port[PAddr] := Hi(Offset);
    Port[PPage] := Page;
    Port[PLen] := Lo(Size);
    Port[PLen] := Hi(Size);
    Port[PMask] := SB_DMA and 3
  End;
  DMA_Transferring := True;
  { Set the playback frequency }
  Time_Constant := 256 - 1000000 div Frequency;
  WriteDSP ($40);
  WriteDSP (Time_Constant);
  { Set the playback type (8-bit) }
  WriteDSP ($24);
  WriteDSP (Lo(Size));
  WriteDSP (Hi(Size))
End;
{$ENDIF}

Procedure RecordbackPhys (PhysAddr : LongInt; Size : Word; Frequency : LongInt);
Var
  Time_Constant : Word;
  PA : Array [0..3] of Byte absolute PhysAddr;
Begin
  Dec (Size);
  { Set up the DMA chip }
  With DMAPorts[SB_DMA] do Begin
    Port[PMask] := SB_DMA or 4;
    Port[PClear] := 0;
    Port[PMode] := $44 or (SB_DMA and 3);
    Port[PAddr] := PA[0];
    Port[PAddr] := PA[1];
    Port[PPage] := PA[2];
    Port[PLen] := Lo(Size);
    Port[PLen] := Hi(Size);
    Port[PMask] := SB_DMA and 3
  End;
  DMA_Transferring := True;
  { Set the playback frequency }
  Time_Constant := 256 - 1000000 div Frequency;
  WriteDSP ($40);
  WriteDSP (Time_Constant);
  { Set the playback type (8-bit) }
  WriteDSP ($24);
  WriteDSP (Lo(Size));
  WriteDSP (Hi(Size))
End;

Procedure ResetMixer;
Begin
  Port[SB_Base+DSP_Mixer_Index] := 0;
  Port[SB_Base+DSP_Mixer_Data] := 0
End;

Procedure SetMixerReg (Index, Value : Byte);
Begin
  Port[SB_Base+DSP_Mixer_Index] := Index;
  Port[SB_Base+DSP_Mixer_Data] := Value
End;

Function GetMixerReg (Index : Word) : Byte;
Begin
  Port[SB_Base+DSP_Mixer_Index] := Index;
  GetMixerReg := Port[SB_Base+DSP_Mixer_Data]
End;

Procedure SelectInput (Source : Byte);
Var X : Byte;
Begin
  X := GetMixerReg ($C);
  X := X and $F9;
  SetMixerReg ($C, X or Source)
End;

Procedure SetStereoIO (Stereo : Boolean);
Var X : Byte;
Begin
  X := GetMixerReg ($E);
  X := X and $FD;
  If Stereo then X := X or 2;
  SetMixerReg ($E, X)
End;

Procedure SetMasterVolume (LeftVol, RightVol : Byte);
Begin
  LeftVol := LeftVol shl 4;
  RightVol := RightVol and $F;
  SetMixerReg ($22, LeftVol+RightVol)
End;

Procedure SetVoiceVolume (LeftVol, RightVol : Byte);
Begin
  LeftVol := LeftVol shl 4;
  RightVol := RightVol and $F;
  SetMixerReg (4, LeftVol+RightVol)
End;

Procedure SetFMVolume (LeftVol, RightVol : Byte);
Begin
  LeftVol := LeftVol shl 4;
  RightVol := RightVol and $F;
  SetMixerReg ($26, LeftVol+RightVol)
End;

Procedure SetCDVolume (LeftVol, RightVol : Byte);
Begin
  LeftVol := LeftVol shl 4;
  RightVol := RightVol and $F;
  SetMixerReg ($28, LeftVol+RightVol)
End;

Procedure SetLineVolume (LeftVol, RightVol : Byte);
Begin
  LeftVol := LeftVol shl 4;
  RightVol := RightVol and $F;
  SetMixerReg ($2E, LeftVol+RightVol)
End;

Procedure SetMicVolume (Volume : Byte);
Begin
  SetMixerReg ($A, Volume and $F)
End;

Procedure LongPlayback (PSound : Pointer; Size, Frequency : LongInt);
Var
  S : Word;
Begin
  Long_Frequency := Frequency;
  Long_Ptr := PSound;
  Long_Size := Size;
  Long_Back_On := True;
  Long_Play := True;
  If Size < 1024 then S := Size
  Else S := 1024;
{$IFDEF DPMI}
  Move (Long_Ptr^, PDOSBuf^, S);
  PlaybackPhys (PDOSBufPhys, S, Long_Frequency)
{$ELSE}
  Playback (Long_Ptr, S, Long_Frequency)
{$ENDIF}
End;

Procedure LongRecordback (PSound : Pointer; Size, Frequency : LongInt);
Var
  S : Word;
Begin
  Long_Frequency := Frequency;
  Long_Ptr := PSound;
  Long_Size := Size;
  Long_Back_On := True;
  Long_Play := False;
  If Size < 1024 then S := Size
  Else S := 1024;
  Long_Record_Len := 0;
{$IFDEF DPMI}
  RecordbackPhys (PDOSBufPhys, S, Long_Frequency)
{$ELSE}
  Recordback (Long_Ptr, S, Long_Frequency)
{$ENDIF}
End;

Function LongRecordLen : LongInt;
Begin
  LongRecordLen := Long_Record_Len
End;

{$F+}
Procedure DMA_End_Handler; Interrupt;
Var
  X : Byte;
  S : Word;
Label LEnd;
Begin
  If Test8086 > 1 then Asm
    DB 66h; PushA      { PushAD 'cause we using 32-bit arithmetic }
  End;
  X := Port[SB_Base+DSP_Data_Avail];
  Dec (Long_Size, 1024);
  If Long_Size <= 0 then Begin
  {$IFDEF DPMI}
    If not Long_Play then Begin
      Move (PDOSBuf^, Long_Ptr^, 1024+Long_Size);
    End;
  {$ENDIF}
    If not Long_Play then
      Inc (Long_Record_Len, 1024+Long_Size);
    DMA_Transferring := False;
    Long_Back_On := False;
    Goto LEnd
  End;
  If Long_Play then Begin
    IncPtr (Long_Ptr, 1024);
    If Long_Size < 1024 then S := Long_Size
    Else S := 1024;
  {$IFDEF DPMI}
    Move (Long_Ptr^, PDOSBuf^, S);
    PlaybackPhys (PDOSBufPhys, S, Long_Frequency);
  {$ELSE}
    Playback (Long_Ptr, S, Long_Frequency)
  {$ENDIF}
  End
  Else Begin
    Inc (Long_Record_Len, 1024);
    If Long_Size < 1024 then S := Long_Size
    Else S := 1024;
  {$IFDEF DPMI}
    Move (PDOSBuf^, Long_Ptr^, 1024);
    IncPtr (Long_Ptr, 1024);
    RecordBackPhys (PDOSBufPhys, S, Long_Frequency);
  {$ELSE}
    IncPtr (Long_Ptr, 1024);
    RecordBack (Long_Ptr, S, Long_Frequency)
  {$ENDIF}
  End;
LEnd:
  If SB_IRQ >= 8 then
    Port[$A0] := $20;
  Port[$20] := $20;
  If Test8086 > 1 then Asm
    DB 66h; PopA       { PopAD 'cause we using 32-bit arithmetic }
  End
End;
{$F-}

Procedure Set_DMA_End_Handler;
Var
  IntNo,
  Mask : Byte;
Begin
  If SB_Base = 0 then Exit;
  IntNo := SB_IRQ+8; If SB_IRQ >= 8 then Inc (IntNo, $60);
  If SB_IRQ < 8 then Begin
    Mask := Port[$21];
    Mask := Mask and not (1 shl SB_IRQ);
    Port[$21] := Mask                           { Enable interrupt }
  End
  Else Begin
    Mask := Port[$A1];
    Mask := Mask and not (1 shl (SB_IRQ and $F));
    Port[$A1] := Mask                           { Enable interrupt }
  End;
  GetIntVec (IntNo, Old_DMA_End_Handler);
  SetIntVec (IntNo, @DMA_End_Handler)
End;

Procedure Restore_DMA_End_Handler;
Var
  IntNo,
  Mask : Byte;
Begin
  If SB_Base = 0 then Exit;
  IntNo := SB_IRQ+8; If SB_IRQ >= 8 then Inc (IntNo, $60);
  If SB_IRQ < 8 then Begin
    Mask := Port[$21];
    Mask := Mask or (1 shl SB_IRQ);
    Port[$21] := Mask                           { Disable interrupt }
  End
  Else Begin
    Mask := Port[$A1];
    Mask := Mask or (1 shl (SB_IRQ and $F));
    Port[$A1] := Mask                           { Disable interrupt }
  End;
  SetIntVec (IntNo, Old_DMA_End_Handler)
End;

{$IFDEF DPMI}
Procedure FreeDOSBuf;           { Put in the end of your prog if in DPMI }
Begin
  GlobalDOSFree (PDOSBufHandler)
End;
{$ENDIF}

Begin
  CheckEnvironment;
  {$IFDEF DPMI}
  PDOSBufHandler := GlobalDOSAlloc (1024);          { Handler to Alloc/Free }
  PDOSBufPhys := (PDOSBufHandler shr 12) and $FFFF0;{ Physical address }
  PDOSBuf := Ptr (PDOSBufHandler and $FFFF, 0);     { Pointer in protected mode }
  {$ENDIF}
End.
