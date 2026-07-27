IMPLEMENTATION MODULE Client ;  (*!m2iso+gm2*)

FROM StrIO IMPORT WriteString, WriteLn ;
FROM BinDict IMPORT Dictionary ;
FROM NumberIO IMPORT StrToCard ;
FROM M2RTS IMPORT InstallTerminationProcedure ;
FROM sckt IMPORT tcpClientSocket, tcpClientState, tcpClientConnect ;
FROM StrLib IMPORT StrLen, StrEqual, StrCopy ;
FROM DynamicStrings IMPORT InitString, KillString, string, Length,
                           char, String ;

FROM Selective IMPORT SetOfFd, Timeval, InitTime, KillTime,
                      InitSet, KillSet, ReadCharRaw, Select,
                      FdSet, MaxFdsPlusOne, FdIsSet ;

FROM ASCII IMPORT esc, nl, lf, cr, nul ;
FROM libc IMPORT printf, strlen, write, exit, sleep ;
FROM SYSTEM IMPORT ADR, ADDRESS ;
FROM Options IMPORT ParseArgs ;
FROM TimerHandler IMPORT TicksPerSecond ;  (* Adjust the select timeout to 1/TicksPerSecond.  *)

FROM Screen IMPORT Wall, DrawMan, Treasure, DoorClosed,
                   DrawLineDefault, DrawPointDefault,
                   DoorPointClosed, Arrow, ArrowRev,
                   MakeAnimWalk, MakeEraseMan,
                   Pulse, ExpidateAnim, Hud, RestCursor,
                   DoorClosedToOpen, DoorOpenToClosed,
                   DoorClosedToTimed, DoorTimedToClosed,
                   DoorSecretToClosed,
                   DoorGoggled,
                   Clear, DrawLineDebug ;

FROM FunctionKey IMPORT Sequence, BindFn,
                        BindCursorUp, BindCursorDown,
                        BindCursorLeft, BindCursorRight,
                        BindShiftCursorUp, BindShiftCursorDown,
                        BindShiftCursorLeft, BindShiftCursorRight,
                        BindAltCursorUp, BindAltCursorDown,
                        BindAltCursorLeft, BindAltCursorRight,
                        BindCtrlCursorUp, BindCtrlCursorDown,
                        BindCtrlCursorLeft, BindCtrlCursorRight ;


IMPORT termios ;
IMPORT BinDict ;
IMPORT color ;
IMPORT Options ;
IMPORT Screen ;
IMPORT SFIO, FIO, libc ;

CONST
   MaxKeyword    = 4096 ;
   MaxLineLength = 4096 ;
   MaxWheelDelay = 1000000 ;
   Seconds       = 0 ;
   MicroSecs     = 1000 DIV TicksPerSecond ;

TYPE
   PtrToChar = POINTER TO CHAR ;
   Versions  = (One) ;

VAR
   connection       : tcpClientState ;
   TokenToProc      : Dictionary ;
   keywords         : ARRAY [0..MaxKeyword] OF CHAR ;
   LastKey          : CARDINAL ;
   keyboard,
   socketFd         : INTEGER ;
   Version          : Versions ;
   outputInitialized,
   PlayerActive,
   RawMode,
   PlayerAlive      : BOOLEAN ;
   LineResult       : BOOLEAN ;
   LineNumber       : CARDINAL ;
   Keyword,
   line             : ARRAY [0..MaxLineLength] OF CHAR ;
   input,
   output           : FIO.File ;
   RawState,
   OrigState        : termios.TERMIOS ;
   Orientation      : CARDINAL ;


(*
   stop -
*)

PROCEDURE stop ;
END stop ;


(*
   ConfigureRawTTY -
*)

PROCEDURE ConfigureRawTTY ;
BEGIN
   OrigState := termios.InitTermios () ;
   IF termios.tcgetattr (keyboard, OrigState) # 0
   THEN
      printf ("unable to get the original state of stdin\n");
      exit (1)
   END ;
   RawState := termios.InitTermios () ;
   IF termios.tcgetattr (keyboard, RawState) # 0
   THEN
      printf ("unable to get the original state of stdin\n");
      exit (1)
   END ;
   termios.cfmakeraw (RawState) ;
   IF termios.tcsetattr (keyboard, termios.tcsnow (), RawState) # 0
   THEN
      printf ("failed to put keyboard into raw mode\n") ;
      exit (1)
   END ;
   RawMode := TRUE
END ConfigureRawTTY ;


(*
   Init - return TRUE if a connection to the server is established.
*)

PROCEDURE Init () : BOOLEAN ;
BEGIN
   RawMode := FALSE ;
   outputInitialized := FALSE ;
   ParseArgs ;
   IF Options.InputFile = NIL
   THEN
      (* Use socket and keyboard pair.  *)
      ConfigureRawTTY ;
      connection := tcpClientSocket (string (Options.ServerName),
                                     Options.ServerPort) ;
      socketFd := tcpClientConnect (connection) ;
      printf ("connection to server established\n")
   ELSE
      (* Use file input for testing and disable the keyboard.  *)
      keyboard := -1 ;
      connection := NIL ;
      input := SFIO.OpenToRead (Options.InputFile) ;
      IF FIO.IsError (input)
      THEN
         printf ("unable to open input file\n");
         socketFd := -1
      ELSE
         socketFd := FIO.GetUnixFileDescriptor (input)
      END
   END ;
   (* Set up an optional log file.  *)
   IF Options.OutputFile # NIL
   THEN
      output := SFIO.OpenToWrite (Options.OutputFile) ;
      IF FIO.IsError (output)
      THEN
         printf ("unable to create output file\n");
         socketFd := -1 ;
      ELSE
         outputInitialized := TRUE
      END
   END ;
   RETURN socketFd >= 0
END Init ;


(*
   SetupClass - automatically sets up a player using arguments from the
                command line if necessary.
*)

PROCEDURE SetupClass ;
BEGIN
   Connect (socketFd) ;
   InitClient
END SetupClass ;


(*
   assert -
*)

PROCEDURE assert (condition: BOOLEAN) ;
BEGIN
   IF NOT condition
   THEN
      printf ("assert failed\n");
      exit (1)
   END
END assert ;


(*
   Protocol -
*)

PROCEDURE Protocol ;
BEGIN
   Version := One ;
END Protocol ;


(*
   PlayerId -
*)

PROCEDURE PlayerId ;
END PlayerId ;


(*
   NewroomStartTag -
*)

PROCEDURE NewroomStartTag ;
END NewroomStartTag ;


(*
   NewroomEndTag -
*)

PROCEDURE NewroomEndTag ;
END NewroomEndTag ;


(*
   KillStartTag -
*)

PROCEDURE KillStartTag ;
END KillStartTag ;


(*
   KillEndTag -
*)

PROCEDURE KillEndTag ;
END KillEndTag ;


(*
   DiedStartTag -
*)

PROCEDURE DiedStartTag ;
END DiedStartTag ;


(*
   DiedEndTag -
*)

PROCEDURE DiedEndTag ;
END DiedEndTag ;


(*
   clear -
*)

PROCEDURE clear ;
BEGIN
   Clear
END clear ;


(*
   dA -
*)

PROCEDURE dA ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   Hud (9, "Arrows", str)
END dA ;


(*
   IsEol -
*)

PROCEDURE IsEol (ch: CHAR) : BOOLEAN ;
BEGIN
   RETURN (ch = nl) OR (ch = lf) OR (ch = cr)
END IsEol ;


(*
   Strip -
*)

PROCEDURE Strip (VAR str: ARRAY OF CHAR) ;
VAR
   len: CARDINAL ;
BEGIN
   len := StrLen (str) ;
   WHILE (len > 0) AND
         ((str[len-1] = ' ') OR IsEol (str[len-1])) DO
      str[len-1] := nul ;
      len := StrLen (str)
   END
END Strip ;


(*
   dC -
*)

PROCEDURE dC (no: CARDINAL) ;
VAR
   str: ARRAY [0..19] OF CHAR ;
BEGIN
   CopyString (str) ;
   Strip (str) ;
   Hud (15+no, str, "")
END dC ;


(*
   dCMD -
*)

PROCEDURE dCMD ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   IF StrLen (str) = 1
   THEN
      CASE str[0] OF

      esc: StrCopy ('<esc>', str) |
      cr:  StrCopy ('<cr>', str) |
      lf:  StrCopy ('<lf>', str)

      ELSE
      END
   END ;
   Hud (14, "Command", str)
END dCMD ;


(*
   dF -
*)

PROCEDURE dF ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   Hud (6, "Fatigue", str)
END dF ;


(*
   dM -
*)

PROCEDURE dM ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   Hud (8, "Magic", str)
END dM ;


(*
   dMap -
*)

PROCEDURE dMap ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   Hud (2, "Map", str)
END dMap ;


(*
   dN -
*)

PROCEDURE dN ;
END dN ;


(*
   dR -
*)

PROCEDURE dR ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   Hud (3, "Room", str)
END dR ;


(*
   dT -
*)

PROCEDURE dT ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   Hud (12, "Time", str)
END dT ;


(*
   dW -
*)

PROCEDURE dW ;
VAR
   str   : ARRAY [0..10] OF CHAR ;
   health: CARDINAL ;
BEGIN
   Copy (1, str) ;
   StrToCard (str, health) ;
   Hud (5, "Wounds", str) ;
   IF health = 0
   THEN
      PlayerAlive := FALSE
   END
END dW ;


(*
   dw -
*)

PROCEDURE dw ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   Hud (11, "Weight", str)
END dw ;


(*
   LineArgs - returns the number of args in line.
*)

PROCEDURE LineArgs () : CARDINAL ;
VAR
   i,
   high,
   count: CARDINAL ;
BEGIN
   count := 0 ;
   i := 0 ;
   high := HIGH (line) ;
   WHILE i <= high DO
      IF line[i] = ' '
      THEN
         INC (count)
      ELSIF line[i] = nul
      THEN
         RETURN count
      END ;
      INC (i)
   END ;
   RETURN count
END LineArgs ;


(*
   eraseLine -
*)

PROCEDURE eraseLine ;
VAR
   x0, y0, x1, y1: CARDINAL ;
BEGIN
   GetVector (x0, y0, x1, y1) ;
   DrawLineDefault (x0, y0, x1, y1)
END eraseLine ;


(*
   erasePoint -
*)

PROCEDURE erasePoint ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawPointDefault (x, y)
END erasePoint ;


(*
   eL -
*)

PROCEDURE eL ;
BEGIN
   IF LineArgs () = 4
   THEN
      eraseLine
   ELSE
      erasePoint
   END
END eL ;


(*
   fl -
*)

PROCEDURE fl ;
BEGIN
END fl ;


(*
   open -
*)

PROCEDURE open ;
BEGIN
   eL
END open ;


(*
   closed -
*)

PROCEDURE closed ;
BEGIN
END closed ;


(*
   goggled -
*)

PROCEDURE goggled ;
VAR
   x0, y0, x1, y1: CARDINAL ;
   horiz         : BOOLEAN ;
BEGIN
   horiz := GetDoorVector (x0, y0, x1, y1) ;
   DoorGoggled (x0, y0, x1, y1, horiz)
END goggled ;


(*
   animdooropenclosed -
*)

PROCEDURE animdooropenclosed ;
VAR
   x0, y0, x1, y1: CARDINAL ;
   horiz         : BOOLEAN ;
BEGIN
   horiz := GetDoorVector (x0, y0, x1, y1) ;
   DoorOpenToClosed (x0, y0, x1, y1, horiz)
END animdooropenclosed ;


(*
   animdoorsecretclosed -
*)

PROCEDURE animdoorsecretclosed ;
VAR
   x0, y0, x1, y1: CARDINAL ;
   horiz         : BOOLEAN ;
BEGIN
   horiz := GetDoorVector (x0, y0, x1, y1) ;
   DoorSecretToClosed (x0, y0, x1, y1, horiz)
END animdoorsecretclosed ;


(*
   animdoorclosedtimed -
*)

PROCEDURE animdoorclosedtimed ;
VAR
   x0, y0, x1, y1: CARDINAL ;
   horiz         : BOOLEAN ;
BEGIN
   horiz := GetDoorVector (x0, y0, x1, y1) ;
   DoorClosedToTimed (x0, y0, x1, y1, horiz)
END animdoorclosedtimed ;


(*
   animdoortimedclosed -
*)

PROCEDURE animdoortimedclosed ;
VAR
   x0, y0, x1, y1: CARDINAL ;
   horiz         : BOOLEAN ;
BEGIN
   horiz := GetDoorVector (x0, y0, x1, y1) ;
   DoorTimedToClosed (x0, y0, x1, y1, horiz)
END animdoortimedclosed ;


(*
   Copy - copy the pos word into dest from line.
*)

PROCEDURE Copy (pos: CARDINAL; VAR dest: ARRAY OF CHAR) ;
VAR
   i, j: CARDINAL ;
BEGIN
   i := 0 ;
   WHILE pos > 0 DO
      WHILE NOT delim (line[i]) DO
         INC (i)
      END ;
      WHILE delim (line[i]) DO
         INC (i)
      END ;
      DEC (pos)
   END ;
   j := 0 ;
   WHILE NOT delim (line[i]) DO
      IF j <= HIGH (dest)
      THEN
         dest[j] := line[i] ;
         INC (j)
      ELSE
         RETURN
      END ;
      INC (i)
   END ;
   dest[j] := nul
END Copy ;


(*
   GetVector -
*)

PROCEDURE GetVector (VAR x0, y0, x1, y1: CARDINAL) ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   StrToCard (str, x0) ;
   Copy (2, str) ;
   StrToCard (str, y0) ;
   Copy (3, str) ;
   StrToCard (str, x1) ;
   Copy (4, str) ;
   StrToCard (str, y1)
END GetVector ;


(*
   GetPoint -
*)

PROCEDURE GetPoint (VAR x, y: CARDINAL) ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   StrToCard (str, x) ;
   Copy (2, str) ;
   StrToCard (str, y)
END GetPoint ;


(*
   GetDoorVector -
*)

PROCEDURE GetDoorVector (VAR x0, y0, x1, y1: CARDINAL) : BOOLEAN ;
VAR
   str  : ARRAY [0..10] OF CHAR ;
   horiz: BOOLEAN ;
BEGIN
   Copy (1, str) ;
   IF StrEqual (str, 'hhinge') OR StrEqual (str, 'vhinge')
   THEN
      horiz := str[0] = 'h' ;
      Copy (2, str) ;
      StrToCard (str, x0) ;
      Copy (3, str) ;
      StrToCard (str, y0) ;
      x1 := x0 ;
      y1 := y0
   ELSIF StrEqual (str, 'hdoor') OR StrEqual (str, 'vdoor')
   THEN
      horiz := str[0] = 'h' ;
      Copy (2, str) ;
      StrToCard (str, x0) ;
      Copy (3, str) ;
      StrToCard (str, y0) ;
      Copy (4, str) ;
      StrToCard (str, x1) ;
      Copy (5, str) ;
      StrToCard (str, y1)
   ELSIF StrEqual (str, 'open') OR StrEqual (str, 'closed') OR
         StrEqual (str, 'secret')
   THEN
      Copy (2, str) ;
      StrToCard (str, x0) ;
      Copy (3, str) ;
      StrToCard (str, y0) ;
      Copy (4, str) ;
      StrToCard (str, x1) ;
      Copy (5, str) ;
      StrToCard (str, y1) ;
      horiz := (y0 = y1)
   ELSE
      Copy (1, str) ;
      StrToCard (str, x0) ;
      Copy (2, str) ;
      StrToCard (str, y0) ;
      Copy (3, str) ;
      StrToCard (str, x1) ;
      Copy (4, str) ;
      StrToCard (str, y1) ;
      horiz := (y0 = y1)
   END ;
   RETURN horiz
END GetDoorVector ;


(*
   hvwall - this client does not distinguish between vertical and horizontal
            walls.
*)

PROCEDURE hvwall ;
VAR
   x0, y0, x1, y1: CARDINAL ;
BEGIN
   GetVector (x0, y0, x1, y1) ;
   Wall (x0, y0, x1, y1)
END hvwall ;


(*
   playerid -
*)

PROCEDURE playerid ;
BEGIN

END playerid ;


(*
   nman -
*)

PROCEDURE nman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 0, TRUE) ;
   Orientation := 0
END nman ;


(*
   eman -
*)

PROCEDURE eman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 1, TRUE) ;
   Orientation := 1
END eman ;


(*
   sman -
*)

PROCEDURE sman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 2, TRUE) ;
   Orientation := 2
END sman ;


(*
   wman -
*)

PROCEDURE wman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 3, TRUE) ;
   Orientation := 3
END wman ;


(*
   Nman -
*)

PROCEDURE Nman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 0, FALSE)
END Nman ;


(*
   Eman -
*)

PROCEDURE Eman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 1, FALSE)
END Eman ;


(*
   Sman -
*)

PROCEDURE Sman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 2, FALSE)
END Sman ;


(*
   Wman -
*)

PROCEDURE Wman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DrawMan (x, y, 3, FALSE)
END Wman ;


(*
   sync -
*)

PROCEDURE sync ;
END sync ;


(*
   dC1 -
*)

PROCEDURE dC1 ;
BEGIN
   dC (1)
END dC1 ;


(*
   dC2 -
*)

PROCEDURE dC2 ;
BEGIN
   dC (2)
END dC2 ;


(*
   dC3 -
*)

PROCEDURE dC3 ;
BEGIN
   dC (3)
END dC3 ;


(*
   hvhinge -
*)

PROCEDURE hvhinge ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   DoorPointClosed (x, y)
END hvhinge ;


(*
   hvdoor -
*)

PROCEDURE hvdoor ;
VAR
   x0, y0, x1, y1: CARDINAL ;
BEGIN
   GetVector (x0, y0, x1, y1) ;
   DoorClosed (x0, y0, x1, y1)
END hvdoor ;


(*
   animdoorclosedopen -
*)

PROCEDURE animdoorclosedopen ;
VAR
   x0, y0, x1, y1: CARDINAL ;
   horiz         : BOOLEAN ;
BEGIN
   horiz := GetDoorVector (x0, y0, x1, y1) ;
   (* DrawLineDebug (x0, y0, x1, y1) ;
   sleep (5) ;  *)
   DoorClosedToOpen (x0, y0, x1, y1, horiz)
END animdoorclosedopen ;


(*
   treasure -
*)

PROCEDURE treasure ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   Treasure (x, y)
END treasure ;


(*
   pS -
*)

PROCEDURE pS ;
END pS ;


(*
   sar -
*)

PROCEDURE sar ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   Arrow (x, y, 2)
END sar ;


(*
   war -
*)

PROCEDURE war ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   Arrow (x, y, 3)
END war ;


(*
   nar -
*)

PROCEDURE nar ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   Arrow (x, y, 0)
END nar ;


(*
   ear -
*)

PROCEDURE ear ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   Arrow (x, y, 1)
END ear ;


(*
   combat -
*)

PROCEDURE combat ;
BEGIN
END combat ;


(*
   quit -
*)

PROCEDURE quit ;
BEGIN

END quit ;


(*
   revnar -
*)

PROCEDURE revnar ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   ArrowRev (x, y, 0)
END revnar ;


(*
   revear -
*)

PROCEDURE revear ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   ArrowRev (x, y, 1)
END revear ;


(*
   revsar -
*)

PROCEDURE revsar ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   ArrowRev (x, y, 2)
END revsar ;


(*
   revwar -
*)

PROCEDURE revwar ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   ArrowRev (x, y, 3)
END revwar ;


(*
   CopyString -
*)

PROCEDURE CopyString (VAR contents: ARRAY OF CHAR) ;
VAR
   ch  : CHAR ;
   i, j,
   len : CARDINAL ;
BEGIN
   len := StrLen (line) ;
   i := 0 ;
   WHILE (i < len) AND (line[i] # ' ') DO
      INC (i)
   END ;
   IF i = len
   THEN
      contents[i] := nul
   ELSE
      INC (i) ;
      j := 0 ;
      WHILE (i < len) AND (i <= HIGH (contents)) DO
         contents[j] := line[i] ;
         INC (i) ;
         INC (j)
      END ;
      IF i <= HIGH (contents)
      THEN
         contents[j] := nul
      END
   END
END CopyString ;


(*
   dWriteStr -
*)

PROCEDURE dWriteStr ;
VAR
   contents: ARRAY [0..MaxLineLength] OF CHAR ;
BEGIN
   CopyString (contents) ;
   Screen.dWriteStr (contents)
END dWriteStr ;


(*
   dWriteLn -
*)

PROCEDURE dWriteLn ;
VAR
   contents: ARRAY [0..MaxLineLength] OF CHAR ;
BEGIN
   CopyString (contents) ;
   Screen.dWriteLn (contents)
END dWriteLn ;


(*
   GetAnim -
*)

PROCEDURE GetAnim (VAR fromx, fromy, tox, toy,
                       step, total, delay: CARDINAL) ;
VAR
   str: ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   StrToCard (str, fromx) ;
   Copy (2, str) ;
   StrToCard (str, fromy) ;
   Copy (3, str) ;
   StrToCard (str, tox) ;
   Copy (4, str) ;
   StrToCard (str, toy) ;
   Copy (5, str) ;
   StrToCard (str, step) ;
   Copy (6, str) ;
   StrToCard (str, total) ;
   Copy (7, str) ;
   StrToCard (str, delay)
END GetAnim ;


(*
   animwalk -
*)

PROCEDURE animwalk (newdir: CARDINAL; self: BOOLEAN) ;
VAR
   fromx, fromy, tox, toy,
   step, total, delay    : CARDINAL ;
BEGIN
   GetAnim (fromx, fromy, tox, toy, step, total, delay) ;
   MakeAnimWalk (fromx, fromy, tox, toy,
                 step, 1, total, delay, newdir, self) ;
   Orientation := newdir
END animwalk ;


(*
   animnwalk -
*)

PROCEDURE animnwalk ;
BEGIN
   animwalk (0, TRUE)
END animnwalk ;


(*
   animewalk -
*)

PROCEDURE animewalk ;
BEGIN
   animwalk (1, TRUE)
END animewalk ;


(*
   animswalk -
*)

PROCEDURE animswalk ;
BEGIN
   animwalk (2, TRUE)
END animswalk ;


(*
   animwwalk -
*)

PROCEDURE animwwalk ;
BEGIN
   animwalk (3, TRUE)
END animwwalk ;


(*
   animNwalk -
*)

PROCEDURE animNwalk ;
BEGIN
   animwalk (0, FALSE)
END animNwalk ;


(*
   animEwalk -
*)

PROCEDURE animEwalk ;
BEGIN
   animwalk (1, FALSE)
END animEwalk ;


(*
   animSwalk -
*)

PROCEDURE animSwalk ;
BEGIN
   animwalk (2, FALSE)
END animSwalk ;


(*
   animWwalk -
*)

PROCEDURE animWwalk ;
BEGIN
   animwalk (3, FALSE)
END animWwalk ;


(*
   animeraseman -
*)

PROCEDURE animeraseman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   MakeEraseMan (x, y, TRUE)
END animeraseman ;


(*
   animeraseman -
*)

PROCEDURE animEraseman ;
VAR
   x, y: CARDINAL ;
BEGIN
   GetPoint (x, y) ;
   MakeEraseMan (x, y, FALSE)
END animEraseman ;


(*
   ReportError -
*)

PROCEDURE ReportError (message: ARRAY OF CHAR) ;
BEGIN
   printf ("socket:%d:", LineNumber) ;
   WriteString (message) ; WriteLn ;
   WriteString (line) ; WriteLn ;
   LineResult := FALSE
END ReportError ;


(*
   TranslateLF -
*)

PROCEDURE TranslateLF (VAR dest: ARRAY OF CHAR; src: ARRAY OF CHAR) ;
VAR
   srchigh,
   desthigh,
   di, si  : CARDINAL ;
BEGIN
   di := 0 ;
   si := 0 ;
   srchigh := StrLen (src) ;
   desthigh := HIGH (dest) ;
   WHILE (si < srchigh) AND (di < desthigh) DO
      IF (src[si]='\') AND (si < srchigh) AND (src[si+1]='n')
      THEN
         dest[di] := nl ;
         INC (di) ;
         INC (si, 2)
      ELSE
         dest[di] := src[si] ;
         INC (di) ;
         INC (si)
      END
   END ;
   IF di < desthigh
   THEN
      dest[di] := nul
   END
END TranslateLF ;


(*
   waitUntilLn -
*)

PROCEDURE waitUntilLn (str: ARRAY OF CHAR) ;
BEGIN
   printf ("waitUntilLn: %s\n", str) ;
   TranslateLF (str, str) ;
   REPEAT
      line[0] := nul ;
      WHILE NOT ReadLine () DO
         printf ("waiting for prompt: ") ;
         printf (str) ;
         printf ("\n") ;
      END ;
      printf ("seen: %s\n", line) ;
      printf ("StrEqual against %s\n", str) ;
   UNTIL StrEqual (line, str) ;
   printf ("matched prompt: ") ;
   printf (str) ;
   printf ("\n")
END waitUntilLn ;


(*
   StrMatch -
*)

PROCEDURE StrMatch (left, right: ARRAY OF CHAR; i: CARDINAL) : BOOLEAN ;
VAR
   l,
   leftLen,
   rightLen: CARDINAL ;
BEGIN
   leftLen := StrLen (left) ;
   rightLen := StrLen (right) ;
   l := 0 ;
   WHILE (l < leftLen) AND (i < rightLen) DO
      IF left[l] = right[i]
      THEN
         INC (l) ;
         INC (i)
      ELSE
         RETURN FALSE
      END
   END ;
   RETURN i = rightLen
END StrMatch ;


(*
   waitUntilStr -
*)

PROCEDURE waitUntilStr (str: ARRAY OF CHAR) ;
VAR
   ch     : CHAR ;
   i,
   lineLen,
   strLen : CARDINAL ;
BEGIN
   printf ("waitUntilStr: %s\n", str) ;
   i := 0 ;
   line[i] := nul ;
   TranslateLF (str, str) ;
   strLen := StrLen (str) ;
   (* Read at least len (str) characters in line.  *)
   REPEAT
      IF Read (ch)
      THEN
         line[i] := ch ;
         INC (i) ;
         line[i] := nul
      END ;
      lineLen := strlen (ADR (line))
   UNTIL lineLen >= strLen ;
   printf ("str = %s\n", str) ;
   printf ("line = %s\n", line) ;
   WHILE NOT StrMatch (str, line, lineLen - strLen) DO
      IF Read (ch)
      THEN
         line[i] := ch ;
         INC (i) ;
         line[i] := nul
      END ;
      lineLen := strlen (ADR (line)) ;
      printf ("comparing str = %s vs ", str) ;
      printf ("line = %s\n", line) ;
   END ;
   printf ("matched prompt: ") ;
   printf (str) ;
   printf ("\n")
END waitUntilStr ;


(*
   Connect - establish a connection to server using socket fd.
*)

PROCEDURE Connect (fd: INTEGER) ;
BEGIN
   waitUntilStr ("dC3 to continue\n") ;
   send ("\n") ;
   waitUntilStr ("dWriteStr What character class do you want to play (type help if unsure)? ") ;
   send ("human\n") ;
   waitUntilStr ("dWriteStr What is thy name? ") ;
   sendS (Options.PlayerName) ;
   send ("\n") ;
   waitUntilStr ("clear") ;
   ToggleAnimMode ;
   PlayerActive := TRUE ;
   PlayerAlive := TRUE ;
   line[0] := nul
END Connect ;


(*
   send -
*)

PROCEDURE send (str: ARRAY OF CHAR) ;
BEGIN
   IF Options.InputFile = NIL
   THEN
      sendLower (str)
   END
END send ;


PROCEDURE sendLower (str: ARRAY OF CHAR) ;
VAR
   len, i: CARDINAL ;
   res   : INTEGER ;
BEGIN
   TranslateLF (str, str) ;
   i := 0 ;
   len := StrLen (str) ;
   WHILE i < len DO
      res := write (socketFd, ADR (str[i]), len-i) ;
      IF res > 0
      THEN
         i := i + CARDINAL (res)
      ELSIF res < 0
      THEN
         printf ("socket connection to server failed, exiting\n");
         HALT
      END
   END
END sendLower ;


(*
   sendS -
*)

PROCEDURE sendS (str: String) ;
BEGIN
   IF Options.InputFile = NIL
   THEN
      sendSLower (str)
   END
END sendS ;


PROCEDURE sendSLower (str: String) ;
VAR
   i, len: CARDINAL ;
   ch    : CHAR ;
   res   : INTEGER ;
BEGIN
   len := Length (str) ;
   i := 0 ;
   WHILE i < len DO
      ch := char (str, i) ;
      res := write (socketFd, ADR (ch), 1) ;
      IF res > 0
      THEN
         INC (i)
      ELSIF res < 0
      THEN
         printf ("socket connection to server failed, exiting\n");
         HALT
      END
   END
END sendSLower ;


(*
   ToggleAnimMode -
*)

PROCEDURE ToggleAnimMode ;
BEGIN
   send ("~!") ;  (* Put it into animation mode.  *)
END ToggleAnimMode ;


(*
   HelpInGame -
*)

PROCEDURE HelpInGame ;
BEGIN
   send ("h") ;  (* Activate help screen.  *)
END HelpInGame ;


(*
   InventoryInGame -
*)

PROCEDURE InventoryInGame ;
BEGIN
   send ("i") ;  (* Activate inventory screen.  *)
END InventoryInGame ;


(*
   TurnOrMove -
*)

PROCEDURE TurnOrMove (newdir: CARDINAL; dist: ARRAY OF CHAR) ;
BEGIN
   IF Orientation = newdir
   THEN
      send (dist)
   ELSE
      CASE Orientation OF

      0:  CASE newdir OF

          1: send ("r") |
          2: send ("v") |
          3: send ("l")

          END |
      1:  CASE newdir OF

          0: send ("l") |
          2: send ("r") |
          3: send ("v")

          END |
      2:  CASE newdir OF

          0: send ("v") |
          1: send ("l") |
          3: send ("r")

          END |
      3:  CASE newdir OF

          0: send ("r") |
          1: send ("v") |
          2: send ("l")

          END
      END
   END
END TurnOrMove ;


(*
   MoveUp -
*)

PROCEDURE MoveUp ;
BEGIN
   TurnOrMove (0, '1')
END MoveUp ;


(*
   MoveDown -
*)

PROCEDURE MoveDown ;
BEGIN
   TurnOrMove (2, '1')
END MoveDown ;


(*
   MoveLeft -
*)

PROCEDURE MoveLeft ;
BEGIN
   TurnOrMove (3, '1')
END MoveLeft ;


(*
   MoveRight -
*)

PROCEDURE MoveRight ;
BEGIN
   TurnOrMove (1, '1')
END MoveRight ;


(*
   ShiftMoveUp -
*)

PROCEDURE ShiftMoveUp ;
BEGIN
   TurnOrMove (0, '9')
END ShiftMoveUp ;


(*
   ShiftMoveDown -
*)

PROCEDURE ShiftMoveDown ;
BEGIN
   TurnOrMove (2, '9')
END ShiftMoveDown ;


(*
   ShiftMoveLeft -
*)

PROCEDURE ShiftMoveLeft ;
BEGIN
   TurnOrMove (3, '9')
END ShiftMoveLeft ;


(*
   ShiftMoveRight -
*)

PROCEDURE ShiftMoveRight ;
BEGIN
   TurnOrMove (1, '9')
END ShiftMoveRight ;


(*
   Slide -
*)

PROCEDURE Slide (first, second: CARDINAL) ;
BEGIN
END Slide ;


(*
   AltMoveUp -
*)

PROCEDURE AltMoveUp ;
BEGIN
   CASE Orientation OF

   0:  send ("m") |
   1:  send ("l1r") |
   3:  send ("r1l")

   ELSE
   END
END AltMoveUp ;


(*
   AltMoveDown -
*)

PROCEDURE AltMoveDown ;
BEGIN
   CASE Orientation OF

   1:  send ("r1l") |
   2:  send ("m") |
   3:  send ("l1r")

   ELSE
   END
END AltMoveDown ;


(*
   AltMoveLeft -
*)

PROCEDURE AltMoveLeft ;
BEGIN
   CASE Orientation OF

   0: send ("l1r") |
   2: send ("r1l") |
   3: send ("m")

   ELSE
   END
END AltMoveLeft ;


(*
   AltMoveRight -
*)

PROCEDURE AltMoveRight ;
BEGIN
   CASE Orientation OF

   0: send ("r1l") |
   1: send ("m") |
   2: send ("l1r")

   ELSE
   END
END AltMoveRight ;


(*
   CtrlMoveUp -
*)

PROCEDURE CtrlMoveUp ;
BEGIN
   CASE Orientation OF

   0: send ("f") |
   1: send ("l") |
   2: send ("v") |
   3: send ("r")

   ELSE
   END
END CtrlMoveUp ;


(*
   CtrlMoveRight -
*)

PROCEDURE CtrlMoveRight ;
BEGIN
   CASE Orientation OF

   0: send ("r") |
   1: send ("f") |
   2: send ("l") |
   3: send ("v")

   ELSE
   END
END CtrlMoveRight ;


(*
   CtrlMoveDown -
*)

PROCEDURE CtrlMoveDown ;
BEGIN
   CASE Orientation OF

   0: send ("v") |
   1: send ("r") |
   2: send ("f") |
   3: send ("l")

   ELSE
   END
END CtrlMoveDown ;


(*
   CtrlMoveLeft -
*)

PROCEDURE CtrlMoveLeft ;
BEGIN
   CASE Orientation OF

   0: send ("l") |
   1: send ("v") |
   2: send ("r") |
   3: send ("f")

   ELSE
   END
END CtrlMoveLeft ;


(*
   CheckFunctionKey -
*)

PROCEDURE CheckFunctionKey (ch: CHAR) ;
BEGIN
   IF Sequence (ch)
   THEN
      (* Do nothing.  *)
   ELSE
      IF ch = esc
      THEN
         color.Pos (1, 32) ;
         HALT (0)
      END ;
      write (socketFd, ADR (ch), 1)
   END
END CheckFunctionKey ;


(*
   HandleKey -
*)

PROCEDURE HandleKey ;
VAR
   ch: CHAR ;
BEGIN
   ch := ReadCharRaw (keyboard) ;
   IF outputInitialized
   THEN
      FIO.WriteString (output, "keyboard: ") ;
      FIO.WriteChar (output, ch) ;
      FIO.WriteLine (output) ;
      FIO.FlushBuffer (output)
   END ;
   CheckFunctionKey (ch)
END HandleKey ;


(*
   Read - return TRUE if a character is read.
          return FALSE if a timeout occurs.
*)

PROCEDURE Read (VAR ch: CHAR) : BOOLEAN ;
VAR
   tval: Timeval ;
   inp : SetOfFd ;
   res : INTEGER ;
   read: BOOLEAN ;
BEGIN
   read := FALSE ;
   tval := InitTime (Seconds, MicroSecs) ;
   inp := InitSet () ;
   FdSet (socketFd, inp) ;
   IF keyboard >= 0
   THEN
      FdSet (keyboard, inp)
   END ;
   res := Select (MaxFdsPlusOne (socketFd, keyboard), inp, NIL, NIL, tval) ;
   IF (keyboard >= 0) AND FdIsSet (keyboard, inp)
   THEN
      ExpidateAnim ;  (* We short cut to the final placement of all
                         outstanding animation sequences.  *)
      HandleKey
   END ;
   IF FdIsSet (socketFd, inp)
   THEN
      read := TRUE ;
      ch := ReadCharRaw (socketFd) ;
      LogChar (ch)
   ELSIF res = 0
   THEN
      (* Timeout.  *)
      Pulse
   END ;
   inp := KillSet (inp) ;
   tval := KillTime (tval) ;
   RETURN read
END Read ;


(*
   ReadLine - return TRUE if a line was read.
              return FALSE if a timeout has occurred.
*)

PROCEDURE ReadLine () : BOOLEAN ;
VAR
   i : CARDINAL ;
   ch: CHAR ;
BEGIN
   i := strlen (ADR (line)) ;
   WHILE Read (ch) DO
      line[i] := ch ;
      INC (i) ;
      IF (i = MaxLineLength) OR (ch = nl) OR (ch = lf) OR (ch = cr)
      THEN
         line[i] := nul ;
         INC (LineNumber) ;
         RETURN TRUE
      END
   END ;
   line[i] := nul ;
   RETURN FALSE
END ReadLine ;


(*
   LogLine -
*)

PROCEDURE LogLine ;
BEGIN
   IF (Options.OutputFile # NIL) AND (FIO.IsNoError (output))
   THEN
      FIO.WriteString (output, line) ;
      FIO.WriteLine (output) ;
      FIO.FlushBuffer (output)
   END ;
END LogLine ;


PROCEDURE LogChar (ch: CHAR) ;
BEGIN
   IF (Options.OutputFile # NIL) AND (FIO.IsNoError (output))
   THEN
      FIO.WriteChar (output, ch) ;
      FIO.FlushBuffer (output)
   END
END LogChar ;


(*
   Interpret - interpret the incomming stream of characters
               from the server, monitor the keyboard and the send
               character to the server.
*)

PROCEDURE Interpret ;
VAR
   command: ARRAY [0..3] OF CHAR ;
BEGIN
   SetupKeys ;
   color.Enable (TRUE) ;
   color.Clear ;
   line[0] := nul ;
   WHILE PlayerAlive DO
      IF ReadLine ()
      THEN
         IF PlayerAlive AND ParseLine ()
         THEN
            line[0] := nul ;
            RestCursor
         ELSE
            stop ;
            PlayerActive := FALSE ;
            RETURN
         END
      ELSIF PlayerAlive
      THEN
         (* Timeout, significant time has elapsed since the ReadLine.  *)
         RestCursor
      END
   END
END Interpret ;


(*
   NoCommand -
*)

PROCEDURE NoCommand () : BOOLEAN ;
VAR
   nocommand: ARRAY [0..20] OF CHAR ;
   i, len   : CARDINAL ;
BEGIN
   StrCopy (' No Command', nocommand) ;
   len := StrLen (nocommand) ;
   i := 0 ;
   WHILE i < len DO
      IF line[i] # nocommand[i]
      THEN
         RETURN FALSE
      END ;
      INC (i)
   END ;
   RETURN TRUE
END NoCommand ;


(*
   ParseLine -
*)

PROCEDURE ParseLine () : BOOLEAN ;
BEGIN
   IF (line[0] = nul) OR
      (((line[0] = nl) OR (line[0] = cr)) AND (line[1] = nul)) OR
      NoCommand ()
   THEN
      RETURN TRUE
   ELSE
      RETURN ParseLineContents ()
   END
END ParseLine ;


(*
   GetKeyword -
*)

PROCEDURE GetKeyword ;
VAR
   i, high: CARDINAL ;
BEGIN
   high := HIGH (Keyword) ;
   i := 0 ;
   WHILE (i <= high) AND (line[i] # ' ') DO
      Keyword[i] := line[i] ;
      INC (i)
   END ;
   Keyword[i] := nul
END GetKeyword ;


(*
   ParseLineContents -
*)

PROCEDURE ParseLineContents () : BOOLEAN ;
VAR
   entry: ADDRESS ;
   proc : PROC ;
BEGIN
   GetKeyword ;
   entry := BinDict.Get (TokenToProc, ADR (Keyword[0])) ;
   IF Options.Debug
   THEN
      (* printf ("**LINE: %s", line) *)
   END ;
   IF entry = NIL
   THEN
      printf ("keyword at beginning of the line is not matched\n") ;
      printf ("**LINE: %s\n", line) ;
      printf ("**KEYWORD: %s\n", Keyword) ;
      RETURN FALSE
   ELSE
      LineResult := TRUE ;
      proc := entry ;
      proc
   END ;
   RETURN LineResult
END ParseLineContents ;


(*
   NoDelete -
*)

PROCEDURE NoDelete (unused: ADDRESS) ;
END NoDelete ;


(*
   AddKeyword - dict[keyword] := proc.
*)

PROCEDURE AddKeyword (dict: Dictionary; keyword: ARRAY OF CHAR; proc: PROC) ;
VAR
   key    : ADDRESS ;
   i, high: CARDINAL ;
BEGIN
   key := ADR (keywords[LastKey]) ;
   high := StrLen (keyword) ;
   i := 0 ;
   WHILE i < high DO
      assert (LastKey <= MaxKeyword) ;
      keywords[LastKey] := keyword[i] ;
      INC (LastKey) ;
      INC (i)
   END ;
   assert (LastKey <= MaxKeyword) ;
   keywords[LastKey] := nul ;
   INC (LastKey) ;
   BinDict.Insert (dict, key, proc)
END AddKeyword ;


(*
   PopulateKeywords -
*)

PROCEDURE PopulateKeywords (dict: Dictionary) ;
BEGIN
   AddKeyword (dict, 'protocol', Protocol) ;
   AddKeyword (dict, 'playerid', PlayerId) ;
   AddKeyword (dict, '<newroom>', NewroomStartTag) ;
   AddKeyword (dict, '</newroom>', NewroomEndTag) ;
   AddKeyword (dict, '<kill>', KillStartTag) ;
   AddKeyword (dict, '</kill>', KillEndTag) ;
   AddKeyword (dict, '<died>', DiedStartTag) ;
   AddKeyword (dict, '</died>', DiedEndTag) ;
   AddKeyword (dict, 'clear', clear) ;
   AddKeyword (dict, 'dA', dA) ;
   AddKeyword (dict, 'dCMD', dCMD) ;
   AddKeyword (dict, 'dF', dF) ;
   AddKeyword (dict, 'dM', dM) ;
   AddKeyword (dict, 'dMap', dMap) ;
   AddKeyword (dict, 'dN', dN) ;
   AddKeyword (dict, 'dR', dR) ;
   AddKeyword (dict, 'dT', dT) ;
   AddKeyword (dict, 'dW', dW) ;
   AddKeyword (dict, 'dw', dw) ;
   AddKeyword (dict, 'eL', eL) ;
   AddKeyword (dict, 'fl', fl) ;
   AddKeyword (dict, 'hwall', hvwall) ;
   AddKeyword (dict, 'vwall', hvwall) ;   (* Horizontal and vertical.  *)
   AddKeyword (dict, 'hhinge', hvhinge) ;
   AddKeyword (dict, 'vhinge', hvhinge) ; (* Horizontal and vertical.  *)
   AddKeyword (dict, 'hdoor', hvdoor) ;
   AddKeyword (dict, 'vdoor', hvdoor) ;   (* Horizontal and vertical.  *)
   AddKeyword (dict, 'treasure', treasure) ;
   AddKeyword (dict, 'pS', pS) ;
   AddKeyword (dict, 'dC1', dC1) ;
   AddKeyword (dict, 'dC2', dC2) ;
   AddKeyword (dict, 'dC3', dC3) ;
   AddKeyword (dict, 'nman', nman) ;
   AddKeyword (dict, 'eman', eman) ;
   AddKeyword (dict, 'sman', sman) ;
   AddKeyword (dict, 'wman', wman) ;
   AddKeyword (dict, 'Nman', Nman) ;
   AddKeyword (dict, 'Eman', Eman) ;
   AddKeyword (dict, 'Sman', Sman) ;
   AddKeyword (dict, 'Wman', Wman) ;
   AddKeyword (dict, 'sync', sync) ;
   AddKeyword (dict, 'dWriteLn', dWriteLn) ;
   AddKeyword (dict, 'dWriteStr', dWriteStr) ;
   AddKeyword (dict, 'nar', nar) ;
   AddKeyword (dict, 'ear', ear) ;
   AddKeyword (dict, 'sar', sar) ;
   AddKeyword (dict, 'war', war) ;
   AddKeyword (dict, 'revnar', revnar) ;
   AddKeyword (dict, 'revear', revear) ;
   AddKeyword (dict, 'revsar', revsar) ;
   AddKeyword (dict, 'revwar', revwar) ;
   AddKeyword (dict, 'combat', combat) ;
   AddKeyword (dict, 'quit', quit) ;
   AddKeyword (dict, 'animnrun', animnwalk) ;
   AddKeyword (dict, 'animerun', animewalk) ;
   AddKeyword (dict, 'animsrun', animswalk) ;
   AddKeyword (dict, 'animwrun', animwwalk) ;
   AddKeyword (dict, 'animnwalk', animnwalk) ;
   AddKeyword (dict, 'animewalk', animewalk) ;
   AddKeyword (dict, 'animswalk', animswalk) ;
   AddKeyword (dict, 'animwwalk', animwwalk) ;
   AddKeyword (dict, 'animeraseman', animeraseman) ;
   AddKeyword (dict, 'animdoorclosedopen', animdoorclosedopen) ;
   AddKeyword (dict, 'animdooropenclosed', animdooropenclosed) ;
   AddKeyword (dict, 'animdoorclosedtimed', animdoorclosedtimed) ;
   AddKeyword (dict, 'animdoortimedclosed', animdoortimedclosed) ;
   AddKeyword (dict, 'animdoorsecretclosed', animdoorsecretclosed) ;
   AddKeyword (dict, 'goggled', goggled) ;
   AddKeyword (dict, 'open', open) ;
   AddKeyword (dict, 'closed', closed) ;
   AddKeyword (dict, 'animNrun', animNwalk) ;
   AddKeyword (dict, 'animErun', animEwalk) ;
   AddKeyword (dict, 'animSrun', animSwalk) ;
   AddKeyword (dict, 'animWrun', animWwalk) ;
   AddKeyword (dict, 'animNwalk', animNwalk) ;
   AddKeyword (dict, 'animEwalk', animEwalk) ;
   AddKeyword (dict, 'animSwalk', animSwalk) ;
   AddKeyword (dict, 'animWwalk', animWwalk) ;
   AddKeyword (dict, 'animEraseman', animEraseman) ;
END PopulateKeywords ;


(*
   delim - return TRUE if ch is nul or ' '.
*)

PROCEDURE delim (ch: CHAR) : BOOLEAN ;
BEGIN
   RETURN (ch = nul) OR (ch = ' ') OR (ch = nl)
END delim ;


(*
   compare - return -1 if left < right.
             return +1 if left > right.
             return  0 if left = right.
*)

PROCEDURE compare (left, right: ADDRESS) : INTEGER ;
VAR
   lp, rp: PtrToChar ;
BEGIN
   lp := left ;
   rp := right ;
   WHILE (NOT delim (lp^)) AND (NOT delim (rp^)) DO
      IF lp^ < rp^
      THEN
         RETURN -1
      ELSIF lp^ > rp^
      THEN
         RETURN +1
      END ;
      INC (lp) ;
      INC (rp)
   END ;
   IF delim (lp^) AND delim (rp^)
   THEN
      RETURN 0
   ELSIF delim (lp^)
   THEN
      RETURN -1
   ELSE
      RETURN +1
   END
END compare ;


(*
   RestoreTTY -
*)

PROCEDURE RestoreTTY ;
BEGIN
   IF RawMode AND (keyboard >= 0)
   THEN
      IF termios.tcsetattr (keyboard, termios.tcsnow (), OrigState) # 0
      THEN
         printf ("failed to put keyboard into raw mode, falling back to system\n") ;
         libc.system (ADR ("stty sane"))
      END
   END ;
   IF (Options.OutputFile # NIL) AND (FIO.IsNoError (output))
   THEN
      FIO.Close (output)
   END
END RestoreTTY ;


(*
   InitClient -
*)

PROCEDURE InitClient ;
BEGIN
   LineNumber := 0 ;
   IF InstallTerminationProcedure (RestoreTTY)
   THEN
   END ;
   PlayerActive := FALSE ;
   PlayerAlive := TRUE ;
   TokenToProc := BinDict.Init (compare, NoDelete, NoDelete) ;
   LastKey := 0 ;
   PopulateKeywords (TokenToProc)
END InitClient ;


(*
   SetupKeys -
*)

PROCEDURE SetupKeys ;
BEGIN
   BindFn (1, HelpInGame) ;
   BindFn (2, InventoryInGame) ;
   BindFn (12, ToggleAnimMode) ;

   BindCursorUp (MoveUp) ;
   BindCursorDown (MoveDown) ;
   BindCursorLeft (MoveLeft) ;
   BindCursorRight (MoveRight) ;

   BindShiftCursorUp (ShiftMoveUp) ;
   BindShiftCursorDown (ShiftMoveDown) ;
   BindShiftCursorLeft (ShiftMoveLeft) ;
   BindShiftCursorRight (ShiftMoveRight) ;

   BindAltCursorUp (AltMoveUp) ;
   BindAltCursorDown (AltMoveDown) ;
   BindAltCursorLeft (AltMoveLeft) ;
   BindAltCursorRight (AltMoveRight) ;

   BindCtrlCursorUp (CtrlMoveUp) ;
   BindCtrlCursorDown (CtrlMoveDown) ;
   BindCtrlCursorLeft (CtrlMoveLeft) ;
   BindCtrlCursorRight (CtrlMoveRight)
END SetupKeys ;


END Client.
