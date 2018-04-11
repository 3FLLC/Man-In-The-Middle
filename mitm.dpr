Program ManInTheMiddle;
{$IFDEF FPC}
   {$MODE DELPHI}{$H+}
{$ENDIF}

/////////////////////////////////////////////////////////////////
// This is a quick utility, may evolve as needed.
// I used this to reverse the wire protocol for MySQL and CubeSQL
/////////////////////////////////////////////////////////////////

uses
{$IFDEF UNIX}
   cThreads,
{$ENDIF}
   Crt,                   // Keyboard routine(s)
   Classes,
   SysUtils,
   DXSock6,               // Core Socket Technology
   DXSock_GenericServer,  // Core Listener Class
   DXUtil_String,
   DXUtil_Numeric,
   DXUtil_Environment;    // Cross Platform Environment Methods

var
   Server:TBPDXGenericServer;
   inport:word;
   destport:word;
   destaddr:String;

type
   tEvents = Class
      class procedure OnProcessSession(Sender:TObject);
   end;

class procedure TEvents.OnProcessSession(Sender:TObject);
var
   Client:TBPDXSock;
   Session:TBPDXGenericServerSession;
   Ws:String;
   Len:Longint;

Begin
   Session:=TBPDXGenericServerSession(Sender);
   Client:=TBPDXSock.Create;
   If Client.ConnectTo(destaddr, destport) then begin
      While Session.Connected do begin
         If Session.Readable then begin
            If Session.CharactersToRead=0 then break; // SYN disconnect received from desktop
            Len:=Session.CharactersToRead;
            Ws:=Session.ReadString(Len,500); // pull from socket layer buffer
            Writeln(StdOut,#13,Len:5,' C->M:"'+CleanStr(Ws)+'"  HEX:"'+HexDump(Ws)+'"');
            Client.Write(Ws); // drop over to the server
            Continue;
         End
         Else Begin
            If Client.Readable then begin
               If Client.CharactersToRead=0 then break; // SYN disconnect received from server
               Len:=Client.CharactersToRead;
               Ws:=Client.ReadString(Len,500);
               Writeln(StdOut,#13,Len:5,' S->M:'+CleanStr(Ws)+'"  HEX:"'+HexDump(Ws)+'"');
               Session.Write(Ws);
               Continue;
            End;
         End;
         DoSleepEx(1);
         ProcessWindowsMessageQueue;
         Ws:='';
      End;
   End;
   Client.Disconnect;
   Client.Free;
   Session.Disconnect;
   // Do not free Session - caller is responsible //
End;

Procedure ShowHelp;
Begin
   TextColor(15);
   Writeln(StdOut,#13#10#13' usage: ',ParamStr(0),' -inport # -destport # [-destaddr hostname]');
   Writeln(StdOut,'');
   TextColor(14);
   Write(StdOut,#13'  -inport #  ');
   TextColor(10);
   Writeln(StdOut,'        this is the port MITM will accept connections on.');
   TextColor(14);
   Write(StdOut,#13'  -destport #');
   TextColor(10);
   Writeln(StdOut,'        this is the port MITM will connect to on your behalf.'+#13#10);
   TextColor(12);
                    //---------0---------0---------0---------0---------0---------0---------0---------0//
   Writeln(StdOut,#13' If the server is not local to MITM then you need to specify the following:');
   TextColor(14);
   Write(StdOut,#13'  -destaddr hostname');
   TextColor(10);
   Writeln(StdOut,' this can be the IP address, machine name or FQDN.');
   Writeln(StdOut,#13);
End;

procedure ProcessCommandLine;
var
   Loop:Longint;
   InB:Boolean;
   OutB:Boolean;
   OutA:Boolean;
   IsNo:Boolean;
   UpWs:String;

Begin
   For Loop:=1 to ParamCount do begin
      UpWs:=Uppercase(ParamStr(Loop));
      If (UpWs='-INPORT') then Begin
         InB:=True;
         Continue;
      End
      Else If (UpWs='-DESTPORT') then Begin
         OutB:=True;
         Continue;
      End
      Else If (UpWs='-DESTADDR') then Begin
         OutA:=True;
         Continue;
      End;
      IsNo:=IsNumericString(ParamStr(Loop));
      If InB then begin
         If IsNo then Inport:=StringToInteger(ParamStr(Loop));
         InB:=False;
         Continue;
      End
      Else If OutB then begin
         If IsNo then Destport:=StringToInteger(ParamStr(Loop));
         OutB:=False;
         Continue;
      End
      Else If OutA then begin
         DestAddr:=ParamStr(Loop);
         OutA:=False;
         Continue;
      End
   End;
End;

Begin
   ClrScr;
   TextColor(14);
   Write('Man In The Middle ');
   TextColor(10);
   Writeln('(c) 2018 by Brain Patchwork DX, LLC.');
   TextColor(8);
   Write('--------------------------------');
   TextColor(11);
   Writeln(' by G.E. Ozz Nixon Jr.');
   If ParamCount<4 then Begin
      ShowHelp;
      TextColor(7);
      Exit;
   End;
   ProcessCommandLine;
   If Inport=0 then begin
      TextColor(12);
      Writeln(StdOut,#13#10#13#254' inport not properly defined.');
      ShowHelp;
      TextColor(7);
      Exit;
   End;
   If Destport=0 then begin
      TextColor(12);
      Writeln(StdOut,#13#10#13#254' destport not properly defined.');
      ShowHelp;
      TextColor(7);
      Exit;
   End;
   If DestAddr='' then DestAddr:='127.0.0.1';
   TextColor(7);
   Server:=TBPDXGenericServer.Create;
   Server.Description:='This is a simple Man in the Middle - used to crack wire protocols';
   Server.OnProcessSession:=TEvents.OnProcessSession;
   Server.StartInBackground('', inport);
   If Server.FailedToStart>0 then begin
      TextColor(12);
      Writeln('Could not start listener on port #',inport,', errorno==',Server.FailedToStart);
      TextColor(7);
      Server.Free;
      Exit;
   End;
   Writeln('Listening on ',inport,', connecting to ',destaddr,':',destport,', started.');
   While Server.Active do begin
      DoSleepEx(1);
      ProcessWindowsMessageQueue;
      If Keypressed then begin
         If ReadKey=#27 then begin
            TextColor(3);
            Writeln(#13+'Escape detected, shutting down listener.');
            TextColor(7);
            Server.Stop;
            DoSleepEx(100);
            Break;
         End;
      End;
   End;
   Server.Free;
End.
