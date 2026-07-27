IMPLEMENTATION MODULE LoadCheckpoint ;

FROM BinDict IMPORT Dictionary ;
FROM SYSTEM IMPORT ADR, ADDRESS ;
FROM Storage IMPORT ALLOCATE ;
FROM ASCII IMPORT nul, bs, nl, lf, cr ;
FROM libc IMPORT printf, exit, write, read, strlen ;
FROM Builtins IMPORT strcmp ;
FROM FIO IMPORT File, IsError, ReadString, Close, EOF ;
FROM SFIO IMPORT OpenToRead ;
FROM StrIO IMPORT WriteString, WriteLn ;
FROM FormatStrings IMPORT Sprintf2 ;
FROM StrLib IMPORT StrLen, StrEqual ;
FROM NumberIO IMPORT StrToCard ;
FROM M2RTS IMPORT InstallTerminationProcedure ;

FROM Selective IMPORT SetOfFd, Timeval, InitTime, KillTime,
                      InitSet, KillSet, ReadCharRaw, Select,
                      FdSet ;

FROM AI IMPORT Image, InitImage, ClearImage, SetCmd, Plot,
               AddToDB, FindBest, CmdPresent, SetScore,
               CopyImage ;

FROM DynamicStrings IMPORT InitString, KillString, string, Length,
                           char ;

IMPORT BinDict, SFIO, FIO, libc, Options, colors ;


CONST
   MaxKeyword    = 4096 ;
   MaxLineLength = 4096 ;
   MaxWheelDelay = 1000000 ;
   Seconds       = 1 ;
   MicroSecs     = 800 ;

TYPE
   PtrToChar = POINTER TO CHAR ;
   Versions = (One) ;
   ByteSet = SET OF [0..7] ;
   Colour = (White, Default, Red, Green, Blue, Magenta, Yellow) ;

CONST
   North = ByteSet {} ;
   East = ByteSet {0} ;
   South = ByteSet {1} ;
   West = ByteSet {0, 1} ;
   Self = ByteSet {2, 3, 4, 5, 6, 7} ;
   SelfN = North + Self ;
   SelfE = East + Self ;
   SelfS = South + Self ;
   SelfW = West + Self ;
   Enemy = ByteSet {2, 3, 4, 5, 6} ;
   EnemyN = North + Enemy ;
   EnemyE = East + Enemy ;
   EnemyS = South + Enemy ;
   EnemyW = West + Enemy ;
   Wall = ByteSet {0, 1, 2, 3, 4, 5} ;
   Door = ByteSet {0, 1, 2, 3, 4} ;
   Treasure = ByteSet {0, 1, 2, 3} ;
   Arrow = ByteSet {2} ;
   ArrowN = North + Arrow ;
   ArrowE = East + Arrow ;
   ArrowS = South + Arrow ;
   ArrowW = West + Arrow ;

VAR
   FileName    : String ;
   LineNumber  : CARDINAL ;
   LineResult  : BOOLEAN ;
   line        : ARRAY [0..MaxLineLength] OF CHAR ;
   TokenToProc : Dictionary ;
   keywords    : ARRAY [0..MaxKeyword] OF CHAR ;
   LastKey     : CARDINAL ;
   Version     : Versions ;
   WheelPos,
   WheelDelay,
   NoOfCMD,
   FrameCount  : CARDINAL ;
   BotFd       : INTEGER ;
   RawMode,
   BotActive,
   BotDead     : BOOLEAN ;
   CurrentImage: Image ;
   CurrentScore: INTEGER ;


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
   localwrite -
*)

PROCEDURE localwrite (ch: CHAR) ;
BEGIN
   FIO.FlushBuffer (FIO.StdOut) ;
   libc.write (1, ADR (ch), 1)
END localwrite ;


(*
   Wheel -
*)

PROCEDURE Wheel ;
BEGIN
   IF WheelDelay = 0
   THEN
      WheelPos := (WheelPos + 1) MOD 4 ;
      CASE WheelPos OF

      0:  localwrite ('|') |
      1:  localwrite ('/') |
      2:  localwrite ('-') |
      3:  localwrite ('\')

      END ;
      localwrite (bs) ;
      INC (WheelDelay)
   ELSE
      INC (WheelDelay) ;
      WheelDelay := WheelDelay MOD MaxWheelDelay
   END
END Wheel ;


(*
   LoadDir - loads in all checkpoint files in mapdir.
*)

PROCEDURE LoadDir (mapdir: String) ;
VAR
   count: CARDINAL ;
BEGIN
   count := 1 ;
   WHILE LoadCheckpoint (mapdir, count) DO
      localwrite (bs) ;
      localwrite ('.') ;
      localwrite ('.') ;
      INC (count)
   END ;
   printf ("\nTotal user commands read: %d\n", NoOfCMD)
END LoadDir ;


(*
   LoadCheckpoint -
*)

PROCEDURE LoadCheckpoint (mapdir: String; count: CARDINAL) : BOOLEAN ;
VAR
   result: BOOLEAN ;
BEGIN
   FileName := Sprintf2 (InitString ('%s/%06d.cpt'), mapdir, count) ;
   (* printf ("%s\n", string (FileName)) ;  *)
   result := FALSE ;
   IF SFIO.Exists (FileName)
   THEN
      result := ParseFile (FileName)
   END ;
   FileName := KillString (FileName) ;
   RETURN result
END LoadCheckpoint ;


(*
   ParseFile -
*)

PROCEDURE ParseFile (name: String) : BOOLEAN ;
VAR
   result: BOOLEAN ;
   fin   : File ;
BEGIN
   fin := OpenToRead (name) ;
   LineNumber := 1 ;
   REPEAT
      Wheel ;
      ReadString (fin, line) ;
      IF line[0] # nul
      THEN
         result := ParseLine () ;
         INC (LineNumber)
      END ;
   UNTIL (line[0] = nul) OR EOF (fin) OR IsError (fin) ;
   Close (fin) ;
   RETURN result
END ParseFile ;


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
   BotFd := fd ;
   waitUntilStr ("dC3 to continue\n") ;
   send ("\n") ;
   waitUntilStr ("dWriteStr What character class do you want to play (type help if unsure)? ") ;
   send ("human\n") ;
   waitUntilStr ("dWriteStr What is thy name? ") ;
   sendS (Options.PlayerName) ;
   send ("\n") ;
   waitUntilStr ("clear") ;
   BotActive := TRUE ;
   BotDead := FALSE ;
   line[0] := nul
END Connect ;


(*
   send -
*)

PROCEDURE send (str: ARRAY OF CHAR) ;
VAR
   len, i: CARDINAL ;
   res   : INTEGER ;
BEGIN
   TranslateLF (str, str) ;
   i := 0 ;
   len := StrLen (str) ;
   WHILE i < len DO
      res := write (BotFd, ADR (str[i]), len-i) ;
      IF res > 0
      THEN
         i := i + CARDINAL (res)
      ELSIF res < 0
      THEN
         printf ("socket connection to server failed, exiting\n");
         HALT
      END
   END
END send ;


(*
   sendS -
*)

PROCEDURE sendS (str: String) ;
VAR
   i, len: CARDINAL ;
   ch    : CHAR ;
   res   : INTEGER ;
BEGIN
   len := Length (str) ;
   i := 0 ;
   WHILE i < len DO
      ch := char (str, i) ;
      res := write (BotFd, ADR (ch), 1) ;
      IF res > 0
      THEN
         INC (i)
      ELSIF res < 0
      THEN
         printf ("socket connection to server failed, exiting\n");
         HALT
      END
   END
END sendS ;


(*
   Read - return TRUE if a character is read.
          return FALSE if a timeout occurs.
*)

PROCEDURE Read (VAR ch: CHAR) : BOOLEAN ;
VAR
   tval: Timeval ;
   inp : SetOfFd ;
   res : INTEGER ;
BEGIN
   tval := InitTime (Seconds, MicroSecs) ;
   inp := InitSet () ;
   FdSet (BotFd, inp) ;
   res := Select (BotFd + 1, inp, NIL, NIL, tval) ;
   inp := KillSet (inp) ;
   tval := KillTime (tval) ;
   IF res = 0
   THEN
      RETURN FALSE
   ELSE
      ch := ReadCharRaw (BotFd) ;
      RETURN TRUE
   END
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
         RETURN TRUE
      END
   END ;
   line[i] := nul ;
   RETURN FALSE
END ReadLine ;


(*
   Generic - provides a basic generic bot.
*)

PROCEDURE Generic ;
VAR
   command: ARRAY [0..3] OF CHAR ;
BEGIN
   EnableRawMode ;
   ClearImage (CurrentImage) ;
   line[0] := nul ;
   WHILE NOT BotDead DO
      IF ReadLine ()
      THEN
         IF ParseLine () AND (NOT BotDead)
         THEN
            line[0] := nul
         ELSE
            BotActive := FALSE ;
            RETURN
         END
      ELSIF NOT BotDead
      THEN
         (* Timeout, significant time has elapsed since the ReadLine.  *)
         FindBest (CurrentImage, Options.K, command) ;
         send (command)
      END
   END
END Generic ;


(*
   Protocol -
*)

PROCEDURE Protocol ;
BEGIN
   Version := One ;
   CurrentScore := 0
END Protocol ;


(*
   PlayerId -
*)

PROCEDURE PlayerId ;
BEGIN

END PlayerId ;


(*
   NewroomStartTag -
*)

PROCEDURE NewroomStartTag ;
BEGIN

END NewroomStartTag ;


(*
   NewroomEndTag -
*)

PROCEDURE NewroomEndTag ;
BEGIN

END NewroomEndTag ;


(*
   KillStartTag -
*)

PROCEDURE KillStartTag ;
BEGIN
   CurrentScore := 1
END KillStartTag ;


(*
   KillEndTag -
*)

PROCEDURE KillEndTag ;
BEGIN
   CurrentScore := 0
END KillEndTag ;


(*
   DiedStartTag -
*)

PROCEDURE DiedStartTag ;
BEGIN
   CurrentScore := -1
END DiedStartTag ;


(*
   DiedEndTag -
*)

PROCEDURE DiedEndTag ;
BEGIN
   CurrentScore := 0
END DiedEndTag ;


(*
   clear -
*)

PROCEDURE clear ;
BEGIN
   ClearImage (CurrentImage) ;
   IF Options.Graphics
   THEN
      colors.clear ;
      colors.home
   END
END clear ;


(*
   dA -
*)

PROCEDURE dA ;
BEGIN

END dA ;


(*
   dC -
*)

PROCEDURE dC ;
END dC ;


(*
   dCMD -
*)

PROCEDURE dCMD ;
VAR
   cmd: ARRAY [0..10] OF CHAR ;
BEGIN
   INC (NoOfCMD) ;
   IF NOT BotActive
   THEN
      Copy (1, cmd) ;
      SetCmd (CurrentImage, cmd)
   END
END dCMD ;


(*
   dF -
*)

PROCEDURE dF ;
END dF ;


(*
   dM -
*)

PROCEDURE dM ;
END dM ;


(*
   dMap -
*)

PROCEDURE dMap ;
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
END dR ;


(*
   dT -
*)

PROCEDURE dT ;
END dT ;


(*
   dW -
*)

PROCEDURE dW ;
VAR
   str   : ARRAY [0..10] OF CHAR ;
   health: CARDINAL ;
BEGIN
   IF BotActive
   THEN
      Copy (1, str) ;
      StrToCard (str, health) ;
      IF health = 0
      THEN
         BotDead := TRUE
      END
   END
END dW ;


(*
   dw -
*)

PROCEDURE dw ;
END dw ;


(*
   eL -
*)

PROCEDURE eL ;
BEGIN

END eL ;


(*
   fl -
*)

PROCEDURE fl ;
VAR
   copy: Image ;
BEGIN
   IF NOT BotActive
   THEN
      INC (FrameCount) ;
      IF CmdPresent (CurrentImage)
      THEN
         SetScore (CurrentImage, CurrentScore) ;
         copy := InitImage () ;
         CopyImage (copy, CurrentImage) ;
         AddToDB (CurrentImage) ;
         CurrentImage := copy
      END
   END
END fl ;


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
   WriteColor -
*)

PROCEDURE WriteColor (col: Colour) ;
BEGIN
   CASE col OF

   White  :  colors.white |
   Default:  colors.reset |
   Red    :  colors.red |
   Green  :  colors.green |
   Blue   :  colors.blue |
   Magenta:  colors.magenta |
   Yellow :  colors.yellow

   END
END WriteColor ;


(*
   WriteCol -
*)

PROCEDURE WriteCol (ch: CHAR; col: Colour; rev: BOOLEAN) ;
BEGIN
   IF rev
   THEN
      colors.reverse (TRUE) ;
      WriteColor (col) ;
      write (1, ADR (ch), 1) ;
      colors.reverse (FALSE)
   ELSE
      WriteColor (col) ;
      write (1, ADR (ch), 1)
   END
END WriteCol ;


(*
   PlotPos -
*)

PROCEDURE PlotPos (b: ByteSet; ch: CHAR; col: Colour; reverse: BOOLEAN) ;
VAR
   x, y: CARDINAL ;
   str : ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   StrToCard (str, x) ;
   Copy (2, str) ;
   StrToCard (str, y) ;
   Plot (CurrentImage, x, y, b) ;
   IF Options.Graphics
   THEN
      colors.home ;
      colors.pos (x, y) ;
      WriteCol (ch, col, reverse)
   END
END PlotPos ;


(*
   PlotPoint -
*)

PROCEDURE PlotPoint (x, y: CARDINAL; b: ByteSet; ch: CHAR; col: Colour; reverse: BOOLEAN) ;
BEGIN
   Plot (CurrentImage, x, y, b) ;
   IF Options.Graphics
   THEN
      colors.home ;
      colors.pos (x, y) ;
      WriteCol (ch, col, reverse)
   END
END PlotPoint ;


(*
   PlotLine -
*)

PROCEDURE PlotLine (b: ByteSet; ch: CHAR; col: Colour; reverse: BOOLEAN) ;
VAR
   x0, y0,
   x1, y1: CARDINAL ;
   str   : ARRAY [0..10] OF CHAR ;
BEGIN
   Copy (1, str) ;
   StrToCard (str, x0) ;
   Copy (2, str) ;
   StrToCard (str, y0) ;
   Copy (3, str) ;
   StrToCard (str, x1) ;
   Copy (4, str) ;
   StrToCard (str, y1) ;
   IF x0 = x1
   THEN
      WHILE y0 <= y1 DO
         PlotPoint (x0, y0, b, ch, col, reverse) ;
         INC (y0)
      END ;
   ELSE
      PlotPoint (x0, y0, b, ch, col, reverse) ;
      INC (x0) ;
      WHILE x0 <= x1 DO
         WriteCol (ch, col, reverse) ;
         INC (x0)
      END ;
   END ;
   IF reverse AND Options.Graphics
   THEN
      colors.reset
   END
END PlotLine ;


(*
   hwall -
*)

PROCEDURE hwall ;
BEGIN
   PlotLine (Wall, ' ', Red, TRUE)
END hwall ;


(*
   vwall -
*)

PROCEDURE vwall ;
BEGIN
   PlotLine (Wall, ' ', Red, TRUE)
END vwall ;


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
BEGIN
   PlotPos (SelfN, '^', White, FALSE)
END nman ;


(*
   eman -
*)

PROCEDURE eman ;
BEGIN
   PlotPos (SelfE, '>', White, FALSE)
END eman ;


(*
   sman -
*)

PROCEDURE sman ;
BEGIN
   PlotPos (SelfS, 'v', White, FALSE)
END sman ;


(*
   wman -
*)

PROCEDURE wman ;
BEGIN
   PlotPos (SelfW, '<', White, FALSE)
END wman ;


(*
   Nman -
*)

PROCEDURE Nman ;
BEGIN
   PlotPos (EnemyN, '^', Blue, FALSE)
END Nman ;


(*
   Eman -
*)

PROCEDURE Eman ;
BEGIN
   PlotPos (EnemyE, '>', Blue, FALSE)
END Eman ;


(*
   Sman -
*)

PROCEDURE Sman ;
BEGIN
   PlotPos (EnemyS, 'v', Blue, FALSE)
END Sman ;


(*
   Wman -
*)

PROCEDURE Wman ;
BEGIN
   PlotPos (EnemyW, '<', Blue, FALSE)
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
END dC1 ;


(*
   dC2 -
*)

PROCEDURE dC2 ;
END dC2 ;


(*
   dC3 -
*)

PROCEDURE dC3 ;
END dC3 ;


(*
   hhinge -
*)

PROCEDURE hhinge ;
BEGIN
   PlotPos (Door, ' ', Magenta, TRUE)
END hhinge ;


(*
   vhinge -
*)

PROCEDURE vhinge ;
BEGIN
   PlotPos (Door, ' ', Magenta, TRUE)
END vhinge ;


(*
   hdoor -
*)

PROCEDURE hdoor ;
BEGIN
   PlotPos (Door, ' ', Magenta, TRUE)
END hdoor ;


(*
   vdoor -
*)

PROCEDURE vdoor ;
BEGIN
   PlotPos (Door, ' ', Magenta, TRUE)
END vdoor ;


(*
   treasure -
*)

PROCEDURE treasure ;
BEGIN
   PlotPos (Treasure, '+', Yellow, TRUE)
END treasure ;


(*
   pS -
*)

PROCEDURE pS ;
END pS ;


(*
   dWriteLn -
*)

PROCEDURE dWriteLn ;
END dWriteLn ;


(*
   sar -
*)

PROCEDURE sar ;
BEGIN
   PlotPos (ArrowS, '*', Red, FALSE)
END sar ;


(*
   war -
*)

PROCEDURE war ;
BEGIN
   PlotPos (ArrowW, '*', Red, FALSE)
END war ;


(*
   nar -
*)

PROCEDURE nar ;
BEGIN
   PlotPos (ArrowN, '*', Red, FALSE)
END nar ;


(*
   ear -
*)

PROCEDURE ear ;
BEGIN
   PlotPos (ArrowE, '*', Red, FALSE)
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
   dWriteStr -
*)

PROCEDURE dWriteStr ;
END dWriteStr ;


(*
   ReportError -
*)

PROCEDURE ReportError (message: ARRAY OF CHAR) ;
BEGIN
   printf ("%s:%d:", string (FileName), LineNumber) ;
   WriteString (message) ; WriteLn ;
   WriteString (line) ; WriteLn ;
   LineResult := FALSE
END ReportError ;


(*
   ParseLine -
*)

PROCEDURE ParseLine () : BOOLEAN ;
BEGIN
   IF (line[0] = nul) OR ((line[0] = nl) AND (line[1] = nul))
   THEN
      RETURN TRUE
   ELSE
      RETURN ParseLineContents ()
   END
END ParseLine ;


(*
   ParseLineContents -
*)

PROCEDURE ParseLineContents () : BOOLEAN ;
VAR
   entry: ADDRESS ;
   proc : PROC ;
BEGIN
   entry := BinDict.Get (TokenToProc, ADR (line[0])) ;
   IF Options.Debug
   THEN
      printf ("**LINE: %s", line)
   END ;
   IF entry = NIL
   THEN
      ReportError ("keyword at beginning of the line is not matched") ;
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
   AddKeyword (dict, 'dC', dC) ;
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
   AddKeyword (dict, 'hwall', hwall) ;
   AddKeyword (dict, 'vwall', vwall) ;
   AddKeyword (dict, 'hhinge', hhinge) ;
   AddKeyword (dict, 'vhinge', vhinge) ;
   AddKeyword (dict, 'hdoor', hdoor) ;
   AddKeyword (dict, 'vdoor', vdoor) ;
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
   AddKeyword (dict, 'combat', combat) ;
   AddKeyword (dict, 'quit', quit) ;
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
   EnableRawMode -
*)

PROCEDURE EnableRawMode ;
BEGIN
   colors.enable (Options.Graphics)
(*
   IF Options.Graphics
   THEN
      RawMode := TRUE ;
      libc.system (ADR ("stty raw"))
   END
*)
END EnableRawMode ;


(*
   RestoreTTY -
*)

PROCEDURE RestoreTTY ;
BEGIN
   IF RawMode AND Options.Graphics
   THEN
      (* libc.system (ADR ("stty sane")) *)
   END
END RestoreTTY ;


(*
   Init -
*)

PROCEDURE Init ;
BEGIN
   RawMode := FALSE ;
   IF InstallTerminationProcedure (RestoreTTY)
   THEN
   END ;
   BotActive := FALSE ;
   BotDead := FALSE ;
   FrameCount := 0 ;
   NoOfCMD := 0 ;
   WheelPos := 0 ;
   WheelDelay := 0 ;
   CurrentScore := 0 ;
   TokenToProc := BinDict.Init (compare, NoDelete, NoDelete) ;
   LastKey := 0 ;
   PopulateKeywords (TokenToProc) ;
   CurrentImage := InitImage ()
END Init ;


BEGIN
   Init
END LoadCheckpoint.
