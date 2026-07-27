IMPLEMENTATION MODULE Screen ;  (*!m2iso+gm2*)

FROM Storage IMPORT ALLOCATE ;
FROM StdIO IMPORT Write ;
FROM UTF8 IMPORT InitUnicode ;
FROM NumberIO IMPORT WriteCard ;
FROM StrIO IMPORT WriteString, WriteLn ;
FROM StdIO IMPORT PushOutput, PopOutput ;
FROM StrLib IMPORT StrLen ;

IMPORT color ;
IMPORT FIO ;
IMPORT SFIO ;
IMPORT UTF8 ;
IMPORT Options ;

CONST
   DebuggingErase = FALSE ;
   MaxGradiant = 23 ;

TYPE
   GradiantType = (open2closed, closed2open,
                   closed2secret, secret2closed,
                   closed2timed, timed2closed) ;

   Color = RECORD
              red,
              green,
              blue : CARDINAL ;
           END ;

   Kind = (WalkT, ArrowT, DoorT, StillT, EraseT) ;

   State = (Solo, Dead, Active, Pending) ;

   WalkRec = RECORD
                fromx,
                fromy,
                tox,
                toy,
                step,
                clientsteps,
                total,
                period,
                dir    : CARDINAL ;
                self   : BOOLEAN ;
                pending: Anim ;
             END ;

   StillRec = RECORD
                 x, y, dir: CARDINAL ;
                 self     : BOOLEAN ;
              END ;

   EraseRec = RECORD
                 x, y: CARDINAL ;
                 self: BOOLEAN ;
              END ;

   DoorRec = RECORD
                fromx,
                fromy,
                tox,
                toy,
                step,
                total,
                period  : CARDINAL ;
                gradiant: GradiantType ;
                horiz   : BOOLEAN ;
             END ;

   Anim = POINTER TO RECORD
                        kind : Kind ;
                        state: State ;
                        Delay: CARDINAL ;
                        id   : CARDINAL ;
                        walk : WalkRec ;
                        still: StillRec ;
                        erase: EraseRec ;
                        door : DoorRec ;
                        Right,
                        Left : Anim ;
                     END ;

   Gradiant = ARRAY [0..MaxGradiant] OF Color ;

VAR
   DebugErase,
   DebugColor,
   WallColor,
   OtherColor,
   PlayerColor,
   BlankColor,
   GoggledColor,
   ClosedColor,
   SecretColor,
   CurrentColor : Color ;
   AnimHead,
   FreeList     : Anim ;
   NamedPipe    : FIO.File ;
   CurrentId    : CARDINAL ;
   PrevEmpty,
   Initialized  : BOOLEAN ;
   ColorGradiant: ARRAY GradiantType OF Gradiant ;
   TextX, TextY : CARDINAL ;


(*
   Assert -
*)

PROCEDURE Assert (condition: BOOLEAN) ;
BEGIN
   IF NOT condition
   THEN
      WriteString ('assert failed') ; WriteLn ;
      HALT (1)
   END
END Assert ;


(*
   ColorGrey -
*)

PROCEDURE ColorGrey (grey: CARDINAL) : Color ;
VAR
   col: Color ;
BEGIN
   col.red := 256 + grey ;
   col.blue := 256 + grey ;
   col.green := 256 + grey ;
   RETURN col
END ColorGrey ;


(*
   IsGrey -
*)

PROCEDURE IsGrey (col: Color) : BOOLEAN ;
BEGIN
   RETURN col.red >= 256
END IsGrey ;


(*
   GetGreyLevel -
*)

PROCEDURE GetGreyLevel (col: Color) : CARDINAL ;
BEGIN
   Assert (IsGrey (col)) ;
   RETURN col.red - 256
END GetGreyLevel ;


(*
   EqualColor - return TRUE if left = right.
*)

PROCEDURE EqualColor (left, right: Color) : BOOLEAN ;
BEGIN
   RETURN (left.red = right.red) AND
          (left.green = right.green) AND
          (left.blue = right.blue)
END EqualColor ;


(*
   MakeDraw -
*)

PROCEDURE MakeDraw (x, y, dir: CARDINAL; self: BOOLEAN) : Anim ;
VAR
   anim: Anim ;
BEGIN
   anim := InitAnim (StillT) ;
   WITH anim^ DO
      Delay := 0 ;
      still.x := x ;
      still.y := y ;
      still.self := self
   END ;
   RETURN anim
END MakeDraw ;


(*
   DrawMan -
*)

PROCEDURE DrawMan (x, y: CARDINAL; dir: CARDINAL; self: BOOLEAN) ;
VAR
   anim: Anim ;
BEGIN
   IF IsOnQueueSelf (WalkT, self)
   THEN
      anim := GetAnimSelf (WalkT, self) ;
      AddToQueueBack (anim^.walk.pending, MakeDraw (x, y, dir, self))
   ELSE
      RawDrawMan (x * 2, y, dir, self)
   END
END DrawMan ;


(*
   RawDrawMan -
*)

PROCEDURE RawDrawMan (x, y: CARDINAL; dir: CARDINAL; self: BOOLEAN) ;
VAR
   utf8: UTF8.UTF8 ;
BEGIN
   color.Pos (x, y) ;
   IF self
   THEN
      ForegroundColor (PlayerColor)
   ELSE
      ForegroundColor (OtherColor)
   END ;
   CASE dir OF

   0:  utf8 := InitUnicode ('U+25B2') |   (* InitUnicode ('U+23F4') *)
   1:  utf8 := InitUnicode ('U+25B6') |
   2:  utf8 := InitUnicode ('U+25BC') |
   3:  utf8 := InitUnicode ('U+25C0')     (* InitUnicode ('U+1F6B6') *)

   END ;
   UTF8.Write (FIO.StdOut, utf8) ;
   ForegroundColor (PlayerColor) ;
   FIO.FlushBuffer (FIO.StdOut)
END RawDrawMan ;


(*
   DrawLineDebug - draw a line x0, y0 -> x1, y1 with the
                   debugging colour.
*)

PROCEDURE DrawLineDebug (x0, y0, x1, y1: CARDINAL) ;
BEGIN
   DrawLineColor (x0, y0, x1, y1, DebugColor) ;
   RestCursor ;
   FIO.FlushBuffer (FIO.StdOut)
END DrawLineDebug ;


(*
   DoorGoggled -
*)

PROCEDURE DoorGoggled (x0, y0, x1, y1: CARDINAL;
                       horiz: BOOLEAN) ;
BEGIN
   DrawDoorColor (x0, y0, x1, y1, horiz, GoggledColor)
END DoorGoggled ;


(*
   DrawLineColor -
*)

PROCEDURE DrawLineColor (x0, y0, x1, y1: CARDINAL; col: Color) ;
BEGIN
   IF x0 = x1
   THEN
      DrawVertColor (x0, y0, y1, col)
   ELSE
      DrawHorizColor (x0, y0, x1, col)
   END
END DrawLineColor ;


(*
   DrawDoorColor -
*)

PROCEDURE DrawDoorColor (x0, y0, x1, y1: CARDINAL;
                         horiz: BOOLEAN; col: Color) ;
BEGIN
   IF horiz
   THEN
      DrawDoorHorizColor (x0, y0, x1, col)
   ELSE
      DrawDoorVertColor (x0, y0, y1, col)
   END
END DrawDoorColor ;


(*
   DrawDoorHorizColor -
*)

PROCEDURE DrawDoorHorizColor (x0, y0, x1: CARDINAL; col: Color) ;
BEGIN
   color.Pos (x0 * 2, y0) ;
   BackgroundColor (col) ;
   WHILE x0 <= x1 DO
      INC (x0) ;
      Write (' ') ;
      Write (' ')
   END ;
   color.Default
END DrawDoorHorizColor ;


(*
   DrawDoorVertColor -
*)

PROCEDURE DrawDoorVertColor (x0, y0, y1: CARDINAL; col: Color) ;
BEGIN
   BackgroundColor (col) ;
   WHILE y0 <= y1 DO
      color.Pos (x0 * 2, y0) ;
      INC (y0) ;
      Write (' ') ;
      Write (' ')
   END ;
   color.Default
END DrawDoorVertColor ;


(*
   DrawHorizColor -
*)

PROCEDURE DrawHorizColor (x0, y0, x1: CARDINAL; col: Color) ;
BEGIN
   color.Pos (x0 * 2, y0) ;
   BackgroundColor (col) ;
   WHILE x0 < x1 DO
      INC (x0) ;
      Write (' ') ;
      Write (' ')
   END ;
   color.Default
END DrawHorizColor ;


(*
   DrawVertColor -
*)

PROCEDURE DrawVertColor (x0, y0, y1: CARDINAL; col: Color) ;
BEGIN
   color.BackgroundRGB6 (col.red, col.green, col.blue) ;
   WHILE y0 <= y1 DO
      color.Pos (x0 * 2, y0) ;
      INC (y0) ;
      Write (' ') ;
      Write (' ')
   END ;
   color.Default
END DrawVertColor ;


(*
   DrawLineDefault -
*)

PROCEDURE DrawLineDefault (x0, y0, x1, y1: CARDINAL) ;
BEGIN
   IF x0 = x1
   THEN
      DrawVertDefault (x0, y0, y1)
   ELSE
      DrawHorizDefault (x0, y0, x1)
   END
END DrawLineDefault ;


(*
   BackgroundColor -
*)

PROCEDURE BackgroundColor (col: Color) ;
BEGIN
   IF EqualColor (col, BlankColor)
   THEN
      color.Default
   ELSIF IsGrey (col)
   THEN
      color.BackgroundGrey (GetGreyLevel (col))
   ELSE
      color.BackgroundRGB6 (col.red, col.green, col.blue)
   END
END BackgroundColor ;


(*
   ForegroundColor -
*)

PROCEDURE ForegroundColor (col: Color) ;
BEGIN
   IF EqualColor (col, BlankColor)
   THEN
      color.ForegroundDefault
   ELSIF IsGrey (col)
   THEN
      color.ForegroundGrey (GetGreyLevel (col))
   ELSE
      color.ForegroundRGB6 (col.red, col.green, col.blue)
   END
END ForegroundColor ;


(*
   DrawHorizDefault -
*)

PROCEDURE DrawHorizDefault (x0, y0, x1: CARDINAL) ;
BEGIN
   color.Pos (x0 * 2, y0) ;
   color.Default ;
   WHILE x0 <= x1 DO
      INC (x0) ;
      Write (' ') ;
      Write (' ')
   END
END DrawHorizDefault ;


(*
   DrawVertDefault -
*)

PROCEDURE DrawVertDefault (x0, y0, y1: CARDINAL) ;
BEGIN
   color.Default ;
   WHILE y0 <= y1 DO
      color.Pos (x0 * 2, y0) ;
      INC (y0) ;
      Write (' ') ;
      Write (' ')
   END
END DrawVertDefault ;


(*
   DrawPointDefault -
*)

PROCEDURE DrawPointDefault (x, y: CARDINAL) ;
BEGIN
   color.Default ;
   color.Pos (x * 2, y) ;
   Write (' ') ;
   Write (' ')
END DrawPointDefault ;


(*
   RawDrawPointDefault -
*)

PROCEDURE RawDrawPointDefault (x, y: CARDINAL) ;
BEGIN
   color.Default ;
   color.Pos (x, y) ;
   Write (' ')
END RawDrawPointDefault ;


(*
   DoorPointClosed -
*)

PROCEDURE DoorPointClosed (x, y: CARDINAL) ;
BEGIN
   DrawPoint (x, y, ClosedColor)
END DoorPointClosed ;


(*
   DrawPoint -
*)

PROCEDURE DrawPoint (x, y: CARDINAL; col: Color) ;
BEGIN
   color.Pos (x * 2, y) ;
   BackgroundColor (col) ;
   Write (' ') ;
   Write (' ')
END DrawPoint ;


(*
   Wall -
*)

PROCEDURE Wall (x0, y0, x1, y1: CARDINAL) ;
BEGIN
   DrawLineColor (x0, y0, x1, y1, WallColor)
END Wall ;


(*
   DoorClosed -
*)

PROCEDURE DoorClosed (x0, y0, x1, y1: CARDINAL) ;
BEGIN
   IF y0 = y1
   THEN
      DrawLineColor (x0, y0, x1+1, y1, ClosedColor)
   ELSE
      DrawLineColor (x0, y0, x1, y1+1, ClosedColor)
   END
END DoorClosed ;


(*
   DoorOpen -
*)

PROCEDURE DoorOpen (x0, y0, x1, y1: CARDINAL) ;
BEGIN
   IF y0 = y1
   THEN
      DrawLineDefault (x0, y0, x1+1, y1)
   ELSE
      DrawLineDefault (x0, y0, x1, y1+1)
   END
END DoorOpen ;


(*
   DoorSecret -
*)

PROCEDURE DoorSecret (x0, y0, x1, y1: CARDINAL) ;
BEGIN
   IF y0 = y1
   THEN
      DrawLineColor (x0, y0, x1+1, y1, SecretColor)
   ELSE
      DrawLineColor (x0, y0, x1, y1+1, SecretColor)
   END
END DoorSecret ;


(*
   GenDoorAnim -
*)

PROCEDURE GenDoorAnim (x0, y0, x1, y1: CARDINAL;
                       horiz: BOOLEAN; gradient: GradiantType) ;
VAR
   door: Anim ;
BEGIN
   (* 10/100s delay between colour change, 24 colour changes.  *)
   door := MakeDoor (x0, y0, x1, y1, 0, 24, 100, gradient, horiz) ;
   door^.Delay := 100 ;
   MakeAnim (door, door^.Delay)
END GenDoorAnim ;


(*
   DoorClosedToOpen -
*)

PROCEDURE DoorClosedToOpen (x0, y0, x1, y1: CARDINAL; horiz: BOOLEAN) ;
BEGIN
   GenDoorAnim (x0, y0, x1, y1, horiz, closed2open)
END DoorClosedToOpen ;


(*
   DoorOpenToClosed -
*)

PROCEDURE DoorOpenToClosed (x0, y0, x1, y1: CARDINAL; horiz: BOOLEAN) ;
BEGIN
   GenDoorAnim (x0, y0, x1, y1, horiz, open2closed)
END DoorOpenToClosed ;


(*
   DoorClosedToTimed -
*)

PROCEDURE DoorClosedToTimed (x0, y0, x1, y1: CARDINAL; horiz: BOOLEAN) ;
BEGIN
   GenDoorAnim (x0, y0, x1, y1, horiz, closed2secret)
END DoorClosedToTimed ;


(*
   DoorTimedToClosed -
*)

PROCEDURE DoorTimedToClosed (x0, y0, x1, y1: CARDINAL; horiz: BOOLEAN) ;
BEGIN
   GenDoorAnim (x0, y0, x1, y1, horiz, secret2closed)
END DoorTimedToClosed ;


(*
   DoorSecretToClosed
*)

PROCEDURE DoorSecretToClosed (x0, y0, x1, y1: CARDINAL; horiz: BOOLEAN) ;
BEGIN
   GenDoorAnim (x0, y0, x1, y1, horiz, secret2closed)
END DoorSecretToClosed ;


(*
   MakeDoor -
*)

PROCEDURE MakeDoor (fromx, fromy, tox, toy,
                    step, total, period: CARDINAL;
                    gradiant: GradiantType ;
                    horiz: BOOLEAN) : Anim ;
VAR
   door: Anim ;
BEGIN
   door := InitAnim (DoorT) ;
   WITH door^ DO
      door.fromx := fromx ;
      door.fromy := fromy ;
      door.tox := tox ;
      door.toy := toy ;
      door.step := step ;
      door.total := total ;
      door.period := period ;
      door.gradiant := gradiant ;
      door.horiz := horiz
   END ;
   RETURN door
END MakeDoor ;


(*
   ProcessDoor - this is only called when anim^.Delay = 0.
*)

PROCEDURE ProcessDoor (anim: Anim) ;
BEGIN
   IF anim^.door.step < anim^.door.total
   THEN
      WITH anim^ DO
         DrawDoorColor (door.fromx, door.fromy, door.tox, door.toy,
                        door.horiz,
                        ColorGradiant[door.gradiant][door.step]) ;
         RestCursor ;
         Delay := door.period
      END ;
      INC (anim^.door.step) ;
      MakeAnim (anim, anim^.door.period)
   ELSE
      (* Reached the end of the sequence.  *)
      (* anim has already been removed from the queue.  *)
      Assert (IsSolo (anim)) ;
      Deconstruct (anim)
   END
END ProcessDoor ;


(*
   WriteUnicode - write a unicode character and flush it to screen.
*)

PROCEDURE WriteUnicode (a: ARRAY OF CHAR) ;
VAR
   utf8: UTF8.UTF8 ;
BEGIN
   utf8 := InitUnicode (a) ;
   UTF8.Write (FIO.StdOut, utf8) ;
   FIO.FlushBuffer (FIO.StdOut)
END WriteUnicode ;


(*
   Treasure -
*)

PROCEDURE Treasure (x, y: CARDINAL) ;
BEGIN
   color.Pos (x * 2, y) ;
   WriteUnicode ('U+1FA8E') ;  (* Treasure chest.  *)
END Treasure ;


(*
   Arrow - draw an arrow at x y.
*)

PROCEDURE Arrow (x, y, dir: CARDINAL) ;
BEGIN
   color.Pos (x * 2, y) ;
   CASE dir OF

   0:  WriteUnicode ('U+2191') |
   1:  WriteUnicode ('U+2192') |
   2:  WriteUnicode ('U+2193') |
   3:  WriteUnicode ('U+2190')

   END
END Arrow ;


(*
   ArrowRev - write a reverse arrow at x y.
*)

PROCEDURE ArrowRev (x, y, dir: CARDINAL) ;
BEGIN
   color.Pos (x * 2, y) ;
   CASE dir OF

   0:  WriteUnicode ('U+293A') |
   1:  WriteUnicode ('U+2938') |
   2:  WriteUnicode ('U+293B') |
   3:  WriteUnicode ('U+2939')

   END
END ArrowRev ;


(*
   InitAnim - return a new anim.
*)

PROCEDURE InitAnim (kind: Kind) : Anim ;
VAR
   anim: Anim ;
BEGIN
   IF FreeList = NIL
   THEN
      NEW (anim) ;
      INC (CurrentId) ;
      anim^.id := CurrentId ;
      anim^.state := Dead ;
      OpenNamedPipe
   ELSE
      anim := FreeList ;
      FreeList := FreeList^.Right
   END ;
   Assert (IsDead (anim)) ;
   anim^.kind := kind ;
   anim := MakeSolo (anim) ;
   RETURN anim
END InitAnim ;


(*
   IsDead - return TRUE if anim is dead.
*)

PROCEDURE IsDead (anim: Anim) : BOOLEAN ;
BEGIN
   RETURN anim^.state = Dead
END IsDead ;


(*
   IsActive - return TRUE if anim is active.
*)

PROCEDURE IsActive (anim: Anim) : BOOLEAN ;
BEGIN
   RETURN anim^.state = Active
END IsActive ;


(*
   MakeSolo - configures anim as a solo queue.
*)

PROCEDURE MakeSolo (anim: Anim) : Anim ;
BEGIN
   anim^.state := Solo ;
   anim^.Right := anim ;
   anim^.Left := anim ;
   RETURN anim
END MakeSolo ;


(*
   KillAnimList -
*)

PROCEDURE KillAnimList (VAR head: Anim) ;
VAR
   el: Anim ;
BEGIN
   IF head # NIL
   THEN
      head^.Left^.Right := FreeList ;
      FreeList := head ;
      head := NIL
   END
END KillAnimList ;


(*
   KillAnim -
*)

PROCEDURE KillAnim (anim: Anim) ;
BEGIN
   IF IsSolo (anim)
   THEN
      IF anim^.kind = WalkT
      THEN
         KillAnimList (anim^.walk.pending)
      END ;
      anim^.state := Dead ;
      anim^.Right := FreeList ;
      FreeList := anim
   ELSE
      Fatal ('anim must be on the solo queue')
   END
END KillAnim ;


(*
   MakeAnimWalk - step is the current step in the sequence 1..total.
                  total is the amount the user has requested.
                  clientsteps is the number of steps the client should
                  perform.  Normally this will be 1.
*)

PROCEDURE MakeAnimWalk (fromx, fromy, tox, toy,
                        step, clientsteps, total,
                        delay, dir: CARDINAL;
                        self: BOOLEAN) ;
VAR
   walk  : Anim ;
   period: CARDINAL ;
BEGIN
   fromx := fromx * 2 ;
   tox := tox * 2 ;
   period := delay ;
   IF (dir MOD 2) = 1
   THEN
      (* But all squares are 2x1.  *)
      clientsteps := clientsteps * 2 ;
      period := period DIV 2
   END ;
   IF period = 0
   THEN
      period := 1   (* We always need a unit of time.  *)
   END ;
   RawDrawMan (fromx, fromy, dir, TRUE) ;
   walk := MakeWalk (fromx, fromy, tox, toy,
                     step, clientsteps, total,
                     dir, period, self) ;
   MakeAnim (walk, delay)
END MakeAnimWalk ;


(*
   MakeWalk - step is the current step in the sequence 1..total.
              total is the amount the user has requested.
              clientsteps is the number of steps the client should
              perform.  Normally this will be 1.
*)

PROCEDURE MakeWalk (fromx, fromy, tox, toy,
                    step, clientsteps, total,
                    dir, period: CARDINAL;
                    self: BOOLEAN) : Anim ;
VAR
   walk: Anim ;
BEGIN
   walk := InitAnim (WalkT) ;
   WITH walk^ DO
      walk.fromx := fromx ;
      walk.fromy := fromy ;
      walk.tox := tox ;
      walk.toy := toy ;
      walk.step := step ;
      walk.clientsteps := clientsteps ;
      walk.total := total ;
      walk.dir := dir ;
      walk.period := period ;
      walk.self := self ;
      walk.pending := NIL ;
   END ;
   RETURN walk
END MakeWalk ;


(*
   MakeAnim - adds anim onto the relative queue.
*)

PROCEDURE MakeAnim (anim: Anim; delay: CARDINAL) ;
BEGIN
   ToActive (anim, delay)
END MakeAnim ;


(*
   IsSolo - return TRUE if anim is on the solo queue.
*)

PROCEDURE IsSolo (anim: Anim) : BOOLEAN ;
BEGIN
   RETURN anim^.state = Solo
END IsSolo ;


(*
   Fatal -
*)

PROCEDURE Fatal (msg: ARRAY OF CHAR) ;
BEGIN
   WriteString (msg) ; WriteLn ;
   HALT (1)
END Fatal ;


(*
   ToActive - move an anim from the solo queue to the active queue.
*)

PROCEDURE ToActive (anim: Anim; delay: CARDINAL) ;
BEGIN
   IF IsSolo (anim)
   THEN
      anim^.state := Active ;
      AddToRelQueue (AnimHead, delay, anim)
   ELSE
      Fatal ('anim must be on the solo queue')
   END
END ToActive ;


(*
   ToSolo -
*)

PROCEDURE ToSolo (anim: Anim) ;
BEGIN
   IF IsSolo (anim)
   THEN
      (* Nothing to do.  *)
   ELSIF IsActive (anim)
   THEN
   END
END ToSolo ;


(*
   AddToRelQueue -
*)

PROCEDURE AddToRelQueue (VAR Head: Anim; delay: CARDINAL; anim: Anim) ;
BEGIN
   IF Head = NIL
   THEN
      Head := anim ;
      anim^.Delay := delay ;
      anim^.Left := anim ;
      anim^.Right := anim
   ELSIF Head^.Right = Head
   THEN
      (* Queue contains one element.  *)
      IF Head^.Delay > delay
      THEN
         (* Needs to go on the front.  *)
         anim^.Delay := delay ;
         DEC (Head^.Delay, delay) ;
         Head := JoinFrontQueue (anim, Head)
      ELSE
         (* Needs to go on the back.  *)
         DEC (delay, Head^.Delay) ;
         anim^.Delay := delay ;
         Head := JoinBackQueue (Head, anim)
      END
   ELSIF Head^.Delay > delay
   THEN
      (* New element goes at the front.  *)
      anim^.Delay := delay ;
      DEC (Head^.Delay, delay) ;
      Head := JoinFrontQueue (anim, Head)
   ELSE
      (* More than two elements on the queue and the new element
         does not go at the front.  *)
      Head := InsertRelQueue (anim, delay, Head)
   END
END AddToRelQueue ;


(*
   InsertRelQueue - relatively add anim into the queue at
                    absolute delay position.  The
                    AnimHead will not be empty and anim does not
                    go at the front of the queue.
*)

PROCEDURE InsertRelQueue (anim: Anim; delay: CARDINAL; Head: Anim) : Anim ;
VAR
   prev,
   next    : Anim ;
   AbsDelay: CARDINAL ;
BEGIN
   prev := Head ;
   next := Head^.Right ;
   AbsDelay := 0 ;
   LOOP
      INC (AbsDelay, prev^.Delay) ;
      IF next = Head
      THEN
         (* anim goes at the end.  *)
         anim^.Delay := delay - AbsDelay ;
         InsertQueue (prev, anim, next) ;
         Head := anim^.Right ;
         RETURN Head
      ELSIF AbsDelay + next^.Delay > delay
      THEN
         (* anim must go after prev, but in front of next.  *)
         anim^.Delay := delay - AbsDelay ;
         InsertQueue (prev, anim, next) ;
         RETURN Head
      ELSE
         prev := next ;
         next := next^.Right
      END
   END
END InsertRelQueue ;


(*
   InsertQueue -
*)

PROCEDURE InsertQueue (prev, anim, next: Anim) ;
BEGIN
   prev^.Right := anim ;
   anim^.Left := prev ;
   anim^.Right := next ;
   next^.Left := anim
END InsertQueue ;


(*
   JoinFrontQueue -
*)

PROCEDURE JoinFrontQueue (elem: Anim; Head: Anim) : Anim ;
BEGIN
   elem^.Right := Head ;
   elem^.Left := Head^.Left ;
   Head^.Left^.Right := elem ;
   Head^.Left := elem ;
   RETURN elem
END JoinFrontQueue ;


(*
   JoinBackQueue - add elem to the end of queue pointed to by
                   Head.  Head must not be NIL.
*)

PROCEDURE JoinBackQueue (Head: Anim; elem: Anim) : Anim ;
BEGIN
   elem^.Right := Head ;
   elem^.Left := Head^.Left ;
   Head^.Left^.Right := elem ;
   Head^.Left := elem ;
   RETURN Head
END JoinBackQueue ;


(*
   AddToQueueBack - adds elem to the end of circular queue Head.
                    Head maybe NIL in which case elem will be the
                    only element on the queue.
*)

PROCEDURE AddToQueueBack (VAR Head: Anim; elem: Anim) ;
BEGIN
   IF Head = NIL
   THEN
      Head := elem ;
      elem^.Left := elem ;
      elem^.Right := elem
   ELSE
      Head := JoinBackQueue (Head, elem)
   END
END AddToQueueBack ;


(*
   IsSingle -
*)

PROCEDURE IsSingle (anim: Anim) : BOOLEAN ;
BEGIN
   RETURN anim^.Right = anim
END IsSingle ;


(*
   SubQueue -
*)

PROCEDURE SubQueue (VAR Head: Anim; anim: Anim) ;
BEGIN
   IF IsSingle (anim)
   THEN
      Head := NIL
   ELSE
      IF Head = anim
      THEN
         Head := Head^.Right
      END ;
      anim^.Left^.Right := anim^.Right ;
      anim^.Right^.Left := anim^.Left
   END
END SubQueue ;


PROCEDURE IncPosition (VAR x, y: CARDINAL ; Dir: CARDINAL) ;
BEGIN
   IF (Dir=0) AND (y>0)
   THEN
      DEC (y)
   ELSIF Dir = 1
   THEN
      INC (x)
   ELSIF Dir = 2
   THEN
      INC(y)
   ELSIF x > 0
   THEN
      DEC(x)
   END
END IncPosition ;


(*
   Deconstruct -
*)

PROCEDURE Deconstruct (anim: Anim) ;
VAR
   el: Anim ;
BEGIN
   WITH anim^ DO
      CASE kind OF

      WalkT: RawDrawMan (walk.fromx, walk.fromy,
                         walk.dir, walk.self) ;
             (* RawProcessErase (walk.fromx, walk.fromy) ; *)
             (* Delete all pending entries in solo anim.  *)
             el := walk.pending ;
             WHILE el # NIL DO
                SubQueue (walk.pending, el) ;
                Process (MakeSolo (el)) ;
                el := walk.pending
             END |
      StillT: RawDrawMan (still.x, still.y,
                          still.dir, still.self) |
      EraseT: RawProcessErase (erase.x, erase.y) |
      DoorT : |

      END
   END ;
   (* Finally give anim to FreeList.  *)
   KillAnim (anim)
END Deconstruct ;


(*
   ProcessWalk -
*)

PROCEDURE ProcessWalk (anim: Anim) ;
VAR
   el: Anim ;
BEGIN
   IF anim^.walk.clientsteps = 0
   THEN
      (* anim has already been removed from the queue.  *)
      Assert (IsSolo (anim)) ;
      Deconstruct (anim)
   ELSE
      WITH anim^ DO
         DEC (walk.clientsteps) ;
         RawProcessErase (walk.fromx, walk.fromy) ;
         (* RawDrawPointDefault (walk.fromx, walk.fromy) ;  *)
         IncPosition (walk.fromx, walk.fromy, walk.dir) ;
         RawDrawMan (walk.fromx, walk.fromy, walk.dir, walk.self) ;
         Delay := walk.period
      END ;
      MakeAnim (anim, anim^.Delay)
   END
END ProcessWalk ;


(*
   AdjustDelay -
*)

PROCEDURE AdjustDelay (head: Anim; newdelay: CARDINAL) ;
VAR
   anim: Anim ;
BEGIN
   IF head # NIL
   THEN
      anim := head ;
      REPEAT
         anim^.Delay := newdelay ;
         CASE anim^.kind OF

         WalkT:  anim^.walk.period := newdelay ;
                 AdjustDelay (anim^.walk.pending, newdelay) |
         DoorT:  anim^.door.period := newdelay ;

         ELSE
         END ;
         anim := anim^.Right
      UNTIL anim = head ;
   END
END AdjustDelay ;


(*
   ExpidateAnim - skips to the end of all animations and
                  draws the final image.
*)

PROCEDURE ExpidateAnim ;
VAR
   anim: Anim ;
BEGIN
   IF AnimHead # NIL
   THEN
      WriteString ("expidate anim") ; WriteLn ;
      AdjustDelay (AnimHead, 0) ;
      WHILE AnimHead # NIL DO
         anim := AnimHead ;
         SubQueue (AnimHead, anim) ;
         Process (MakeSolo (anim))
      END
   END
END ExpidateAnim ;


(*
   CheckInitialized -
*)

PROCEDURE CheckInitialized ;
BEGIN
   IF Options.Debug AND (NOT Initialized)
   THEN
      OpenNamedPipe
   END
END CheckInitialized ;


(*
   OpenNamedPipe -
*)

PROCEDURE OpenNamedPipe ;
BEGIN
   IF Options.Debug AND (NOT Initialized)
   THEN
      Initialized := TRUE ;
      NamedPipe := SFIO.OpenToWrite (Options.DebugFile) ;
      IF FIO.IsError (NamedPipe)
      THEN
         WriteString ("unable to open named pipe 'debugging'") ;
         WriteLn ;
         HALT (1)
      END
   END
END OpenNamedPipe ;


(*
   WriteNamedPipe -
*)

PROCEDURE WriteNamedPipe (ch: CHAR) ;
BEGIN
   FIO.WriteChar (NamedPipe, ch) ;
   FIO.FlushBuffer (NamedPipe)
END WriteNamedPipe ;


(*
   DumpQueue -
*)

PROCEDURE DumpQueue (title: ARRAY OF CHAR) ;
BEGIN
   IF Options.Debug
   THEN
      IF PrevEmpty AND (AnimHead = NIL)
      THEN
         RETURN
      END ;
      PrevEmpty := (AnimHead = NIL) ;
      CheckInitialized ;
      PushOutput (WriteNamedPipe) ;
      WriteString (title) ; WriteLn ;
      DumpQueueInfo ("AnimHead", 0, AnimHead) ;
      DumpQueueInfo ("FreeList", 0, FreeList) ;
      WriteString ("end ") ; WriteString (title) ; WriteLn ;
      PopOutput
   END
END DumpQueue ;


(*
   DumpType -
*)

PROCEDURE DumpType (item: Anim) ;
BEGIN
   CASE item^.kind OF

   WalkT :  WriteString ('walk ') |
   ArrowT:  WriteString ('arrow') |
   DoorT :  WriteString ('door ') |
   StillT:  WriteString ('still') |
   EraseT:  WriteString ('erase')

   END
END DumpType ;


(*
   WritePoint -
*)

PROCEDURE WritePoint (x, y: CARDINAL) ;
BEGIN
   WriteString ('(') ;
   WriteCard (x, 0) ;
   WriteString (', ') ;
   WriteCard (y, 0) ;
   WriteString (')')
END WritePoint ;


(*
   DumpItem -
*)

PROCEDURE DumpItem (item: Anim; indent: CARDINAL) ;
BEGIN
   WriteIndent (indent) ;
   WriteCard (item^.id, 4) ;
   WriteString (' ') ;
   DumpType (item) ;
   WriteString (' delay') ;
   WriteCard (item^.Delay, 4) ;
   WITH item^ DO
      CASE kind OF

      WalkT:  WriteString (' from rel ') ;
              WritePoint (walk.fromx, walk.fromy) ;
              WriteString (' to abs ') ;
              WritePoint (walk.tox, walk.toy) ;
              WriteString (' step') ;
              WriteCard (walk.step, 4) ;
              WriteString (' clientsteps') ;
              WriteCard (walk.clientsteps, 4) ;
              WriteString (' total') ;
              WriteCard (walk.total, 4) ;
              WriteString (' period') ;
              WriteCard (walk.period, 4) ;
              WriteString (' dir') ;
              WriteCard (walk.dir, 4) ;
              WriteLn ;
              IF walk.pending # NIL
              THEN
                 DumpQueueInfo ('Pending', indent+1, walk.pending)
              END |
      StillT: WriteString (' pos ') ;
              WritePoint (still.x, still.y) ;
              WriteString (' dir') ;
              WriteCard (still.dir, 4) ;
              WriteLn |
      EraseT: WriteString (' pos ') ;
              WritePoint (erase.x, erase.y) ;
              WriteLn |
      DoorT:  WriteString (' from ') ;
              WritePoint (door.fromx, door.fromy) ;
              WriteString (' to ') ;
              WritePoint (door.tox, door.toy) ;
              WriteString (' step') ;
              WriteCard (door.step, 4) ;
              WriteString (' total') ;
              WriteCard (door.total, 4) ;
              WriteString (' period') ;
              WriteCard (door.period, 4) ;
              WriteCard (ORD (door.gradiant), 4) ;
              IF door.horiz
              THEN
                 WriteString (' horizontal')
              ELSE
                 WriteString (' vertical')
              END ;
              WriteLn

      ELSE
      END
   END
END DumpItem ;


(*
   WriteIndent -
*)

PROCEDURE WriteIndent (spaces: CARDINAL) ;
BEGIN
   WHILE spaces > 0 DO
      Write (' ') ;
      DEC (spaces)
   END
END WriteIndent ;


(*
   DumpQueueInfo -
*)

PROCEDURE DumpQueueInfo (name: ARRAY OF CHAR; indent: CARDINAL; Head: Anim) ;
VAR
   item: Anim ;
BEGIN
   WriteIndent (indent) ;
   IF Head = NIL
   THEN
      WriteString (name) ; WriteString (' is empty') ; WriteLn
   ELSE
      WriteString (name) ; WriteString (' queue:') ; WriteLn ;
      item := Head ;
      REPEAT
         DumpItem (item, indent) ;
         item := item^.Right
      UNTIL (item = Head) OR (item = NIL)
      (* The FreeList is NIL terminated.  *)
   END
END DumpQueueInfo ;


(*
   MakeEraseMan -
*)

PROCEDURE MakeEraseMan (x, y: CARDINAL; self: BOOLEAN) ;
VAR
   head,
   anim: Anim ;
BEGIN
   anim := InitAnim (EraseT) ;
   WITH anim^ DO
      Delay := 0 ;
      erase.x := x ;
      erase.y := y ;
      erase.self := self
   END ;
   IF IsOnQueueSelf (WalkT, self)
   THEN
      head := GetAnimSelf (WalkT, self) ;
      AddToQueueBack (head^.walk.pending, anim)
   ELSE
      MakeAnim (anim, 0)
   END
END MakeEraseMan ;


(*
   GetAnim -
*)

PROCEDURE GetAnim (kind: Kind) : Anim ;
VAR
   anim: Anim ;
BEGIN
   IF AnimHead # NIL
   THEN
      anim := AnimHead ;
      REPEAT
         IF anim^.kind = kind
         THEN
            RETURN anim
         END ;
         anim := anim^.Right
      UNTIL anim = AnimHead
   END ;
   RETURN NIL
END GetAnim ;


(*
   GetAnimSelf -
*)

PROCEDURE GetAnimSelf (kind: Kind; self: BOOLEAN) : Anim ;
VAR
   anim: Anim ;
BEGIN
   IF AnimHead # NIL
   THEN
      anim := AnimHead ;
      REPEAT
         IF anim^.kind = kind
         THEN
            CASE anim^.kind OF

            WalkT : IF anim^.walk.self = self
                    THEN
                       RETURN anim
                    END |
            ArrowT,
            DoorT : RETURN anim |
            StillT: IF anim^.still.self = self
                    THEN
                       RETURN anim
                    END |
            EraseT: IF anim^.erase.self = self
                    THEN
                       RETURN anim
                    END

            END
         END ;
         anim := anim^.Right
      UNTIL anim = AnimHead
   END ;
   RETURN NIL
END GetAnimSelf ;


(*
   IsOnQueue -
*)

PROCEDURE IsOnQueue (kind: Kind) : BOOLEAN ;
VAR
   anim: Anim ;
BEGIN
   IF AnimHead # NIL
   THEN
      anim := AnimHead ;
      REPEAT
         IF anim^.kind = kind
         THEN
            RETURN TRUE
         END ;
         anim := anim^.Right
      UNTIL anim = AnimHead
   END ;
   RETURN FALSE
END IsOnQueue ;


(*
   IsOnQueueSelf -
*)

PROCEDURE IsOnQueueSelf (kind: Kind; self: BOOLEAN) : BOOLEAN ;
VAR
   anim: Anim ;
BEGIN
   IF AnimHead # NIL
   THEN
      anim := AnimHead ;
      REPEAT
         IF anim^.kind = kind
         THEN
            CASE anim^.kind OF

            WalkT : IF anim^.walk.self = self
                    THEN
                       RETURN TRUE
                    END |
            ArrowT,
            DoorT : RETURN TRUE |
            StillT: IF anim^.still.self = self
                    THEN
                       RETURN TRUE
                    END |
            EraseT: IF anim^.erase.self = self
                    THEN
                       RETURN TRUE
                    END

            END
         END ;
         anim := anim^.Right
      UNTIL anim = AnimHead
   END ;
   RETURN FALSE
END IsOnQueueSelf ;


(*
   ProcessStill -
*)

PROCEDURE ProcessStill (anim: Anim) ;
BEGIN
   KillAnim (anim)
END ProcessStill ;


(*
   ProcessErase -
*)

PROCEDURE ProcessErase (anim: Anim) ;
BEGIN
   RawProcessErase (anim^.erase.x,
                    anim^.erase.y) ;
   KillAnim (anim)
END ProcessErase ;


(*
   RawProcessErase -
*)

PROCEDURE RawProcessErase (x, y: CARDINAL) ;
BEGIN
   IF DebuggingErase
   THEN
      color.BackgroundRGB6 (DebugErase.red,
                            DebugErase.green,
                            DebugErase.blue)
   ELSE
      color.Default
   END ;
   color.Pos (x, y) ;
   Write (' ') ;
   IF DebuggingErase
   THEN
      color.Default
   END ;
   FIO.FlushBuffer (FIO.StdOut)
END RawProcessErase ;


(*
   RestCursor - places the cursor at the bottom right of the screen.
*)

PROCEDURE RestCursor ;
BEGIN
   color.Pos (79, 34) ;
   FIO.FlushBuffer (FIO.StdOut)
END RestCursor ;


(*
   FlushAnim -
*)

PROCEDURE FlushAnim ;
VAR
   anim: Anim ;
BEGIN
   WHILE AnimHead # NIL DO
      anim := AnimHead ;
      SubQueue (AnimHead, anim) ;
      KillAnim (MakeSolo (anim))
   END
END FlushAnim ;


(*
   Clear - clear the screen, this will immediately
           flush any animations.
*)

PROCEDURE Clear ;
BEGIN
   FlushAnim ;
   color.Clear ;
   color.Home ;
   TextX := 1 ;
   TextY := 1
END Clear ;


(*
   Hud - update the heads up display at line with
         title and amount.
*)

PROCEDURE Hud (line: CARDINAL; Title, Amount: ARRAY OF CHAR) ;
VAR
   len: CARDINAL ;
BEGIN
   color.Pos (79-12, line) ;
   FIO.WriteString (FIO.StdOut, Title) ;
   FIO.WriteString (FIO.StdOut, " ") ;
   FIO.WriteString (FIO.StdOut, Amount) ;
   len := StrLen (Title) + StrLen (Amount) + 1 ;
   WHILE len < 79 DO
      FIO.WriteString (FIO.StdOut, " ") ;
      INC (len)
   END ;
   FIO.FlushBuffer (FIO.StdOut)
END Hud ;


(*
   Process -
*)

PROCEDURE Process (anim: Anim) ;
BEGIN
   IF anim # NIL
   THEN
      CASE anim^.kind OF

      WalkT:  ProcessWalk (anim) |
      StillT: ProcessStill (anim) |
      EraseT: ProcessErase (anim) |
      DoorT:  ProcessDoor (anim)

      END
   END
END Process ;


(*
   Pulse - called on a select timeout.
*)

PROCEDURE Pulse ;
VAR
   anim: Anim ;
BEGIN
   DumpQueue ("Pulse start") ;
   IF (AnimHead # NIL) AND (AnimHead^.Delay > 0)
   THEN
      DEC (AnimHead^.Delay)
   END ;
   WHILE (AnimHead # NIL) AND (AnimHead^.Delay = 0) DO
      anim := AnimHead ;
      SubQueue (AnimHead, anim) ;
      Process (MakeSolo (anim))
   END ;
   DumpQueue ("Pulse end")
END Pulse ;


(*
   GenerateGradiants -
*)

PROCEDURE GenerateGradiants ;
VAR
   grey: CARDINAL ;
BEGIN
   FOR grey := 0 TO MaxGradiant DO
      (* Closed to Open.  *)
      ColorGradiant[0][grey] := ColorGrey (grey) ;
      (* Open to Closed.  *)
      ColorGradiant[1][grey] := ColorGrey (MaxGradiant - grey)
   END ;
   (* And use BlankColor for open door.  *)
   ColorGradiant[1][MaxGradiant] := BlankColor ;   (* Open to closed.  *)
   ColorGradiant[0][0] := BlankColor ;  (* Closed to open.  *)

   (* Secret to Closed.  *)
   ColorGradiant[3][0] := WallColor ;
   ColorGradiant[3][1] := Color {3, 1, 1} ;
   ColorGradiant[3][2] := Color {3, 1, 2} ;
   ColorGradiant[3][3] := Color {3, 1, 1} ;
   ColorGradiant[3][4] := Color {3, 1, 2} ;
   ColorGradiant[3][4] := Color {3, 1, 1} ;
   ColorGradiant[3][5] := Color {3, 2, 2} ;
   ColorGradiant[3][6] := Color {3, 2, 1} ;
   ColorGradiant[3][7] := Color {3, 2, 2} ;
   ColorGradiant[3][8] := Color {3, 2, 1} ;
   ColorGradiant[3][9] := Color {3, 2, 2} ;
   ColorGradiant[3][10] := Color {3, 2, 1} ;
   ColorGradiant[3][11] := Color {4, 2, 1} ;
   FOR grey := 12 TO MaxGradiant DO
      ColorGradiant[3][grey] := ColorGrey (grey)
   END ;
   (* Closed to Secret.  *)
   FOR grey := 0 TO MaxGradiant DO
      ColorGradiant[2][grey] := ColorGradiant[3][MaxGradiant - grey]
   END
END GenerateGradiants ;


(*
   dWriteStr - write a string contents.
*)

PROCEDURE dWriteStr (contents: ARRAY OF CHAR) ;
BEGIN
   color.Pos (TextX, TextY) ;
   FIO.WriteString (FIO.StdOut, contents) ;
   FIO.FlushBuffer (FIO.StdOut) ;
   INC (TextX, StrLen (contents))
END dWriteStr ;


(*
   dWriteLn - write a string contents and a newline.
*)

PROCEDURE dWriteLn (contents: ARRAY OF CHAR) ;
BEGIN
   color.Pos (TextX, TextY) ;
   FIO.WriteString (FIO.StdOut, contents) ;
   FIO.WriteLine (FIO.StdOut) ;
   FIO.FlushBuffer (FIO.StdOut) ;
   INC (TextY) ;
   TextX := 1
END dWriteLn ;


(*
   Init -
*)

PROCEDURE Init ;
BEGIN
   WallColor := Color {3, 1, 1} ;
   BlankColor := Color {0, 0, 0} ;
   ClosedColor := ColorGrey (MaxGradiant) ;
   SecretColor := Color {1, 5, 2} ;
   DebugErase := Color {2, 0, 0} ;
   DebugColor := Color {0, 0, 5} ;
   GoggledColor := Color {0, 1, 1} ;
   OtherColor := Color {1, 1, 4} ;
   PlayerColor := ColorGrey (MaxGradiant) ;
   FreeList := NIL ;
   AnimHead := NIL ;
   CurrentId := 0 ;
   Initialized := FALSE ;
   PrevEmpty := FALSE ;
   GenerateGradiants ;
   TextX := 1 ;
   TextY := 1
END Init ;


BEGIN
   Init
END Screen.
