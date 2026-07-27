IMPLEMENTATION MODULE color ;

FROM StdIO IMPORT Write ;
FROM StrIO IMPORT WriteString, WriteLn ;
FROM NumberIO IMPORT WriteCard, WriteHex ;
FROM DynamicStrings IMPORT String, InitString, KillString, Length, char ;
FROM StringConvert IMPORT CardinalToString ;
FROM SFIO IMPORT WriteS ;
FROM ASCII IMPORT esc ;

IMPORT FIO ;
IMPORT StdIO ;


VAR
   Enabled: BOOLEAN ;


(*
   LocalWrite -
*)

PROCEDURE LocalWrite (ch: CHAR) ;
BEGIN
   FIO.WriteChar (FIO.StdOut, ch) ;
   (* FIO.FlushBuffer (FIO.StdOut) *)
END LocalWrite ;


(*
   LocalWriteS -
*)

PROCEDURE LocalWriteS (s: String) ;
VAR
   i, len: CARDINAL ;
BEGIN
   i := 0 ;
   len := Length (s) ;
   WHILE i<len DO
      LocalWrite (char (s, i)) ;
      INC (i)
   END ;
   s := KillString (s)
END LocalWriteS ;


(*
   Enable - turn on/off production of color terminal escape strings
            associated with each procedure.
*)

PROCEDURE Enable (value: BOOLEAN) ;
BEGIN
   Enabled := value ;
   (* StdIO.PushOutput (LocalWrite) *)
END Enable ;


(*
   ForegroundRGB6 -
*)

PROCEDURE ForegroundRGB6 (r, g, b: CARDINAL) ;
VAR
   code: CARDINAL ;
BEGIN
   IF Enabled
   THEN
      code := 16 + (r * 36) + (g * 6) + b ;
      Write (esc) ;
      WriteString ("[38:5:") ; WriteCard (code, 0) ;
      FIO.FlushBuffer (FIO.StdOut) ;
      Write ('m')
   END
END ForegroundRGB6 ;


(*
   BackgroundRGB6 -
*)

PROCEDURE BackgroundRGB6 (r, g, b: CARDINAL) ;
VAR
   code: CARDINAL ;
BEGIN
   IF Enabled
   THEN
      code := 16 + (r * 36) + (g * 6) + b ;
      Write (esc) ;
      WriteString ("[48:5:") ; WriteCard (code, 0) ;
      Write ('m')
   END
END BackgroundRGB6 ;


(*
   BackgroundGrey - grey should be 0..23.
*)

PROCEDURE BackgroundGrey (grey: CARDINAL) ;
VAR
   code: CARDINAL ;
BEGIN
   IF Enabled
   THEN
      code := 232 + grey ;
      Write (esc) ;
      WriteString ("[48:5:") ; WriteCard (code, 0) ;
      Write ('m')
   END
END BackgroundGrey ;


(*
   ForegroundGrey - grey should be 0..23.
*)

PROCEDURE ForegroundGrey (grey: CARDINAL) ;
VAR
   code: CARDINAL ;
BEGIN
   IF Enabled
   THEN
      code := 232 + grey ;
      Write (esc) ;
      WriteString ("[38:5:") ; WriteCard (code, 0) ;
      Write ('m')
   END
END ForegroundGrey ;


(*
   Red -
*)

PROCEDURE Red ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[31m")
   END
END Red ;


(*
   Green -
*)

PROCEDURE Green ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[32m")
   END
END Green ;


(*
   Yellow -
*)

PROCEDURE Yellow ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[33m")
   END
END Yellow ;


(*
   Blue -
*)

PROCEDURE Blue ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[34m")
   END
END Blue ;


(*
   Magenta -
*)

PROCEDURE Magenta ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[35m")
   END
END Magenta ;


(*
   Cyan -
*)

PROCEDURE Cyan ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[36m")
   END
END Cyan ;


(*
   White -
*)

PROCEDURE White ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[37m")
   END
END White ;


(*
   Default -
*)

PROCEDURE Default ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[0m")
   END
END Default ;


(*
   ForegroundDefault -
*)

PROCEDURE ForegroundDefault ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[49m")
   END
END ForegroundDefault ;


(*
   Clear -
*)

PROCEDURE Clear ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      WriteString ("[2J")
   END
END Clear ;


(*
   Home -
*)

PROCEDURE Home ;
BEGIN
   IF Enabled
   THEN
      Pos (0, 0)
   END
END Home ;


(*
   Pos - position cursor at location, x, y on the screen.
         0, 0 is top left corner.
*)

PROCEDURE Pos (x, y: CARDINAL) ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      Write ("[") ;
      WriteCard (y, 0) ;
      Write (";") ;
      WriteCard (x, 0) ;
      Write ("H")
   END
END Pos ;


(*
   Reverse - turn on/off reverse video.
*)

PROCEDURE Reverse (on: BOOLEAN) ;
BEGIN
   IF Enabled
   THEN
      Write (esc) ;
      IF on
      THEN
         WriteString ("[7m")
      ELSE
         WriteString ("[27m")
      END
   END
END Reverse ;


END color.
