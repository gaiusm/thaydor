IMPLEMENTATION MODULE Options ;

FROM DynamicStrings IMPORT String, InitString, KillString ;
FROM StringConvert IMPORT stoc ;
FROM StrIO IMPORT WriteString, WriteLn ;
FROM StdIO IMPORT Write ;
FROM ASCII IMPORT nul ;
FROM GetOpt IMPORT GetOpt ;
FROM libc IMPORT printf, exit ;
FROM AdvCheckpoint IMPORT CheckpointEnable ;

IMPORT SArgs, UnixArgs ;

CONST
   programName = "thaydor" ;


(*
   help -
*)

PROCEDURE help (code: INTEGER) ;
BEGIN
   printf ("Usage %s [-c checkpointdir] [-d] mapfile\n", programName) ;
   printf ("  -c checkpointdir              # configure checkpoint directory\n") ;
   printf ("  -d                            # enable debugging\n") ;
   exit (code)
END help ;


(*
   ParseArgs - check the options and configure the program.
*)

PROCEDURE ParseArgs ;
VAR
   optind,
   opterr,
   optopt: INTEGER ;
   arg,
   s, l  : String ;
   ch    : CHAR ;
   count : CARDINAL ;
BEGIN
   l := InitString (':c:d:h') ;
   s := NIL ;
   arg := NIL ;
   count := 1 ;
   ch := GetOpt (UnixArgs.GetArgC (), UnixArgs.GetArgV (), l,
                 arg, optind, opterr, optopt) ;
   WHILE ch # nul DO
      CASE ch OF

      'c':  CheckpointEnable (TRUE, arg) ;
            INC (count, 2) |
      'd':  Debug := TRUE ;
            INC (count) |
      'h':  help (0) |
      '?':  printf ("illegal option\n") ; help (1)

      ELSE
         WriteString ("unrecognised option '-") ; Write (ch) ; WriteString ('"') ; WriteLn ;
         exit (1)
      END ;
      arg := KillString (arg) ;
      ch := GetOpt (UnixArgs.GetArgC (), UnixArgs.GetArgV (), l,
                    arg, optind, opterr, optopt)
   END ;
   MapFile := NIL ;
   IF (count < SArgs.Narg ()) AND SArgs.GetArg (MapFile, count)
   THEN
   END
END ParseArgs ;


(*
   Init -
*)

PROCEDURE Init ;
BEGIN
   Debug := FALSE ;
   MapFile := NIL
END Init ;


BEGIN
   Init
END Options.
