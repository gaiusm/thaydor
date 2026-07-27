IMPLEMENTATION MODULE AdvCheckpoint ;

IMPORT FIO, SFIO, ARRAYOFCHAR, DynamicStrings ;

FROM StrLib IMPORT StrLen ;
FROM String IMPORT Write, WriteLn ;
FROM AdvSystem IMPORT MaxNoOfPlayers, PlayerNo, Player ;
FROM Storage IMPORT ALLOCATE ;
FROM NumberIO IMPORT HexToStr, CardToStr ;
FROM DynamicStrings IMPORT String, InitString, KillString ;
FROM FormatStrings IMPORT Sprintf2 ;
FROM StringFileSysOp IMPORT Exists, IsDir ;
FROM libc IMPORT printf, exit ;
FROM FIO IMPORT File, StdOut, WriteNBytes, FlushBuffer ;
FROM Executive IMPORT SEMAPHORE, InitSemaphore, Wait, Signal ;
FROM SYSTEM IMPORT ADR ;



CONST
   MaxBufferSize = 1024 ;
   Version = "1.0" ;
   Verbose = TRUE ;

TYPE
   Buffer = POINTER TO RECORD
                          buf    : ARRAY [0..MaxBufferSize] OF CHAR ;
                          nextpos: CARDINAL ;
                          next   : Buffer ;
                       END ;

VAR
   Slot          : ARRAY [0..MaxNoOfPlayers] OF Buffer ;
   Enabled       : BOOLEAN ;
   CPFile        : File ;
   CPMutex       : SEMAPHORE ;
   CheckPointName: String ;
   FileOpened    : BOOLEAN ;


(*
   writeString -
*)

PROCEDURE writeString (a: ARRAY OF CHAR) ;
VAR
   i, n: CARDINAL ;
BEGIN
   i := 0 ;
   n := StrLen (a) ;
   WHILE i < n DO
      IF (a[i] = '\') AND (i+1 < n) AND (a[i+1] = 'n')
      THEN
         WriteLn (CPFile) ;
         INC (i)
      ELSE
         FIO.WriteChar (CPFile, a[i])
      END ;
      INC (i)
   END
END writeString ;


(*
   CreateNewFile - creates a new checkpoint file in dir.
*)

PROCEDURE CreateNewFile (dir: String) ;
VAR
   i: CARDINAL ;
BEGIN
   i := 0 ;
   CheckPointName := NIL ;
   REPEAT
      INC (i) ;
      IF CheckPointName # NIL
      THEN
         CheckPointName := KillString (CheckPointName)
      END ;
      CheckPointName := Sprintf2 (InitString ('%s/%06d.cpt'), dir, i) ;
   UNTIL NOT Exists (CheckPointName) ;
   IF Verbose
   THEN
      ARRAYOFCHAR.Write (StdOut, 'checkpointing to file: ') ;
      Write (StdOut, CheckPointName) ; WriteLn (StdOut)
   END ;
END CreateNewFile ;


(*
   ForceOpenFile - opens the newfile and writes the protocol version.
*)

PROCEDURE ForceOpenFile ;
BEGIN
   IF NOT FileOpened
   THEN
      FileOpened := TRUE ;
      CPFile := SFIO.OpenToWrite (CheckPointName) ;
      FIO.WriteString (CPFile, "protocol version ") ;
      FIO.WriteString (CPFile, Version) ;
      WriteLn (CPFile) ;
      FIO.FlushBuffer (CPFile) ;
      CheckPointName := KillString (CheckPointName)
   END
END ForceOpenFile ;


(*
   CheckpointEnable - enable/disable checkpointing.
*)

PROCEDURE CheckpointEnable (on: BOOLEAN; dir: String) ;
BEGIN
   Enabled := on ;
   IF Enabled
   THEN
      IF IsDir (dir)
      THEN
         CreateNewFile (dir)
      ELSE
         printf ("checkpoint directory does not exist\n") ;
         exit (1)
      END
   END
END CheckpointEnable ;


(*
   CheckpointWrite - capture a single character of the frame
                     and buffer it until a checkpoint is reached.
*)

PROCEDURE CheckpointWrite (p: CARDINAL; ch: CHAR) ;
VAR
   bptr: Buffer ;
BEGIN
   IF Enabled
   THEN
      bptr := FindNonEmpty (Slot[p]) ;
      (* bptr might be NIL, at the beginning the splash screen
         it will NIL as the player has not decided their character
         class yet.  *)
      IF bptr # NIL
      THEN
         bptr^.buf[bptr^.nextpos] := ch ;
         INC (bptr^.nextpos)
      END
   END
END CheckpointWrite ;


(*
   CheckpointEnter - player enters the game.
*)

PROCEDURE CheckpointEnter (p: CARDINAL) ;
VAR
   bptr: Buffer ;
BEGIN
   IF Enabled
   THEN
      bptr := FindNonEmpty (Slot[p]) ;
      IF bptr = NIL
      THEN
         NEW (bptr) ;
         Initialize (bptr) ;
         Slot[p] := bptr
      END
   END
END CheckpointEnter ;


(*
   FindNonEmpty - return the first non empty slot.
*)

PROCEDURE FindNonEmpty (bptr: Buffer) : Buffer ;
BEGIN
   WHILE (bptr # NIL) AND (bptr^.nextpos = MaxBufferSize) DO
      IF bptr^.next = NIL
      THEN
         NEW (bptr^.next) ;
         Initialize (bptr^.next) ;
      END ;
      bptr := bptr^.next
   END ;
   RETURN bptr
END FindNonEmpty ;


(*
   Initialize - initialize bptr to empty.
*)

PROCEDURE Initialize (bptr: Buffer) ;
BEGIN
   WITH bptr^ DO
      nextpos := 0 ;
      next := NIL
   END
END Initialize ;


(*
   CheckpointReset - empty all buffers belonging to calling player.
*)

PROCEDURE CheckpointReset (p: CARDINAL) ;
VAR
   bptr: Buffer ;
BEGIN
   IF Enabled
   THEN
      bptr := Slot[p] ;
      WHILE bptr # NIL DO
         bptr^.nextpos := 0 ;
         bptr := bptr^.next
      END
   END
END CheckpointReset ;


(*
   CheckpointKill - flush the checkpoint buffer and tag it as a kill.
                    Player killed someone, record it.
*)

PROCEDURE CheckpointKill (p: CARDINAL) ;
BEGIN
   IF Enabled
   THEN
      CheckpointDump (p, 'kill')
   END
END CheckpointKill ;


(*
   writePlayer -
*)

PROCEDURE writePlayer (p: CARDINAL) ;
VAR
   str: ARRAY [0..20] OF CHAR ;
BEGIN
   writeString ('playerid ') ;
   CardToStr (p, 0, str) ;
   writeString (str) ;
   writeString (' playername ') ;
   writeString (Player[p].Entity.Name) ;
   writeString ('\n')
END writePlayer ;


(*
   writeBuffer -
*)

PROCEDURE writeBuffer (p: CARDINAL) ;
VAR
   n   : CARDINAL ;
   bptr: Buffer ;
BEGIN
   bptr := Slot[p] ;
   WHILE bptr # NIL DO
      n := 0 ;
      REPEAT
         n := WriteNBytes (CPFile, bptr^.nextpos - n, ADR (bptr^.buf[n])) ;
      UNTIL n >= bptr^.nextpos ;
      bptr := bptr^.next
   END
END writeBuffer ;


(*
   CheckpointDump -
*)

PROCEDURE CheckpointDump (p: CARDINAL; str: ARRAY OF CHAR) ;
BEGIN
   ForceOpenFile ;
   writeString ('<') ;
   writeString (str) ;
   writeString ('>\n') ;
   writePlayer (p) ;
   Wait (CPMutex) ;
   writeBuffer (p) ;  (* Protect file IO using mutex.  *)
   Signal (CPMutex) ;
   writeString ('</') ;
   writeString (str) ;
   writeString ('>\n') ;
   Wait (CPMutex) ;
   FlushBuffer (CPFile) ;  (* Protect file IO using mutex.  *)
   Signal (CPMutex) ;
   CheckpointReset (p)
END CheckpointDump ;


(*
   CheckpointDied - reset the checkpoint buffer.  Record the player died.
*)

PROCEDURE CheckpointDied (p: CARDINAL) ;
BEGIN
   IF Enabled
   THEN
      CheckpointDump (p, 'died')
   END
END CheckpointDied ;


(*
   CheckpointNewRoom - player has moved into a new room tag this as a newroom.
*)

PROCEDURE CheckpointNewRoom (p: CARDINAL) ;
BEGIN
   IF Enabled
   THEN
      CheckpointDump (p, 'newroom')
   END
END CheckpointNewRoom ;


(*
   CheckpointInit - initialize the checkpoint buffer for player.
*)

PROCEDURE CheckpointInit ;
BEGIN
   IF Enabled
   THEN
      CheckpointReset (PlayerNo ())
   END
END CheckpointInit ;


(*
   CheckpointStatus - write out checkpoint status.
*)

PROCEDURE CheckpointStatus ;
BEGIN
   IF Enabled
   THEN

   END
END CheckpointStatus ;


(*
   CheckpointFinish - flush any pending checkpoints and terminate the game server.
*)

PROCEDURE CheckpointFinish ;
BEGIN
   HALT (0)
END CheckpointFinish ;


(*
   Init -
*)

PROCEDURE Init ;
VAR
   i: CARDINAL ;
BEGIN
   FileOpened := FALSE ;
   CheckPointName := NIL ;
   CPMutex := InitSemaphore (1, 'CPMutex') ;
   CheckpointEnable (FALSE, NIL) ;
   FOR i := 0 TO MaxNoOfPlayers DO
      Slot[i] := NIL
   END
END Init ;


BEGIN
   Init
END AdvCheckpoint.
