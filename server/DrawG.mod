IMPLEMENTATION MODULE DrawG ;


FROM AdvMap IMPORT Rooms, Door, DoorStatus, Line, Adjacent ;
FROM ASCII IMPORT lf, bs ;
FROM Window IMPORT Clip, ClipPoint ;
FROM StdIO IMPORT Write ;
IMPORT DrawL ;

FROM Screen IMPORT Height, Width, Flush,
                   WriteCommentLine1, WriteCommentLine2, WriteCommentLine3 ;

FROM AdvMap IMPORT IncPosition ;

FROM AdvSystem IMPORT Player, PlayerNo, PlayerSet,
                      NextFreePlayer,
                      IsPlayerActive,
                      GetReadAccessToPlayer,
                      GetWriteAccessToPlayer,
                      ReleaseReadAccessToPlayer,
                      ReleaseWriteAccessToPlayer,
                      GetReadAccessToDoor,
                      ReleaseReadAccessToDoor,
                      GetReadAccessToTreasure,
                      ReleaseReadAccessToTreasure,
                      GetAccessToScreenNo,
                      ReleaseAccessToScreenNo ;


(* All these procedures to draw on the screens - are Global *)
(* Ie they will draw to all the screens that are within     *)
(* the area of effect.                                      *)


(* DrawMan draws the calling player on every screen that    *)
(* is within the area of effect. And which has the same     *)
(* current room number.                                     *)
(* This routine only uses the AccessToScreen Locks.         *)

PROCEDURE DrawMan (p: CARDINAL) ;
VAR
   i,
   x, y, Sx, Sy, r,
   dir            : CARDINAL ;
BEGIN
   WITH Player[p] DO
      r := RoomOfMan ;
      x := Xman ;
      y := Yman ;
      dir := Direction
   END ;

   FOR i := 0 TO NextFreePlayer-1 DO
      IF IsPlayerActive(i)
      THEN
         WITH Player[i] DO
            IF r=RoomOfMan
            THEN
               Sy := ScreenY ;
               Sx := ScreenX ;
               IF (x>=Sx) AND (x<=Sx+Width) AND
                  (y>=Sy) AND (y<=Sy+Height)
               THEN
                  GetAccessToScreenNo(i) ;
                  DrawL.DrawMan(p#i, x-Sx, y-Sy, dir) ;
                  ReleaseAccessToScreenNo(i)
               END
            END
         END
      END
   END
END DrawMan ;


(* EraseMan erases the calling player on every screen that is *)
(* currently displaying this player.                          *)

PROCEDURE EraseMan (p: CARDINAL) ;
VAR
   i, r, x, y, Sx, Sy: CARDINAL ;
BEGIN
   WITH Player[p] DO
      r := RoomOfMan ;
      x := Xman ;
      y := Yman
   END ;

   FOR i := 0 TO NextFreePlayer-1 DO
      IF IsPlayerActive(i)
      THEN
         WITH Player[i] DO
            IF r=RoomOfMan
            THEN
               Sy := ScreenY ;
               Sx := ScreenX ;
               IF (x>=Sx) AND (x<=Sx+Width) AND
                  (y>=Sy) AND (y<=Sy+Height)
               THEN
                  GetAccessToScreenNo(i) ;
                  DrawL.Erase(x-Sx, y-Sy) ;
                  Flush(i) ;
                  ReleaseAccessToScreenNo(i)
               END
            END
         END
      END
   END
END EraseMan ;


(* AnimEraseMan erases the calling player on every screen     *)
(* that is currently displaying this player.                  *)

PROCEDURE AnimEraseMan (p: CARDINAL) ;
VAR
   i, r, x, y, Sx, Sy: CARDINAL ;
BEGIN
   WITH Player[p] DO
      r := RoomOfMan ;
      x := Xman ;
      y := Yman
   END ;

   FOR i := 0 TO NextFreePlayer-1 DO
      IF IsPlayerActive (i) AND IsVisible (i, r, x, y)
      THEN
         WITH Player[i] DO
            Sx := ScreenX ;
            Sy := ScreenY
         END ;
         GetAccessToScreenNo (i) ;
         DrawL.AnimEraseMan (i#p, x-Sx, y-Sy) ;
         Flush (i) ;
         ReleaseAccessToScreenNo (i)
      END
   END
END AnimEraseMan ;


(*
   IsVisible - return TRUE if position x, y is visible for player p.
*)

PROCEDURE IsVisible (p, r, x, y: CARDINAL) : BOOLEAN ;
VAR
   Sx, Sy: CARDINAL ;
BEGIN
   WITH Player[p] DO
      IF r = RoomOfMan
      THEN
         Sx := ScreenX ;
         Sy := ScreenY ;
         IF (x>=Sx) AND (x<=Sx+Width) AND
            (y>=Sy) AND (y<=Sy+Height)
         THEN
            RETURN TRUE
         END
      END
   END ;
   RETURN FALSE
END IsVisible ;


PROCEDURE AnimMoveMan (player, step, TotalDist, dir, delay, room: CARDINAL) ;
VAR
   Sx, Sy,
   pn, i, j,
   x, y, r : CARDINAL ;
BEGIN
   WITH Player[player] DO
      x := Xman ;
      y := Yman ;
      dir := Direction
   END ;

   FOR pn := 0 TO NextFreePlayer-1 DO
      IF IsPlayerActive (pn)
      THEN
         IF IsVisible (pn, room, x, y)
         THEN
            WITH Player[pn] DO
               Sx := ScreenX ;
               Sy := ScreenY
            END ;
            i := x ;
            j := y ;
            IncPosition (i, j, dir) ;
            GetAccessToScreenNo (pn) ;
            IF IsVisible (pn, room, i, j)
            THEN
               DrawL.AnimMoveMan (player # pn, x-Sx, y-Sy, i, j, dir, step, TotalDist, delay)
            ELSE
               DrawL.AnimEraseMan (player # pn, x-Sx, y-Sy) ;
               Flush (pn)
            END ;
            ReleaseAccessToScreenNo (pn)
         END
      END
   END
END AnimMoveMan ;


(* DrawDoor draws a door on every screen possible ie all that *)
(* are in this particular area. Hence the coordinates need    *)
(* to be absolute NOT relative!                               *)
(* This procedure uses Locks GetAccessToScreen ONLY!          *)

PROCEDURE DrawDoor (RoomOfDoor, IndexToDoor: CARDINAL) ;
BEGIN
   DrawDoorChange (RoomOfDoor, IndexToDoor,
                   Rooms[RoomOfDoor].Doors[IndexToDoor].StateOfDoor)
END DrawDoor ;


PROCEDURE DrawDoorChange (RoomOfDoor, IndexToDoor: CARDINAL;
                          ToStatus: DoorStatus) ;
VAR
   p                   : CARDINAL ;
   hx, hy,
   x, y, NextRoom,
   i, j, x1, y1, x2, y2: CARDINAL ;
   ok                  : BOOLEAN ;
   yt, xt              : CARDINAL ;
   FromStatus          : DoorStatus ;
BEGIN
   WITH Rooms[RoomOfDoor].Doors[IndexToDoor].Position DO
      x1 := X1 ;
      x2 := X2 ;
      y1 := Y1 ;
      y2 := Y2
   END ;

   WITH Rooms[RoomOfDoor].Doors[IndexToDoor] DO
      FromStatus := StateOfDoor ;
      StateOfDoor := ToStatus ;
      NextRoom := LeadsTo
   END ;

   FOR p := 0 TO NextFreePlayer-1 DO
      IF IsPlayerActive (p)
      THEN
         WITH Player[p] DO
            IF (RoomOfDoor=RoomOfMan) OR (RoomOfMan=NextRoom)
            THEN
               i := x1 ;
               j := y1 ;
               x := x2 ;
               y := y2 ;
               Clip (i, j, x, y, ScreenX, ScreenY, ok) ;
               IF ok
               THEN
                  GetAccessToScreenNo (p) ;
                  IF i=x
                  THEN
                     hx := x2 ;
                     hy := y2
                  ELSE
                     hx := x1 ;
                     hy := y1 ;
                  END ;
                  ClipPoint (hx, hy, ScreenX, ScreenY, ok) ;
                  DrawL.DLine (p, i, j, x, y, ok,
                               FromStatus, ToStatus) ;
                  ReleaseAccessToScreenNo (p)
               END
            END
         END
      END
   END
END DrawDoorChange ;


(* This procedure only uses LOCKS GetAccessToScreen *)

PROCEDURE DrawTreasure (room, x, y: CARDINAL) ;
VAR
   p     : CARDINAL ;
   Sx, Sy: CARDINAL ;
BEGIN
   p := 0 ;
   WHILE p < NextFreePlayer DO
      IF IsPlayerActive(p)
      THEN
         WITH Player[p] DO
            IF room=RoomOfMan
            THEN
               Sy := ScreenY ;
               Sx := ScreenX ;
               IF (x>=Sx) AND (x<=Sx+Width) AND
                  (y>=Sy) AND (y<=Sy+Height)
               THEN
                  GetAccessToScreenNo(p) ;
                  DrawL.DTreasure(x-Sx, y-Sy) ;
                  ReleaseAccessToScreenNo(p)
               END
            END
         END
      END ;
      INC (p)
   END
END DrawTreasure ;


PROCEDURE EraseTreasure (room, x, y: CARDINAL) ;
VAR
   p     : CARDINAL ;
   Sx, Sy: CARDINAL ;
BEGIN
   p := 0 ;
   WHILE p < NextFreePlayer DO
      IF IsPlayerActive(p)
      THEN
         WITH Player[p] DO
            IF room=RoomOfMan
            THEN
               Sy := ScreenY ;
               Sx := ScreenX ;
               IF (x>=Sx) AND (x<=Sx+Width) AND
                  (y>=Sy) AND (y<=Sy+Height)
               THEN
                  GetAccessToScreenNo(p) ;
                  DrawL.Erase(x-Sx, y-Sy) ;
                  Flush(p) ;
                  ReleaseAccessToScreenNo(p)
               END
            END
         END
      END ;
      INC (p)
   END
END EraseTreasure ;


(* This procedure only uses LOCKS GetAccessToScreen *)

PROCEDURE DrawArrow (room, x, y, dir: CARDINAL ; VAR playerscreen: PlayerSet) ;
VAR
   p, Sx, Sy: CARDINAL ;
BEGIN
   playerscreen := PlayerSet{} ;
   p := 0 ;
   WHILE p < NextFreePlayer DO
      IF IsPlayerActive(p)
      THEN
         WITH Player[p] DO
            IF room=RoomOfMan
            THEN
               Sy := ScreenY ;
               Sx := ScreenX ;
               IF (x>=Sx) AND (x<=Sx+Width) AND
                  (y>=Sy) AND (y<=Sy+Height)
               THEN
                  INCL(playerscreen, p) ;
                  GetAccessToScreenNo(p) ;
                  DrawL.DArrow(x-Sx, y-Sy, dir) ;
                  ReleaseAccessToScreenNo(p)
               END
            END
         END
      END ;
      INC (p)
   END
END DrawArrow ;


PROCEDURE EraseArrow (x, y: CARDINAL ; playerscreen: PlayerSet; flush: BOOLEAN) ;
VAR
   p, Sx, Sy: CARDINAL ;
BEGIN
   p := 0 ;
   WHILE p < NextFreePlayer DO
      IF IsPlayerActive(p)
      THEN
         WITH Player[p] DO
            IF p IN playerscreen
            THEN
               Sy := ScreenY ;
               Sx := ScreenX ;
               IF (x>=Sx) AND (x<=Sx+Width) AND
                  (y>=Sy) AND (y<=Sy+Height)
               THEN
                  GetAccessToScreenNo(p) ;
                  DrawL.Erase(x-Sx, y-Sy) ;
                  IF flush
                  THEN
                     Flush(p)
                  END ;
                  ReleaseAccessToScreenNo(p)
               END
            END
         END
      END ;
      INC (p)
   END
END EraseArrow ;


PROCEDURE ReverseArrow (room, x, y, dir: CARDINAL) ;
VAR
   p, Sx, Sy: CARDINAL ;
BEGIN
   p := 0 ;
   WHILE p < NextFreePlayer DO
      IF IsPlayerActive(p)
      THEN
         WITH Player[p] DO
            IF room=RoomOfMan
            THEN
               Sy := ScreenY ;
               Sx := ScreenX ;
               IF (x>=Sx) AND (x<=Sx+Width) AND
                  (y>=Sy) AND (y<=Sy+Height)
               THEN
                  GetAccessToScreenNo (p) ;
                  DrawL.ReverseArrow (x-Sx, y-Sy, dir) ;
                  ReleaseAccessToScreenNo (p)
               END
            END
         END
      END ;
      INC (p)
   END
END ReverseArrow ;


PROCEDURE DisplayMessage (a1, a2, a3: ARRAY OF CHAR) ;
VAR
   i, p, r: CARDINAL ;
BEGIN
   p := PlayerNo() ;
   GetReadAccessToPlayer ;
   r := Player[p].RoomOfMan ;
   FOR i := 0 TO NextFreePlayer-1 DO
      IF IsPlayerActive(i)
      THEN
         WITH Player[i] DO
            IF r=RoomOfMan
            THEN
               GetAccessToScreenNo(i) ;
               WriteCommentLine1(i, a1) ;
               WriteCommentLine2(i, a2) ;
               WriteCommentLine3(i, a3) ;
               ReleaseAccessToScreenNo(i)
            END
         END
      END
   END ;
   ReleaseReadAccessToPlayer
END DisplayMessage ;


END DrawG.
(*
 * Local variables:
 *  compile-command: "make"
 * End:
 *)
