{$G+}
Uses CRT, DOS, Grafix, KeyPres2, FixPoint, Render{, WinAPI};

Const
  a_0   =    0;                                 { используемые    }
  a_1   =    5;                                 {                 }
  a_2   =   11;                                 {                 }
  a_3   =   16;                                 {                 }
  a_4   =   21;                                 {                 }
  a_5   =   26;                                 {                 }
  a_6   =   32;                                 {                 }
  a_8   =   43;                                 {                 }
  a_15  =   80;                                 {                 }
  a_30  =  160;                                 {                 }
  a_45  =  240;                                 {                 }
  a_60  =  320;                                 {      единицы    }
  a_90  =  480;                                 {                 }
  a_180 =  960;                                 {                 }
  a_270 = 1440;                                 {                 }
  a_360 = 1920;                                 {          углов  }

  d_angle : Integer = a_4;                      { приращение угла }

  Step : LongInt =  10;                         { величина шага вперед/назад }
  Close = 24;                                   {    минимальное расстояние }
                                                { до стены, лучше на менять }

  ShadeFactor : Byte = 6;

  Chars : Array [0..9] of Char = '0123456789';

Type
  Table = Array [a_0..a_360] of LongInt;
  PTable = ^Table;
  TDoor = Record
    Pos : LongInt;
    X, Y : Word;
    Status : Byte;                      { 0 - неподвижна, 1 - откр., 2 - закр. }
    Time : Byte;                        { время до закрытия }
  End;
  TSprSliver = Record
    PTexture : Pointer;
    Dist : LongInt;
    H : Word;
    X : Byte
  End;
  TEnemy = Record
    Typ : Byte;
    X, Y : LongInt;
    Phase : Byte;
    Health : Byte
  End;
  THPT = Array [0..4095] of Pointer;
  TableA = Array [0..319] of Integer {LongInt};
  PTableA = ^TableA;
  TableT = Array [0..2364] of Integer;
  PTableT = ^TableT;
  TableS = Array [0..319,0..15] of TSprSliver;
  PTableS = ^TableS;

Var
  MapL,                                         { размеры игровой }
  MapH : Byte;                                  { карты; maximum - 64x64 }
  Map : Array [0..63,0..63] of Char;            { игровая карта }

  PSin, PCos, PTan, PCTan,
  PSc, PCsc, PXStep, PYStep : PTable;   { таблицы sin, cos & tan, ... }
  Xp, Yp : Word;                        { координаты героя }
  Ang : Integer;                        { угол обзора героя }
  DX, DY : LongInt;                     { приращения для шага }

  WallTextures : Array [0..9,0..1] of Pointer;
                                        { Массив указателей на текстуры стен }
  HorizTextures : Array [0..9] of Pointer;
                                        { Массив указателей на текстуры
                                        { пола и потолка }
  PHPT : ^THPT;                         { ^массив указателей на текстуры }
                                        { пола и потолка, - для рендеринга }
  MonsterTxt : Pointer;
  Monster2Txt : Pointer;
  S : Word;
  Pal : TPal;                           { Палитра игрушки }
  BackPic : Pointer;                    { Указатель на картинку с небом }
  BackSz : Word;                        { Объем картинки неба в байтах }

  Doors : Array [0..255] of TDoor;      { Записи-данные для каждой двери }
  DoorCnt : Word;                       { Кол-во дверей на уровне }
  PSprites : PTableS;                   { Данные о спрайтах для рендеринга }
  SprCnt : Array [0..319] of Word;      { Кол-во спрайтов на луч -//- }
  Timer : Byte;                         { Счетчик для таймерного обработчика }
  OldTimer : Pointer;                   { ^старый обработчик прерывания таймера }
  Screen : Pointer;                     { ^Виртуальный экран }

  PAngles : PTableA;                    { "Арки" для исключения искажений стен }
  PArcTan : PTableT;                    { "Арки" для поддержки динам. спрайтов }

  Enemys : Array [0..7] of TEnemy;
  EnemyCnt : Byte;
  OldExitProc : Pointer;

Procedure Load_World;
Var
  F : Text;
  S : String;
  I, J : Word;
Begin
  Assign (F, 'MAP.DAT');
  Reset (F);
  ReadLn (F, MapL);
  ReadLn (F, MapH);
  For I := 0 to MapH-1 do Begin
    ReadLn (F, S);
    While Length(S) < MapL do S := S + ' ';
    For J := 0 to MapL-1 do
      Map[I,J] := S[J+1]
  End;
  System.Close (F);

  For J := 0 to 127 do
    For I := 0 to 63 do
      PHPT^[J*64+I] := HorizTextures[0];        { FOR PROTECT MODE :-( }

  Assign (F, 'FLOOR.DAT');
  Reset (F);
  For I := 1 to MapH do Begin
    ReadLn (F, S);
    While Length(S) < MapL do S := S + ' ';
    For J := 0 to MapL-1 do
      If Ord(S[J+1]) = 48 then PHPT^[2*((MapH-I)*64+J)] := Nil
      Else PHPT^[2*((MapH-I)*64+J)] := HorizTextures[Ord(S[J+1])-49]
  End;
  System.Close (F);
  Assign (F, 'CEILING.DAT');
  Reset (F);
  For I := 1 to MapH do Begin
    ReadLn (F, S);
    While Length(S) < MapL do S := S + ' ';
    For J := 0 to MapL-1 do
      If Ord(S[J+1]) = 48 then PHPT^[2*((MapH-I)*64+J)+1] := Nil
      Else PHPT^[2*((MapH-I)*64+J)+1] := HorizTextures[Ord(S[J+1])-49]
  End;
  System.Close (F)
End;

Procedure FindDoors;
Var
  X, Y : Word;
Begin
  DoorCnt := 0;
  For Y := 0 to MapH-1 do
    For X := 0 to MapL-1 do
      If UpCase(Map[MapH-1-Y,X]) = 'D' then Begin
        Doors[DoorCnt].X := X; Doors[DoorCnt].Y := Y;
        Doors[DoorCnt].Pos := 0;
        Doors[DoorCnt].Status := 0;
        Inc (DoorCnt)
      End
End;

Function GetDoor (X, Y : Word) : Byte;
Var
  I : Byte;
Begin
  For I := 0 to DoorCnt-1 do
    If (Doors[I].X = X) and (Doors[I].Y = Y) then Break;
  GetDoor := I
End;

Procedure FindPlayer;
Var
  X, Y : Word;
Begin
  For Y := 0 to MapH-1 do
    For X := 0 to MapL-1 do
      If UpCase(Map[MapH-1-Y,X]) = 'P' then Begin
        Xp := (X shl 6) + 32;
        Yp := (Y shl 6) + 32;
        Map[MapH-1-Y,X] := ' ';
        Break
      End
End;

Procedure FindEnemys;
Var
  X, Y : Word;
Begin
  FillChar (Enemys, SizeOf(Enemys), $FF);
  EnemyCnt := 0;
  For Y := 0 to MapH-1 do
    For X := 0 to MapL-1 do
      If UpCase(Map[MapH-1-Y,X]) = 'E' then Begin
        Enemys[EnemyCnt].X := (X shl 6) + 32;
        Enemys[EnemyCnt].Y := (Y shl 6) + 32;
        Enemys[EnemyCnt].Health := 100;
        Inc (EnemyCnt);
        Map[MapH-1-Y,X] := ' '
      End
{  Enemys[0].X := 17*64+32;
  Enemys[0].Y := 2*64+32;
  Enemys[0].Health := 100;
  EnemyCnt := 1}
End;

Procedure Load_Textures;
Var I : Byte;
Begin
  For I := 1 to 6 do Begin
    LoadPCX256 ('WT'+Chars[I]+'1.PCX', WallTextures[I,0], S, Pal);
    LoadPCX256 ('WT'+Chars[I]+'2.PCX', WallTextures[I,1], S, Pal)
  End;
  LoadPCX256 ('FT1.PCX', HorizTextures[0], S, Pal);
  LoadPCX256 ('FT2.PCX', HorizTextures[1], S, Pal);
  LoadPCX256 ('MSTR2.PCX', MonsterTxt, S, Pal);
  LoadPCX256 ('MSTR.PCX', Monster2Txt, S, Pal);
  LoadPCX256 ('BACK.PCX', BackPic, BackSz, Pal)
End;

Procedure Kill_Textures;
Var I : Byte;
Begin
  For I := 1 to 6 do Begin
    FreeMem (WallTextures[I,0], S);
    FreeMem (WallTextures[I,1], S)
  End;
  FreeMem (HorizTextures[0], S);
  FreeMem (HorizTextures[1], S);
  FreeMem (MonsterTxt, S);
  FreeMem (Monster2Txt, S);
  FreeMem (BackPic, BackSz)
End;

Procedure Make_Tables;                  { подготавливает таблицы sin, ... }
Var
  Ang : Word;
  I, T : Real;
Begin
  New (PSin);
  New (PCos);
  New (PTan);
  New (PCTan);
  New (PSc);
  New (PCsc);
  New (PXStep);
  New (PYStep);
  WriteLn ('Computing tables. Please wait...');
  For Ang := a_0 to a_360 do Begin
    GotoXY (1 + (Ang shr 6), WhereY); Write (#254);

    I := Ang*PI/a_180;

    PSin^[Ang] := Trunc (4096 * Sin(I));
    PCos^[Ang] := Trunc (4096 * Cos(I));
    If PCos^[Ang] <> 0 then Begin
      PTan^[Ang] := Trunc (4096 * Sin(I)/Cos(I));
      PSc^[Ang] := Trunc (4096 / Cos(I));
    End;
    If PSin^[Ang] <> 0 then Begin
      PCTan^[Ang] := Trunc (4096 * Cos(I)/Sin(I));
      PCsc^[Ang] := Trunc (4096 / Sin(I))
    End;

    If (a_0 <= Ang) and (Ang < a_180) then Begin
      Fix1 := Abs (PTan^[Ang]); Fix2 := 6; LSal;
      PYStep^[Ang] := FixRes
    End
    Else Begin
      Fix1 := - Abs (PTan^[Ang]); Fix2 := 6; LSal;
      PYStep^[Ang] := FixRes
    End;
    If (a_90 <= Ang) and (Ang < a_270) then Begin
      Fix1 := - Abs (PCTan^[Ang]); Fix2 := 6; LSal;
      PXStep^[Ang] := FixRes
    End
    Else Begin
      Fix1 := Abs (PCTan^[Ang]); Fix2 := 6; LSal;
      PXStep^[Ang] := FixRes
    End
  End;
  WriteLn;

  New (PAngles);
  I := 160;
  For Ang := 0 to 319 do Begin
    T := I/(160*Sqrt(3));
    PAngles^[Ang] := Trunc(ArcTan(T)*a_180/pi);
    I := I - 1
  End;

  New (PArcTan);
  For Ang := 0 to 2364 do Begin
    I := Ang;
    I := I / (2364*Sqrt(3));
    PArcTan^[Ang] := Trunc(ArcTan(I)*a_180/pi)
  End
End;

Procedure Kill_Tables;                  { освобождает память от таблиц }
Begin
  Dispose (PSin);
  Dispose (PCos);
  Dispose (PTan);
  Dispose (PCTan);
  Dispose (PSc);
  Dispose (PCsc);
  Dispose (PYStep);
  Dispose (PXStep);

  Dispose (PAngles);
  Dispose (PArcTan)
End;

Procedure DrawBoth (X, Y : LongInt; View_Ang : Integer);
Var
  Delta, Z, G, Sine, Cosine,
  K, Cell_X, Cell_Y : LongInt;
  XS, YS,
  Theta : Integer;
  XXX : LongInt;
Begin
  Fix1 := X; Long2Fix; X := FixRes;
  Fix1 := Y; Long2Fix; Y := FixRes;

  Theta := View_Ang - a_90;
  If Theta < 0 then Inc (Theta, a_360);
  Sine := PSin^[Theta];
  Cosine := PCos^[Theta];

  For Delta := 1 to 99 do Begin
    Z := {8192} 7936 div Delta;                 { was 32*256, 31*256 - better }
    Fix1 := 4729; Fix2 := Z; LMul;              { 4729 = 2/sqrt(3) * 2^12 }
    G := FixRes;                                { Z * 2/sqrt(3) }

    Theta := View_Ang + a_30;
    If Theta >= a_360 then Dec (Theta, a_360);
    Fix1 := PCos^[Theta]; Fix2 := G; FixMul;
    Render_Start_X := X + FixRes;
    Fix1 := PSin^[Theta]; Fix2 := G; FixMul;
    Render_Start_Y := Y + FixRes;

    Fix1 := G; Fix2 := 320; LDiv;
    K := FixRes;

    Fix1 := K; Fix2 := Cosine; FixMul;
    Render_DX := FixRes;
    Fix1 := K; Fix2 := Sine; FixMul;
    Render_DY := FixRes;

    YS := 100 + Delta;

    Render_Y := YS;
    XXX := (8192 div Delta) shr (ShadeFactor);
    If XXX > 16 then XXX := 16;
    Render_Shade := XXX;
    Render_Both2S
  End
End;

Procedure PreCastEnemy;
Var
  I : Byte;
  XE, YE, Height,
  TGL, TGR,
  TG, XT : LongInt;
  GL, GR,
  Ray, R, A : Integer;
Label L;
Begin
  FillChar (SprCnt, SizeOf(SprCnt), 0);
  A := Ang;
  For I := 0 to 7 do If Enemys[I].Health < $FF then Begin
    Fix1 := Enemys[I].X-Xp; Fix2 := PSin^[A]; LMul; XE := FixRes;
    Fix1 := Enemys[I].Y-Yp; Fix2 := PCos^[A]; LMul; Dec (XE, FixRes);
    Fix1 := Enemys[I].Y-Yp; Fix2 := PSin^[A]; LMul; YE := FixRes;
    Fix1 := Enemys[I].X-Xp; Fix2 := PCos^[A]; LMul; Inc (YE, FixRes);
    If YE < 4*4096 then Continue;
    Fix1 := XE-32*4096; Fix2 := YE; FixDiv;
    TGL := FixRes;
    Fix1 := XE+31*4096; Fix2 := YE; FixDiv;
    TGR := FixRes;
    If (TGL > 2364) or (TGR < -2364) then Continue;
    If TGL < -2364 then TGL := -2364;
    If TGR > 2364 then TGR := 2364;
    If TGL = -2364 then GL := -160 Else         { Left vert. line of screen }
      If TGL >= 0 then GL := PArcTan^[TGL]
      Else GL := -PArcTan^[-TGL];
    If TGR >= 0 then GR := PArcTan^[TGR]
    Else GR := -PArcTan^[-TGR];
    Fix1 := $4000000; Fix2 := YE; LDiv;
    Height := FixRes;
    R := GL+160;
    For Ray := GL to GR do Begin
      If Ray >= 0 then TG := PTan^[Ray]
      Else TG := -PTan^[-Ray];
      Fix1 := YE; Fix2 := TG; FixMul;
      Fix1 := FixRes + 32*4096 - XE; Fix2Long;
      XT := FixRes;
      If (XT >= 0) and (XT < 64) then with PSprites^[R,SprCnt[R]] do Begin
        X := XT;
        H := Height;
        Dist := YE;
        PTexture := Monster2Txt;
        Inc (SprCnt[R])
      End;
      Inc (R)
    End
  End
End;

Procedure SortSprSlivers (Ray : Word);          { по возраст. }
Var
  I, J, M : Word;
  Tmp : TSprSliver;
Begin
  If SprCnt[Ray] > 1 then Begin
    For I := SprCnt[Ray]-1 downto 0 do Begin
      M := I;
      For J := I downto 0 do
        If PSprites^[Ray,J].Dist > PSPrites^[Ray,M].Dist then M := J;
      If M <> I then Begin
        Tmp := PSprites^[Ray,M];
        PSprites^[Ray,M] := PSprites^[Ray,I];
        PSprites^[Ray,I] := Tmp
      End
    End
  End
End;

Procedure RayCast (X, Y : LongInt; View_Ang : Integer);
(* отсекает лучи и рисует трехмерную проекцию *)
{ X, Y - позиция героя }
{ View_Ang - угол направления просмотра героя }
Var
  Ray : Word;
  X_Ray, Y_Ray : Boolean;
  Casting, X_Hit, Y_Hit : Byte;
  Ang,
  N_Y_Cell, N_X_Cell, X_Bound, Y_Bound,
  X_Delta, Y_Delta, Xi, Yi,
  Cur_Cell_X, Cur_Cell_Y, Dist_X, Dist_Y,
  Tan, CTan, Sc, Csc,
  Xd, Yd,
  Height : LongInt;
  DoorNum : Byte;
  Distance, XXX : LongInt;

Label
  LX_Door_Skip, LY_Door_Skip, L_Skip1, L_Skip2;

Function CalcSprite : Boolean;
Var
  CX, CY, XP_, YP_, XS : LongInt;
  Delta : Integer;
Begin
  Fix1 := Cur_Cell_X; Fix2 := 18; LSal; CX := FixRes;
  Fix1 := X - 32; Long2Fix; CX := FixRes - CX;
  Fix1 := Cur_Cell_Y; Fix2 := 18; LSal; CY := FixRes;
  Fix1 := Y - 32; Long2Fix; CY := FixRes - CY;

  Fix1 := CX; Fix2 := PSin^[Ang]; FixMul; XP_ := FixRes;
  Fix1 := CY; Fix2 := PCos^[Ang]; FixMul; Dec (XP_, FixRes);
  Fix1 := CY; Fix2 := PSin^[Ang]; FixMul; YP_ := FixRes;
  Fix1 := CX; Fix2 := PCos^[Ang]; FixMul; Inc (YP_, FixRes);

  Delta := Ang - View_Ang;
  If Delta < 0 then Inc (Delta, a_360);
  If Delta >= a_360 then Dec (Delta, a_360);
  Fix1 := YP_; Fix2 := PTan^[Delta]; FixMul;
  Fix1 := XP_ - FixRes; Fix2Long;
  XS := 32 + FixRes;
  If (XS >= 0) and (XS < 64) then Begin
    PSprites^[Ray,SprCnt[Ray]].PTexture := MonsterTxt;
    PSprites^[Ray,SprCnt[Ray]].X := XS;
    Fix1 := $4000000; Fix2 := -YP_; FixDiv;
    Fix1 := FixRes; Fix2Long;
    If FixRes <= 0 then Begin
      CalcSprite := False;
      Exit
    End;
    PSprites^[Ray,SprCnt[Ray]].H := FixRes;
    PSprites^[Ray,SprCnt[Ray]].Dist := -YP_;
    Inc (SprCnt[Ray])
  End;
  CalcSprite := True
End;

Begin
  Ang := View_ang;

  For Ray := 319 downto 0 do Begin
    View_Ang := Ang + PAngles^[Ray];
    If View_Ang < a_0 then Inc (View_Ang, a_360);
    If View_Ang >= a_360 then Dec (View_Ang, a_360);

    Fix1 := X; Long2Fix; Xi := FixRes;
    Fix1 := Y; Long2Fix; Yi := FixRes;

    Tan := PTan^[View_Ang];
    CTan := PCTan^[View_Ang];
    Sc := PSc^[View_Ang];
    Csc := PCsc^[View_Ang];

    If (a_0 <= View_Ang) and (View_Ang < a_180) then Begin
      Y_Bound := 64 + (Y and $FFFFFFC0);
      Y_Delta := 64;
      N_Y_Cell := 0
    End
    Else Begin
      Y_Bound := Y and $FFFFFFC0;
      Y_Delta := -64;
      N_Y_Cell := -1
    End;
    Fix1 := CTan; Fix2 := Y_Bound-Y; LMul; Inc (Xi, FixRes);

    If (View_Ang < a_90) or (a_270 <= View_Ang) then Begin
      X_Bound := 64 + (X and $FFFFFFC0);
      X_Delta := 64;
      N_X_Cell := 0
    End
    Else Begin
      X_Bound := X and $FFFFFFC0;
      X_Delta := -64;
      N_X_Cell := -1
    End;
    Fix1 := Tan; Fix2 := X_Bound-X; LMul; Inc (Yi, FixRes);

    Casting := 2;
    X_Ray := False;
    Y_Ray := False;

    If (View_Ang = a_90) or (View_Ang = a_270) then Begin
      Dist_X := $10000000;
      X_Ray := True;
      Dec (Casting)
    End;

    If (View_Ang = a_0) or (View_Ang = a_180) then Begin
      Dist_Y := $10000000;
      Y_Ray := True;
      Dec (Casting)
    End;

    (*** Sprites ***)
{    SprCnt[Ray] := 0;}                         { Now in PreCastEnemy }
    (*** Sprites ***)

    While Casting > 0 do Begin
      If not X_Ray then Begin
        Cur_Cell_X := (X_bound + N_X_Cell) Shr 6;
        Fix1 := Yi; Fix2 := 18; LSar; Cur_Cell_Y := FixRes;

        If (Cur_Cell_Y < 0) or (Cur_Cell_Y > MapH-1) or    { FOR PROTECT }
           (Cur_Cell_X < 0) or (Cur_Cell_X > MapL-1) then  {  MODE  :-(  }
             Begin
               Dist_X := $10000000;
               X_Ray := True;
               Dec (Casting);
               Goto L_Skip1
             End;
        X_Hit := Byte(Map[MapH-1-Cur_Cell_Y,Cur_Cell_X]);

        (*** Sprites ***)
        If X_Hit = 109 then Begin                       { 'm' }
          CalcSprite;
          Goto LX_Door_Skip
        End;
        (*** Sprites ***)

{ Doors support begin }
        If X_Hit = 100 then Begin                       { 'd' }
          Fix1 := PYStep^[View_Ang]; Fix2 := 1; LSar;
          Yd := Yi + FixRes;
          Fix1 := Yd; Fix2Long;
          Render_Texture_X := FixRes and 63;
          Fix1 := FixRes; Fix2 := 6; LSar;
          If FixRes <> Cur_Cell_Y then
            Goto LX_Door_Skip;                  { Not a door => skip }
          DoorNum := GetDoor (Cur_Cell_X, Cur_Cell_Y);
          Inc (Render_Texture_X, Doors[DoorNum].Pos);
          If Render_Texture_X > 63 then
            Goto LX_Door_Skip;                  { Door is opened }
          Yi := Yd + (Doors[DoorNum].Pos shl 12);
          Fix1 := X_Bound-X;
          If X_Delta = 64 then Inc (Fix1, 32)
          Else Dec (Fix1, 32);
          Fix2 := Sc; LMul; Dist_X := FixRes;
          X_Ray := True;
          Dec (Casting);
          X_Delta := -64;
          X_Hit := 53
        End                                             { '5' }
{ Doors support end }

        Else
        If (X_Hit <> 32) and (X_Hit <> 68) then Begin   { ' ', 'D' }
          Fix1 := X_Bound-X; Fix2 := Sc; LMul; Dist_X := FixRes;
          X_Ray := True;
          Dec (Casting)
        End
        Else
LX_Door_skip:
          Inc (Yi, PYStep^[View_Ang])
      End;

L_Skip1:

      If not Y_Ray then Begin
        Cur_Cell_Y := (Y_bound + N_Y_Cell) Shr 6;
        Fix1 := Xi; Fix2 := 18; LSar; Cur_Cell_X := FixRes;

        If (Cur_Cell_Y < 0) or (Cur_Cell_Y > MapH-1) or    { FOR PROTECT }
           (Cur_Cell_X < 0) or (Cur_Cell_X > MapL-1) then  {  MODE  :-(  }
             Begin
               Dist_Y := $10000000;
               Y_Ray := True;
               Dec (Casting);
               Goto L_Skip2
             End;
        Y_Hit := Byte(Map[MapH-1-Cur_Cell_Y,Cur_Cell_X]);

        (*** Sprites ***)
        If Y_Hit = 109 then Begin                       { 'm' }
          CalcSprite;
          Goto LY_Door_Skip
        End;
        (*** Sprites ***)

{ Doors support begin }
        If Y_Hit = 68 then Begin                        { 'D' }
          Fix1 := PXStep^[View_Ang]; Fix2 := 1; LSar;
          Xd := Xi + FixRes;
          Fix1 := Xd; Fix2Long;
          Render_Texture_X := FixRes and 63;
          Fix1 := FixRes; Fix2 := 6; LSar;
          If FixRes <> Cur_Cell_X then
            Goto LY_Door_Skip;                  { Not a door => skip }
          DoorNum := GetDoor (Cur_Cell_X, Cur_Cell_Y);
          Inc (Render_Texture_X, Doors[DoorNum].Pos);
          If Render_Texture_X > 63 then
            Goto LY_Door_Skip;                  { Door is opened }
          Xi := Xd + (Doors[DoorNum].Pos shl 12);
          Fix1 := Y_Bound-Y;
          If Y_Delta = 64 then Inc (Fix1, 32)
          Else Dec (Fix1, 32);
          Fix2 := Csc; LMul; Dist_Y := FixRes;
          Y_Ray := True;
          Dec (Casting);
          Y_Delta := 64;
          Y_Hit := 53                                   { '5' }
        End
{ Doors support end }

        Else
        If (Y_Hit <> 32) and (Y_Hit <> 100) then Begin  { ' ', 'd' }
          Fix1 := Y_Bound-Y; Fix2 := Csc; LMul; Dist_Y := FixRes;
          Y_Ray := True;
          Dec (Casting)
        End
        Else
LY_Door_Skip:
          Inc (Xi, PXStep^[View_Ang])
      End;

L_Skip2:

      Inc (X_Bound, X_Delta);
      Inc (Y_Bound, Y_Delta)
    End;

    If Dist_X < Dist_Y then Begin
      Fix1 := Yi; Fix2Long;
      If X_Delta > 0 then FixRes := 63 - FixRes;
      Render_Texture_X := FixRes and 63;
      Fix1 := $4000000; Fix2 := Dist_X; FixDiv;
      Render_Texture := WallTextures[X_Hit-48,0];
      Distance := Dist_X
    End Else Begin
      Fix1 := Xi; Fix2Long;
      If Y_Delta < 0 then FixRes := 63 - FixRes;
      Render_Texture_X := FixRes and 63;
      Fix1 := $4000000; Fix2 := Dist_Y; FixDiv;
      Render_Texture := WallTextures[Y_Hit-48,1];
      Distance := Dist_Y
    End;
    Fix1 := FixRes; Fix2 := PSc^[Abs(View_Ang-Ang)]; FixMul;
    Fix1 := FixRes; Fix2Long; Height := FixRes;

    Render_Sliver_H := Height;
    Render_Screen_X := Ray;

    Fix1 := Distance; Fix2 := PCos^[Abs(View_Ang-Ang)]; FixMul;
    XXX := FixRes shr (12+ShadeFactor);
    If XXX > 16 then XXX := 16;
    Render_Shade := XXX;
    Render_SliverS;

    (*** Sprites ***)
    SortSprSlivers (Ray);
    If SprCnt[Ray] > 0 then Repeat
      Dec (SprCnt[Ray]);
      Render_Sliver_H := PSprites^[Ray,SprCnt[Ray]].H;
      Render_Texture := PSprites^[Ray,SprCnt[Ray]].PTexture;
      Render_Texture_X := PSprites^[Ray,SprCnt[Ray]].X;
      If ((Dist_X < Dist_Y) and (Dist_X > PSprites^[Ray,SprCnt[Ray]].Dist)) or
        ((Dist_X > Dist_Y) and (Dist_Y > PSprites^[Ray,SprCnt[Ray]].Dist)) then Begin
          XXX := PSprites^[Ray,SprCnt[Ray]].Dist shr (12+ShadeFactor);
          If XXX > 16 then XXX := 16;
          Render_Shade := XXX;
          Render_SliverS
        End;
    Until SprCnt[Ray] = 0;
    (*** Sprites ***)

    Inc (View_Ang);
    If View_Ang >= a_360 then Dec (View_Ang, a_360)
  End;
End;

Procedure Rotate (Left : Boolean);
Begin
  If Left then Begin
    Inc (Ang, d_angle);
    If Ang >= a_360 then Dec (Ang, a_360)
  End
  Else Begin
    Dec (Ang, d_angle);
    If Ang < a_0 then Inc (Ang, a_360)
  End;
  Fix1 := Step; Fix2 := PCos^[Ang]; LMul;
  Fix1 := FixRes; Fix2Long; DX := FixRes;
  Fix1 := Step; Fix2 := PSin^[Ang]; LMul;
  Fix1 := FixRes; Fix2Long; DY := FixRes
End;

Procedure Go (Forward : Boolean);
Var
  XO, YO,
  DX2, DY2,
  Cell_X, Cell_Y,
  X_Sub, Y_Sub : LongInt;
  Hit : Char;
  DoorNum : Byte;
Begin
  XO := Xp; YO := Yp;
  DX2 := DX; DY2 := DY;
  If not Forward then Begin
    DX2 := -DX2; DY2 := -DY2;
  End;
  Inc (Xp, DX2); Inc (Yp, DY2);
  Fix1 := Xp; Fix2 := 6; LSar;
  Cell_X := FixRes;
  Fix1 := Yp; Fix2 := 6; LSar;
  Cell_Y := FixRes;
  X_Sub := Xp and 63;
  Y_Sub := Yp and 63;

  If DX2 > 0 then Begin
    Hit := Map[MapH-1-Cell_Y,Cell_X+1];
    DoorNum := GetDoor (Cell_X+1, Cell_Y);
    If Upcase(Hit) = 'D' then Begin
      If (Doors[DoorNum].Pos < 64) and (X_Sub > 64 - Close) then
        Dec (Xp, X_Sub - (64 - Close))
    End
    Else {If Hit <> 'm' then}                     { into 'm' }
    If (Hit <> #32) and (X_Sub > 64 - Close) then
      Dec (Xp, X_Sub - (64 - Close))
  End
  Else Begin
    Hit := Map[MapH-1-Cell_Y,Cell_X-1];
    DoorNum := GetDoor (Cell_X-1, Cell_Y);
    If Upcase(Hit) = 'D' then Begin
      If (Doors[DoorNum].Pos < 64) and (X_Sub < Close) then
        Inc (Xp, Close - X_Sub)
    End
    Else {If Hit <> 'm' then}                     { into 'm' }
    If (Hit <> #32) and (X_Sub < Close) then
      Inc (Xp, Close - X_Sub)
  End;

  If DY2 > 0 then Begin
    Hit := Map[MapH-1-(Cell_Y+1),Cell_X];
    DoorNum := GetDoor (Cell_X, Cell_Y+1);
    If Upcase(Hit) = 'D' then Begin
      If (Doors[DoorNum].Pos < 64) and (Y_Sub > 64 - Close) then
        Dec (Yp, Y_Sub - (64 - Close))
    End
    Else {If Hit <> 'm' then}                     { into 'm' }
    If (Hit <> #32) and (Y_Sub > 64 - Close) then
      Dec (Yp, Y_Sub - (64 - Close))
  End
  Else Begin
    Hit := Map[MapH-1-(Cell_Y-1),Cell_X];
    DoorNum := GetDoor (Cell_X, Cell_Y-1);
    If Upcase(Hit) = 'D' then Begin
      If (Doors[DoorNum].Pos < 64) and (Y_Sub < Close) then
        Inc (Yp, Close - Y_Sub)
    End
    Else {If Hit <> 'm' then}                     { into 'm' }
    If (Hit <> #32) and (Y_Sub < Close) then
      Inc (Yp, Close - Y_Sub)
  End;

  Fix1 := Xp; Fix2 := 6; LSar;
  Cell_X := FixRes;
  Fix1 := Yp; Fix2 := 6; LSar;
  Cell_Y := FixRes;
  Case Map[MapH-1-Cell_Y,Cell_X] of
    #32, 'd', 'D'{,'m'} :;                        { into 'm' }
    Else Begin
      Xp := XO;
      Yp := YO
    End
  End
End;

Procedure DoorToggle;
Var
  D_Cell_X,
  D_Cell_Y : Word;
  DoorNum : Word;
Begin
  D_Cell_X := Xp shr 6;
  D_Cell_Y := Yp shr 6;
  If (a_360-a_45 <= Ang) or (Ang < a_45) then Inc (D_Cell_X)
  Else  If (a_45 <= Ang) and (Ang < a_90+a_45) then Inc (D_Cell_Y)
  Else If (a_90+a_45 <= Ang) and (Ang < a_180+a_45) then Dec (D_Cell_X)
  Else If (a_180+a_45 <= Ang) and (Ang < a_270+a_45) then Dec (D_Cell_Y);
  If UpCase(Map[MapH-1-D_Cell_Y,D_Cell_X]) <> 'D' then Exit;
  DoorNum := GetDoor (D_Cell_X, D_Cell_Y);
  If Doors[DoorNum].Status <> 0 then Exit;
  Doors[DoorNum].Status := 1
End;

Procedure NewTimer; Interrupt;
Var
  I : Word;
Begin
  If Timer = 0 then
    Asm
      PushF
      Call  DWord Ptr OldTimer
    End
  Else Port[$20] := $20;
  Inc (Timer); If Timer = 4 then Timer := 0;

  If DoorCnt > 0 then
  For I := 0 to DoorCnt-1 do Begin
    If Doors[I].Status = 1 then Begin
      If Doors[I].Pos < 64 then Inc (Doors[I].Pos)
      Else Begin
        Doors[I].Status := 2;
        Doors[I].Time := 96                     { 96 55mks ticks }
      End
    End
    Else If Doors[I].Status = 2 then Begin
      If Doors[I].Time > 0 then Begin
        If Timer = 0 then
          Dec (Doors[I].Time)
      End
      Else If Doors[I].Pos > 0 then Dec (Doors[I].Pos)
      Else Doors[I].Status := 0
    End
  End
End;

Procedure ScreenUpdate;
Var
  SkyStart : Word;
Begin
  SkyStart := 319 - Ang div 6;
  If SkyStart = 0 then
    PutImage (0, 0, BackPic^)
  Else Begin
    PutImagePart (0, 0, BackPic^, SkyStart, 0, 320-SkyStart, 100);
    PutImagePart (320-SkyStart, 0, BackPic^, 0, 0, SkyStart, 100)
  End;
    DrawBoth (Xp, Yp, Ang);
    PreCastEnemy;
    RayCast (Xp, Yp, Ang);
    Asm
      Mov   BX, DS
      Mov   AX, SegA000 {0A000h}
      LDS   SI, Screen
      Mov   ES, AX
      Xor   DI, DI
      Mov   CX, 16000
      CLD
      DB    66h
      Rep   MovSW
      Mov   DS, BX
    End
End;

{$F+}
Procedure NewExitProc;
Begin
  ExitProc := OldExitProc;
  CloseGraph
End;
{$F-}

Var
  Dir : Boolean;

Const
  Moving : Boolean = False;             {    Для плавной остановки }
  PhysV : LongInt = 0;                  {          (разгона) после }
  Vel : LongInt = 0;                    { (при) отпускания клавиши }
  Frames : LongInt = 0;                 { frame counter }
  Ticks : LongInt = 5*18;               { 5 sec }
  STicks : LongInt = 0;                 { ticks at start }
  FrameRate : Real = 0;
  Moving2 : Boolean = False;
  PhysV2 : LongInt = 0;
  Vel2 : LongInt = 10;

Begin
  If Test8086 < 2 then Begin
    WriteLn ('Want a 80386 or better processor!');
    Exit
  End;
  OldExitProc := ExitProc;
  ExitProc := @NewExitProc;
  GetMem (Screen, 64000);
  GetMem (PHPT, 32768);
  New (PSprites);
  Textures_Ptrs := PHPT;
  Load_Textures;
  Load_World;
  FindDoors;
  FindPlayer;
  FindEnemys;
  Make_Tables;
  WaitForACSReleased;
  Set_Handler;
  InitGraph;
  SetPal (Pal);
  SetActivePage (Seg(Screen^));
  Render_VSeg := Seg(Screen^);

  Ang := a_0;
  Rotate (True); Rotate (False);
  ScreenUpdate;

  Timer := 0;
  GetIntVec (8, OldTimer);
  SetIntVec (8, @NewTimer);
  Port[$43] := $34;                             { Ускорили частоту }
  Port[$40] := ($10000 div 4) and $FF;          { таймера в        }
  Port[$40] := ($10000 div 4) shr 8;            { 4     раза       }

  STicks := MemL[Seg0040:$6C];

  Repeat
    If KeyMap[sRShift] then Begin
      Vel := 16;
      d_angle := a_6;
      Rotate (True); Rotate (False)
    End
    Else Begin
      Vel := 10;
      d_angle := a_4;
      Rotate (True); Rotate (False)
    End;
    Moving := Ord(KeyMap[sUp])+Ord(KeyMap[sDown]) = 1;
    Moving2 := KeyMap[sLeft] xor KeyMap[sRight];
    If (not Moving) and (PhysV <> 0) then Begin
      Step := Abs(PhysV);
      Rotate (True); Rotate (False);
      Go (PhysV > 0);
      If PhysV > 0 then Dec (PhysV)
      Else Inc (PhysV)
    End;
    If (not Moving2) and (PhysV2 <> 0) then Begin
      Step := Abs(PhysV2);
      Asm Push d_angle End;
      d_angle := a_90;
      Rotate (True);
      Go (PhysV2 > 0);
      If PhysV2 > 0 then Dec (PhysV2)
      Else Inc (PhysV2);
      Rotate (False);
      Asm Pop d_angle End;
    End;
    If Moving and KeyMap[sUp] then              { движение вперед }
      Begin
        If PhysV <= 0 then PhysV := 1;
        Step := PhysV;
        Rotate (True); Rotate (False);
        Go (True);
        If PhysV < Vel then
          Inc (PhysV)
      End;
    If Moving and KeyMap[sDown] then            { движение назад }
      Begin
        If PhysV >= 0 then PhysV := -1;
        Step := -PhysV;
        Rotate (True); Rotate (False);
        Go (False);
        If -PhysV < Vel then
          Dec (PhysV)
      End;
    If not KeyMap[sAlt] then Begin
      If KeyMap[sLeft] then                       { поворот налево }
        Rotate (True);
      If KeyMap[sRight] then                      { поворот направо }
        Rotate (False);
    End
    Else Begin
      If KeyMap[sLeft] then Begin                 { шаг влево }
        If PhysV2 <= 0 then PhysV2 := 1;
        Step := PhysV2;
        Asm Push d_angle End;
        d_angle := a_90;
        Rotate (True);
        Go (True);
        Rotate (False);
        Asm Pop d_Angle End;
        If PhysV2 < Vel2 then
          Inc (PhysV2)
      End;
      If KeyMap[sRight] then Begin                { шаг вправо }
        If PhysV2 >= 0 then PhysV2 := -1;
        Step := -PhysV2;
        Asm Push d_angle End;
        d_angle := a_90;
        Rotate (True);
        Go (False);
        Rotate (False);
        Asm Pop d_Angle End;
        If -PhysV2 < Vel2 then
          Dec (PhysV2)
      End
    End;
    If KeyMap[sSpace] then
      DoorToggle;
    If Dir then Begin
      If Enemys[0].X > 2*64 then Begin
        Dec (Enemys[0].X, 8);
        If Enemys[0].X <= 2*64 then Dir := False
      End
    End
    Else Begin
      If Enemys[0].X < 18*64 then Begin
        Inc (Enemys[0].X, 8);
        If Enemys[0].X >= 18*64 then Dir := True
      End
    End;
    If KeyMap[sGrayPlus] and (ShadeFactor<12) then Inc (ShadeFactor);
    If KeyMap[sGrayMinus] and (ShadeFactor>0) then Dec (ShadeFactor);
    ScreenUpdate;
    If MemL[Seg0040:$6C] < STicks+Ticks then
      Inc (Frames)
  Until KeyMap[sEsc];

  SetIntVec (8, OldTimer);
  Port[$43] := $34;                             { Вернули прежнюю частоту }
  Port[$40] := $00;                             { таймера -               }
  Port[$40] := $00;                             { 18.2 герц               }

  Remove_Handler;
  CloseGraph;
  Dispose (PSprites);
  FreeMem (PHPT, 32768);
  Kill_Tables;
  Kill_Textures;
  FreeMem (Screen, 64000);
  ExitProc := OldExitProc;
  If MemL[Seg0040:$6C] >= STicks+Ticks then Begin
    FrameRate := Frames*18/Ticks;
    WriteLn (FrameRate:6:1,' frames per second.')
  End;
  WriteLn ('┌─────────────────────────────────────────┐');
  WriteLn ('│   Lab3D by Alexei A. Frounze (c) 1998   │');
  WriteLn ('│  Homepage : http://www.chat.ru/~alexfru │');
  WriteLn ('│        E-Mail : alexfru@chat.ru         │');
  WriteLn ('└─────────────────────────────────────────┘')
End.
