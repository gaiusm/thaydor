IMPLEMENTATION MODULE FunctionKey ;

FROM Storage IMPORT ALLOCATE ;
FROM StrLib IMPORT StrConCat ;
FROM ASCII IMPORT nul, esc ;


CONST
   MaxFunctionKey = 12 ;
   MaxSig         = 20 ;

TYPE
   KeySequence = POINTER TO RECORD
                               sig : ARRAY [0..MaxSig] OF CHAR ;
                               idx : CARDINAL ;
                               proc: PROC ;
                               next: KeySequence ;
                            END ;

VAR
   DefinedKey  : KeySequence ;
   FunctionKeys: ARRAY [1..MaxFunctionKey] OF KeySequence ;
   Left,
   Right,
   Up,
   Down,
   ShiftLeft,
   ShiftRight,
   ShiftUp,
   ShiftDown,
   AltLeft,
   AltRight,
   AltUp,
   AltDown,
   CtrlLeft,
   CtrlRight,
   CtrlUp,
   CtrlDown: KeySequence ;


(*
   Sequence - return TRUE if ch advances the function
              key sequence.  If ch is the last character in
              the function call sequence then the appropriate
              function call handler is called.
*)

PROCEDURE Sequence (ch: CHAR) : BOOLEAN ;
VAR
   key  : KeySequence ;
   match: BOOLEAN ;
BEGIN
   key := DefinedKey ;
   match := FALSE ;
   WHILE key # NIL DO
      IF KeyMatch (key, ch)
      THEN
         match := TRUE
      END ;
      key := key^.next
   END ;
   RETURN match
END Sequence ;


(*
   KeyMatch - advances the sig idx if ch matches.
              TRUE if returned if a match was seen.
              The procedure attached to key is invoked
              if the sequence is completed.
*)

PROCEDURE KeyMatch (key: KeySequence; ch: CHAR) : BOOLEAN ;
BEGIN
   WITH key^ DO
      IF sig[idx] = ch
      THEN
         INC (idx) ;
         IF sig[idx] = nul
         THEN
            proc ;
            idx := 0
         END ;
         RETURN TRUE
      ELSE
         idx := 0 ;
         RETURN FALSE
      END
   END
END KeyMatch ;


(*
   BindKey -
*)

PROCEDURE BindKey (key: KeySequence; proc: PROC) ;
BEGIN
   key^.idx := 0 ;
   key^.proc := proc
END BindKey ;


(*
   BindFn - associates proc with F[keyno].
*)

PROCEDURE BindFn (keyno: CARDINAL; proc: PROC) ;
BEGIN
   BindKey (FunctionKeys[keyno], proc)
END BindFn ;


(*
   UnBindFn - removes any procedure associated with F[keyno].
*)

PROCEDURE UnBindFn (keyno: CARDINAL) ;
BEGIN
   BindKey (FunctionKeys[keyno], None)
END UnBindFn ;


(*
   BindCursorRight -
*)

PROCEDURE BindCursorRight (proc: PROC) ;
BEGIN
   BindKey (Right, proc)
END BindCursorRight ;


(*
   UnBindCursorRight -
*)

PROCEDURE UnBindCursorRight ;
BEGIN
   BindKey (Right, None)
END UnBindCursorRight ;


(*
   BindCursorLeft -
*)

PROCEDURE BindCursorLeft (proc: PROC) ;
BEGIN
   BindKey (Left, proc)
END BindCursorLeft ;


(*
   UnBindCursorLeft -
*)

PROCEDURE UnBindCursorLeft ;
BEGIN
   BindKey (Left, None)
END UnBindCursorLeft ;


(*
   BindCursorUp -
*)

PROCEDURE BindCursorUp (proc: PROC) ;
BEGIN
   BindKey (Up, proc)
END BindCursorUp ;


(*
   UnBindCursorUp -
*)

PROCEDURE UnBindCursorUp ;
BEGIN
   BindKey (Up, None)
END UnBindCursorUp ;


(*
   BindCursorDown -
*)

PROCEDURE BindCursorDown (proc: PROC) ;
BEGIN
   BindKey (Down, proc)
END BindCursorDown ;


(*
   UnBindCursorDown -
*)

PROCEDURE UnBindCursorDown ;
BEGIN
   BindKey (Down, None)
END UnBindCursorDown ;


(*
   BindShiftCursorRight -
*)

PROCEDURE BindShiftCursorRight (proc: PROC) ;
BEGIN
   BindKey (ShiftRight, proc)
END BindShiftCursorRight ;


(*
   UnBindShiftCursorRight -
*)

PROCEDURE UnBindShiftCursorRight ;
BEGIN
   BindKey (ShiftRight, None)
END UnBindShiftCursorRight ;


(*
   BindShiftCursorLeft -
*)

PROCEDURE BindShiftCursorLeft (proc: PROC) ;
BEGIN
   BindKey (ShiftLeft, proc)
END BindShiftCursorLeft ;


(*
   UnBindShiftCursorLeft -
*)

PROCEDURE UnBindShiftCursorLeft ;
BEGIN
   BindKey (ShiftLeft, None)
END UnBindShiftCursorLeft ;


(*
   BindShiftCursorUp -
*)

PROCEDURE BindShiftCursorUp (proc: PROC) ;
BEGIN
   BindKey (ShiftUp, proc)
END BindShiftCursorUp ;


(*
   UnBindShiftCursorUp -
*)

PROCEDURE UnBindShiftCursorUp ;
BEGIN
   BindKey (ShiftUp, None)
END UnBindShiftCursorUp ;


(*
   BindShiftCursorDown -
*)

PROCEDURE BindShiftCursorDown (proc: PROC) ;
BEGIN
   BindKey (ShiftDown, proc)
END BindShiftCursorDown ;


(*
   UnBindShiftCursorDown -
*)

PROCEDURE UnBindShiftCursorDown ;
BEGIN
   BindKey (ShiftDown, None)
END UnBindShiftCursorDown ;


(*
   BindAltCursorRight -
*)

PROCEDURE BindAltCursorRight (proc: PROC) ;
BEGIN
   BindKey (AltRight, proc)
END BindAltCursorRight ;


(*
   UnBindAltCursorRight -
*)

PROCEDURE UnBindAltCursorRight ;
BEGIN
   BindKey (AltRight, None)
END UnBindAltCursorRight ;


(*
   BindAltCursorLeft -
*)

PROCEDURE BindAltCursorLeft (proc: PROC) ;
BEGIN
   BindKey (AltLeft, proc)
END BindAltCursorLeft ;


(*
   UnBindAltCursorLeft -
*)

PROCEDURE UnBindAltCursorLeft ;
BEGIN
   BindKey (AltLeft, None)
END UnBindAltCursorLeft ;


(*
   BindAltCursorUp -
*)

PROCEDURE BindAltCursorUp (proc: PROC) ;
BEGIN
   BindKey (AltUp, proc)
END BindAltCursorUp ;


(*
   UnBindAltCursorUp -
*)

PROCEDURE UnBindAltCursorUp ;
BEGIN
   BindKey (AltUp, None)
END UnBindAltCursorUp ;


(*
   BindAltCursorDown -
*)

PROCEDURE BindAltCursorDown (proc: PROC) ;
BEGIN
   BindKey (AltDown, proc)
END BindAltCursorDown ;


(*
   UnBindAltCursorDown -
*)

PROCEDURE UnBindAltCursorDown ;
BEGIN
   BindKey (AltDown, None)
END UnBindAltCursorDown ;


(*
   BindCtrlCursorRight -
*)

PROCEDURE BindCtrlCursorRight (proc: PROC) ;
BEGIN
   BindKey (CtrlRight, proc)
END BindCtrlCursorRight ;


(*
   UnBindCtrlCursorRight -
*)

PROCEDURE UnBindCtrlCursorRight ;
BEGIN
   BindKey (CtrlRight, None)
END UnBindCtrlCursorRight ;


(*
   BindCtrlCursorLeft -
*)

PROCEDURE BindCtrlCursorLeft (proc: PROC) ;
BEGIN
   BindKey (CtrlLeft, proc)
END BindCtrlCursorLeft ;


(*
   UnBindCtrlCursorLeft -
*)

PROCEDURE UnBindCtrlCursorLeft ;
BEGIN
   BindKey (CtrlLeft, None)
END UnBindCtrlCursorLeft ;


(*
   BindCtrlCursorUp -
*)

PROCEDURE BindCtrlCursorUp (proc: PROC) ;
BEGIN
   BindKey (CtrlUp, proc)
END BindCtrlCursorUp ;


(*
   UnBindCtrlCursorUp -
*)

PROCEDURE UnBindCtrlCursorUp ;
BEGIN
   BindKey (CtrlUp, None)
END UnBindCtrlCursorUp ;


(*
   BindCtrlCursorDown -
*)

PROCEDURE BindCtrlCursorDown (proc: PROC) ;
BEGIN
   BindKey (CtrlDown, proc)
END BindCtrlCursorDown ;


(*
   UnBindCtrlCursorDown -
*)

PROCEDURE UnBindCtrlCursorDown ;
BEGIN
   BindKey (CtrlDown, None)
END UnBindCtrlCursorDown ;


(*
   None -
*)

PROCEDURE None ;
END None ;


(*
   InitKeySigEsc -
*)

PROCEDURE InitKeySigEsc (VAR sig: ARRAY OF CHAR; src: ARRAY OF CHAR) ;
BEGIN
   sig[0] := esc ;
   sig[1] := nul ;
   StrConCat (sig, src, sig)
END InitKeySigEsc ;


(*
   InitKey -
*)

PROCEDURE InitKey (sig: ARRAY OF CHAR) : KeySequence ;
VAR
   key: KeySequence ;
BEGIN
   NEW (key) ;
   InitKeySigEsc (key^.sig, sig) ;
   WITH key^ DO
      idx := 0 ;
      proc := None ;
      next := DefinedKey
   END ;
   DefinedKey := key ;
   RETURN key
END InitKey ;


(*
   Init - initialize the function keys and other supported
          special keys.
*)

PROCEDURE Init ;
VAR
   i: CARDINAL ;
BEGIN
   DefinedKey := NIL ;
   FOR i := 1 TO MaxFunctionKey DO
      FunctionKeys[i] := NIL
   END ;
   Left := NIL ;
   Right := NIL ;
   Up := NIL ;
   Down := NIL ;
   FunctionKeys[1] := InitKey ('OP') ;
   FunctionKeys[2] := InitKey ('OQ') ;
   FunctionKeys[12] := InitKey ('[24~') ;
   Up := InitKey ('[A') ;
   Down := InitKey ('[B') ;
   Right := InitKey ('[C') ;
   Left := InitKey ('[D') ;

   ShiftUp := InitKey ('[1;2A') ;
   ShiftDown := InitKey ('[1;2B') ;
   ShiftRight := InitKey ('[1;2C') ;
   ShiftLeft := InitKey ('[1;2D') ;

   AltUp := InitKey ('[1;3A') ;
   AltDown := InitKey ('[1;3B') ;
   AltRight := InitKey ('[1;3C') ;
   AltLeft := InitKey ('[1;3D') ;

   CtrlUp := InitKey ('[1;5A') ;
   CtrlDown := InitKey ('[1;5B') ;
   CtrlRight := InitKey ('[1;5C') ;
   CtrlLeft := InitKey ('[1;5D')
END Init ;


BEGIN
   Init
END FunctionKey.
