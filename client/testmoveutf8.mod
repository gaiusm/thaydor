MODULE testutf8 ;  (*!m2iso+gm2*)

IMPORT UTF8 ;
IMPORT FIO ;
IMPORT libc ;

VAR
   triangle: UTF8.UTF8 ;
   x       : CARDINAL ;
BEGIN
   triangle := UTF8.InitUnicode ('U+25B6') ;
   FOR x := 1 TO 30 DO
      UTF8.Write (FIO.StdOut, triangle) ; FIO.FlushBuffer (FIO.StdOut) ;
      libc.sleep (1)
   END
END testutf8.
