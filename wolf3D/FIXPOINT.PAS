Unit FixPoint;

Interface

Var
  Fix1, Fix2, FixRes : LongInt;

Procedure Long2Fix;
Procedure Fix2Long;
Procedure LSal;
Procedure LSar;
Procedure LMul;
Procedure LDiv;
Procedure FixMul;
Procedure FixDiv;


Implementation

{$L FIXPOINT.OBJ}

{$F+}
Procedure Long2Fix; External;
{$F-}

{$F+}
Procedure Fix2Long; External;
{$F-}

{$F+}
Procedure LSal; External;
{$F-}

{$F+}
Procedure LSar; External;
{$F-}

{$F+}
Procedure LMul; External;
{$F-}

{$F+}
Procedure LDiv; External;
{$F-}

{$F+}
Procedure FixMul; External;
{$F-}

{$F+}
Procedure FixDiv; External;
{$F-}

End.
