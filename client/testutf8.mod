MODULE testutf8 ;  (*!m2iso+gm2*)

IMPORT UTF8 ;
IMPORT FIO ;

VAR
   brick: UTF8.UTF8 ;
BEGIN
   (* 🧱🧱🧱🧱🧱🧱🧱🧱🧱.  *)
   brick := UTF8.InitUnicode ('U+1F9F1') ;
   UTF8.Write (FIO.StdOut, brick) ; UTF8.WriteLn (FIO.StdOut)
END testutf8.
