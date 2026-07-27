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
   UTF8Array = ARRAY [0..3] OF BYTE ;


(*
   Size -
*)

PROCEDURE Size (utf8: UTF8) : CARDINAL ;
BEGIN
   IF utf8 < 128
   THEN
      RETURN 1
   ELSIF utf8 < 2048
   THEN
      RETURN 2
   ELSIF utf8 < 65536
   THEN
      RETURN 3
   ELSE
      RETURN 4
   END
END Size ;


(*
   InitUTF8Array - initialize a UTF8Array and return the HIGH
                   byte indice.  MAX(CARDINAL) is returned if
                   the utf8 character cannot be encoded.
*)

PROCEDURE InitUTF8 (utf8: CARDINAL; VAR content: UTF8Array) : CARDINAL ;
BEGIN
   IF utf8 < 128
   THEN
      (* Single byte required.  *)
      content[0] := VAL (BYTE, utf8 MOD 256) ;
      RETURN 0
   ELSIF utf8 < 2048
   THEN
      (* Two bytes required.  *)
      content[1] := VAL (BYTE, 128 + utf8 MOD 64) ;   (* 6 bits of data.  *)
      utf8 := utf8 DIV 64 ;
      content[0] := VAL (BYTE, 192 + utf8 MOD 32) ;   (* 5 bits of data.  *)
      RETURN 1
   ELSIF utf8 < 65536
   THEN
      (* Three bytes required.  *)
      content[2] := VAL (BYTE, 128 + utf8 MOD 64) ;   (* 6 bits of data.  *)
      utf8 := utf8 DIV 64 ;
      content[1] := VAL (BYTE, 128 + utf8 MOD 64) ;   (* 6 bits of data.  *)
      utf8 := utf8 DIV 64 ;
      content[0] := VAL (BYTE, 224 + utf8 MOD 16) ;   (* 4 bits of data.  *)
      RETURN 2
   ELSIF utf8 < MAXUTF8
   THEN
      (* All four bytes required.  *)
      content[3] := VAL (BYTE, 128 + utf8 MOD 64) ;   (* 6 bits of data.  *)
      utf8 := utf8 DIV 64 ;
      content[2] := VAL (BYTE, 128 + utf8 MOD 64) ;   (* 6 bits of data.  *)
      utf8 := utf8 DIV 64 ;
      content[1] := VAL (BYTE, 128 + utf8 MOD 64) ;   (* 6 bits of data.  *)
      utf8 := utf8 DIV 64 ;
      content[0] := VAL (BYTE, 240 + utf8 MOD 8) ;    (* 3 bits of data.  *)
      RETURN 3
   END ;
   RETURN MAX(CARDINAL)
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
      RETURN c
   ELSE
      RETURN 0
   END
END StringInitUTF8 ;


(*
   Write - write a UTF8 object to file f.
*)

PROCEDURE Write (f: File; utf8: UTF8) ;
VAR
   i, high: CARDINAL ;
   content: UTF8Array ;
BEGIN
   i := 0 ;
   high := InitUTF8 (utf8, content) ;
   IF high = MAX (CARDINAL)
   THEN
      HALT  (* Should raise an out of range exception.  *)
   ELSE
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


(*
   WriteByteSequence - returns a byte sequence containing uft8.
*)

(*
PROCEDURE WriteByteSequence (utf8: UTF8) : ByteSequence ;
VAR
   i, high: CARDINAL ;
   content: UTF8Array ;
BEGIN
   i := 0 ;
   high := InitUTF8 (utf8, content) ;
   IF high = MAX (CARDINAL)
   THEN
      HALT  (* Should raise an out of range exception.  *)
   ELSE
      RETURN InitByteSequenceBlock (ADR (content), high)
   END
END WriteByteSequence ;
*)


END UTF8.
