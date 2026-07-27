MODULE Dungeon ;
(* *)

FROM AdvIntroduction IMPORT StartGame ;
FROM SArgs IMPORT GetArg ;
FROM AdvParse IMPORT ParseMap ;
FROM DynamicStrings IMPORT String, string ;
FROM libc IMPORT printf, exit ;
FROM Screen IMPORT AssignMapName ;

IMPORT Options ;

VAR
   s: String ;
   r: INTEGER ;
BEGIN
   Options.ParseArgs ;
   IF Options.MapFile = NIL
   THEN
      printf ("usage: dungeon mapfile\n")
   ELSE
      r := ParseMap (string (Options.MapFile)) ;
      IF r = 0
      THEN
         AssignMapName (Options.MapFile) ;
         StartGame
      ELSE
         exit (r)
      END
   END
END Dungeon.
