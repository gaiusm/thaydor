MODULE Thaydor ;  (*!m2iso+gm2*)

IMPORT Client ;

BEGIN
   IF Client.Init ()
   THEN
      Client.SetupClass ;
      Client.Interpret
   END
END Thaydor.
