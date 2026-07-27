MODULE botml ;

IMPORT Options, LoadCheckpoint, Bot ;

BEGIN
   Options.ParseArgs ;
   LoadCheckpoint.LoadDir (Options.MapDir) ;
   Bot.Run
END botml.
