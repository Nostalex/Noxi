Unit Render;

Interface

                        (*** COMMON VARS ***)

Const
  Render_VSeg           : Word = $A000;
  Render_Transparent    : Byte = 0 { $FF };
  Render_Shade          : Byte = 0;

                   (*** SLIVER-RENDERING VARS ***)

Var
  Render_Texture        : Pointer;
  Render_Texture_X,
  Render_Sliver_H,
  Render_Screen_X       : Word;

                   (*** FLOOR-RENDERING VARS ***)

  Render_Screen_Y       : Word;
  Render_Floor_Start_X,
  Render_Floor_Start_Y,
  Render_Floor_DX,
  Render_Floor_DY       : LongInt;

             (*** FLOOR- AND CEILING-RENDERING VARS ***)

  Render_Start_X,
  Render_Start_Y,
  Render_DX,
  Render_DY             : LongInt;
  Render_Y,
  Render_Map_Ofs,
  Textures_Table_Ofs    : Word;

  Textures_Ptrs         : Pointer;

Procedure Render_Sliver;
Procedure Render_Floor;
Procedure Render_Both;
Procedure Render_Both2;
Procedure Render_SliverS;
Procedure Render_Both2S;


Implementation

{$L RENDER.OBJ}

{$F+}
Procedure Render_Sliver; External;
Procedure Render_Floor; External;
Procedure Render_Both; External;
Procedure Render_Both2; External;
Procedure Render_SliverS; External;
Procedure Render_Both2S; External;
{$F-}

End.
