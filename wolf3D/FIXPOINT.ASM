.386

;��ଠ� �᫠ � 䨪�஢����� ����⮩:
;20 ����� ��� - 楫�� ���� (ᠬ� ���訩 - �������),
;12 ������ ��� - �஡���.

CODE    SEGMENT PUBLIC USE16
ASSUME  CS:CODE, DS:CODE

EXTRN   Fix1:DWORD
EXTRN   Fix2:DWORD
EXTRN   FixRes:DWORD

PUBLIC  Long2Fix
PUBLIC  Fix2Long
PUBLIC	LSAL
PUBLIC	LSAR
PUBLIC  LMul
PUBLIC  LDiv
PUBLIC  FixMul
PUBLIC  FixDiv

Long2Fix PROC FAR
;�८�ࠧ�� 楫�� � ��
  MOV   EAX, [Fix1]
  SAL   EAX, 12
  MOV   [FixRes], EAX
  RET
Long2Fix ENDP

Fix2Long PROC FAR
;�८�ࠧ�� �� � 楫��
  MOV   EAX, [Fix1]
  SAR   EAX, 12
  MOV   [FixRes], EAX
  RET
Fix2Long ENDP

LSAL    PROC FAR
  MOV   EAX, [Fix1]
  MOV   CL, BYTE PTR [Fix2]
  SAL   EAX, CL
  MOV   [FixRes], EAX
  RET
LSAL    ENDP

LSAR    PROC FAR
  MOV   EAX, [Fix1]
  MOV   CL, BYTE PTR [Fix2]
  SAR   EAX, CL
  MOV   [FixRes], EAX
  RET
LSAR    ENDP

LMul    PROC FAR
;���筮� 㬭������ 楫��
  MOV   EAX, [Fix1]
  IMUL  [Fix2]
  MOV 	[FixRes], EAX
  RET
LMul    ENDP

LDiv    PROC FAR
;���筮� ������� 楫��
  MOV   EAX, [Fix1]
  CDQ
  IDIV  [Fix2]
  MOV 	[FixRes], EAX
  RET
LDiv    ENDP

FixMul  PROC FAR
;��������� �ᥫ � ��
  MOV   EAX, [Fix1]
  IMUL  [Fix2]
  SHRD  EAX,EDX,12
  MOV   [FixRes], EAX
  RET
FixMul  ENDP

FixDiv  PROC FAR
;������� �ᥫ � ��
  MOV   EAX, [Fix1]
  CDQ
  SHLD  EDX, EAX, 12
  SAL   EAX, 12
  IDIV  [Fix2]
  SHLD  EDX,EAX,12
  MOV   [FixRes], EAX
  RET
FixDiv  ENDP

CODE    ENDS

END
