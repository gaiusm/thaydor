IMPLEMENTATION MODULE Options ;

FROM DynamicStrings IMPORT String, InitString, KillString, InitStringCharStar ;
FROM StringConvert IMPORT stoc ;
FROM StrIO IMPORT WriteString, WriteLn ;
FROM StdIO IMPORT Write ;
FROM ASCII IMPORT nul ;
FROM GetOpt IMPORT GetOpt ;
FROM libc IMPORT printf, exit ;
FROM StringConvert IMPORT stoc ;

IMPORT SArgs, UnixArgs ;

CONST
   programName   = "botml" ;
   RandomDefault = 7 ;
   KDefault = 7 ;
   PlayerNameDefault = "bot" ;
   ServerNameDefault = "localhost" ;
   ServerPortDefault = 7000 ;


(*
   help -
*)

PROCEDURE help (code: INTEGER) ;
BEGIN
   printf ("Usage %s [-a servername][-d][-g][-p port][-s value][-v] mapdir\n", programName) ;
   printf ("  -a servername                 # set server name (default %s)\n", ServerNameDefault) ;
   printf ("  -d                            # enable debugging\n") ;
   printf ("  -g                            # enable text graphics\n") ;
   printf ("  -p port                       # set server port no. (default %d)\n", ServerPortDefault) ;
   printf ("  -s value                      # set random seed to value (default %d)\n", RandomDefault) ;
   printf ("  -n name                       # set player name (default %s)\n", PlayerNameDefault) ;
   printf ("  -v                            # enable verbose\n") ;
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
   l := InitString (':dghn:p:s:v') ;
   s := NIL ;
   arg := NIL ;
   count := 1 ;
   ch := GetOpt (UnixArgs.GetArgC (), UnixArgs.GetArgV (), l,
                 arg, optind, opterr, optopt) ;
   WHILE ch # nul DO
      CASE ch OF

      'a':  ServerName := InitStringCharStar (arg) ;
            INC (count, 2) |
      'd':  Debug := TRUE ;
            INC (count) |
      'g':  Graphics := TRUE ;
            INC (count) |
      'h':  help (0) |
      'n':  PlayerName := InitStringCharStar (arg) ;
            INC (count, 2) |
      'p':  ServerPort := stoc (arg) ;
            INC (count, 2) |
      's':  Seed := stoc (arg) ;
            INC (count, 2) |
      'v':  Verbose := TRUE ;
            INC (count) |
      '?':  printf ("illegal option\n") ; help (1)

      ELSE
         WriteString ("unrecognised option '-") ; Write (ch) ; WriteString ('"') ; WriteLn ;
         exit (1)
      END ;
      arg := KillString (arg) ;
      ch := GetOpt (UnixArgs.GetArgC (), UnixArgs.GetArgV (), l,
                    arg, optind, opterr, optopt)
   END ;
   MapDir := NIL ;
   IF (count < SArgs.Narg ()) AND SArgs.GetArg (MapDir, count)
   THEN
   END
END ParseArgs ;


(*
   Init -
*)

PROCEDURE Init ;
BEGIN
   PlayerName := InitString (PlayerNameDefault) ;
   ServerName := InitString (ServerNameDefault) ;
   ServerPort := ServerPortDefault ;
   Debug := FALSE ;
   Graphics := FALSE ;
   Verbose := FALSE ;
   MapDir := NIL ;
   Seed := RandomDefault ;
   K := KDefault
END Init ;


BEGIN
   Init
END Options.
