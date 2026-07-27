(* UTF8.mod provides a UTF8 data type and basic manipulation procedures.

Copyright (C) 2026 Free Software Foundation, Inc.
Contributed by Gaius Mulley <gaiusmod2@gmail.com>.

This file is part of GNU Modula-2.

GNU Modula-2 is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

GNU Modula-2 is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

Under Section 7 of GPL version 3, you are granted additional
permissions described in the GCC Runtime Library Exception, version
3.1, as published by the Free Software Foundation.

You should have received a copy of the GNU General Public License and
a copy of the GCC Runtime Library Exception along with this program;
see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
<http://www.gnu.org/licenses/>.  *)

IMPLEMENTATION MODULE UTF8 ;  (*!m2iso+gm2*)

FROM Storage IMPORT ALLOCATE, DEALLOCATE ;
FROM SYSTEM IMPORT BYTE ;
FROM DynamicStrings IMPORT String, InitString, KillString, Slice, char,
                           Length ;
FROM StringConvert IMPORT StringToCardinal ;
FROM FIO IMPORT WriteChar ;

IMPORT FIO ;


TYPE
   UTF8 = POINTER TO RECORD
                        high   : CARDINAL ;  (* Last byte used.  *)
                        content: ARRAY [0..3] OF BYTE ;
                        next   : UTF8 ;
                     END ;

VAR
   FreeList: UTF8 ;


(*
   New - return a pointer to a new or reused uft8 uninitialized block of memory.
*)

PROCEDURE New () : UTF8 ;
VAR
   utf8: UTF8 ;
BEGIN
   IF FreeList = NIL
   THEN
      NEW (utf8)
   ELSE
      utf8 := FreeList ;
      FreeList := FreeList^.next
   END ;
   RETURN utf8
END New ;


(*
   KillUTF8 - places utf8 onto the freelist and return NIL.
*)

PROCEDURE KillUTF8 (utf8: UTF8) : UTF8 ;
BEGIN
   utf8^.next := FreeList ;
   FreeList := utf8 ;
   RETURN NIL
END KillUTF8 ;


(*
   InitUTF8 - initialize a UTF8 object and return it.
*)

PROCEDURE InitUTF8 (ch: CARDINAL) : UTF8 ;
VAR
   utf8: UTF8 ;
BEGIN
   utf8 := New () ;
   WITH utf8^ DO
      next := NIL ;
      IF ch < 128
      THEN
         (* Single byte required.  *)
         high := 0 ;
         content[0] := VAL (BYTE, ch MOD 256)
      ELSIF ch < 2048
      THEN
         (* Two bytes required.  *)
         high := 1 ;
         content[1] := VAL (BYTE, 128 + ch MOD 64) ;   (* 6 bits of data.  *)
         ch := ch DIV 64 ;
         content[0] := VAL (BYTE, 192 + ch MOD 32) ;   (* 5 bits of data.  *)
      ELSIF ch < 65536
      THEN
         (* Three bytes required.  *)
         high := 2 ;
         content[2] := VAL (BYTE, 128 + ch MOD 64) ;   (* 6 bits of data.  *)
         ch := ch DIV 64 ;
         content[1] := VAL (BYTE, 128 + ch MOD 64) ;   (* 6 bits of data.  *)
         ch := ch DIV 64 ;
         content[0] := VAL (BYTE, 224 + ch MOD 16)     (* 4 bits of data.  *)
      ELSE
         (* All four bytes required.  *)
         high := 3 ;
         content[3] := VAL (BYTE, 128 + ch MOD 64) ;   (* 6 bits of data.  *)
         ch := ch DIV 64 ;
         content[2] := VAL (BYTE, 128 + ch MOD 64) ;   (* 6 bits of data.  *)
         ch := ch DIV 64 ;
         content[1] := VAL (BYTE, 128 + ch MOD 64) ;   (* 6 bits of data.  *)
         ch := ch DIV 64 ;
         content[0] := VAL (BYTE, 240 + ch MOD 8)      (* 3 bits of data.  *)
      END
   END ;
   RETURN utf8
END InitUTF8 ;


(*
   InitUnicode - initialize a UTF8 object using an array of char.
                 For example 'U+1F9F1'.
*)

PROCEDURE InitUnicode (a: ARRAY OF CHAR) : UTF8 ;
VAR
   s   : String ;
   utf8: UTF8 ;
BEGIN
   s := InitString (a) ;
   utf8 := StringInitUTF8 (s) ;
   s := KillString (s) ;
   RETURN utf8
END InitUnicode ;


(*
   StringInitUTF8 - init a single unicode object defined in string
                    to a UTF8 object.
*)

PROCEDURE StringInitUTF8 (s: String) : UTF8 ;
VAR
   c    : CARDINAL ;
   found: BOOLEAN ;
BEGIN
   IF (Length (s) > 2) AND (char (s, 1) = '+')
   THEN
      (* Skip the u+ or U+ preamble.  *)
      s := Slice (s, 2, 0) ;
      c := StringToCardinal (s, 16, found) ;
      s := KillString (s)
   ELSE
      c := StringToCardinal (s, 16, found)
   END ;
   IF found
   THEN
      RETURN InitUTF8 (c)
   ELSE
      RETURN InitUTF8 (0)
   END
END StringInitUTF8 ;


(*
   Write - write a UTF8 object to file f.
*)

PROCEDURE Write (f: File; utf8: UTF8) ;
VAR
   i: CARDINAL ;
BEGIN
   WITH utf8^ DO
      i := 0 ;
      WHILE i <= high DO
         WriteChar (f, content[i]) ;
         INC (i)
      END
   END
END Write ;


(*
   WriteLn - write a newline to file f.
*)

PROCEDURE WriteLn (f: File) ;
BEGIN
   FIO.WriteLine (f)
END WriteLn ;


BEGIN
   FreeList := NIL
END UTF8.
