IMPLEMENTATION MODULE Bot ;

FROM sckt IMPORT tcpClientConnect, tcpClientSocket ;
FROM DynamicStrings IMPORT string ;

IMPORT Options, AI, LoadCheckpoint ;


(*
   getSocketFd - return the file descriptor after connecting to the server and port.
*)

PROCEDURE getSocketFd () : INTEGER ;
BEGIN
   RETURN tcpClientConnect (tcpClientSocket (string (Options.ServerName), Options.ServerPort))
END getSocketFd ;


(*
   Run - connect to the game server and play a game.
*)

PROCEDURE Run ;
BEGIN
   LoadCheckpoint.Connect (getSocketFd ()) ;
   (* Currently just runs the generic response for testing.  *)
   LoadCheckpoint.Generic
END Run ;


END Bot.
