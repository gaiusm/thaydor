IMPLEMENTATION MODULE DrawL ;


FROM ASCII IMPORT lf, bs ;
FROM Window IMPORT Clip, ClipPoint ;
FROM StrIO IMPORT WriteString, WriteLn ;
FROM NumberIO IMPORT WriteCard ;
FROM StdIO IMPORT Write ;
FROM StrLib IMPORT StrCopy ;
FROM Debug IMPORT Halt ;
FROM Assertion IMPORT Assert ;

FROM AdvMap IMPORT Rooms, DoorStatus, Line, Room, Door, Treasure ;

FROM AdvMath IMPORT MaxNoOfTreasures, MagicGoggles ;

FROM AdvSystem IMPORT Player, PlayerNo,
                      IsPlayerActive,
                      NextFreePlayer,
                      IsDeviceAnim,
                      GetAccessToScreen,
                      ReleaseAccessToScreen,
                      GetAccessToScreenNo,
                      ReleaseAccessToScreenNo,
                      GetWriteAccessToPlayer,
                      ReleaseWriteAccessToPlayer,
                      GetReadAccessToPlayer,
                      ReleaseReadAccessToPlayer,
                      GetReadAccessToDoor,
                      ReleaseReadAccessToDoor,
                      GetReadAccessToTreasure,
                      ReleaseReadAccessToTreasure ;


(* Draws the current Room that the callers player is in. It also draws *)
(* all treasures, doors and players associated with this room. This    *)
(* procedure DOES get access to treasure locks and door locks but NO   *)
(* player lock is used.                                                *)
(* This procedure does NOT draw SECRET doors as might give them away!  *)
(* It is assumed that walls cover ALL doors.                           *)

PROCEDURE DrawRoom ;
VAR
   ok            : BOOLEAN ;
   hx, hy,
   x1, y1, x2, y2,
   p, t, r, i,
   Sx, Sy        : CARDINAL ;
   ds            : DoorStatus ;
BEGIN
   p := PlayerNo() ;
   WITH Player[p] DO

      r := RoomOfMan ;
      Sx := ScreenX ;
      Sy := ScreenY ;
      t := Rooms[r].NoOfWalls ;
      FOR i := 1 TO t DO
         WITH Rooms[r].Walls[i] DO
            x1 := X1 ;
            y1 := Y1 ;
            x2 := X2 ;
            y2 := Y2
         END ;
         Clip( x1, y1, x2, y2, Sx, Sy, ok ) ;

         IF ok
         THEN
            GetAccessToScreen ;
            WLine(x1, y1, x2, y2) ;
            ReleaseAccessToScreen
         END
      END ;

      GetReadAccessToDoor ;
      t := Rooms[r].NoOfDoors ;
      FOR i := 1 TO t DO
         WITH Rooms[r].Doors[i] DO
            x1 := Position.X1 ;
            y1 := Position.Y1 ;
            x2 := Position.X2 ;
            y2 := Position.Y2 ;
            ds := StateOfDoor ;
            IF ((ds = Secret) OR (ds = Timed)) AND
               (MagicGoggles IN Player[p].Entity.TreasureOwn)
            THEN
               ds := Goggled
            END ;
            IF (ds # Secret) AND (ds # Timed)
            THEN
               Clip( x1, y1, x2, y2, Sx, Sy, ok ) ;
               IF ok
               THEN
                  GetAccessToScreenNo (p) ;
                  IF Position.X1=Position.X2
                  THEN
                     hx := Position.X2 ;
                     hy := Position.Y2 ;
                     Assert((ScreenX=Sx) AND (ScreenY=Sy)) ;
                     ClipPoint(hx, hy, ScreenX, ScreenY, ok) ;
                     DLine(p, x1, y1, x2, y2, ok, ds, ds)
                  ELSE
                     hx := Position.X1 ;
                     hy := Position.Y1 ;
                     Assert((ScreenX=Sx) AND (ScreenY=Sy)) ;
                     ClipPoint(hx, hy, ScreenX, ScreenY, ok) ;
                     DLine(p, x1, y1, x2, y2, ok, ds, ds)
                  END ;
                  ReleaseAccessToScreenNo (p)
               END
            END
         END
      END ;
      ReleaseReadAccessToDoor ;

      GetReadAccessToTreasure ;
      FOR i := 1 TO MaxNoOfTreasures DO
         WITH Rooms[r] DO
            IF i IN Treasures
            THEN
               x1 := Treasure[i].Xpos ;
               y1 := Treasure[i].Ypos ;
               ClipPoint(x1, y1, ScreenX, ScreenY, ok) ;
               IF ok
               THEN
                  GetAccessToScreen ;
                  DTreasure(x1, y1) ;
                  ReleaseAccessToScreen
               END
            END
         END
      END ;
      ReleaseReadAccessToTreasure ;
   END ;

   (* This called routine must now draw the other players as well *)
   (* as drawing the current man.                                 *)
   (* Assumes that this player has been updated in Data Structure *)
   (* but has not yet been displayed on the screen.               *)

   DrawAllPlayers ;

END DrawRoom ;


(* Draw all players uses no player lock.                        *)

PROCEDURE DrawAllPlayers ;
VAR
   pn,
   Sx, Sy, dir, p: CARDINAL ;
   x, y, r       : CARDINAL ;
   ok            : BOOLEAN ;
   ch            : CHAR ;
BEGIN
   p := PlayerNo() ;
   WITH Player[p] DO
      Sx := ScreenX ;
      Sy := ScreenY ;
      r := RoomOfMan ;
      dir := Direction ;
      x := Xman-Sx ;
      y := Yman-Sy ;
      GetAccessToScreenNo(p) ;
      DrawMan(FALSE, x, y, dir) ;
      ReleaseAccessToScreenNo(p)
   END ;

   (* Now write all the other Players on the screen *)

   FOR pn := 0 TO NextFreePlayer-1 DO
      IF (pn#p) AND IsPlayerActive(pn)
      THEN
         WITH Player[pn] DO
            IF r=RoomOfMan
            THEN
               x := Xman ;
               y := Yman ;
               dir := Direction ;
               ClipPoint(x, y, Sx, Sy, ok) ;
               IF ok
               THEN
                  GetAccessToScreenNo( p ) ;
                  DrawMan(TRUE, x, y, dir) ;
                  ReleaseAccessToScreenNo( p )
               END
            END
         END
      END
   END
END DrawAllPlayers ;


(* This procedure uses no player lock.                        *)

PROCEDURE EraseAllPlayers ;
VAR
   pn,
   Sx, Sy, p: CARDINAL ;
   x, y, r  : CARDINAL ;
   ok       : BOOLEAN ;
BEGIN
   p := PlayerNo() ;
   WITH Player[p] DO
      Sx := ScreenX ;
      Sy := ScreenY ;
      r := RoomOfMan ;
      x := Xman-Sx ;
      y := Yman-Sy ;
      GetAccessToScreenNo(p) ;
      Erase(x, y) ;
      ReleaseAccessToScreenNo(p)
   END ;

   (* Now write all the other Players on the screen *)

   FOR pn := 0 TO NextFreePlayer-1 DO
      IF (pn#p) AND IsPlayerActive(pn)
      THEN
         WITH Player[pn] DO
            IF r=RoomOfMan
            THEN
               x := Xman ;
               y := Yman ;
               ClipPoint(x, y, Sx, Sy, ok) ;
               IF ok
               THEN
                  GetAccessToScreenNo(p) ;
                  Erase(x, y) ;
                  ReleaseAccessToScreenNo(p)
               END
            END
         END
      END
   END
END EraseAllPlayers ;


(* Clears the Room specified of all treasures and all OTHER players. *)
(* It uses NO lock on any Player. But uses Treasure Lock.            *)

PROCEDURE ClearRoom (r: CARDINAL) ;
VAR
   p, Sx, Sy,
   x, y, pn,
   x1, y1, i: CARDINAL ;
   ok       : BOOLEAN ;
BEGIN
   p := PlayerNo() ;
   WITH Player[p] DO
      Sx := ScreenX ;
      Sy := ScreenY ;
      GetReadAccessToTreasure ;
      FOR i := 1 TO MaxNoOfTreasures DO
         WITH Rooms[r] DO
            IF i IN Treasures
            THEN
               x1 := Treasure[i].Xpos ;
               y1 := Treasure[i].Ypos ;
               ClipPoint(x1, y1, Sx, Sy, ok) ;
               IF ok
               THEN
                  GetAccessToScreenNo(p) ;
                  Erase(x1, y1) ;
                  ReleaseAccessToScreenNo(p)
               END
            END
         END
      END ;
      ReleaseReadAccessToTreasure
   END ;

   (* Now erase all the other Players on the screen *)

   FOR pn := 0 TO NextFreePlayer-1 DO
      IF p#pn
      THEN
         WITH Player[pn] DO
            IF r=RoomOfMan
            THEN
               x := Xman ;
               y := Yman ;
               ClipPoint (x, y, Sx, Sy, ok) ;
               IF ok
               THEN
                  GetAccessToScreenNo (p) ;
                  Erase (x, y) ;
                  ReleaseAccessToScreenNo (p)
               END
            END
         END
      END
   END
END ClearRoom ;


PROCEDURE StrLine (a: ARRAY OF CHAR; x1, y1, x2, y2: CARDINAL) ;
BEGIN
   WriteString(a) ; Write(' ') ;
   WriteCard(x1, 0) ; Write(' ') ;
   WriteCard(y1, 0) ; Write(' ') ;
   WriteCard(x2, 0) ; Write(' ') ;
   WriteCard(y2, 0) ; WriteLn
END StrLine ;


PROCEDURE StrMove (direction: ARRAY OF CHAR; command: ARRAY OF CHAR;
                   x1, y1, x2, y2, stepno, total, delay: CARDINAL) ;
BEGIN
   WriteString (direction) ;
   WriteString (command) ; Write(' ') ;
   WriteCard (x1, 0) ; Write(' ') ;
   WriteCard (y1, 0) ; Write(' ') ;
   WriteCard (x2, 0) ; Write(' ') ;
   WriteCard (y2, 0) ; Write(' ') ;
   WriteCard (stepno, 0) ; Write(' ') ;
   WriteCard (total, 0) ;  Write(' ') ;
   WriteCard (delay, 0) ; WriteLn
END StrMove ;


PROCEDURE WLine (x1, y1, x2, y2: CARDINAL) ;
BEGIN
   IF y1=y2
   THEN
      StrLine('hwall', x1, y1, x2, y2)
   ELSE
      Assert(x1=x2) ;
      StrLine('vwall', x1, y1, x2, y2)
   END
END WLine ;


(*
   DescribeStatus -
*)

PROCEDURE DescribeStatus (status: DoorStatus) ;
BEGIN
   CASE status OF

   Open  :  WriteString ('open') |
   Closed:  WriteString ('closed') |
   Secret:  WriteString ('secret') |
   Timed :  WriteString ('timed')

   END
END DescribeStatus ;


(*
   DoorChange -
*)

PROCEDURE DoorChange (p: CARDINAL; From, To: DoorStatus) ;
BEGIN
   IF IsDeviceAnim (p) AND (From # To)
   THEN
      WriteString ('animdoor') ;
      DescribeStatus (From) ;
      DescribeStatus (To) ;
      WriteString (' ')
   END
END DoorChange ;


(*
   DsStrPoint -
*)

PROCEDURE DsStrPoint (p: CARDINAL;
                      str: ARRAY OF CHAR; x1, y1: CARDINAL; From, To: DoorStatus) ;
BEGIN
   DoorChange (p, From, To) ;
   WriteString (str) ; Write(' ') ;
   WriteCard (x1, 0) ; Write(' ') ;
   WriteCard (y1, 0) ; Write(' ') ;
   WriteLn
END DsStrPoint ;


PROCEDURE DsStrLine (p: CARDINAL;
                     str: ARRAY OF CHAR; x1, y1, x2, y2: CARDINAL; From, To: DoorStatus) ;
BEGIN
   DoorChange (p, From, To) ;
   StrLine (str, x1, y1, x2, y2)
END DsStrLine ;


PROCEDURE DLine (p: CARDINAL;
                 x1, y1, x2, y2: CARDINAL;
                 hinge: BOOLEAN;
                 From, To: DoorStatus) ;
VAR
   x, ys: CARDINAL ;
BEGIN
   IF y1=y2
   THEN
      CASE To OF

      Closed : IF hinge
               THEN
                  DsStrPoint (p, 'hhinge', x1, y1, From, To) ;
                  INC(x1)
               END ;
               IF x1<=x2
               THEN
                  DsStrLine (p, 'hdoor', x1, y1, x2, y2, From, To)
               END |
      Open   : DsStrLine (p, 'open', x1, y1, x2, y2, From, To) |
      Timed,
      Secret : DsStrLine (p, 'secret', x1, y1, x2, y2, From, To) |
      Goggled: DsStrLine (p, 'goggled', x1, y1, x2, y2, From, To)

      END
   ELSE
      CASE To OF

      Closed : IF hinge
               THEN
                  DsStrPoint (p, 'vhinge', x1, y2, From, To) ;
                  DEC(y2)
               END ;
               IF y1<=y2
               THEN
                  DsStrLine(p, 'vdoor', x1, y1, x2, y2, From, To)
               END |
      Open   : DsStrLine (p, 'open', x1, y1, x2, y2, From, To) |
      Timed,
      Secret : DsStrLine (p, 'secret', x1, y1, x2, y2, From, To) |
      Goggled: DsStrLine (p, 'goggled', x1, y1, x2, y2, From, To)

      END
   END
END DLine ;


PROCEDURE StrPoint (a: ARRAY OF CHAR; x, y: CARDINAL) ;
BEGIN
   WriteString(a) ; Write(' ') ;
   WriteCard(x, 0) ; Write(' ') ;
   WriteCard(y, 0) ; WriteLn
END StrPoint ;


PROCEDURE DTreasure (x, y: CARDINAL) ;
BEGIN
   StrPoint('treasure', x, y)
END DTreasure ;


PROCEDURE Erase (x, y: CARDINAL) ;
BEGIN
   StrPoint('eL', x, y)
END Erase ;


PROCEDURE DrawMan (other: BOOLEAN; x, y, dir: CARDINAL) ;
BEGIN
   IF other
   THEN
      CASE dir OF

      0:  StrPoint('Nman', x, y) |
      1:  StrPoint('Wman', x, y) |
      2:  StrPoint('Sman', x, y) |
      3:  StrPoint('Eman', x, y)

      ELSE
         Halt ('unexpected direction', __FILE__, __FUNCTION__, __LINE__)
      END
   ELSE
      CASE dir OF

      0:  StrPoint('nman', x, y) |
      1:  StrPoint('wman', x, y) |
      2:  StrPoint('sman', x, y) |
      3:  StrPoint('eman', x, y)

      ELSE
         Halt ('unexpected direction', __FILE__, __FUNCTION__, __LINE__)
      END
   END
END DrawMan ;


PROCEDURE AnimEraseMan (other: BOOLEAN; x, y: CARDINAL) ;
BEGIN
   IF other
   THEN
      StrPoint ('animEraseman', x, y)
   ELSE
      StrPoint ('animeraseman', x, y)
   END
END AnimEraseMan ;


PROCEDURE AnimMoveMan (other: BOOLEAN; fromrelx, fromrely, toabsx, toabsy, dir, stepno, total, delay: CARDINAL) ;
VAR
   command: ARRAY [0..20] OF CHAR ;
BEGIN
   IF total <= 1
   THEN
      StrCopy ("walk", command)
   ELSE
      StrCopy ("run", command)
   END ;
   IF other
   THEN
      CASE dir OF

      0:  StrMove ('animN', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay) |
      1:  StrMove ('animW', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay) |
      2:  StrMove ('animS', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay) |
      3:  StrMove ('animE', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay)

      ELSE
         Halt ('unexpected direction', __FILE__, __FUNCTION__, __LINE__)
      END
   ELSE
      CASE dir OF

      0:  StrMove ('animn', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay) |
      1:  StrMove ('animw', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay) |
      2:  StrMove ('anims', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay) |
      3:  StrMove ('anime', command, fromrelx, fromrely, toabsx, toabsy, stepno, total, delay)

      ELSE
         Halt ('unexpected direction', __FILE__, __FUNCTION__, __LINE__)
      END
   END
END AnimMoveMan ;


PROCEDURE AnimArrow (fromx, fromy, tox, toy, dir, stepno, total, delay: CARDINAL) ;
BEGIN
   CASE dir OF

   0:  StrMove ('anim', 'nar', fromx, fromy, tox, toy, stepno, total, delay) |
   1:  StrMove ('anim', 'ear', fromx, fromy, tox, toy, stepno, total, delay) |
   2:  StrMove ('anim', 'sar', fromx, fromy, tox, toy, stepno, total, delay) |
   3:  StrMove ('anim', 'war', fromx, fromy, tox, toy, stepno, total, delay)

   ELSE
      Halt ('unexpected direction', __FILE__, __FUNCTION__, __LINE__)
   END
END AnimArrow ;


(*
   ReverseArrow -
*)

PROCEDURE ReverseArrow (x, y, dir: CARDINAL) ;
BEGIN
   CASE dir OF

   0:  StrPoint('revnar', x, y) |
   1:  StrPoint('revwar', x, y) |
   2:  StrPoint('revsar', x, y) |
   3:  StrPoint('revear', x, y)

   ELSE
      Halt ('unexpected direction', __FILE__, __FUNCTION__, __LINE__)
   END
END ReverseArrow ;


PROCEDURE DArrow (x, y, dir: CARDINAL) ;
BEGIN
   CASE dir OF

   0:  StrPoint('nar', x, y) |
   1:  StrPoint('war', x, y) |
   2:  StrPoint('sar', x, y) |
   3:  StrPoint('ear', x, y)

   ELSE
      Halt ('unexpected direction', __FILE__, __FUNCTION__, __LINE__)
   END
END DArrow ;


END DrawL.
(*
 * Local variables:
 *  compile-command: "make"
 * End:
 *)
