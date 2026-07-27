IMPLEMENTATION MODULE AdvUtil ;


FROM libc IMPORT printf ;
FROM AdvSystem IMPORT PlayerSet ;
FROM ASCII IMPORT cr, lf, nul, bs, del, nak ;
FROM Screen IMPORT WriteString ;
FROM Storage IMPORT ALLOCATE, DEALLOCATE ;
FROM Assertion IMPORT Assert ;
FROM AdvSound IMPORT Miss, Swish, Hit ;
FROM AdvCheckpoint IMPORT CheckpointKill, CheckpointDied, CheckpointNewRoom ;

FROM AdvSystem IMPORT Player, PlayerNo, IsPlayerActive,
                      MaxNoOfPlayers,
                      ArrowArgs,
                      NextFreePlayer,
                      TypeOfDeath,
                      RandomNumber,
                      DefaultWrite,

                      GetReadAccessToPlayer,
                      ReleaseReadAccessToPlayer,
                      GetWriteAccessToPlayer,
                      ReleaseWriteAccessToPlayer,

                      GetReadAccessToTreasure,
                      ReleaseReadAccessToTreasure,
                      GetWriteAccessToTreasure,
                      ReleaseWriteAccessToTreasure,

                      GetReadAccessToDoor,
                      ReleaseReadAccessToDoor,
                      GetWriteAccessToDoor,
                      ReleaseWriteAccessToDoor,

                      GetAccessToScreen,
                      ReleaseAccessToScreen,
                      GetAccessToScreenNo,
                      ReleaseAccessToScreenNo,
                      IsDeviceAnim,
                      ClientRead ;

FROM AdvMath IMPORT MaxNoOfTreasures, MaxCard,
                    GetDamageByParry, GetDamageByThrust, GetDamageByAttack,
                    GetDamageFirePlayer,
                    GetRateMove,
                    isQueryBoolean, getQueryCardinal ;

FROM AdvMap IMPORT Treasure, Rooms, DoorStatus, TreasureKind,
                   NoOfRoomsToHidePlayers,
                   ActualNoOfRooms,
                   IncPosition ;

FROM Executive IMPORT GetCurrentProcess, Wait, Signal ;
FROM TimerHandler IMPORT Sleep, TicksPerSecond, GetTicks ;
FROM ProcArgs IMPORT ProcessArgs, CollectArgs ;

FROM Screen IMPORT InitScreen,
                   WriteWounds,
                   WriteRoom, WriteWeight,
                   WriteCommentLine1, DelCommentLine1,
                   WriteCommentLine2, DelCommentLine2,
                   WriteCommentLine3, DelCommentLine3,
                   InnerX, OuterX, InnerY, OuterY, OffX, OffY,
                   Height, Width ;

FROM AdvMath IMPORT MagicSword,
                    MagicShield,

                    getQueryCardinal,
                    StrengthToParry,
                    StrengthToAttack,
                    StrengthToThrust,
                    StrengthToFireArrow,
                    StrengthToFireMagic,
                    StrengthToMove,
                    UpDateWoundsAndFatigue ;

FROM DrawL IMPORT DrawAllPlayers, DrawRoom, ClearRoom ;

FROM DrawG IMPORT DrawMan, EraseMan, DrawDoor, DrawArrow, EraseArrow,
                  AnimMoveMan, AnimEraseMan,
                  DisplayMessage, DrawTreasure,
                  ReverseArrow, DrawDoorChange ;

FROM AdvTreasure IMPORT ScatterTreasures, RespawnTreasure, SilentScatterTreasures ;


CONST
   SquaresPerSecond = 25 ;    (* speed of arrows *)
   DelayPerSquare   = TicksPerSecond DIV SquaresPerSecond ;


PROCEDURE Max (a, b: CARDINAL) : CARDINAL ;
BEGIN
   IF a>b
   THEN
      RETURN( a )
   ELSE
      RETURN( b )
   END
END Max ;


PROCEDURE PointOnLine (x, y, x1, y1, x2, y2: CARDINAL ; VAR ok: BOOLEAN) ;
BEGIN
   IF (x=x1) AND (y>=y1) AND (y<=y2)
   THEN
      ok := TRUE
   ELSIF (y=y1) AND (x>=x1) AND (x<=x2)
   THEN
      ok := TRUE
   ELSE
      ok := FALSE
   END
END PointOnLine ;


(* All the following routines assume that the calling process has gained *)
(* access to map, if needed!                                             *)

PROCEDURE ChangeStatusOfDoor (RoomNo, DoorNo: CARDINAL; ds: DoorStatus) ;
VAR
   r,i,x1,x2,y1,y2: CARDINAL ;
BEGIN
   WITH Rooms[RoomNo].Doors[DoorNo] DO
      r := LeadsTo ;
      x1 := Position.X1 ;
      y1 := Position.Y1 ;
      x2 := Position.X2 ;
      y2 := Position.Y2 ;
      DrawDoorChange (RoomNo, DoorNo, ds)
   END ;
   IF r#0
   THEN
      GetDoorIndex (r, x1, y1, x2, y2, i) ;
      DrawDoorChange (r, i, ds)
   END
END ChangeStatusOfDoor ;


PROCEDURE GetDoorIndex (RoomNo,
                        x1, y1, x2, y2: CARDINAL ;
                        VAR i: CARDINAL) ;
VAR
   Max : CARDINAL ;
   ok  : BOOLEAN ;
BEGIN
   i := 1 ;
   ok := TRUE ;
   Max := Rooms[RoomNo].NoOfDoors ;
   WITH Rooms[RoomNo] DO
      WHILE (i<=NoOfDoors) AND ok DO
         WITH Doors[i].Position DO
            IF (x1=X1) AND (y1=Y1) AND
               (x2=X2) AND (y2=Y2)
            THEN
               ok := FALSE
            ELSE
               INC( i )
            END
         END
      END
   END
END GetDoorIndex ;


PROCEDURE GetDoorOnPoint (RoomNo, x, y: CARDINAL ;
                          VAR DoorNo: CARDINAL ; VAR Success: BOOLEAN) ;
VAR
   Max : CARDINAL ;
BEGIN
   Max := Rooms[RoomNo].NoOfDoors ;
   DoorNo := 1 ;
   Success := FALSE ;
   WITH Rooms[RoomNo] DO
      WHILE (NOT Success) AND (DoorNo<=Max) DO
         WITH Doors[DoorNo].Position DO
            PointOnLine( x, y, X1, Y1, X2, Y2, Success ) ;
            IF NOT Success
            THEN
               INC( DoorNo )
            END
         END
      END
   END
END GetDoorOnPoint ;


PROCEDURE TimedDoorToClosed (roomno, x, y, dir: CARDINAL) : BOOLEAN ;
VAR
   success: BOOLEAN ;
   DoorNo : CARDINAL ;
BEGIN
   IncPosition (x, y, dir) ;
   GetDoorOnPoint (roomno, x, y, DoorNo, success) ;
   IF success
   THEN
      IF Rooms[roomno].Doors[DoorNo].StateOfDoor = Timed
      THEN
         ChangeStatusOfDoor (roomno, DoorNo, Closed)
      ELSE
         success := FALSE
      END
   END ;
   RETURN success
END TimedDoorToClosed ;


PROCEDURE OpenToClosedDoor (VAR Success: BOOLEAN) ;
VAR
   x, y, DoorNo: CARDINAL ;
BEGIN
   WITH Player[PlayerNo()] DO
      x := Xman ;
      y := Yman ;
      IncPosition( x, y, Direction ) ;
      GetDoorOnPoint( RoomOfMan, x, y, DoorNo, Success ) ;
      IF Success
      THEN
         IF Rooms[RoomOfMan].Doors[DoorNo].StateOfDoor=Open
         THEN
            ChangeStatusOfDoor( RoomOfMan, DoorNo, Closed )
         ELSE
            Success := FALSE
         END
      END
   END
END OpenToClosedDoor ;


PROCEDURE ClosedToOpenDoor (VAR Success: BOOLEAN) ;
VAR
   x, y, DoorNo: CARDINAL ;
BEGIN
   WITH Player[PlayerNo()] DO
      x := Xman ;
      y := Yman ;
      IncPosition(x, y, Direction) ;
      GetDoorOnPoint( RoomOfMan, x, y, DoorNo, Success ) ;
      IF Success
      THEN
         IF Rooms[RoomOfMan].Doors[DoorNo].StateOfDoor=Closed
         THEN
            ChangeStatusOfDoor( RoomOfMan, DoorNo, Open )
         ELSE
            Success := FALSE
         END
      END
   END
END ClosedToOpenDoor ;


PROCEDURE ClosedToSecretDoor (VAR Success: BOOLEAN) ;
VAR
   x, y, DoorNo: CARDINAL ;
BEGIN
   WITH Player[PlayerNo()] DO
      x := Xman ;
      y := Yman ;
      IncPosition( x, y, Direction ) ;
      GetDoorOnPoint( RoomOfMan, x, y, DoorNo, Success ) ;
      IF Success
      THEN
         IF Rooms[RoomOfMan].Doors[DoorNo].StateOfDoor=Closed
         THEN
            ChangeStatusOfDoor( RoomOfMan, DoorNo, Secret )
         ELSE
            Success := FALSE
         END
      END
   END
END ClosedToSecretDoor ;


PROCEDURE SecretToClosedDoor (VAR Success: BOOLEAN) ;
VAR
   x, y, DoorNo: CARDINAL ;
BEGIN
   WITH Player[PlayerNo()] DO
      x := Xman ;
      y := Yman ;
      IncPosition( x, y, Direction ) ;
      GetDoorOnPoint( RoomOfMan, x, y, DoorNo, Success ) ;
      IF Success
      THEN
         IF Rooms[RoomOfMan].Doors[DoorNo].StateOfDoor=Secret
         THEN
            ChangeStatusOfDoor( RoomOfMan, DoorNo, Closed )
         ELSE
            Success := FALSE
         END
      END
   END
END SecretToClosedDoor ;


PROCEDURE ClosedToTimedDoor () : BOOLEAN ;
VAR
   x, y, DoorNo: CARDINAL ;
   success     : BOOLEAN ;
BEGIN
   WITH Player[PlayerNo()] DO
      x := Xman ;
      y := Yman ;
      IncPosition( x, y, Direction ) ;
      GetDoorOnPoint (RoomOfMan, x, y, DoorNo, success) ;
      IF success
      THEN
         IF Rooms[RoomOfMan].Doors[DoorNo].StateOfDoor = Closed
         THEN
            ChangeStatusOfDoor (RoomOfMan, DoorNo, Timed) ;
            success := TRUE
         ELSE
            success := FALSE
         END
      END
   END ;
   RETURN success
END ClosedToTimedDoor ;


PROCEDURE PointOnWall (RoomNo, x, y: CARDINAL ;
                       VAR Success: BOOLEAN) ;
VAR
   Max,
   WallNo : CARDINAL ;
BEGIN
   Max := Rooms[RoomNo].NoOfWalls ;
   WallNo := 1 ;
   Success := FALSE ;
   WHILE (NOT Success) AND (WallNo<=Max) DO
      WITH Rooms[RoomNo].Walls[WallNo] DO
         PointOnLine( x, y, X1, Y1, X2, Y2, Success ) ;
         IF NOT Success
         THEN
            INC( WallNo )
         END
      END
   END
END PointOnWall ;


PROCEDURE PointOnTreasure (RoomNo, x, y: CARDINAL ;
                           VAR TreasNo: CARDINAL ; VAR Success: BOOLEAN) ;
BEGIN
   TreasNo := 1 ;
   Success := FALSE ;
   WHILE (NOT Success) AND (TreasNo<=MaxNoOfTreasures) DO
      WITH Treasure[TreasNo] DO
         IF (Rm = RoomNo) AND (kind # onfloor)
         THEN
            printf ("warning treasure %d is not on the floor\n",
                    TreasNo)
         END ;
         IF (Rm = RoomNo) AND (kind = onfloor)
         THEN
            IF (Xpos=x) AND (Ypos=y)
            THEN
               Success := TRUE
            ELSE
               INC( TreasNo )
            END
         ELSE
            INC( TreasNo )
         END
      END
   END
END PointOnTreasure ;


(* This routine finds out if a point is upon a player. It does use *)
(* GetReadAccessToPlayer & ReleaseReadAccessToPlayer. This routine *)
(* returns Success if the point was on a player and also sets      *)
(* PlayNo to tell which player is upon this square.                *)

PROCEDURE PointOnPlayer (RoomNo, x, y: CARDINAL ;
                         VAR PlayNo: CARDINAL ; VAR Success: BOOLEAN) ;
BEGIN
   PlayNo := 0 ;
   Success := FALSE ;
   GetReadAccessToPlayer ;
   WHILE (NOT Success) AND (PlayNo<NextFreePlayer) DO
      WITH Player[PlayNo] DO
         IF IsPlayerActive(PlayNo) AND (Xman=x) AND (Yman=y)
         THEN
            Success := TRUE
         ELSE
            INC(PlayNo)
         END
      END
   END ;
   ReleaseReadAccessToPlayer
END PointOnPlayer ;


PROCEDURE TestIfLastLivePlayer (VAR yes: BOOLEAN) ;
VAR
   p, i: CARDINAL ;
BEGIN
   p := PlayerNo() ;
   i := 0 ;
   yes := TRUE ;
   WHILE (i<NextFreePlayer) AND yes DO
      IF p#i
      THEN
         IF (Player[i].Entity.DeathType = living) AND IsPlayerActive (i)
         THEN
            yes := FALSE
         END
      END ;
      INC( i )
   END
END TestIfLastLivePlayer ;

PROCEDURE ReceiveFireFromProcess (p: CARDINAL;
                                  VAR r, x, y, d: CARDINAL;
                                  VAR isdart: BOOLEAN ;
                                  magic: BOOLEAN) ;
VAR
   aa: ArrowArgs ;
BEGIN
   IF magic
   THEN
      aa := CollectArgs(Player[p].MagicProcArgs)
   ELSE
      aa := CollectArgs(Player[p].NormalProcArgs)
   END ;
   WITH aa^ DO
      Assert(p=ArrowPlayer) ;
      r := ArrowRoom ;
      x := ArrowX ;
      y := ArrowY ;
      d := ArrowDir ;
      isdart := IsBlowDart
   END ;
   DISPOSE(aa)
END ReceiveFireFromProcess ;


PROCEDURE NormalArrow (p: CARDINAL) ;
VAR
   x, y, r,
   d,
   player : CARDINAL ;
   dart,
   hit,
   done,
   SlainP : BOOLEAN ;
BEGIN
   WITH Player[p] DO
      LOOP
         SlainP := FALSE ;
         ReceiveFireFromProcess (p, r, x, y, d,
                                 dart, FALSE) ;
         REPEAT
            FireArrow (p, r, x, y, d,
                       dart, hit, player) ;
            IF hit
            THEN
               GetReadAccessToPlayer ;
               WITH Player[player] DO
                  IF MagicShield IN Entity.TreasureOwn
                  THEN
                     done := FALSE ;
                     d := (d+2) MOD 4 ;
                     x := Xman ;
                     y := Yman ;
                     r := RoomOfMan ;
                     IncPosition (x, y, d) ;
                     (* We should not need the playerscreen set
                        for ReverseArrow as it is replacing an arrow
                        character.  *)
                     ReverseArrow (r, x, y, d)
                  ELSE
                     done := TRUE
                  END
               END ;
               ReleaseReadAccessToPlayer ;
               IF NOT done
               THEN
                  (* Add a delay after we have reversed the arrow
                     and released read access to player.  *)
                  Sleep (DelayPerSquare)
               END
            ELSE
               done := TRUE
            END
         UNTIL done ;
         IF hit
         THEN
            WITH Player[player] DO
               GetWriteAccessToPlayer ;

               GetAccessToScreenNo (player) ;
               UpDateWoundsAndFatigue (player) ;
               IF Entity.Wounds <= GetDamageFirePlayer (player, FALSE, dart)
               THEN
                  r := RoomOfMan ;
                  SlainP := TRUE ;
                  Entity.Wounds := 0 ;
                  IF dart
                  THEN
                     Entity.DeathType := normalblow
                  ELSE
                     Entity.DeathType := normalarrow
                  END
               ELSE
                  DEC (Entity.Wounds, GetDamageFirePlayer (player, FALSE, dart))
               END ;
               WriteWounds (player, Entity.Wounds) ;
               IF dart
               THEN
                  WriteCommentLine1 (player, 'blow dart hit') ;
                  Entity.DartStrike := TRUE ;
                  Entity.DartTime := GetTicks ()
               ELSE
                  WriteCommentLine1 (player, 'struck thee')
               END ;
               DelCommentLine2 (player) ;
               DelCommentLine3 (player) ;
               ReleaseAccessToScreenNo (player) ;

               GetAccessToScreenNo (p) ;
               IF Entity.Wounds = 0
               THEN
                  DelCommentLine1 (p) ;
                  WriteCommentLine2 (p, 'slain') ;
                  WriteCommentLine3 (p,  Entity.Name )
               ELSE
                  WriteCommentLine1 (p, 'thwunk') ;
                  DelCommentLine2 (p) ;
                  DelCommentLine3 (p)
               END ;
               ReleaseAccessToScreenNo (p) ;
               ReleaseWriteAccessToPlayer
            END
         ELSE
            GetAccessToScreenNo (p) ;
            WriteCommentLine1 (p, 'swish') ;
            DelCommentLine2 (p) ;
            DelCommentLine3 (p) ;
            ReleaseAccessToScreenNo (p)
         END ;
         IF SlainP
         THEN
            Dead (player, p, r)
         END
      END
   END
END NormalArrow ;


PROCEDURE MagicArrow (p: CARDINAL) ;
VAR
   x, y, r,
   d,
   player : CARDINAL ;
   dart,
   hit,
   SlainP : BOOLEAN ;
BEGIN
   WITH Player[p] DO
      LOOP
         SlainP := FALSE ;
         ReceiveFireFromProcess (p, r, x, y, d,
                                 dart, TRUE) ;
         FireArrow (p, r, x, y, d,
                    dart, hit, player) ;
         IF hit
         THEN
            WITH Player[player] DO
               GetWriteAccessToPlayer ;

               GetAccessToScreenNo(player) ;
               UpDateWoundsAndFatigue(player) ;
               IF Entity.Wounds <= GetDamageFirePlayer (player, TRUE, dart)
               THEN
                  r := RoomOfMan ;
                  SlainP := TRUE ;
                  Entity.DeathType := magicarrow ;
                  Entity.Wounds := 0
               ELSE
                  DEC (Entity.Wounds, GetDamageFirePlayer (player, TRUE, dart))
               END ;
               WriteWounds (player, Entity.Wounds) ;
               WriteCommentLine1 (player, 'struck thee') ;
               DelCommentLine2 (player) ;
               DelCommentLine3 (player) ;
               ReleaseAccessToScreenNo (player) ;

               GetAccessToScreenNo (p) ;

               IF Entity.Wounds = 0
               THEN
                  DelCommentLine1 (p) ;
                  WriteCommentLine2 (p, 'slain') ;
                  WriteCommentLine3 (p,  Entity.Name)
               ELSE
                  WriteCommentLine1 (p, 'thwunk') ;
                  DelCommentLine2 (p) ;
                  DelCommentLine3 (p)
               END ;
               ReleaseAccessToScreenNo (p) ;
               ReleaseWriteAccessToPlayer
            END
         ELSE
            GetAccessToScreenNo(p) ;

            WriteCommentLine1 (p, 'swish') ;
            DelCommentLine2 (p) ;
            DelCommentLine3 (p) ;
            ReleaseAccessToScreenNo (p)
         END ;
         IF SlainP
         THEN
            Dead (player, p, r)
         END
      END
   END
END MagicArrow ;


PROCEDURE FireArrow (p, r, x, y, d: CARDINAL ;
                     dart: BOOLEAN ;
                     VAR hit: BOOLEAN ;
                     VAR player: CARDINAL) ;
VAR
   t           : INTEGER ;
   NotCont     : BOOLEAN ;
   door,
   X, Y,
   i, j        : CARDINAL ;
   playerscreen: PlayerSet ;
   LastTime,
   DelayTime   : CARDINAL ;
BEGIN
   i := x ;   (* old x & y         *)
   j := y ;
   playerscreen := PlayerSet{} ;
   Swish(r) ;
   REPEAT
      LastTime := GetTicks() ;
      PointOnPlayer(r, x, y, player, NotCont) ;
      hit := NotCont ;
      IF NOT NotCont
      THEN
         GetReadAccessToDoor ;
         GetDoorOnPoint(r, x, y, door, NotCont) ;
         IF NotCont
         THEN
            WITH Rooms[r].Doors[door] DO
               IF (StateOfDoor=Open) AND (LeadsTo#0)
               THEN
                  NotCont := FALSE ;
                  r := LeadsTo
               END
            END ;
            ReleaseReadAccessToDoor ;
         ELSE
            ReleaseReadAccessToDoor ;
            PointOnWall(r, x, y, NotCont) ;
            IF NOT NotCont
            THEN
               GetReadAccessToTreasure ;
               PointOnTreasure(r, x, y, door, NotCont) ;
               ReleaseReadAccessToTreasure ;
               IF NOT NotCont
               THEN
                  GetReadAccessToPlayer ;
                  EraseArrow(i, j, playerscreen, FALSE) ;
                  DrawArrow(r, x, y, d, playerscreen) ;
                  ReleaseReadAccessToPlayer ;
                  i := x ;
                  j := y
               END
            END
         END
      END ;
      IncPosition(x, y, d) ;
      (* now we regulate a constant velocity arrow! *)
      DelayTime := GetTicks() - LastTime ;
      IF DelayTime<DelayPerSquare
      THEN
         (* t := printf("before Sleep for %d ticks\n", DelayPerSquare-DelayTime) ; *)
         Sleep(DelayPerSquare-DelayTime)
         (* ; t := printf("after Sleep\n") ; *)
      END
   UNTIL NotCont ;
   IF hit
   THEN
      Hit(p)
   ELSE
      Miss(r)
   END ;
   IF (X#i) OR (Y#j)
   THEN
      GetReadAccessToPlayer ;
      EraseArrow(i, j, playerscreen, TRUE) ;
      ReleaseReadAccessToPlayer
   END
END FireArrow ;


PROCEDURE Exit ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo() ;
   Dead (p, p, Player[p].RoomOfMan)
END Exit ;


(* MoveMan moves the man forward TotalDist squares, providing these squares   *)
(* are free from a WALL, DOOR (closed, secret), TREASURE and MAN.     *)

PROCEDURE MoveMan (TotalDist: CARDINAL) ;
VAR
   player: CARDINAL ;
BEGIN
   IF TotalDist > 0
   THEN
      player := PlayerNo () ;
      IF IsDeviceAnim (player)
      THEN
         MoveAnim (TotalDist, player)
      ELSE
         MoveMan1 (TotalDist, player)
      END ;
      IF Player[player].Entity.DeathType = exitdungeon
      THEN
         Dead (player, player, Player[0].RoomOfMan)
      END
   END
END MoveMan ;


(*
   UpdatePos -
*)

PROCEDURE UpdatePos (p: CARDINAL; x, y: CARDINAL; Sx, Sy: CARDINAL;
                     newroom, oldroom: CARDINAL) ;
VAR
   scaled: BOOLEAN ;
BEGIN
   WITH Player[p] DO
      IF (x#Xman) OR (y#Yman)
      THEN
         Xman := x ;
         Yman := y ;
         ScaleSights (x, y, Sx, Sy, scaled) ;
         ScreenX := Sx ;
         ScreenY := Sy ;
         RoomOfMan := newroom ;
         IF newroom#0
         THEN
            IF (oldroom # newroom) OR scaled
            THEN
               IF scaled
               THEN
                  InitScreen (p)
               ELSE
                  GetAccessToScreenNo (p) ;
                  WriteRoom (p, newroom) ;
                  ReleaseAccessToScreenNo (p)
               END ;
               ClearRoom (oldroom) ;
               DrawRoom
            END
         END
      END
   END
END UpdatePos ;


(*
   MoveAnim - attempts to move player a TotalDist of units forward.
              It must check for doors and adjust over the doorway
              it should also update all other player screens who
              can see player.
*)

PROCEDURE MoveAnim (TotalDist, player: CARDINAL) ;
VAR
   delayPerSquare: CARDINAL ;
BEGIN
   GetWriteAccessToPlayer ;
   IF StrengthToMove (TotalDist)
   THEN
      delayPerSquare := GetRateMove (TotalDist) DIV (100 DIV TicksPerSecond)
                        DIV TotalDist ;
      MoveAnimLower (TotalDist, player, delayPerSquare)
   END ;
   ReleaseWriteAccessToPlayer
END MoveAnim ;


(*
   GetPlayerRoomInfo -
*)

PROCEDURE GetPlayerRoomInfo (player: CARDINAL; VAR x, y, dir, room: CARDINAL) ;
BEGIN
   WITH Player[player] DO
      x := Xman ;
      y := Yman ;
      dir := Direction ;
      room := RoomOfMan
   END
END GetPlayerRoomInfo ;


(*
   MoveThroughDoor - returns TRUE if player can move though the door.
                     Position x, y is expected to be on a doorway.
                     The player is moved though the door is the position
                     on the other side is empty.
*)

PROCEDURE MoveThroughDoor (x, y, dir, step, TotalDist,
                           leadsto, player, delayPerSquare: CARDINAL) : BOOLEAN ;
VAR
   hit: BOOLEAN ;
BEGIN
   IncPosition (x, y, dir) ;
   TakenPointInRoom (leadsto, x, y, hit) ;
   IF NOT hit  (* Empty Point In Room *)
   THEN
      EraseMan (player) ;
      UpdatePos (player, x, y,
                 Player[player].ScreenX,
                 Player[player].ScreenY,
                 leadsto, Player[player].RoomOfMan) ;
      DrawMan (player) ;
      RETURN TRUE
   END ;
   RETURN FALSE
END MoveThroughDoor ;


(*
   RoomPositionEmpty - return TRUE if position x, y is empty in room.
*)

PROCEDURE RoomPositionEmpty (room, x, y: CARDINAL) : BOOLEAN ;
VAR
   hit     : BOOLEAN ;
   other,
   treasure: CARDINAL ;
BEGIN
   PointOnWall (room, x, y, hit) ;
   IF hit
   THEN
      RETURN FALSE
   ELSE
      GetReadAccessToTreasure ;
      PointOnTreasure (room, x, y, treasure, hit) ;
      ReleaseReadAccessToTreasure ;
      IF hit
      THEN
         RETURN FALSE
      ELSE
         RETURN NOT PointOnOtherPlayer (x, y, other)
      END
   END
END RoomPositionEmpty ;


(*
   MoveAnimLower - the caller is expected to have gained
                   WriteAccessToPlayer.
*)

PROCEDURE MoveAnimLower (TotalDist, player, delayPerSquare: CARDINAL) ;
VAR
   hit      : BOOLEAN ;
   DoorNo,
   step,
   leadsto,
   x, y,
   room, dir: CARDINAL ;
BEGIN
   GetPlayerRoomInfo (player, x, y, dir, room) ;
   (* We examine visible players a step at a time.  *)
   step := 1 ;
   WHILE (step <= TotalDist) AND
          (NOT Player[player].Entity.DartStrike) DO
      IncPosition (x, y, dir) ;
      GetReadAccessToDoor ;
      GetDoorOnPoint (room, x, y, DoorNo, hit) ;
      IF hit
      THEN
         IF Rooms[room].Doors[DoorNo].StateOfDoor = Open
         THEN
            leadsto := Rooms[room].Doors[DoorNo].LeadsTo ;
            ReleaseReadAccessToDoor ;
            IF leadsto = 0
            THEN
               AnimEraseMan (player) ;
               (* Door leads to the exit.  *)
               Player[player].Entity.DeathType := exitdungeon ;
               RETURN
            ELSE
               IF MoveThroughDoor (x, y, dir, step, TotalDist,
                                   leadsto, player, delayPerSquare)
               THEN
                  INC (step) ;
                  ReleaseWriteAccessToPlayer ;
                  (* Everything can change after the sleep.  *)
                  Sleep (delayPerSquare) ;
                  GetWriteAccessToPlayer ;
                  GetPlayerRoomInfo (player, x, y, dir, room)
               ELSE
                  (* Failed to move through the door.  *)
                  RETURN
               END
            END
         ELSE
            (* Bumped into a closed/secret or timed door.  *)
            ReleaseReadAccessToDoor ;
            RETURN
         END
      ELSE
         ReleaseReadAccessToDoor ;
         IF RoomPositionEmpty (room, x, y)
         THEN
            AnimMoveMan (player, step, TotalDist, dir,
                         delayPerSquare, room) ;
            INC (step) ;
            MoveWithinRoom (player, x, y, room) ;
            ReleaseWriteAccessToPlayer ;
            Sleep (delayPerSquare) ;
            GetWriteAccessToPlayer ;
            GetPlayerRoomInfo (player, x, y, dir, room)
         ELSE
            (* Bumped into a treasure or player.  *)
            RETURN
         END
      END
   END ;
   (* We have been hit by a freeze dart or reached the end.  *)
END MoveAnimLower ;


(*
   MoveWithinRoom -
*)

PROCEDURE MoveWithinRoom (player, x, y, room: CARDINAL) ;
VAR
   hit     : BOOLEAN ;
   other,
   treasure: CARDINAL ;
BEGIN
   PointOnWall (room, x, y, hit) ;
   IF NOT hit
   THEN
      GetReadAccessToTreasure ;
      PointOnTreasure (room, x, y, treasure, hit) ;
      ReleaseReadAccessToTreasure ;
      IF NOT hit
      THEN
         hit := PointOnOtherPlayer (x, y, other) ;
         IF NOT hit
         THEN
            UpdatePos (player, x, y,
                       Player[player].ScreenX,
                       Player[player].ScreenY,
                       room, room)
         END
      END
   END
END MoveWithinRoom ;


(*
PROCEDURE MoveAnim (TotalDist, player: CARDINAL) ;
VAR
   delayPerSquare,
   x, y,
   i, j, step,
   inc,
   r,  dir,
   tr, z,
   Sx, Sy,
   DoorNo        : CARDINAL ;
   hit           : BOOLEAN ;
BEGIN
   GetWriteAccessToPlayer ;
   IF StrengthToMove (TotalDist)
   THEN
      delayPerSquare := GetRateMove (TotalDist) DIV (100 DIV TicksPerSecond) DIV TotalDist ;
      WITH Player[player] DO
         dir := Direction ;
         tr := RoomOfMan ;
         x := Xman ;
         y := Yman ;
         Sx := ScreenX ;
         Sy := ScreenY ;
         hit := FALSE ;
         step := 1 ;
         i := x ;
         j := y ;
         r := tr ;
         WHILE (step <= TotalDist) AND (NOT hit) DO
            inc := 1 ;
            IncPosition (i, j, dir) ;
            GetReadAccessToDoor ;
            GetDoorOnPoint (r, i, j, DoorNo, hit) ;
            IF hit
            THEN
               IF Rooms[r].Doors[DoorNo].StateOfDoor=Open
               THEN
                  AnimEraseMan (player) ;
                  z := Rooms[r].Doors[DoorNo].LeadsTo ;
                  ReleaseReadAccessToDoor ;
                  IF z=0
                  THEN
                     Entity.DeathType := exitdungeon
                  ELSE
                     IncPosition (i, j, dir) ;
                     TakenPointInRoom (z, i, j, hit) ;
                     IF NOT hit  (* Empty Point In Room *)
                     THEN
                        r := z ; (* Ok so changed room *)
                        INC (inc) ;
                        AnimMoveMan (player, step, inc, dir, delayPerSquare, r) ;
                        x := i ;
                        y := j ;
                        INC (step) ;
                        UpdatePos (player, x, y, Sx, Sy, r, tr) ;
                        ReleaseWriteAccessToPlayer ;
                        Sleep (delayPerSquare) ;
                        GetWriteAccessToPlayer ;
                        tr := RoomOfMan ;
                        x := Xman ;
                        y := Yman ;
                        Sx := ScreenX ;
                        Sy := ScreenY ;
                     END
                  END
               ELSE
                  ReleaseReadAccessToDoor
               END
            ELSE
               ReleaseReadAccessToDoor ;
               PointOnWall (r, i, j, hit) ;
               IF NOT hit
               THEN
                  GetReadAccessToTreasure ;
                  PointOnTreasure (r, i, j, z, hit) ;
                  ReleaseReadAccessToTreasure ;
                  IF NOT hit
                  THEN
                     hit := PointOnOtherPlayer (i, j, z) ;
                     IF NOT hit
                     THEN
                        AnimMoveMan (player, step, inc, dir, delayPerSquare, r) ;
                        x := i ;
                        y := j ;
                        INC (step) ;
                        UpdatePos (player, x, y, Sx, Sy, r, tr) ;
                        ReleaseWriteAccessToPlayer ;
                        Sleep (delayPerSquare) ;
                        GetWriteAccessToPlayer ;
                        tr := RoomOfMan ;
                        x := Xman ;
                        y := Yman ;
                        Sx := ScreenX ;
                        Sy := ScreenY ;
                     END
                  END
               END
            END
         END
      END
   END ;
   ReleaseWriteAccessToPlayer
END MoveAnim ;
*)


PROCEDURE MoveMan1 (TotalDist, player: CARDINAL) ;
VAR
   x, y,
   i, j,
   step,
   r,  dir,
   tr, z,
   Sx, Sy,
   DoorNo : CARDINAL ;
   hit    : BOOLEAN ;
BEGIN
   GetWriteAccessToPlayer ;
   IF StrengthToMove (TotalDist)
   THEN
      WITH Player[player] DO
         EraseMan (player) ;
         dir := Direction ;
         tr := RoomOfMan ;
         x := Xman ;
         y := Yman ;
         Sx := ScreenX ;
         Sy := ScreenY ;
         hit := FALSE ;
         step := 1 ;
         i := x ;
         j := y ;
         r := tr ;
         WHILE (step <= TotalDist) AND (NOT hit) DO
            IncPosition (i, j, dir) ;
            GetReadAccessToDoor ;
            GetDoorOnPoint (r, i, j, DoorNo, hit) ;
            IF hit
            THEN
               IF Rooms[r].Doors[DoorNo].StateOfDoor=Open
               THEN
                  z := Rooms[r].Doors[DoorNo].LeadsTo ;
                  ReleaseReadAccessToDoor ;
                  IF z=0
                  THEN
                     Entity.DeathType := exitdungeon
                  ELSE
                     IncPosition (i, j, dir) ;
                     TakenPointInRoom (z, i, j, hit) ;
                     IF NOT hit  (* Empty Point In Room *)
                     THEN
                        INC (step) ;
                        x := i ;
                        y := j ;
                        r := z ; (* Ok so changed room *)
                        CheckpointNewRoom (player)
                     END
                  END
               ELSE
                  ReleaseReadAccessToDoor
               END ;
            ELSE
               ReleaseReadAccessToDoor ;
               PointOnWall (r, i, j, hit) ;
               IF NOT hit
               THEN
                  GetReadAccessToTreasure ;
                  PointOnTreasure (r, i, j, z, hit) ;
                  ReleaseReadAccessToTreasure ;
                  IF NOT hit
                  THEN
                     hit := PointOnOtherPlayer (i, j, z) ;
                     IF NOT hit
                     THEN
                        x := i ;
                        y := j ;
                        INC (step)
                     END
                  END
               END
            END
         END ;
         IF (x#Xman) OR (y#Yman)
         THEN
            Xman := x ;
            Yman := y ;
            ScaleSights (x, y, Sx, Sy, hit) ;
            ScreenX := Sx ;
            ScreenY := Sy ;
            RoomOfMan := r ;
            IF r#0
            THEN
               IF (tr#r) OR hit
               THEN
                  IF hit
                  THEN
                     InitScreen (player)
                  ELSE
                     GetAccessToScreenNo (player) ;
                     WriteRoom (player, r) ;
                     ReleaseAccessToScreenNo (player)
                  END ;
                  ClearRoom (tr) ;
                  DrawRoom
               END ;
               DrawMan (player)
            END
         ELSE
            DrawMan (player)
         END
      END
   END ;
   ReleaseWriteAccessToPlayer
END MoveMan1 ;


PROCEDURE TakenPointInRoom (room, x, y: CARDINAL ; VAR ok: BOOLEAN) ;
VAR
   z: CARDINAL ;
BEGIN
   PointOnWall( room, x, y, ok ) ;
   IF NOT ok
   THEN
      GetReadAccessToDoor ;
      GetDoorOnPoint(room, x, y, z, ok) ;
      ReleaseReadAccessToDoor ;
      IF NOT ok
      THEN

         (* No need to get Read Access To Player 's since taken care of *)
         (* in the called routine.                                      *)

         ok := PointOnOtherPlayer(x, y, z) ;
         IF NOT ok
         THEN
            GetReadAccessToTreasure ;
            PointOnTreasure(room, x, y, z, ok) ;
            ReleaseReadAccessToTreasure
         END
      END
   END
END TakenPointInRoom ;


(* ScaleSights scales the sights of the ScreenX and ScreenY      *)
(* coordinates according to whether the player is off the        *)
(* screen or off the boundary. It returns Done if the routine    *)
(* has altered Sx, Sy.                                           *)

PROCEDURE ScaleSights (x, y: CARDINAL ; VAR Sx, Sy: CARDINAL ;
                       VAR Done: BOOLEAN) ;
VAR
   sx, sy: CARDINAL ;
BEGIN
   sx := Sx ;
   sy := Sy ;
   IF Sx+InnerX>x
   THEN
      Dec(Sx, OffX)
   ELSIF Sx+OuterX < x
   THEN
      Inc(Sx, OffX)
   END ;
   IF Sy+InnerY>y
   THEN
      Dec(Sy, OffY)
   ELSIF Sy+OuterY<y
   THEN
      Inc(Sy, OffY)
   END ;
   Done := (sx#Sx) OR (sy#Sy)
END ScaleSights ;


PROCEDURE Inc (VAR s: CARDINAL ; c: CARDINAL) ;
BEGIN
   IF (c DIV 2) + (s DIV 2) < 32768
   THEN
      INC(s, c)
   END
END Inc ;


PROCEDURE Dec (VAR s: CARDINAL ; c: CARDINAL) ;
BEGIN
   IF c<=s
   THEN
      DEC(s, c)
   ELSIF s>0
   THEN
      s := 0
   END
END Dec ;


(*
   Damage -
*)

PROCEDURE Damage (inflict: CARDINAL; amountOfDamage: CARDINAL;
                  deathType: TypeOfDeath; VAR roomOfDeath: CARDINAL) : BOOLEAN ;
VAR
   p: CARDINAL ;
   slain: BOOLEAN ;
BEGIN
   p := PlayerNo () ;
   GetAccessToScreenNo (p) ;
   WITH Player[inflict] DO
      IF Entity.Wounds > amountOfDamage
      THEN
         slain := FALSE ;
         DEC (Entity.Wounds, amountOfDamage) ;
         WriteCommentLine1 (p, 'hit') ;
         DelCommentLine2 (p) ;
         DelCommentLine3 (p)
      ELSE
         roomOfDeath := RoomOfMan ;
         slain := TRUE ;
         Entity.Wounds := 0 ;
         Entity.DeathType := deathType ;
         DelCommentLine1 (p) ;
         WriteCommentLine2 (p, 'Slain') ;
         WriteCommentLine3 (p, Entity.Name )
      END
   END ;
   ReleaseAccessToScreenNo(p) ;
   RETURN slain
END Damage ;


PROCEDURE Sword (VAR PlayerNoSlain, RoomOfSlain: CARDINAL;
                 getDamage: getQueryCardinal) : BOOLEAN ;
VAR
   isSlain, hit: BOOLEAN ;
   p, x, y     : CARDINAL ;
BEGIN
   isSlain := FALSE ;
   p := PlayerNo () ;
   WITH Player[p] DO
      GetReadAccessToPlayer ;
      x := Xman ;
      y := Yman ;
      IncPosition(x, y, Direction) ;
      hit := PointOnOtherPlayer (x, y, PlayerNoSlain) ;
      ReleaseReadAccessToPlayer ;
      IF hit
      THEN
         WITH Player[PlayerNoSlain] DO
            GetWriteAccessToPlayer ;

            GetAccessToScreenNo (PlayerNoSlain) ;
            UpDateWoundsAndFatigue (PlayerNoSlain) ;
            ReleaseAccessToScreenNo (PlayerNoSlain) ;

            isSlain := Damage (PlayerNoSlain, getDamage (), sword, RoomOfSlain) ;

            GetAccessToScreenNo (PlayerNoSlain) ;
            WriteCommentLine1 (PlayerNoSlain, 'hit thee') ;
            DelCommentLine2 (PlayerNoSlain) ;
            DelCommentLine3 (PlayerNoSlain) ;
            WriteWounds (PlayerNoSlain, Entity.Wounds ) ;
            ReleaseAccessToScreenNo (PlayerNoSlain) ;

            ReleaseWriteAccessToPlayer
         END
      ELSE
         GetAccessToScreenNo (p) ;
         WriteCommentLine1 (p, 'missed') ;
         DelCommentLine2 (p) ;
         DelCommentLine3 (p) ;
         ReleaseAccessToScreenNo (p)
      END
   END ;
   RETURN isSlain
END Sword ;


PROCEDURE TrySwingSword (isQuery: isQueryBoolean; getDamage: getQueryCardinal) ;
VAR
   PlayerNoSlain,
   p, x, y,
   RoomOfSlain  : CARDINAL ;
   isSlain      : BOOLEAN ;
BEGIN
   isSlain := FALSE ;
   p := PlayerNo () ;
   WITH Player[p] DO
      GetWriteAccessToPlayer ;
      IF isQuery ()
      THEN
         ReleaseWriteAccessToPlayer ;
         isSlain := Sword (PlayerNoSlain, RoomOfSlain, getDamage)
      ELSE
         ReleaseWriteAccessToPlayer
      END
   END ;
   IF isSlain
   THEN
      Dead (PlayerNoSlain, p, RoomOfSlain)
   END
END TrySwingSword ;


PROCEDURE Parry ;
BEGIN
   TrySwingSword (StrengthToParry, GetDamageByParry)
END Parry ;


PROCEDURE Attack ;
BEGIN
   TrySwingSword (StrengthToAttack, GetDamageByAttack)
END Attack ;


PROCEDURE Thrust ;
BEGIN
   TrySwingSword (StrengthToThrust, GetDamageByThrust)
END Thrust ;


(*
   Alive - return TRUE if the entity is still alive.  If it is not alive
           mark it in room 0 and out of the map.
*)

PROCEDURE Alive () : BOOLEAN ;
VAR
   p   : CARDINAL ;
   Dead: BOOLEAN ;
BEGIN
   p := PlayerNo () ;
   WITH Player[p] DO
      IF Entity.DeathType = living
      THEN
         RETURN TRUE
      ELSE
         RoomOfMan := 0 ;
         Xman := MaxCard - Width ;
         Yman := MaxCard - Height ;
         RETURN FALSE
      END
   END
END Alive ;



(* Tests to see whether the point is occupied by another player. *)
(* This procedure does NOT use any lock.                         *)

PROCEDURE PointOnOtherPlayer (x, y: CARDINAL;
                              VAR Pn: CARDINAL) : BOOLEAN ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo() ;
   Pn := 0 ;
   WHILE Pn < NextFreePlayer DO
      IF (Pn#p) AND IsPlayerActive (Pn)
      THEN
         WITH Player[Pn] DO
            IF (Xman=x) AND (Yman=y)
            THEN
               RETURN TRUE
            ELSE
               INC (Pn)
            END
         END
      ELSE
         INC (Pn)
      END
   END ;
   RETURN FALSE
END PointOnOtherPlayer ;


PROCEDURE OpenDoor ;
VAR
   Success: BOOLEAN ;
BEGIN
   GetReadAccessToPlayer ;
   GetWriteAccessToDoor ;
   ClosedToOpenDoor(Success) ;
   GetAccessToScreen ;
   IF Success
   THEN
      DelCommentLine1(PlayerNo())
   ELSE
      WriteCommentLine1(PlayerNo(), 'thou canst')
   END ;
   ReleaseAccessToScreen ;
   ReleaseWriteAccessToDoor ;
   ReleaseReadAccessToPlayer
END OpenDoor ;


PROCEDURE ExamineDoor ;
VAR
   Success: BOOLEAN ;
BEGIN
   GetReadAccessToPlayer ;
   GetWriteAccessToDoor ;
   SecretToClosedDoor(Success) ;
   GetAccessToScreen ;
   IF Success
   THEN
      DelCommentLine1(PlayerNo())
   ELSE
      WriteCommentLine1(PlayerNo(), 'nothing')
   END ;
   ReleaseAccessToScreen ;
   ReleaseWriteAccessToDoor ;
   ReleaseReadAccessToPlayer
END ExamineDoor ;


PROCEDURE CloseDoor ;
VAR
   Success: BOOLEAN ;
BEGIN
   GetReadAccessToPlayer ;
   GetWriteAccessToDoor ;
   OpenToClosedDoor(Success) ;
   GetAccessToScreen ;
   IF Success
   THEN
      DelCommentLine1(PlayerNo())
   ELSE
      WriteCommentLine1(PlayerNo(), 'thou canst')
   END ;
   ReleaseAccessToScreen ;
   ReleaseWriteAccessToDoor ;
   ReleaseReadAccessToPlayer
END CloseDoor ;


(* Speak Function                                                     *)

PROCEDURE Speak ;
VAR
   a1, a2, a3: ARRAY [0..14] OF CHAR ;
   i, r, p   : CARDINAL ;
   ch        : CHAR ;
BEGIN
   p := PlayerNo() ;
   r := Player[p].RoomOfMan ;
   i := 0 ;
   a1[0] := nul ;
   a2[0] := nul ;
   a3[0] := nul ;
   REPEAT
      IF ClientRead(ch)
      THEN
         IF ch=nak
         THEN
            i := 0
         ELSIF (ch=del) OR (ch=bs)
         THEN
            IF i>0
            THEN
               DEC( i )
            END
         ELSIF (ch>=' ') OR (ch=cr)
         THEN
            IF ch=cr
            THEN
               ch := nul
            END ;
            IF i<15
            THEN
               a1[i] := ch
            ELSIF i<30
            THEN
               a2[i-15] := ch
            ELSE
               a3[i-30] := ch
            END ;
            INC( i )
         END
      ELSE
         RETURN
      END
   UNTIL (ch=nul) OR (i>44) ;
   DisplayMessage( a1, a2, a3 ) ;
END Speak ;


PROCEDURE Dead (PlayerDied, KilledBy, room: CARDINAL) ;
BEGIN
   WITH Player[PlayerDied] DO
      GetWriteAccessToPlayer ;
      CheckpointKill (KilledBy) ;
      CheckpointDied (PlayerDied) ;
      IF room#0
      THEN
         GetReadAccessToDoor ;
         GetWriteAccessToTreasure ;
         IF fd=-1
         THEN
            SilentScatterTreasures (PlayerDied, room)
         ELSE
            ScatterTreasures (PlayerDied, room) ;
            EraseMan (PlayerDied) ;
         END ;
         ReleaseWriteAccessToTreasure ;
         ReleaseReadAccessToDoor
      END ;
      ReleaseWriteAccessToPlayer
   END
END Dead ;


(* RandomRoom takes the current room and works out a random room.    *)

PROCEDURE RandomRoom (CurrentRoom, NoOfRoomsApart: CARDINAL ;
                      VAR room: CARDINAL) ;
VAR
   i: CARDINAL ;
BEGIN
   (* Warning the method used here may cause problems to a map which *)
   (* does not have consecutive rooms.                               *)

   RandomNumber( i, ActualNoOfRooms) ;
   room := i+1

(*
   Cutting out this routine for the moment.

   room := CurrentRoom ;
   WHILE NoOfRoomsApart>0 DO
      IF Rooms[CurrentRoom].NoOfDoors=1
      THEN
         i := 1
      ELSE
         RandomNumber( i, Rooms[CurrentRoom].NoOfDoors ) ;
         INC( i )
      END ;
      room := Rooms[CurrentRoom].Doors[i].LeadsTo ;
      IF room=0
      THEN
         room := CurrentRoom
      ELSE
         CurrentRoom := room
      END ;
      DEC( NoOfRoomsApart )
   END
*)
END RandomRoom ;


(* GetRandomPosition finds a free random position within a room *)

PROCEDURE PositionInRoom (room: CARDINAL ;
                          VAR x, y: CARDINAL ; VAR Success: BOOLEAN) ;
VAR
   r          : INTEGER ;
   maxx, maxy,
   x1, y1, doorno,
   j, i, d, z,
   OldRoom    : CARDINAL ;
   OkOld, ok,
   OkCurrent  : BOOLEAN ;
BEGIN
   doorno := 1 ;
   Success := FALSE ;
   WHILE (doorno<=Rooms[room].NoOfDoors) AND (NOT Success) DO
      OldRoom := Rooms[room].Doors[doorno].LeadsTo ;
      IF OldRoom#0
      THEN
         WITH Rooms[room].Doors[doorno].Position DO
            x1 := X1 ;
            y1 := Y1 ;
            i := X2
         END ;
         IF x1=i
         THEN
            d := 1
         ELSE
            d := 0
         END ;
         i := 1 ;
         maxx := 0 ;
         maxy := 0 ;
         WHILE i<=Rooms[room].NoOfWalls DO
            maxx := Max(Rooms[room].Walls[i].X2, maxx) ;
            maxy := Max(Rooms[room].Walls[i].Y2, maxy) ;
            INC(i)
         END ;
         OkCurrent := FALSE ;
         OkOld := FALSE ;
         WHILE NOT OkCurrent DO
            d := (d+2) MOD 4 ;
            i := x1 ;
            j := y1 ;
            REPEAT
               IncPosition(i, j, d) ;
               PointOnWall(room, i, j, OkCurrent) ;
               IF NOT OkCurrent
               THEN
                  GetDoorOnPoint(room, i, j, z, OkCurrent)
               END ;
               PointOnWall(OldRoom, i, j, OkOld) ;
               IF NOT OkOld
               THEN
                  GetDoorOnPoint(OldRoom, i, j, z, OkOld)
               END ;
               IF NOT OkCurrent
               THEN
                  FreeOfPlayersAndTreasure(room, i, j, ok) ;
                  IF ok
                  THEN
                     Success := TRUE ;
                     x := i ;
                     y := j
                  END
               END
            UNTIL OkCurrent OR OkOld OR
                  (ODD(d) AND ((i=0) OR (i>=maxx))) OR
                  ((NOT ODD(d)) AND ((j=0) OR (j>=maxy))) ;
            IF OkOld
            THEN
               Success := FALSE
            END
         END
      END ;
      INC(doorno)
   END ;
   IF Success
   THEN
      r := printf("room %d position %d %d\n", room, x, y)
   END
END PositionInRoom ;


PROCEDURE FreeOfPlayersAndTreasure (room, x, y: CARDINAL ; VAR Success: BOOLEAN) ;
VAR
   i : CARDINAL ;
BEGIN
   Success := TRUE ;
   i := 0 ;
   WHILE (i<NextFreePlayer) AND Success DO
      IF IsPlayerActive(i)
      THEN
         WITH Player[i] DO
            IF room=RoomOfMan
            THEN
               IF (Xman=x) AND (Yman=y)
               THEN
                  Success := FALSE
               END
            END
         END
      END ;
      INC (i)
   END ;
   IF Success
   THEN
      i := 1 ;
      WHILE (i <= MaxNoOfTreasures) AND Success DO
         WITH Treasure[i] DO
            IF (Rm=room) AND (kind=onfloor)
            THEN
               IF (Xpos=x) AND (Ypos=y)
               THEN
                  Success := FALSE
               END
            END
         END ;
         INC (i)
      END
   END
END FreeOfPlayersAndTreasure ;


(*
   HideTreasure - hides treasure, t, which is assummed to be absent from the
                  data structures when this procedure is called.
*)

PROCEDURE HideTreasure (t: CARDINAL) ;
VAR
   ok: BOOLEAN ;
BEGIN
   GetReadAccessToTreasure ;
   RespawnTreasure (GetRandomRoom(NoOfRoomsToHidePlayers, ActualNoOfRooms), t, 0) ;
   ReleaseReadAccessToTreasure
END HideTreasure ;


(*
   GetRandomRoom - returns a random room.
*)

PROCEDURE GetRandomRoom (NoOfRoomsToTraverse, TotalRooms: CARDINAL) : CARDINAL ;
VAR
   x, y, r: CARDINAL ;
BEGIN
   RandomNumber(x, NoOfRoomsToTraverse) ;
   INC(x) ;
   RandomNumber(y, TotalRooms) ;
   INC(y) ;
   RandomRoom(y, x, r) ;
   RETURN( r )
END GetRandomRoom ;


PROCEDURE Positioning ;
VAR
   Attempt,
   i, r, x, y, p: CARDINAL ;
   ok           : BOOLEAN ;
BEGIN
   Attempt := MaxNoOfPlayers ;
   p := PlayerNo() ;
   WITH Player[p] DO
      GetWriteAccessToPlayer ;
      GetReadAccessToDoor ;
      GetReadAccessToTreasure ;
      REPEAT
         r := GetRandomRoom(NoOfRoomsToHidePlayers, ActualNoOfRooms) ;
         ok := TRUE ;
         IF Attempt>0
         THEN
            FOR i := 0 TO NextFreePlayer-1 DO
               IF IsPlayerActive(i) AND (i#p)
               THEN
                  IF r=Player[i].RoomOfMan
                  THEN
                     ok := FALSE
                  END
               END
            END ;
            DEC(Attempt)
         END ;
         IF ok
         THEN
            PositionInRoom(r, x, y, ok)
         END
      UNTIL ok ;
      ScreenX := x-(x MOD Width) ;
      ScreenY := y-(y MOD Height) ;
      RoomOfMan := r ;
      Xman := x ;
      Yman := y ;
      ScaleSights(Xman, Yman, ScreenX, ScreenY, ok) ;
      ReleaseReadAccessToTreasure ;
      ReleaseReadAccessToDoor ;
      ReleaseWriteAccessToPlayer
   END
END Positioning ;


(* Miscellaneous routines that connect the screen to the main program *)


PROCEDURE InitialDisplay ;
BEGIN
   InitScreen(PlayerNo()) ;
   GetReadAccessToPlayer ;
   DrawRoom ;
   ReleaseReadAccessToPlayer
END InitialDisplay ;


END AdvUtil.
(*
 * Local variables:
 *  compile-command: "make"
 * End:
 *)
