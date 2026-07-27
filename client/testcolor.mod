MODULE testcolor ;

IMPORT color ;
FROM StdIO IMPORT Write ;
FROM StrIO IMPORT WriteLn ;

CONST
   MaxColor = 5 ;


(*
   test -
*)

PROCEDURE test ;
VAR
   r, g, b: CARDINAL ;
BEGIN
   color.Enable (TRUE) ;
   FOR r := 0 TO MaxColor DO
      FOR g := 0 TO MaxColor DO
         FOR b := 0 TO MaxColor DO
            color.ForegroundRBG6 (r, g, b) ; Write ("*")
         END ;
         WriteLn ;
      END
   END ;
   FOR r := 0 TO MaxColor DO
      FOR g := 0 TO MaxColor DO
         FOR b := 0 TO MaxColor DO
            color.BackgroundRBG6 (r, g, b) ;
            Write (" ") ;
            color.Default
         END ;
         WriteLn ;
      END
   END ;
END test ;


BEGIN
   test
END testcolor.
