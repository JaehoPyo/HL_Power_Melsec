unit h_ReferLib;

interface

uses Inifiles,Windows, Sysutils;

  function  IniRead ( IniRoot , KeyName  , FieldName , ReadStr   : String ) : String;
  function  IniWrite( IniRoot , KeyName  , FieldName , WriteStr  : String ) : Boolean;
  procedure LogWrite( Filename, Msg : string );
  procedure LogFileCopy( Filename : string );
  function  LPAD(Msg : string; Len : Integer; Addch:Char = '0') : string;
  function  Data10To16(Rs : Integer) : string;         // 15     -> 'F'
  function  DecToHexa(Rs : Integer) : string;          // 1024 -> Hexa('0100')
  function  HexStrToBinStr( HexStr : String) : String;
  function  BinStrToHexStr( BinStr : String ) : String; // 0010 0000 -> 20
  function  ReverseStr( Rs : String) : String;
  function  BinStrToCharStr( BinS : String ) : String; // 0010 -> 2
  function  BinStringToChar( BinS : String ) : Char; // 0010 -> 2
  function  chStrToInt( Str : String) : Integer;

var
  BiteArray : Array [0..15] of String = ('0000', '0001', '0010', '0011', '0100', '0101',
                                         '0110', '0111', '1000', '1001', '1010', '1011',
                                         '1100', '1101', '1110', '1111');


implementation

//==============================================================================
// INI 파일에서 Key Field 의 값을 읽어온다
//==============================================================================
function IniRead( IniRoot , KeyName , FieldName , ReadStr : String ): String;
var Ini_File    : TIniFile;
begin
  try
    Ini_File := TIniFile.Create( ExpandFileName ( IniRoot )  );
    try
      Result := PChar ( Ini_File.ReadString ( KeyName ,FieldName , ReadStr ) );
    finally
      Ini_File := nil;
      Ini_File.Free;
    end;
  except
    Result := ReadStr;
  end;
end;

//==============================================================================
// INI 파일에서 Key Field 의 값을 기록한다
//==============================================================================
function IniWrite ( IniRoot , KeyName, FieldName, WriteStr : String ): Boolean ;
var Ini_File   : TIniFile;
begin
  try
    Ini_File := TIniFile.Create( ExpandFileName ( IniRoot )  );
    try
      Ini_File.WriteString( KeyName, FieldName, WriteStr  );
      Result := True;
    finally
      Ini_File := nil;
      Ini_File.Free;
    end;
  except
    Result := False;
  end;
end;

procedure LogWrite( Filename, Msg : string );
var
  F: TextFile;
  S: file of Byte;
  Rc : integer;
  Size : Longint;
  LogFile    : string;
begin

  LogFile := Filename ;

  if FileExists(LogFile) then
  begin
    AssignFile(S, LogFile);
    Reset(S);

    Size := FileSize(S);
    CloseFile(S);
    if (size > 5000000) then
    begin  //10KB   //1K is 1000Byte
      LogFileCopy(Filename);
      Rc := 0; // 0:생성
    end else
      Rc := 1; // 추가
  end else
    Rc := 0 ;

  AssignFile(F, LogFile);
  if Rc = 1 then
     Append(F)   // 추가
  else
     Rewrite(F); // 파일 생성

  Writeln(F, Msg);
  CloseFile(F);
end;

procedure LogFileCopy(Filename:string);
var
  F, R : TextFile;
  LogFile, LogFileOld, Msg : string;
  i : integer;
begin
  LogFile    := Filename ;

  for i := length(Filename) downto 1 do
  begin
     if  Filename[i] = '.' then
     begin
       msg := copy(Filename,1,i-1) + '_' + FormatDateTime('YYYYMMDDHHNN', Now) + '.'+
              copy(Filename,i+1,length(Filename)-i );
       break;
     end;
  end;

  if Msg = '' then
       LogFileOld := Filename + FormatDateTime('YYMMDDhhnn', Now)
  else LogFileOld := Msg ;

  // Read File 처리
  AssignFile(R, LogFile);
  Reset(R);
  ReadLn(R, Msg);

  // Write File  처리
  AssignFile(F, LogFileOld);
  Rewrite(F); // 파일 생성
  Writeln(F, Msg );

  while not Eof(R) do
  begin
    ReadLn( R, Msg );
    Writeln(F, Msg );
  end;
  CloseFile(R);
  CloseFile(F);
end;

function LPAD(Msg : string; Len : Integer; Addch:Char) : string;
var
  i, Len1 : integer;
begin
  Result := Msg;
  Len1   := length(Msg);
  if Len = Len1 then Exit;

  For i := 1 to Len do
  Begin
    if Len1 < i then Result := Addch + Result ;
  end;
end;

function Data10To16(Rs : Integer) : string; // 15 -> 'F'
begin
   result := '0';
   case Rs of
   15 :  Result := 'F';
   14 :  Result := 'E';
   13 :  Result := 'D';
   12 :  Result := 'C';
   11 :  Result := 'B';
   10 :  Result := 'A';
   9  :  Result := '9';
   8  :  Result := '8';
   7  :  Result := '7';
   6  :  Result := '6';
   5  :  Result := '5';
   4  :  Result := '4';
   3  :  Result := '3';
   2  :  Result := '2';
   1  :  Result := '1';
   end;
end;

function  DecToHexa(Rs : Integer) : string;          // 1024 -> Hexa('0100')
var
  xDiv, xInt : Integer;
  xStr : String;
begin
   result := '0000';
   xInt := Rs;
   if xInt > 2048 then
   begin
      xDiv := xInt div 2048 ;
      xInt := xInt mod 2048 ;
      xStr := Data10To16(xDiv);
   end else xStr := '0';

   if xInt > 128 then
   begin
      xDiv := xInt div 128 ;
      xInt := xInt mod 128 ;
      xStr := xStr +Data10To16(xDiv);
   end else xStr := xStr +'0';

   if xInt > 16 then
   begin
      xDiv := xInt div 16 ;
      xInt := xInt mod 16 ;
      xStr := xStr +Data10To16(xDiv);
   end else xStr := xStr +'0';

   xStr := xStr +Data10To16(xInt);

   Result := LPad(xStr,4);

end;

function HexStrToBinStr( HexStr : String) : String;        // 'FFA1' -> '1111111110100001'
var
  i : Integer;
begin
  Result := '' ;
  for i := 1 to Length(HexStr) do
  begin
    Result := Result + BiteArray[strtoint('$'+ HexStr[i])];
  end;
end;

function  BinStrToHexStr( BinStr : String ) : String; // 0010 -> 2
var i, j : Integer;
begin
  Result := '' ;
  For i := 1 to (Length(Binstr) div 4) do
  begin
    for j := low(BiteArray) to high(BiteArray) do
    begin
      if Copy(Binstr, ((i-1)*4)+1, 4) = BiteArray[j] then Break;
    end;
    Result := Result + inttohex(j, 0);
  End;
end;

function  ReverseStr( Rs : String) : String;
var
  i : Integer;
begin
  Result := '';
  for i := Length(Rs) Downto 1 do begin
    Result := Result + Copy(Rs, i, 1);
  end;
end;

function  BinStrToCharStr( BinS : String ) : String; // 0010 -> 2
var i : Integer;
begin
  Result := '' ;
  For i := 1 to (Length(Bins) div 4) do Begin
   Result := Result + BinStringToChar(Copy(Bins, ((i-1)*4)+1, 4));
  End;
end;

function BinStringToChar( BinS : String ) : Char; // 0010 -> 2
var str : String;
begin

  Str := Data10To16 (
    ChStrToInt(copy(BinS,1,1)) * 8 +
    ChStrToInt(copy(BinS,2,1)) * 4 +
    ChStrToInt(copy(BinS,3,1)) * 2 +
    ChStrToInt(copy(BinS,4,1)) * 1 );
  Result := Str[1];

end;

function chStrToInt( Str : String) : Integer;
var xstr, xstr2 : String;
    i : Integer;
begin
  xStr := Trim(Str);
  xStr2 := '';
  if trim(xStr) = '' then xStr2 := '0'
  else begin
    for i := 1 to length(xStr) do begin
      if xStr[i] in ['1'..'9','0','-'] then
        xStr2 := xStr2 + xStr[i];
    end;
  end;
  if xStr2 = '' then xStr2 := '0';

  result := StrToInt(xStr2);
end;

end.
