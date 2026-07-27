IMPLEMENTATION MODULE AdvMath ;


FROM TimerHandler IMPORT TicksPerSecond, GetTicks ;

FROM AdvSystem IMPORT Player,
                      PlayerNo,
                      TypeOfEntity,
                      TimeMinSec,
                      GetAccessToScreenNo, ReleaseAccessToScreenNo ;

FROM Screen IMPORT WriteWounds, WriteFatigue, WriteCommentLine1 ;

FROM StrLib IMPORT StrCopy ;


(*
CONST
   RequiredToParry       =   3 ;
   RequiredToAttack      =   5 ;
   RequiredToThrust      =   9 ;
   RequiredToFireArrow   =  10 ;
   RequiredToFireMagic   =  15 ;
   RequiredToMove        =   6 ;  (* For 9 squares *)
   RequiredToMagicShoes  =   3 ;  (* For 9 squares *)
   RequiredToMagicParry  =   1 ;
   RequiredToMagicAttack =   3 ;
   RequiredToMagicThrust =   6 ;

   DamageByParry         =   7 ;
   DamageByAttack        =  13 ;
   DamageByThrust        =  17 ;
   DamageByFireArrow     =  23 ;
   DamageByFireMagic     =  74 ;
   DamageByHandGrenade   =  69 ;
   DamageByHotIron       =  19 ;
   DamageByMagicParry    =   8 ;
   DamageByMagicAttack   =  14 ;
   DamageByMagicThrust   =  18 ;
*)

TYPE
   MagicNormalRecord = RECORD
                          RequiredParry,
                          RequiredAttack,
                          RequiredThrust,
                          RequiredFire,
                          RequireMove9,
                          RateMove1,
                          RateMove9,
                          DamageParry,
                          DamageAttack,
                          DamageThrust,
                          DamageFire,
                          DamageDart   : CARDINAL ;
                       END ;

   MagicNormalArray = ARRAY BOOLEAN OF MagicNormalRecord ;

   CharisticRecord = RECORD
                        name             : ARRAY [0..13] OF CHAR ;
                        MagicNormal      : MagicNormalArray ;
                        DamageHandGrenade,
                        DamageHotIron,
                        DefaultWeight    : CARDINAL ;
                     END ;

   CharisticArray = ARRAY TypeOfEntity OF CharisticRecord ;

   getQuery       = PROCEDURE () : CARDINAL ;

CONST
   Charistic = CharisticArray {CharisticRecord {"Human",            (*                    Fatigue     | Rate    (in 1/100s).  *)
                                                 MagicNormalArray { (* Normal attributes:               1    9                *)
                                                                    MagicNormalRecord {3, 5, 9, 10, 6, 2, 60, 7, 13, 17, 23, 3},
                                                                    (* Magic attributes.  *)
                                                                    MagicNormalRecord {1, 3, 6, 15, 3, 2, 28, 8, 14, 18, 74, 3}},
                                                 69, 19, 70},
                               CharisticRecord {"Orc",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 200, 400, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 200, 8, 14, 18, 74, 3}},
                                                 69, 19, 70},
                               CharisticRecord {"Giant Ant",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 100, 200, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 100, 8, 14, 18, 74, 3}},
                                                 69, 19, 70},
                               CharisticRecord {"Dwarf",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 200, 400, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 200, 8, 14, 18, 74, 3}},
                                                69, 19, 70},
                               CharisticRecord {"Elf",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 200, 400, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 200, 8, 14, 18, 74, 3}},
                                                69, 19, 70},
                               CharisticRecord {"Salamander",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 200, 400, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 200, 8, 14, 18, 74, 3}},
                                                69, 19, 70},
                               CharisticRecord {"Creeping Crud",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 200, 400, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 200, 8, 14, 18, 74, 3}},
                                                69, 19, 70},
                               CharisticRecord {"Fire Elemental",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 200, 400, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 200, 8, 14, 18, 74, 3}},
                                                29, 0, 70},
                               CharisticRecord {"Troll",
                                                MagicNormalArray { (* Normal attributes.  *)
                                                                   MagicNormalRecord {3, 5, 9, 10, 6, 200, 400, 7, 13, 17, 23, 3},
                                                                   (* Magic attributes.  *)
                                                                   MagicNormalRecord {1, 3, 6, 15, 3, 100, 200, 8, 14, 18, 74, 3}},
                                                                   69, 19, 70}} ;


(* No access lock on anything ! *)

PROCEDURE UpDateWoundsAndFatigue (p: CARDINAL) ;
VAR
   HalfSecs,
   sec, tsec: CARDINAL ;
BEGIN
   TimeMinSec (sec) ;
   HalfSecs := GetTicks () DIV (TicksPerSecond DIV 2) ;    (* we want half seconds *)
   WITH Player[p] DO
      IF HalfSecs>LastSecFatigue
      THEN
         tsec := HalfSecs-LastSecFatigue ;
         IF Entity.Fatigue<100
         THEN
            Entity.Fatigue := Entity.Fatigue + tsec ;
            IF Entity.Fatigue > 100
            THEN
               Entity.Fatigue := 100
            END ;
            WriteFatigue (p, Entity.Fatigue)
         END ;
         LastSecFatigue := HalfSecs
      END ;
      IF sec > LastSecWounds
      THEN
         tsec := sec - LastSecWounds ;
         IF tsec > 5
         THEN
            LastSecWounds := sec
         END ;
         IF Entity.Wounds < 100
         THEN
            Entity.Wounds := Entity.Wounds + (tsec DIV 6) ;
            IF Entity.Wounds > 100
            THEN
               Entity.Wounds := 100
            END ;
            WriteWounds (p, Entity.Wounds)
         END ;
         LastSecWounds := sec
      END
   END
END UpDateWoundsAndFatigue ;


PROCEDURE StrengthToSwingSword (Required: getQuery) : BOOLEAN ;
VAR
   ok  : BOOLEAN ;
   p, t: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   WITH Player[p] DO
      t := (Entity.Weight * Required ()) DIV GetDefaultWeight () ;
      GetAccessToScreenNo (p) ;
      IF t > Entity.Fatigue
      THEN
         WriteCommentLine1 (p, 'too tired') ;
         ok := FALSE
      ELSE
         DEC (Entity.Fatigue, t) ;
         WriteFatigue (p, Entity.Fatigue) ;
         ok := TRUE
      END ;
      ReleaseAccessToScreenNo (p)
   END ;
   RETURN ok
END StrengthToSwingSword ;


PROCEDURE GetRequiredToParry  () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   WITH Player[p] DO
      RETURN Charistic[Entity.EntityType].MagicNormal[MagicSword IN
        Entity.TreasureOwn].RequiredParry
   END
END GetRequiredToParry ;


PROCEDURE GetRequiredToAttack  () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   WITH Player[p] DO
      RETURN Charistic[Entity.EntityType].MagicNormal[MagicSword IN
        Entity.TreasureOwn].RequiredAttack
   END
END GetRequiredToAttack ;


PROCEDURE GetRequiredToThrust  () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   WITH Player[p] DO
      RETURN Charistic[Entity.EntityType].MagicNormal[MagicSword IN
        Entity.TreasureOwn].RequiredThrust
   END
END GetRequiredToThrust ;


(* The following routines do use AccessToScreen when needed *)

PROCEDURE StrengthToParry () : BOOLEAN ;
BEGIN
   RETURN StrengthToSwingSword (GetRequiredToParry)
END StrengthToParry ;


PROCEDURE StrengthToAttack () : BOOLEAN ;
BEGIN
   RETURN StrengthToSwingSword (GetRequiredToAttack)
END StrengthToAttack ;


PROCEDURE StrengthToThrust () : BOOLEAN ;
BEGIN
   RETURN StrengthToSwingSword (GetRequiredToThrust)
END StrengthToThrust ;


PROCEDURE StrengthToPullBow (RequiredToPull: getQuery) : BOOLEAN ;
VAR
   ok  : BOOLEAN ;
   p, t: CARDINAL ;
BEGIN
   p := PlayerNo() ;
   WITH Player[p] DO
      t := (Entity.Weight * RequiredToPull ()) DIV GetDefaultWeight () ;
      GetAccessToScreenNo (p) ;
      IF t > Entity.Fatigue
      THEN
         WriteCommentLine1 (p, 'too tired') ;
         ok := FALSE
      ELSE
         DEC (Entity.Fatigue, t) ;
         WriteFatigue (p, Entity.Fatigue) ;
         ok := TRUE
      END ;
      ReleaseAccessToScreenNo (p)
   END ;
   RETURN ok
END StrengthToPullBow ;


PROCEDURE StrengthToFireArrow () : BOOLEAN ;
BEGIN
   RETURN StrengthToPullBow (GetRequiredFireArrow)
END StrengthToFireArrow ;


PROCEDURE StrengthToFireMagic () : BOOLEAN ;
BEGIN
   RETURN StrengthToPullBow (GetRequiredFireMagic)
END StrengthToFireMagic ;


PROCEDURE StrengthToMove (n: CARDINAL) : BOOLEAN ;
VAR
   ok  : BOOLEAN ;
   p, t: CARDINAL ;
BEGIN
   p := PlayerNo() ;
   WITH Player[p] DO
      t := (((Entity.Weight * GetRequireMove9 ()) DIV 9) * n) DIV GetDefaultWeight () ;
      GetAccessToScreenNo (p) ;
      IF t > Entity.Fatigue
      THEN
         WriteCommentLine1 (p, 'too tired') ;
         ok := FALSE
      ELSE
         DEC (Entity.Fatigue, t) ;
         WriteFatigue (p, Entity.Fatigue) ;
         ok := TRUE
      END ;
      ReleaseAccessToScreenNo (p)
   END ;
   RETURN ok
END StrengthToMove ;


PROCEDURE GetDamageByParry () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN Charistic[Player[p].Entity.EntityType].MagicNormal[MagicSword IN Player[p].Entity.TreasureOwn].DamageParry
END GetDamageByParry ;


PROCEDURE GetDamageByAttack () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN Charistic[Player[p].Entity.EntityType].MagicNormal[MagicSword IN Player[p].Entity.TreasureOwn].DamageAttack
END GetDamageByAttack ;


PROCEDURE GetDamageByThrust () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN Charistic[Player[p].Entity.EntityType].MagicNormal[MagicSword IN Player[p].Entity.TreasureOwn].DamageThrust
END GetDamageByThrust ;


(*
   GetEntityWeightDefault -
*)

PROCEDURE GetEntityWeightDefault (type: TypeOfEntity) : CARDINAL ;
BEGIN
   RETURN Charistic[type].DefaultWeight
END GetEntityWeightDefault ;


PROCEDURE GetDefaultWeight () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN GetEntityWeightDefault (Player[p].Entity.EntityType)
END GetDefaultWeight ;


PROCEDURE GetRequiredFire (magic: BOOLEAN) : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN Charistic[Player[p].Entity.EntityType].MagicNormal[magic].RequiredFire
END GetRequiredFire ;


PROCEDURE GetRequiredFireArrow () : CARDINAL ;
BEGIN
   RETURN GetRequiredFire (FALSE)
END GetRequiredFireArrow ;


PROCEDURE GetRequiredFireMagic () : CARDINAL ;
BEGIN
   RETURN GetRequiredFire (TRUE)
END GetRequiredFireMagic ;


PROCEDURE GetDamageFirePlayer (player: CARDINAL; magic, dart: BOOLEAN) : CARDINAL ;
BEGIN
   IF dart
   THEN
      RETURN Charistic[Player[player].Entity.EntityType].MagicNormal[magic].DamageDart
   ELSE
      RETURN Charistic[Player[player].Entity.EntityType].MagicNormal[magic].DamageFire
   END
END GetDamageFirePlayer ;


(*
   GetRequireMove9 -
*)

PROCEDURE GetRequireMove9 () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN Charistic[Player[p].Entity.EntityType].MagicNormal[MagicShoes IN Player[p].Entity.TreasureOwn].RequireMove9
END GetRequireMove9 ;


(*
   GetRateMove - return the delay in 100 * seconds if a player travels n units
*)

PROCEDURE GetRateMove (n: CARDINAL) : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   IF n <= 1
   THEN
      RETURN Charistic[Player[p].Entity.EntityType].MagicNormal[SpeedPotion IN Player[p].Entity.TreasureOwn].RateMove1
   ELSE
      RETURN Charistic[Player[p].Entity.EntityType].MagicNormal[SpeedPotion IN Player[p].Entity.TreasureOwn].RateMove9
   END
END GetRateMove ;


(*
   GetEntityName - assign Charistic[type].name to typename.
*)

PROCEDURE GetEntityName (type: TypeOfEntity; VAR typename: ARRAY OF CHAR) ;
BEGIN
   StrCopy (Charistic[type].name, typename)
END GetEntityName ;


PROCEDURE GetDamageHandGrenadePlayer (player: CARDINAL) : CARDINAL ;
BEGIN
   RETURN Charistic[Player[player].Entity.EntityType].DamageHandGrenade
END GetDamageHandGrenadePlayer ;


PROCEDURE GetDamageHandGrenade () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN GetDamageHandGrenadePlayer (p)
END GetDamageHandGrenade ;


PROCEDURE GetDamageHotIron () : CARDINAL ;
VAR
   p: CARDINAL ;
BEGIN
   p := PlayerNo () ;
   RETURN Charistic[Player[p].Entity.EntityType].DamageHotIron
END GetDamageHotIron ;


END AdvMath.
