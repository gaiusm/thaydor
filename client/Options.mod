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
   programName       = "thaydor" ;
   PlayerNameDefault = "unknown" ;
   ServerNameDefault = "localhost" ;
   ServerPortDefault = 7000 ;


(*
   help -
*)

PROCEDURE help (code: INTEGER) ;
BEGIN
   printf ("Usage %s [-a servername][-d debugfile][-i inputfile][-o outputfile][-p port]\n", programName) ;
   printf ("  -a servername                 # set server name (default %s)\n", ServerNameDefault) ;
   printf ("  -d debugfile                  # enable debugging and dump it to debugfile\n") ;
   printf ("  -i name                       # set input trace file\n") ;
   printf ("  -p port                       # set server port no. (default %d)\n", ServerPortDefault) ;
   printf ("  -n name                       # set player name (default %s)\n", PlayerNameDefault) ;
   printf ("  -o name                       # set output log file\n") ;
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
   Init ;
   l := InitString (':d:hi:no:p:') ;
   s := NIL ;
   arg := NIL ;
   count := 1 ;
   ch := GetOpt (UnixArgs.GetArgC (), UnixArgs.GetArgV (), l,
                 arg, optind, opterr, optopt) ;
   WHILE ch # nul DO
      CASE ch OF

      'a':  ServerName := InitStringCharStar (arg) ;
            INC (count, 2) |
      'd':  DebugFile := InitStringCharStar (arg) ;
            Debug := TRUE ;
            INC (count, 2) |
      'h':  help (0) |
      'i':  InputFile := InitStringCharStar (arg) ;
            INC (count, 2) |
      'n':  PlayerName := InitStringCharStar (arg) ;
            INC (count, 2) |
      'o':  OutputFile := InitStringCharStar (arg) ;
            INC (count, 2) |
      'p':  ServerPort := stoc (arg) ;
            INC (count, 2) |
      '?':  printf ("illegal option\n") ;
            help (1)

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
   DebugFile := NIL ;
   PlayerName := InitString (PlayerNameDefault) ;
   ServerName := InitString (ServerNameDefault) ;
   ServerPort := ServerPortDefault ;
   OutputFile := NIL ;
   InputFile := NIL ;
   Debug := FALSE
END Init ;


END Options.
