IMPLEMENTATION MODULE AI ;

FROM SYSTEM IMPORT BYTE, ADR, ADDRESS ;
FROM Storage IMPORT ALLOCATE ;
FROM ASCII IMPORT nul ;
FROM libc IMPORT memset, printf ;
FROM StrLib IMPORT StrCopy, StrLen ;
FROM Builtins IMPORT memcmp, memcpy ;
FROM DynamicStrings IMPORT String, Length, Slice, Mark, ConCat,
                           InitString, KillString, Index, char, string ;

IMPORT Options ;

TYPE
   Image = POINTER TO RECORD
                         content: ImageContent ;
                         cmd    : ARRAY [0..3] OF CHAR ;
                         score  : INTEGER ;
                         count  : INTEGER ;
                         who    : CARDINAL ;
                         dt     : CARDINAL ;  (* Time since last command
                                                 in 1/10s of a second.  *)
                         next   : Image ;
                      END ;

   ImageContent = ARRAY [0..MaxX], [0..MaxY] OF ByteSet ;

   ByteSet = SET OF [0..7] ;

   DoubleLink = RECORD
                   Head,
                   Tail: Image ;
                END ;

   Candidate = RECORD
                  image: Image ;
                  diff : CARDINAL ;  (* No of bits different.  *)
               END ;

CONST
   MaxX = 63 ;
   MaxY = 63 ;
   MaxNeighbours = 19 ;

VAR
   FreeList  : Image ;
   DataBase  : DoubleLink ;
   Best      : ARRAY [0..MaxNeighbours] OF Candidate ;
   RandomSeed: CARDINAL ;


(*
   InitImage - return a new blank image.
*)

PROCEDURE InitImage () : Image ;
VAR
   im: Image ;
BEGIN
   NewImage (im) ;
   WITH im^ DO
      memset (ADR (content), 0, (MaxX+1) * (MaxY+1)) ;
      cmd[0] := nul ;
      score := 0 ;
      count := 0 ;
      who := 0 ;
      dt := 0 ;
      next := NIL
   END ;
   RETURN im
END InitImage ;


(*
   ClearImage - erase the image content.
*)

PROCEDURE ClearImage (im: Image) ;
BEGIN
   memset (ADR (im^.content), 0, (MaxX+1) * (MaxY+1))
END ClearImage ;


(*
   CopyImage - copies the image content from src to dest.
               It copies the bitmap and also score and count.
*)

PROCEDURE CopyImage (dest, src: Image) ;
BEGIN
   dest^.content := src^.content ;
   dest^.score := src^.score ;
   dest^.count := dest^.count
END CopyImage ;


(*
   SetCmd - assign the command to image.
*)

PROCEDURE SetCmd (im: Image; command: ARRAY OF CHAR) ;
BEGIN
   StrCopy (command, im^.cmd)
END SetCmd ;


(*
   SetScore - set score to image im.
*)

PROCEDURE SetScore (im: Image; val: INTEGER) ;
BEGIN
   im^.score := val
END SetScore ;


(*
   DisposeImage -
*)

PROCEDURE DisposeImage (im: Image) ;
BEGIN
   im^.next := FreeList ;
   FreeList := im
END DisposeImage ;


(*
   NewImage -
*)

PROCEDURE NewImage (VAR im: Image) ;
BEGIN
   IF FreeList = NIL
   THEN
      NEW (im)
   ELSE
      im := FreeList ;
      FreeList := FreeList^.next
   END
END NewImage ;


(*
   Plot - places value at position [x, y] in image.
*)

PROCEDURE Plot (im: Image; x, y: CARDINAL; value: ByteSet) ;
BEGIN
   im^.content[x, y] := value
END Plot ;


(*
   ExactMatch -
*)

PROCEDURE ExactMatch (im: Image) : BOOLEAN ;
VAR
   h: Image ;
BEGIN
   h := DataBase.Head ;
   WHILE h # NIL DO
      IF memcmp (ADR (h^.content),
                 ADR (im^.content),
                 SIZE (im^.content)) = 0
      THEN
         INC (h^.count) ;
         h^.score := h^.score + im^.score ;
         printf ("\nmatched %d times, score %d\n", h^.count, h^.score) ;
         RETURN TRUE
      END ;
      h := h^.next
   END ;
   RETURN FALSE
END ExactMatch ;


(*
   AddNew -
*)

PROCEDURE AddNew (im: Image) ;
BEGIN
   IF DataBase.Tail = NIL
   THEN
      DataBase.Head := im ;
      DataBase.Tail := im ;
   ELSE
      DataBase.Tail^.next := im ;
      DataBase.Tail := im
   END ;
   im^.next := NIL ;
   im^.count := 1
END AddNew ;


(*
   AddToDB - add image im to the end of the data base of images.
*)

PROCEDURE AddToDB (im: Image) ;
BEGIN
   IF ExactMatch (im)
   THEN
      DisposeImage (im)
   ELSE
      AddNew (im)
   END
END AddToDB ;


(*
   CmdPresent - return TRUE if image contains a command.
*)

PROCEDURE CmdPresent (im: Image) : BOOLEAN ;
BEGIN
   RETURN im^.cmd[0] # nul
END CmdPresent ;


(*
   Random - return a random value 0..n-1.
*)

PROCEDURE Random (n: CARDINAL) : CARDINAL ;
VAR
   r, ms: CARDINAL ;
BEGIN
   IF n = 1
   THEN
      r := 0
   ELSE
      r := RandomSeed MOD n ;
      ms := RandomSeed MOD 256 ;
      RandomSeed := ms * 257 ;
      IF (MAX(CARDINAL)-RandomSeed) >= 0ABCDH  (* Add 0ABCDH *)
      THEN
         INC (RandomSeed, 0ABCDH)
      ELSE
         DEC (RandomSeed, (MAX(CARDINAL)-0ABCDH))
      END
   END ;
   RETURN r
END Random ;


(*
   SumSymmetricDifferenceBitset -
*)

PROCEDURE SumSymmetricDifferenceBitset (left, right: Image) : CARDINAL ;
TYPE
   BitsetArray = POINTER TO ARRAY [0..SIZE (ImageContent) DIV SIZE (BITSET)] OF BITSET ;
VAR
   pl, pr: BitsetArray ;
   diff  : BITSET ;
   j, i,
   total : CARDINAL ;
BEGIN
   total := 0 ;
   pl := ADR (left^.content) ;
   pr := ADR (right^.content) ;
   FOR i := 0 TO HIGH (pl^) DO
      diff := pl^[i] - pr^[i] ;
      FOR j := 0 TO MAX (BITSET) DO
         IF j IN diff
         THEN
            INC (total)
         END
      END
   END ;
   RETURN total
END SumSymmetricDifferenceBitset ;


(*
   SumSymmetricDifference -
*)

PROCEDURE SumSymmetricDifference (left, right: Image) : CARDINAL ;
BEGIN
   IF left = right
   THEN
      RETURN 0
   ELSE
      RETURN SumSymmetricDifferenceBitset (left, right)
   END
END SumSymmetricDifference ;


(*
   SortBest - sort Best into best move first.
*)

PROCEDURE SortBest (k: CARDINAL; VAR count, n: CARDINAL) ;
VAR
   temp   : Candidate ;
   i, j   : CARDINAL ;
   changed: BOOLEAN ;
BEGIN
   changed := TRUE ;
   i := 0 ;
   WHILE changed AND (i < n-1) DO
      changed := FALSE ;
      j := 0 ;
      WHILE j < n - i -1 DO
         IF Best[j].diff > Best[j+1].diff
         THEN
            temp := Best[j] ;
            Best[j] := Best[j+1] ;
            Best[j+1] := temp ;
            changed := TRUE
         END ;
         INC (j)
      END ;
      INC (i)
   END ;
   (* And recalculate n, count.  *)
   n := 0 ;
   count := 0 ;
   WHILE count < k DO
      INC (count, Best[n].image^.count) ;
      INC (n)
   END
END SortBest ;


(*
   DumpBest -
*)

PROCEDURE DumpBest (count, k: CARDINAL) ;
VAR
   i, c: CARDINAL ;
BEGIN
   i := 0 ;
   c := 0 ;
   WHILE (c < k) AND (Best[i].image # NIL) DO
      printf ("Best[%d] score = %d", i, Best[i].image^.score);
      printf (" count = %d", Best[i].image^.count);
      printf (" cmd = %s\n", ADR (Best[i].image^.cmd));
      INC (c, Best[i].image^.count) ;
      INC (i)
   END
END DumpBest ;


(*
   FindBest - find the best response to the image and assign the command.
              It chooses the best from the k nearest neighbours.
*)

PROCEDURE FindBest (im: Image; k: CARDINAL; VAR command: ARRAY OF CHAR) ;
VAR
   i,
   cand,
   choice,
   count : CARDINAL ;
   best  : INTEGER ;
BEGIN
   FindCandidates (im, k) ;
   (* They are now in sorted order of match closeness.  *)
   (* Now choose the highest score.  *)
   best := MIN (INTEGER) ;
   choice := 0 ;
   i := 0 ;
   cand := 0 ;
   count := 0 ;
   WHILE (count < k) AND (Best[i].image # NIL) DO
      IF best = Best[i].image^.score
      THEN
         INC (cand)
      ELSIF best < Best[i].image^.score
      THEN
         cand := 1 ;
         best := Best[i].image^.score ;
         choice := i
      END ;
      INC (count, Best[i].image^.count) ;
      INC (i)
   END ;
   IF cand > 1
   THEN
      printf ("%d candidates give the same score\n", cand);
      cand := Random (cand) + 1 ;
      printf ("choosing %d candidate\n", cand);
      count := 0 ;
      i := 0 ;
      WHILE (count < k) AND (cand > 0) DO
         IF best = Best[i].image^.score
         THEN
            choice := i ;
            printf ("slot %d\n", i);
            DEC (cand)
         END ;
         INC (count, Best[i].image^.count) ;
         INC (i)
      END
   END ;
   DumpBest (count, k) ;
   IF best >= 0
   THEN
      CopyCmd (command, choice) ;
      printf ("best: %s\n", ADR (command))
   ELSE
      AvoidKill (k, command) ;
      printf ("avoid kill using: %s\n", ADR (command))
   END
END FindBest ;


(*
   RemoveCommand - remove cmd from possibility and return the new string.
*)

PROCEDURE RemoveCommand (possibility: String; cmd: ARRAY OF CHAR) : String ;
VAR
   len,
   i  : CARDINAL ;
BEGIN
   IF StrLen (cmd) = 1
   THEN
      len := Length (possibility) ;
      i := 0 ;
      WHILE i < len DO
         IF char (possibility, i) = cmd[0]
         THEN
            IF i = 0
            THEN
               possibility := Slice (Mark (possibility), 1, 0)
            ELSE
               IF i < len
               THEN
                  possibility := ConCat (Slice (Mark (possibility), 0, i),
                                         Slice (Mark (possibility), i+1, 0))
               ELSE
                  possibility := Slice (Mark (possibility), 0, i)
               END
            END ;
            RETURN possibility
         END ;
         INC (i)
      END
   END ;
   RETURN possibility
END RemoveCommand ;


(*
   AvoidKill - all k images result in a loss so we choose a random other command.
*)

PROCEDURE AvoidKill (k: CARDINAL; VAR command: ARRAY OF CHAR) ;
VAR
   possibility: String ;
   i,
   count,
   len        : CARDINAL ;
BEGIN
   possibility := InitString ('rlvpatoc123456789fmg') ;
   i := 0 ;
   count := 0 ;
   WHILE (count < k) AND (Best[i].image # NIL) DO
      possibility := RemoveCommand (possibility, Best[i].image^.cmd) ;
      INC (count, Best[i].image^.count) ;
      INC (i)
   END ;
   len := Length (possibility) ;
   IF len = 0
   THEN
      command[0] := '0'  (* This should be very rare,
                            basically dont know what to do.  *)
   ELSE
      command[0] := char (possibility, Random (len))
   END ;
   command[1] := nul ;
   possibility := KillString (possibility)
END AvoidKill ;


(*
   CopyCmd - copy the command from the choice image in the Best array.
*)

PROCEDURE CopyCmd (VAR command: ARRAY OF CHAR; choice: CARDINAL) ;
VAR
   acc, i: CARDINAL ;
BEGIN
   acc := 0 ;
   i := 0 ;
   REPEAT
      INC (acc, Best[i].image^.count) ;
      INC (i) ;
   UNTIL acc > choice ;
   StrCopy (Best[i-1].image^.cmd, command)
END CopyCmd ;


(*
   FindCandidates - populate the Best array with the k best images.
*)

PROCEDURE FindCandidates (im: Image; k: CARDINAL) ;
VAR
   BitsDiff,
   count,
   i       : CARDINAL ;
   h       : Image ;
BEGIN
   h := DataBase.Head ;
   i := 0 ;
   count := 0 ;
   WHILE h # NIL DO
      BitsDiff := SumSymmetricDifference (h, im) ;
      IF count < k
      THEN
         (* We have empty slots, continue to fill the first, k.  *)
         Best[i].image := h ;
         Best[i].diff := BitsDiff ;
         INC (count, h^.count) ;
         IF count = k
         THEN
            (* We sort now so that from now on the least best is
               last in the Best array.  We only need to compare this
               entry with new frames.  *)
            SortBest (k, count, i)
         ELSE
            INC (i)
         END
      ELSIF Best[i-1].diff > BitsDiff  (* Checking least best frame.  *)
      THEN
         (* All slots full, but we have found a closer matching image.  *)
         Best[i].image := h ;
         Best[i].diff := BitsDiff ;
         SortBest (k, count, i)
      END ;
      h := h^.next
   END
END FindCandidates ;


(*
   Init -
*)

PROCEDURE Init ;
BEGIN
   FreeList := NIL ;
   DataBase.Head := NIL ;
   DataBase.Tail := NIL ;
   RandomSeed := Options.Seed
END Init ;


BEGIN
   Init
END AI.
