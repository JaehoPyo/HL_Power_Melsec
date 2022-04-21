unit u_Control;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, Buttons, ExtCtrls, DB, ADODB, StrUtils,
  h_ReferLib, ScktComp, OleCtrls, ACTETHERLib_TLB ;

type

  TCOMM_FLAG = ( CVW_D_W1 , // Write D Word
                 CVW_D_W2 , // Write D Word
                 CVR_D_W1, // Read D Word(Word)
                 CVR_D_W2, // Read D Word(bit)
                 CVR_D_W3  // Read D Word(Word) RFID data area
               );

  TSC_ORDER = Record
    SCORD_NO,             // 작업번호
    SCORD_D100,           // 적재 열
    SCORD_D101,           // 적재 연
    SCORD_D102,           // 적재 단
    SCORD_D103,           // 하역 열
    SCORD_D104,           // 하역 연
    SCORD_D105,           // 하역 단
    SCORD_D106,           // 예비
    SCORD_D107,           // 예비
    SCORD_D108,           // 예비
    SCORD_D109,           // 예비
    SCORD_D110,           // 기동지시 and Data Reset
    SCORD_ST,             // 지시타입
    SCORD_DT : String ;   // 지시 시간
  end;

  TPLC_ORDER = Record
    D111   ,
    ORD_ST ,
    ORD_DT : String;
  end;

  TfrmControl = class(TForm)
    Panel1: TPanel;
    pgcStatus: TPageControl;
    TabSheet1: TTabSheet;
    staInfo: TStatusBar;
    MainDatabase: TADOConnection;
    qryInfo1: TADOQuery;
    tmSendRecv1: TTimer;
    tmTimeOut1: TTimer;
    qryUpdate1: TADOQuery;
    Pnl_Main: TPanel;
    memLog: TMemo;
    qrySelect1: TADOQuery;
    Pnl_Bottom: TPanel;
    GroupBox6: TGroupBox;
    ckLog1: TCheckBox;
    bbComm1: TBitBtn;
    bbExit: TBitBtn;
    ActQNUDECPUTCP1: TActQNUDECPUTCP;
    ActQJ71E71TCP1: TActQJ71E71TCP;
    tmrConnectCheck: TTimer;
    qryDBChk: TADOQuery;
    pnlPLC1: TPanel;
    spLED11: TShape;
    Label7: TLabel;
    pnlPLC2: TPanel;
    spLED12: TShape;
    Label8: TLabel;
    pnlPLC3: TPanel;
    spLED13: TShape;
    Label10: TLabel;
    Button1: TButton;
    Panel3: TPanel;
    Label20: TLabel;
    cbUsed1: TCheckBox;
    Panel2: TPanel;
    plConn1: TPanel;
    plTimeOut1: TPanel;
    gb_SC_COMM: TGroupBox;
    ShpCon: TShape;
    qryTemp: TADOQuery;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);

    procedure bbCommClick(Sender: TObject);
    procedure bbExitClick(Sender: TObject);
    procedure ckLogClick(Sender: TObject);

    procedure tmSendRecvTimer(Sender: TObject);
    procedure tmTimeOutTimer(Sender: TObject);
    procedure tmrConnectCheckTimer(Sender: TObject);

    procedure MainDatabaseAfterConnect(Sender: TObject);
    procedure MainDatabaseAfterDisconnect(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure cbUsed1Click(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
    procedure LogWriteStr(PLC_NO:integer ; WriteStr : String);

    procedure ReConnect(PLC_NO:Integer) ;
    procedure Set_COMM_FLAG(PLC_NO:integer) ;
    procedure SetOnCommPNL(PLC_NO, iMode:integer) ;
    procedure SetOffCommPNL(PLC_NO, iMode:integer) ;

    procedure PLC_READ_PROCESS(PLC_NO:integer)  ; // Read Flag Update
    procedure PLC_WRITE_PROCESS(PLC_NO:integer) ; // Write Flag Update

    procedure PLC_READ_WORD1(PLC_NO:Integer); // CH01 ~ CH02 : SC D(Bit) 영역  (  Bit D0010.00 ~ D0011.15 : 2Word * 16Field = 32 Bit )
    procedure PLC_READ_WORD2(PLC_NO:Integer); // CH03 ~ CH05 : SC D(word)영역  ( Word D0012 ~ D0023 : 4Word * 3Field = 12 Word )
    procedure PLC_READ_WORD3(PLC_NO:Integer); //
    procedure PLC_READ_WORD4(PLC_NO:Integer); //


    procedure PLC_WRITE_WORD1(PLC_NO:Integer) ;   // D Word 영역 Write 처리
    procedure PLC_WRITE_WORD2(PLC_NO:Integer) ;

    function  DBConnection: Boolean;
    function  Get_COMM_FLAG(PLC_NO:Integer):String ;
    function  Get_COMM_FLAGNo(PLC_NO:Integer):integer ;
    function  HexaReverse(PLC_NO:integer;StrBuf:String) :String ;

    // SC 작업지시 관련
    function Get_PLC_JOB1(PLC_NO: integer; var SCORD: TSC_ORDER): Boolean ;
    function Get_PLC_JOB2(PLC_NO: Integer; var PLC_ORD: TPLC_ORDER): Boolean ;
    function Del_PLC_JOB1(PLC_NO: integer; SCORD: TSC_ORDER): Boolean ;
    function Del_PLC_JOB2(PLC_NO: integer; PLC_ORD: TPLC_ORDER): Boolean ;

    function fnDBConChk: Boolean;
    procedure CloseChkMsg(Sender: TObject);

    procedure fnSet_Current(Cur_Name, FName, FValue : String);
  end;

Const
  INI_PATH  : String = 'MELSEC.INI';

  START_PLCNO = 1 ; // START PLC NO
  End_PLCNO   = 1 ; // END PLC NO
  MaxPLC_Cnt  = 1 ; // PLC COUNT


var
  frmControl: TfrmControl;
  COMM_FLAG : Array[START_PLCNO..End_PLCNO] of TCOMM_FLAG ;
  COMM_ON   : Array[START_PLCNO..End_PLCNO] of Boolean ;
  LogSave   : Boolean ;
  DBConChk  : Boolean ;
  FormClose : Boolean ;
  RunMode   : Boolean ;
  CloseChk  : Boolean ;       // 프로그램 종료 Flag

implementation

{$R *.dfm}

//==============================================================================
// DBConnection
//==============================================================================
function TfrmControl.DBConnection: Boolean;
var
  DbKind, DbSource, DbOLE, DbAlais, DbUser, DbPasswd : String;
begin
  DbKind   := IniRead(INI_PATH, 'Database', 'Connection', 'IniRead Fail');
  DbSource := IniRead(INI_PATH, 'Database', 'DataSource', 'IniRead Fail');
  DbOLE    := IniRead(INI_PATH, 'Database', 'Provider', 'IniRead Fail');
  DbAlais  := IniRead(INI_PATH, 'Database', 'Alais'   , 'IniRead Fail');
  DbUser   := IniRead(INI_PATH, 'Database', 'User'    , 'IniRead Fail');
  DbPasswd := IniRead(INI_PATH, 'Database', 'Pswd'    , 'IniRead Fail');

  try
    MainDatabase.Close;
    MainDatabase.ConnectionString :='';
    if (UpperCase(DbKind) = 'ORACLE') then
    begin
      MainDatabase.ConnectionString := 'Provider=' + DbOLE +
                                       ';Data Source=' + DbAlais +
                                       ';Persist Security Info=True' +
                                       ';User ID =' + DbUser +
                                       ';Password=' + DbPasswd ;
    end
    else if (UpperCase(DbKind) = 'MSSQL') then
    begin
      MainDatabase.ConnectionString := 'Provider=' + DbOLE +
                                       ';Initial Catalog=' + DbAlais +
                                       ';Data Source=' + DbSource +
                                       ';Persist Security Info=True' +
                                       ';User ID =' + DbUser +
                                       ';Password=' + DbPasswd ;
    end;

    MainDatabase.Connected := True;
    Result := True ;
    DBConChk := True ;
    LogWriteStr(1, 'Database Connection Success !');
  except
    Result := False ;
    DBConChk := False ;
    LogWriteStr(1, 'Database Connection Fail..');
  end;
end;

//==============================================================================
// FormCreate
//==============================================================================
procedure TfrmControl.FormCreate(Sender: TObject);
var
  i : integer ;
  Cap  : String;
begin
  Cap := IniRead(INI_PATH, 'Program', 'ProgramName',  'IniRead Failed');
  if FindWindow(nil, pChar(Cap)) <> 0 then
  begin
    Close;
    ExitProcess( 0 );
  end;
  (Sender as TForm).Caption := Cap;

  for i := START_PLCNO to END_PLCNO do
  begin
    COMM_FLAG[i] := CVR_D_W1 ; // Word 영역 부터 Read

    TCheckBox(Self.FindComponent('cbUsed'+IntToStr(i))).Checked :=
      Boolean(UpperCase(IniRead(INI_PATH, 'Comm', 'Used'+IntToStr(i), 'False'))='TRUE') ;
  end;

  LogSave := ckLog1.Checked ;
  FormClose := False;
  RunMode := True ;
  CloseChk:= False ;

  staInfo.Panels[0].Text := FormatDatetime('YYYY/MM/DD HH:MM:SS', now())+'  ';
end;

//==============================================================================
// FormShow
//==============================================================================
procedure TfrmControl.FormShow(Sender: TObject);
var
  i : integer ;
begin
  if DBConnection then
  begin
    fnSet_Current('MELSEC', 'OPTION1', '1');
    for i := START_PLCNO to END_PLCNO do
    begin
      if TCheckBox(Self.FindComponent('cbUsed'+IntToStr(i))).Checked then
         bbCommClick(TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))));
    end;
  end;
  if DBConChk then ShpCon.Brush.Color := clLime
  else ShpCon.Brush.Color := clRed ;
end;

//==============================================================================
// 통신 시작, 통신 중지 버튼 Click Event
//==============================================================================
procedure TfrmControl.bbCommClick(Sender: TObject);
var
  i, Result : integer;
begin
  i := ( Sender as TBitBtn ).Tag ;

  //++++++++++++++++
  // 통신 시작
  //++++++++++++++++
  if TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))).Caption = '통신시작' then
  begin
    if not TCheckBox(Self.FindComponent('cbUsed'+IntToStr(i))).Checked then Exit;

    if RunMode then
    begin
     Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(i))).Open ;
    // Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(i))).Open ;
    // Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(i))).Open;
      if Result <> 0 then
      begin
        TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))).Caption := '통신시작' ;
        TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(i))).Close ;
     //   TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(i))).Close;
     //   TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(i))).Close;
      end ;
    end else
    begin
      Result := 0 ;
    end;

    if Result = 0 then
    begin
      COMM_ON[i] := True ;
      LogWriteStr(i, 'PLC' + IntToStr(i) + ' Device Channel Open Success. ');
      TPanel(Self.FindComponent('plConn' + IntToStr(i))).Color := clLime ;
      TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))).Caption := '통신중지' ;
      if not (TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled) then
         TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled := True;
      if not tmrConnectCheck.Enabled then tmrConnectCheck.Enabled := True;
    end else
    begin
      LogWriteStr(i, 'PLC' + IntToStr(i) + ' Device Channel Open Fail. ErrorCode :[' +
                     IntToStr(Result) + '(' + IntToHex(Result, 8) + ')]' );
    end;

    BBExit.Enabled := Not ( COMM_ON[i] ) ;
  end else


  //++++++++++++++++
  // 통신 중지
  //++++++++++++++++
  begin
    if RunMode then
    begin
   //  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(i))).Close ;
    Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(i))).Close ;
   //   TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(i))).Close;
      if Result <> 0 then
      begin
        TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))).Caption  := '통신중지';
      end else
      begin
        TPanel(Self.FindComponent('plConn' + IntToStr(i))).Color := clRed ;
      end;
    end else
    begin
      Result := 0 ;
    end;

    if Result = 0 then
    begin
      COMM_ON[i] := False ;
      LogWriteStr(i, 'PLC' + IntToStr(i) + ' Device Channel Close Success. ');
      SetOffCommPNL(i, 0);
      TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))).Caption := '통신시작' ;
      TPanel(Self.FindComponent('plTimeOut' +IntToStr(i))).Color := clYellow ;
      TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled := False;
      TTimer(Self.FindComponent('tmTimeOut' +IntToStr(i))).Enabled := False;
      if tmrConnectCheck.Enabled then tmrConnectCheck.Enabled := False;
    end else
    begin
      LogWriteStr(i, 'PLC' + IntToStr(i) + ' Device Channel Open Fail. ErrorCode :[' +
                  IntToStr(Result) + '(' + IntToHex(Result, 8) + ')]' );
    end;
    BBExit.Enabled := Not ( COMM_ON[i] ) ;
  end;
end;

//==============================================================================
// ReConnect
//==============================================================================
procedure TfrmControl.ReConnect(PLC_NO:Integer);
var
  Result : integer;
begin
  if not TCheckBox(Self.FindComponent('cbUsed'+IntToStr(PLC_NO))).Checked then Exit;

  if RunMode then
  begin
  //  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).Open ;
    Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).Open;
    if Result <> 0 then
    begin
      TBitBtn(Self.FindComponent('bbComm'+IntToStr(PLC_NO))).Caption  := '통신시작';
    //  TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).Close;
    //  TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).Close;
      TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).Close ;
      COMM_ON[PLC_NO] := False ;
    end;
  end else
  begin
    Result := 0 ;
  end;

  if (Result = 0) and (RunMode) then
  begin
    COMM_ON[PLC_NO] := True ;
    LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Device Channel Open Success. ');
    TPanel(Self.FindComponent('plConn' + IntToStr(PLC_NO))).Color := clLime ;
    TBitBtn(Self.FindComponent('bbComm'+IntToStr(PLC_NO))).Caption := '통신중지' ;
    if not (TTimer(Self.FindComponent('tmSendRecv'+IntToStr(PLC_NO))).Enabled) then
       TTimer(Self.FindComponent('tmSendRecv'+IntToStr(PLC_NO))).Enabled := True;
  end else
  begin
    LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Device Channel Open Fail. ');
  end;
  BBExit.Enabled := Not ( COMM_ON[PLC_NO] ) ;
end;


//==============================================================================
// PLC -> PC Data Read
//==============================================================================
procedure TfrmControl.PLC_READ_PROCESS(PLC_NO:integer);
begin
  case COMM_FLAG[PLC_NO] of
    CVR_D_W1 : PLC_READ_WORD1(PLC_NO) ; //  Read D Word(Word)
    CVR_D_W2 : PLC_READ_WORD2(PLC_NO) ; //  Read D Word(Bit)
    CVR_D_W3 : PLC_READ_WORD4(PLC_NO) ; //  Read D Word(RFID data area);
  end;
end;

//==============================================================================
// PC -> PLC Data Send
//==============================================================================
procedure TfrmControl.PLC_WRITE_PROCESS(PLC_NO:integer);
begin
  case COMM_FLAG[PLC_NO] of
    CVW_D_W1 : PLC_WRITE_WORD1(PLC_NO) ; // Write D Word
    CVW_D_W2 : PLC_WRITE_WORD2(PLC_NO) ; // Write D Word
  end;
end;

//==============================================================================
// tmSendRecv1Timer
//==============================================================================
procedure TfrmControl.tmSendRecvTimer(Sender: TObject);
var
  i, PLC_NO : integer ;
begin
  PLC_NO := ( Sender as TTimer ).Tag ;

  if DBConChk then ShpCon.Brush.Color := clLime
  else ShpCon.Brush.Color := clRed ;

//  Exit;

  TTimer(Self.FindComponent('tmSendRecv'+IntToStr(PLC_NO))).Enabled := False;
  TTimer(Self.FindComponent('tmTimeOut' +IntToStr(PLC_NO))).Enabled := True ;
  TPanel(Self.FindComponent('plTimeOut' +IntToStr(PLC_NO))).Color := clLime ;

  try
    i := Get_COMM_FLAGNo(PLC_NO) ;

    SetOnCommPNL(PLC_NO, i) ; // LED ON

    case COMM_FLAG[PLC_NO] of
      CVR_D_W1, CVR_D_W2, CVR_D_W3 :
      begin // Read D Word(Bit) , Read D Word(Word)
        LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'READ PROCESS Start');
        PLC_READ_PROCESS(PLC_NO) ;
      end;

      CVW_D_W1, CVW_D_W2 :
      begin // Write D Word
        LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'WRITE PROCESS Start');
        PLC_WRITE_PROCESS(PLC_NO);
      end;
    end;

    SetOffCommPNL(PLC_NO, i) ; // LED Off
    LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC Communication End');
    Set_COMM_FLAG(PLC_NO) ;
  finally
    TTimer(Self.FindComponent('tmTimeOut' +IntToStr(PLC_NO))).Enabled := False ;
    TTimer(Self.FindComponent('tmSendRecv'+IntToStr(PLC_NO))).Enabled := True;
    staInfo.Panels[0].Text := FormatDatetime('YYYY/MM/DD HH:MM:SS', now())+'  ';
  end;
end;

//==============================================================================
// tmrConnectCheckTimer
//==============================================================================
procedure TfrmControl.tmrConnectCheckTimer(Sender: TObject);
var
  i : integer;
begin
  try
    (Sender as TTimer).Enabled := False ;

    if not fnDBConChk then
    begin
      for i := START_PLCNO to END_PLCNO do
      begin
        if TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled then
           TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled := False ;
      end;

      if DBConnection then
      begin
        for i := START_PLCNO to END_PLCNO do
        begin
          if not TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled then
             TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled := True ;
        end;
      end;
    end else
    begin
      for i := START_PLCNO to END_PLCNO do
      begin
        if not TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled then
           TTimer(Self.FindComponent('tmSendRecv'+IntToStr(i))).Enabled := True ;
      end;
    end;
  finally
    (Sender as TTimer).Enabled := True ;
  end;
end;

//==============================================================================
// fnDBConChk
//==============================================================================
function TfrmControl.fnDBConChk: Boolean;
var
  StrSQL : string;
begin
  Result := False ;
  StrSQL := ' SELECT GETDATE() ' ;

  try
    with qryDBChk do
    begin
      Close;
      SQL.Clear ;
      SQL.Text := StrSQL ;
      Open ;
      if not (Bof and Eof) then
      begin
        Result := True ;
        DBConChk := True ;
      end;
    end;
  except
    DBConChk := False ;
    if qryDBChk.Active then qryDBChk.Close;
  end;
end;

//==============================================================================
// SetOffCommPNL : 해당 되는 PNL 을 Off ( clYellow ) 시킨다.
//==============================================================================
procedure TfrmControl.SetOffCommPNL(PLC_NO, iMode:integer);
var
  i : Integer ;
begin
  if iMode = 0 then
  begin
    for i := 1 to 3 do
       TShape(Self.FindComponent('spLED' + intToStr(PLC_NO) + IntToStr(i))).Brush.Color := clBtnface ;
  end else
  begin
    if iMode in [1..3] then
       TShape(Self.FindComponent('spLED' + intToStr(PLC_NO) + IntToStr(iMode))).Brush.Color := clYellow ;
    Application.ProcessMessages ;
  end;
end;

//==============================================================================
// SetOnCommPNL : 해당 되는 PNL 을 On ( clLime ) 시킨다.
//==============================================================================
procedure TfrmControl.SetOnCommPNL(PLC_NO, iMode:integer);
var
  i : Integer ;
begin
  if iMode = 0 then
  begin
    for i := 1 to 3 do
       TShape(Self.FindComponent('spLED' + intToStr(PLC_NO) + IntToStr(i))).Brush.Color := clLime ;
  end else
  begin
    if iMode in [1..3] then
       TShape(Self.FindComponent('spLED' + intToStr(PLC_NO) + IntToStr(iMode))).Brush.Color := clLime ;
    Application.ProcessMessages ;
  end;
end;

//==============================================================================
// 통신 사용유무
//==============================================================================
procedure TfrmControl.cbUsed1Click(Sender: TObject);
var
  Idx : String ;
begin
  Idx := IntToStr((Sender as TCheckBox).Tag) ;

  if (Sender as TCheckBox).Checked then
       IniWrite( INI_PATH , 'Comm'  , 'Used'+Idx , 'TRUE')
  else IniWrite( INI_PATH , 'Comm'  , 'Used'+Idx , 'FALSE') ;
end;

//==============================================================================
// 로그 저장 변경
//==============================================================================
procedure TfrmControl.ckLogClick(Sender: TObject);
var
  i : integer ;
begin
  i := (Sender as TCheckBox).Tag ;
  LogSave := TCheckBox(Self.FindComponent('ckLog'+IntToStr(i))).Checked;
end;

//==============================================================================
// 로그 저장 Procedure
//==============================================================================
procedure TfrmControl.LogWriteStr(PLC_NO:integer ;  WriteStr : String );
var
  StrLogDt, filename : string;
  i : integer;
begin
  if memLog.Lines.Count > 50 then
  begin
    for i := 1 to 2 do
    begin
      memLog.Lines.Delete(i);
    end;
  end;
  StrLogDt := '[' + FormatDateTime('HH:NN:SS', Now) + '] ';
  memLog.lines.add(StrLogDt + WriteStr);

  if LogSave then
  begin
    filename := '.\Log\PLC' + IntToStr(PLC_NO) + '_' + FormatDatetime('YYYYMMDD', now) + '.log';
    LogWrite(filename, StrLogDt + WriteStr);
  end;
end;

//==============================================================================
// 데이터 Send후 응답시간 초과에 대한 Event
//==============================================================================
procedure TfrmControl.tmTimeOutTimer(Sender: TObject);
var
  i : integer ;
begin
  i := ( Sender as TTimer ).Tag ;
  TTimer(Self.FindComponent('tmTimeOut'+IntToStr(i))).Enabled := False;
  TPanel(Self.FindComponent('plTimeOut'+IntToStr(i))).Color := clYellow ;

  case COMM_FLAG[i] of
    CVR_D_W1  : COMM_FLAG[i] := CVR_D_W2;
    CVR_D_W2  : COMM_FLAG[i] := CVR_D_W3;
    CVR_D_W3  : COMM_FLAG[i] := CVW_D_W1;
    CVW_D_W1  : COMM_FLAG[i] := CVW_D_W2;
    CVW_D_W2  : COMM_FLAG[i] := CVR_D_W1;
  end;
  LogWriteStr(i, 'Time Over ReStart Communication');
end;

//==============================================================================
// Set_COMM_FLAG
//==============================================================================
procedure TfrmControl.Set_COMM_FLAG(PLC_NO:integer);
begin
  case COMM_FLAG[PLC_NO] of
    CVR_D_W1  : COMM_FLAG[PLC_NO] := CVR_D_W2;
    CVR_D_W2  : COMM_FLAG[PLC_NO] := CVR_D_W3;
    CVR_D_W3  : COMM_FLAG[PLC_NO] := CVW_D_W1;
    CVW_D_W1  : COMM_FLAG[PLC_NO] := CVW_D_W2;
    CVW_D_W2  : COMM_FLAG[PLC_NO] := CVR_D_W1;
  end;
end;

//==============================================================================
// MainDatabaseAfterConnect
//==============================================================================
procedure TfrmControl.MainDatabaseAfterConnect(Sender: TObject);
begin
  DBConChk := True;
end;

//==============================================================================
// MainDatabaseAfterDisconnect
//==============================================================================
procedure TfrmControl.MainDatabaseAfterDisconnect(Sender: TObject);
begin
  DBConChk := False ;
end;

//==============================================================================
// FormCloseQuery
//==============================================================================
procedure TfrmControl.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not CloseChk then
  begin
    CloseChkMsg(nil);
    CanClose := False;
  end;
end;

//==============================================================================
// CloseChkMsg
//==============================================================================
procedure TfrmControl.CloseChkMsg(Sender: TObject);
begin
  if MessageDlg(frmControl.Caption+'을 종료하시겠습니까?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    CloseChk := True ;
    if MainDatabase.Connected then
    begin
      MainDataBase.Close ;
      fnSet_Current('MELSEC', 'OPTION1', '0');
    end;

    ExitProcess(0);
  end;
end;

//==============================================================================
// bbExitClick
//==============================================================================
procedure TfrmControl.bbExitClick(Sender: TObject);
begin
  Close ;
end;

//==============================================================================
// Get_COMM_FLAG -> 해당 작업 종류를 Get
//==============================================================================
function TfrmControl.Get_COMM_FLAG(PLC_NO:Integer):String;
var
  strResult : String ;
begin
  strResult := '' ;
  case COMM_FLAG[PLC_NO] of
    CVR_D_W1 : strResult := '[RECV] PLC Word(Word) Area ' ;  // 상태정보 읽기(Word)
    CVR_D_W2 : strResult := '[RECV] PLC Word(Bit)  Area ' ;  // 상태정보 읽기(Bit)
    CVR_D_W3 : strResult := '[RECV] PLC_Word(Word) RFID Area ' ;
    CVW_D_W1 : strResult := '[SEND] PLC Word(Word) Area ' ;  // SC작업지시
    CVW_D_W2 : strResult := '[SEND] PLC Word(Word) Area ' ;  // 커튼 on/off
  end;
  Result := strResult ;
end;

//==============================================================================
// Get_COMM_FLAGNo -> 해당 작업의 Idx를 Get
//==============================================================================
function TfrmControl.Get_COMM_FLAGNo(PLC_NO:Integer): integer;
var
  iResult : Integer ;
begin
  iResult := 0 ;
  case COMM_FLAG[PLC_NO] of
    CVR_D_W1 : iResult := 1 ;  // 상태정보 읽기(Word)
    CVR_D_W2 : iResult := 2 ;  // 상태정보 읽기(Bit)
    CVR_D_W3 : iResult := 3 ;
    CVW_D_W1 : iResult := 4 ;  // SC작업지시
    CVW_D_W2 : iResult := 5 ;  // 커튼 On/Off
  end;
  Result := iResult ;
end;

//==============================================================================
// HexaReverse : PLC Data 를 역변환 한다.
//==============================================================================
function TfrmControl.HexaReverse(PLC_NO:integer; StrBuf:String): String;
Var
  tStr, Str_Low : string;
begin
  // 데이터 변환
  if COMM_FLAG[PLC_NO] in [CVR_D_W1, CVR_D_W3] then // Read  D Word "Word" Type Data
  begin
    tStr   := Copy(StrBuf, 1, 4);
    Result := tStr ;
  end else
  if COMM_FLAG[PLC_NO] = CVR_D_W2 then // Read  D Word "Bit"  Type Data
  begin
    Str_Low := HexStrToBinStr(copy(StrBuf, 1, 4)); // 41 42 => 0100 0001 0100 0010
    tStr    := ReverseString(Str_Low) ;            // 0100 0001 0100 0010 => 0100 0010 1000 0010
    Result  := tStr ;
  end;
end;

//==============================================================================
// PLC_READ_WORD1 -> Word Data
//==============================================================================
procedure TfrmControl.PLC_READ_WORD1(PLC_NO: Integer);
var
  Result, Net_Size, i, j: integer ;
  strSQL_U, strSQL_I, strSQL, tempSQL, tempSQL2, tempSQL3 : String ;
  Net_Addr : WideString ;
  Buffer : Array [0..11] of integer ;
  WordData : Array [0..11] of String;
begin
  FillChar(Buffer, sizeof(Buffer), 0 );

  //++++++++++++++++++++++++++++++
  // CH01 ~ CH03 : SC D(Word)영역
  //++++++++++++++++++++++++++++++
  Net_Addr := 'D0200' ;
  Net_Size := 12 ;

  //++++++++++++
  // Data Read
  //++++++++++++
//  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;
//  Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0]);
  Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;


  if Result = 0 then
  begin
    LogWriteStr(PLC_NO, '[PLC' + IntToStr(PLC_NO) + ']: '+ Get_COMM_FLAG(PLC_NO) + ' Memory Read Success');

    for i := Low(WordData) to High(WordData) do
    begin
      //0000
      if (i in [10, 11, 44, 45]) then
        WordData[i] := '0000' // 초기화
      else
        WordData[i] := HexaReverse(PLC_NO, IntToHex(Buffer[i], 4 )) ;
    end;

//    tmp := Chr(StrToInt('$'+Copy(WordData[12], 1, 2)));
//    tmp := tmp + Chr(StrToInt('$'+Copy(WordData[12], 3, 2)));

    LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Read1 Data [' + intToStr(Net_Size) + ']');

    try
      strSQL   := ' Select * from TT_SCC ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ' ;

      tempSQL  := '';
      tempSQL2 := '';
      tempSQL3 := '';

      i := 0 ;
      j := 1 ;
      while j <= 3 do
      begin
        tempSQL  := tempSQL  + 'CH' + FormatFloat('00', j) + ' = ''' + WordData[i+0]+ WordData[i+1]+ WordData[i+2]+ WordData[i+3] + ''', '; // Update Bit Data
        tempSQL2 := tempSQL2 + 'CH' + FormatFloat('00', j) + ', ';                                                                          // Insert Field Name
        tempSQL3 := tempSQL3 + '''' + WordData[i+0]+ WordData[i+1]+ WordData[i+2]+ WordData[i+3]  + ''', ';                                 // Insert Value

        inc(i, 4);
        Inc(j) ;
      end;

      strSQL_U := ' Update TT_SCC ' +
                  '    Set ' + tempSQL + ' SCC_DT = GETDATE() ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ';

      strSQL_I := ' Insert Into TT_SCC ( SCC_NO, ' +  tempSQL2 + ' SCC_DT, SCC_SR )' +
                  '   VALUES ( ''' + IntToStr(PLC_NO) + ''', ' + tempSQL3 + ' GETDATE(), ''R'' ) ' ;

      with TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))) do
      begin
        Close ;
        SQL.Text := strSQL ;
        Open;
        if RecordCount > 0 then
             strSQL := strSQL_U
        else strSQL := strSQL_I;
        Close;
      end;

      with TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))) do
      begin
        Close;
        SQL.Text := strSQL;
        ExecSQL ;
      end;
    except
      if TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active := False;
      if TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active := False;
    end;
  end else
  begin
    LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Read Fail , ErrorCode [' + IntToStr(Result) + '] ');
    ReConnect(PLC_NO);
  end;
end;

//==============================================================================
// PLC_READ_Word2 -> Bit Data
//==============================================================================
procedure TfrmControl.PLC_READ_Word2(PLC_NO:Integer);
var
  Result, Net_Size, i, j: integer ;
  strSQL_U, strSQL_I, strSQL, tempSQL, tempSQL2, tempSQL3 : String ;
  Net_Addr : WideString ;
  Buffer : Array [0..3] of integer ;
  WordData : Array [0..3] of String;
begin
  FillChar(Buffer, sizeof(Buffer), 0 );

  //++++++++++++++++++++++++++++++
  // CH04 ~ CH05 : SC D(Bit)영역
  //++++++++++++++++++++++++++++++
  Net_Addr := 'D0210' ;
  Net_Size := 4 ;

  //++++++++++++
  // Data Read
  //++++++++++++
//  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;
//  Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0]);
  Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;

  if Result = 0 then
  begin
    LogWriteStr(PLC_NO, '[PLC' + IntToStr(PLC_NO) + ']: '+ Get_COMM_FLAG(PLC_NO) + ' Memory Read Success');

    for i := Low(WordData) to High(WordData) do
    begin
      //0000000000000000
      WordData[i] := HexaReverse(PLC_NO, IntToHex(Buffer[i], 4 )) ;
    end;

    LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Read2 Data [' + intToStr(Net_Size) + ']');

    try
      strSQL   := ' Select * from TT_SCC ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ' ;

      tempSQL  := '';
      tempSQL2 := '';
      tempSQL3 := '';

      i := 0 ; j := 4 ;
      while j <= 7 do
      begin
        tempSQL  := tempSQL  + 'CH' + FormatFloat('00', j) + ' = ''' + WordData[i] + ''', '; // Update Bit Data
        tempSQL2 := tempSQL2 + 'CH' + FormatFloat('00', j) + ', ';                           // Insert Field Name
        tempSQL3 := tempSQL3 + '''' + WordData[i] + ''', ';                                  // Insert Value Bit Data

        Inc(i, 1);
        Inc(j);
      end;

      strSQL_U := ' Update TT_SCC ' +
                  '    Set ' + tempSQL + ' SCC_DT = GETDATE() ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ';

      strSQL_I := ' Insert Into TT_SCC ( SCC_NO, ' +  tempSQL2 + ' SCC_DT, SCC_SR )' +
                  '   VALUES ( ''' + IntToStr(PLC_NO) + ''', ' + tempSQL3 + ' GETDATE(), ''R'' ) ' ;

      with TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))) do
      begin
        Close ;
        SQL.Clear;
        SQL.Text := strSQL ;
        Open;
        if RecordCount > 0 then
             strSQL := strSQL_U
        else strSQL := strSQL_I;
        Close;
      end;

      with TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))) do
      begin
        Close;
        SQL.Clear;
        SQL.Text := strSQL;
        ExecSQL ;
      end;
    except
      if TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active := False;
      if TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active := False;
    end;
  end else
  begin
    LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Read Fail , ErrorCode [' + IntToStr(Result) + '] ');
    ReConnect(PLC_NO);
  end;
end;

//==============================================================================
// PLC_READ_Word3 -> Word RFID Data
//==============================================================================
procedure TfrmControl.PLC_READ_WORD3(PLC_NO: Integer);
var
  Result, Net_Size, i, j: integer ;
  strSQL_U, strSQL_I, strSQL, tempSQL, tempSQL2, tempSQL3 : String ;
  Net_Addr : WideString ;
  Buffer : Array [0..191] of integer ;
  WordData : Array [0..191] of String;
begin
  FillChar(Buffer, sizeof(Buffer), 0 );

  //++++++++++++++++++++++++++++++
  // CH04 ~ CH05 : SC D(Bit)영역
  //++++++++++++++++++++++++++++++
  Net_Addr := 'D1200' ;
  Net_Size := 192 ;

  //++++++++++++
  // Data Read
  //++++++++++++
//  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;
//  Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0]);
  Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;

  if Result = 0 then
  begin
    LogWriteStr(PLC_NO, '[PLC' + IntToStr(PLC_NO) + ']: '+ Get_COMM_FLAG(PLC_NO) + ' Memory Read Success');

    for i := Low(WordData) to High(WordData) do
    begin
      //0000
      WordData[i] := HexaReverse(PLC_NO, IntToHex(Buffer[i], 4 )) ;
    end;

    LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Read3 Data [' + intToStr(Net_Size) + ']');

    try
      strSQL   := ' Select * from TT_SCC ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ' ;

      tempSQL  := '';
      tempSQL2 := '';
      tempSQL3 := '';

      i := 0 ; j := 8 ;
      while j <= 55 do
      begin
        // Update SQL
        tempSQL  := tempSQL  + 'CH' + FormatFloat('00', j) + ' = ''' + WordData[i+0] + WordData[i+1] + WordData[i+2] + WordData[i+3] + ''', ';
        // Insert SQL Field Name
        tempSQL2 := tempSQL2 + 'CH' + FormatFloat('00', j) + ', ';
        // Insert Value
        tempSQL3 := tempSQL3 + '''' + WordData[i+0] + WordData[i+1] + WordData[i+2] + WordData[i+3]  + ''', ';
        inc(i, 4);
        Inc(j) ;
      end;

      strSQL_U := ' Update TT_SCC ' +
                  '    Set ' + tempSQL + ' SCC_DT = GETDATE() ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ';

      strSQL_I := ' Insert Into TT_SCC ( SCC_NO, ' +  tempSQL2 + ' SCC_DT, SCC_SR )' +
                  '   VALUES ( ''' + IntToStr(PLC_NO) + ''', ' + tempSQL3 + ' GETDATE(), ''R'' ) ' ;

      with TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))) do
      begin
        Close ;
        SQL.Clear;
        SQL.Text := strSQL ;
        Open;
        if RecordCount > 0 then
             strSQL := strSQL_U
        else strSQL := strSQL_I;

        Close;
      end;

      with TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))) do
      begin
        Close;
        SQL.Clear;
        SQL.Text := strSQL;
        ExecSQL ;
      end;

      with TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO)) ) do
      begin
        Close;
        SQL.Clear;
        j := 0;
        for i := 1 to 6 do
        begin
          StrSQL := ' UPDATE TC_RFID ' +
                      '  SET H01 = ' + QuotedStr(AsciiToString(WordData[j + 0])) +     // H00
                      '    , H02 = ' + QuotedStr(AsciiToString(WordData[j + 1])) +     // H01
                      '    , H03 = ' + QuotedStr(AsciiToString(WordData[j + 2])) +     // H02
                      '    , H04 = ' + QuotedStr(AsciiToString(WordData[j + 3])) +     // H03
                      '    , H05 = ' + QuotedStr(AsciiToString(WordData[j + 4])) +     // H04
                      '    , H06 = ' + QuotedStr(AsciiToString(WordData[j + 5])) +     // H05
                      '    , H07 = ' + QuotedStr(AsciiToString(WordData[j + 6])) +     // H06
                      '    , H08 = ' + QuotedStr(AsciiToString(WordData[j + 7])) +     // H07
                      '    , H09 = ' + QuotedStr(AsciiToString(WordData[j + 8])) +     // H08
                      '    , H10 = ' + QuotedStr(AsciiToString(WordData[j + 9])) +     // H09
                      '    , H11 = ' + QuotedStr(AsciiToString(WordData[j + 10])) +    // H10
                      '    , H12 = ' + QuotedStr(AsciiToString(WordData[j + 11])) +    // H11
                      '    , H13 = ' + QuotedStr(AsciiToString(WordData[j + 12])) +    // H12
                      '    , H14 = ' + QuotedStr(AsciiToString(WordData[j + 13])) +    // H13
                      '    , H15 = ' + QuotedStr(AsciiToString(WordData[j + 14])) +    // H14
                      '    , H16 = ' + QuotedStr(AsciiToString(WordData[j + 15])) +    // H15
                      '    , H17 = ' + QuotedStr(AsciiToString(WordData[j + 16])) +    // H16
                      '    , H18 = ' + QuotedStr(AsciiToString(WordData[j + 17])) +    // H17
                      '    , H19 = ' + QuotedStr(IntToStr(StrToInt('$' + (WordData[j + 18][3] + WordData[j + 18][4] + WordData[j + 18][1] + WordData[j + 18][2])))) +    // H18
                      '    , H20 = ' + QuotedStr(AsciiToString(WordData[j + 19])) +    // H19
                      '    , H21 = ' + QuotedStr(HexStrToBinStr(WordData[j + 20][3] + WordData[j + 20][4] + WordData[j + 20][1] + WordData[j + 20][2])) +    // H20
                      '    , H22 = ' + QuotedStr(HexStrToBinStr(WordData[j + 21][3] + WordData[j + 21][4] + WordData[j + 21][1] + WordData[j + 21][2])) +    // H21
                      '    , H23 = ' + QuotedStr(HexStrToBinStr(WordData[j + 22][3] + WordData[j + 22][4] + WordData[j + 22][1] + WordData[j + 22][2])) +    // H22
                      '    , H24 = ' + QuotedStr(HexStrToBinStr(WordData[j + 23][3] + WordData[j + 23][4] + WordData[j + 23][1] + WordData[j + 23][2])) +
                      '    , H25 = ' + QuotedStr(AsciiToString(WordData[j + 24])) +
                      '    , H26 = ' + QuotedStr(AsciiToString(WordData[j + 25])) +
                      '    , H27 = ' + QuotedStr(AsciiToString(WordData[j + 26])) +
                      '    , H28 = ' + QuotedStr(AsciiToString(WordData[j + 27])) +
                      '    , H29 = ' + QuotedStr(AsciiToString(WordData[j + 28])) +
                      '    , H30 = ' + QuotedStr(AsciiToString(WordData[j + 29])) +
                      '    , H31 = ' + QuotedStr(AsciiToString(WordData[j + 30])) +
                      '    , H32 = ' + QuotedStr(AsciiToString(WordData[j + 31])) +
                      '    , UPD_DT = GETDATE() ' +
                     ' WHERE PORT_NO = ' + QuotedStr(IntToStr(i));
          SQL.Text := StrSQL;
          ExecSQL;
          inc(j, 32);
        end;
      end;

    except
      if TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active := False;
      if TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active := False;
    end;
  end else
  begin
    LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Read Fail , ErrorCode [' + IntToStr(Result) + '] ');
    ReConnect(PLC_NO);
  end;
end;

//==============================================================================
// PLC_READ_Word3 -> Word RFID Data
//==============================================================================
procedure TfrmControl.PLC_READ_WORD4(PLC_NO: Integer);
var
  Result, Net_Size, i, j, k: integer ;
  strSQL_U, strSQL_I, strSQL, tempSQL, tempSQL2, tempSQL3 : String ;
  Net_Addr : WideString ;
  Buffer : Array [1..6, 0..99] of integer ;
  WordData : Array [1..6, 0..99] of String;
begin
  FillChar(Buffer, sizeof(Buffer), 0 );

  //++++++++++++++++++++++++++++++
  //
  //++++++++++++++++++++++++++++++
  for i := 1 to 6 do
  begin
    case i of
      1 : Net_Addr := 'D1100';
      2 : Net_Addr := 'D1200';
      3 : Net_Addr := 'D1300';
      4 : Net_Addr := 'D1400';
      5 : Net_Addr := 'D1500';
      6 : Net_Addr := 'D1600';
    end;
    Net_Size := 100;
    //++++++++++++
    // Data Read
    //++++++++++++
    //  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;
    //  Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0]);
    Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[i][0] ) ;

    if Result = 0 then
    begin
      LogWriteStr(PLC_NO, '[PLC' + IntToStr(PLC_NO) + ']: '+ Get_COMM_FLAG(PLC_NO) + ' Memory Read Success');

      for j := Low(WordData[i]) to High(WordData[i]) do
      begin
        WordData[i][j] := HexaReverse(PLC_NO, IntToHex(Buffer[i][j], 4));
      end;

      LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Read3 Data [' + intToStr(Net_Size) + ']');

      try
        strSQL   := ' Select * from TT_SCC_RFID ' +
                    '  Where PORT_NO = ''' + IntToStr(i) + ''' ';

        tempSQL  := '';
        tempSQL2 := '';
        tempSQL3 := '';

        j := 0 ; k := 1 ;
        while k <= 25 do
        begin
          // Update SQL
          tempSQL  := tempSQL  + 'CH' + FormatFloat('00', k) + ' = ''' + WordData[i][j] + ''', ';
          // Insert SQL Field Name
          tempSQL2 := tempSQL2 + 'CH' + FormatFloat('00', k) + ', ';
          // Insert Value
          tempSQL3 := tempSQL3 + '''' + WordData[i][j] + ''', ';
          inc(j, 4);
          Inc(k) ;
        end;

        strSQL_U := ' Update TT_SCC_RFID ' +
                    '    Set ' + tempSQL + ' UP_DT = GETDATE() ' +
                    '  Where PORT_NO = ''' + IntToStr(i) + ''' ' ;

        strSQL_I := ' Insert Into TT_SCC_RFID ( PORT_NO, ' +  tempSQL2 + ' UP_DT )' +
                    '   VALUES ( ''' + IntToStr(i) + ''', ' + tempSQL3 + ' GETDATE() ) ' ;

        with TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))) do
        begin
          Close ;
          SQL.Clear;
          SQL.Text := strSQL ;
          Open;
          if RecordCount > 0 then
               strSQL := strSQL_U
          else strSQL := strSQL_I;

          Close;
        end;

        with TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))) do
        begin
          Close;
          SQL.Clear;
          SQL.Text := strSQL;
          ExecSQL ;
        end;

        with TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO)) ) do
        begin
          Close;
          SQL.Clear;
          StrSQL := ' UPDATE TC_RFID ' +
                      '  SET H00 = ' + QuotedStr(AsciiToString(WordData[i][0])) +     // H00
                      '    , H01 = ' + QuotedStr(AsciiToString(WordData[i][1])) +     // H01
                      '    , H02 = ' + QuotedStr(AsciiToString(WordData[i][2])) +     // H02
                      '    , H03 = ' + QuotedStr(AsciiToString(WordData[i][3])) +     // H03
                      '    , H04 = ' + QuotedStr(AsciiToString(WordData[i][4])) +     // H04
                      '    , H05 = ' + QuotedStr(AsciiToString(WordData[i][5])) +     // H05
                      '    , H06 = ' + QuotedStr(AsciiToString(WordData[i][6])) +     // H06
                      '    , H07 = ' + QuotedStr(AsciiToString(WordData[i][7])) +     // H07
                      '    , H08 = ' + QuotedStr(AsciiToString(WordData[i][8])) +     // H08
                      '    , H09 = ' + QuotedStr(AsciiToString(WordData[i][9])) +     // H09
                      '    , H10 = ' + QuotedStr(AsciiToString(WordData[i][10])) +    // H10
                      '    , H11 = ' + QuotedStr(AsciiToString(WordData[i][11])) +    // H11
                      '    , H12 = ' + QuotedStr(AsciiToString(WordData[i][12])) +    // H12
                      '    , H13 = ' + QuotedStr(AsciiToString(WordData[i][13])) +    // H13
                      '    , H14 = ' + QuotedStr(AsciiToString(WordData[i][14])) +    // H14
                      '    , H15 = ' + QuotedStr(AsciiToString(WordData[i][15])) +    // H15
                      '    , H16 = ' + QuotedStr(AsciiToString(WordData[i][16])) +    // H16
                      '    , H17 = ' + QuotedStr(AsciiToString(WordData[i][17])) +    // H17
                      '    , H18 = ' + QuotedStr(IntToStr(StrToInt('$' + (WordData[i][18][3] + WordData[i][18][4] + WordData[i][18][1] + WordData[i][18][2])))) +    // H18
                      '    , H19 = ' + QuotedStr(AsciiToString(WordData[i][19])) +    // H19
                      '    , H20 = ' + QuotedStr(HexStrToBinStr(WordData[i][20][3] + WordData[i][20][4] + WordData[i][20][1] + WordData[i][20][2])) +    // H20
                      '    , H21 = ' + QuotedStr(HexStrToBinStr(WordData[i][21][3] + WordData[i][21][4] + WordData[i][21][1] + WordData[i][21][2])) +    // H21
                      '    , H22 = ' + QuotedStr(HexStrToBinStr(WordData[i][22][3] + WordData[i][22][4] + WordData[i][22][1] + WordData[i][22][2])) +    // H22
                      '    , H23 = ' + QuotedStr(IntToStr(StrToInt('$' + (WordData[i][23][3] + WordData[i][23][4] + WordData[i][23][1] + WordData[i][23][2])))) +
                      '    , H24 = ' + QuotedStr(AsciiToString(WordData[i][24])) +
                      '    , H25 = ' + QuotedStr(AsciiToString(WordData[i][25])) +
                      '    , H26 = ' + QuotedStr(AsciiToString(WordData[i][26])) +
                      '    , H27 = ' + QuotedStr(AsciiToString(WordData[i][27])) +
                      '    , H28 = ' + QuotedStr(AsciiToString(WordData[i][28])) +
                      '    , H29 = ' + QuotedStr(AsciiToString(WordData[i][29])) +
                      '    , H30 = ' + QuotedStr(AsciiToString(WordData[i][30])) +
                      '    , H31 = ' + QuotedStr(AsciiToString(WordData[i][31])) +
                      '    , H32 = ' + QuotedStr(AsciiToString(WordData[i][32])) +
                      '    , H33 = ' + QuotedStr(AsciiToString(WordData[i][33])) +
                      '    , H34 = ' + QuotedStr(AsciiToString(WordData[i][34])) +
                      '    , H35 = ' + QuotedStr(AsciiToString(WordData[i][35])) +
                      '    , H36 = ' + QuotedStr(AsciiToString(WordData[i][36])) +
                      '    , H37 = ' + QuotedStr(AsciiToString(WordData[i][37])) +
                      '    , H38 = ' + QuotedStr(AsciiToString(WordData[i][38])) +
                      '    , H39 = ' + QuotedStr(AsciiToString(WordData[i][39])) +
                      '    , H40 = ' + QuotedStr(AsciiToString(WordData[i][40])) +
                      '    , H41 = ' + QuotedStr(AsciiToString(WordData[i][41])) +
                      '    , H42 = ' + QuotedStr(AsciiToString(WordData[i][42])) +
                      '    , H43 = ' + QuotedStr(AsciiToString(WordData[i][43])) +
                      '    , H44 = ' + QuotedStr(AsciiToString(WordData[i][44])) +
                      '    , H45 = ' + QuotedStr(AsciiToString(WordData[i][45])) +
                      '    , H46 = ' + QuotedStr(AsciiToString(WordData[i][46])) +
                      '    , H47 = ' + QuotedStr(AsciiToString(WordData[i][47])) +
                      '    , H48 = ' + QuotedStr(AsciiToString(WordData[i][48])) +
                      '    , H49 = ' + QuotedStr(AsciiToString(WordData[i][49])) +
                      '    , H50 = ' + QuotedStr(AsciiToString(WordData[i][50])) +
                      '    , H51 = ' + QuotedStr(AsciiToString(WordData[i][51])) +
                      '    , H52 = ' + QuotedStr(AsciiToString(WordData[i][52])) +
                      '    , H53 = ' + QuotedStr(AsciiToString(WordData[i][53])) +
                      '    , H54 = ' + QuotedStr(AsciiToString(WordData[i][54])) +
                      '    , H55 = ' + QuotedStr(AsciiToString(WordData[i][55])) +
                      '    , H56 = ' + QuotedStr(AsciiToString(WordData[i][56])) +
                      '    , H57 = ' + QuotedStr(AsciiToString(WordData[i][57])) +
                      '    , H58 = ' + QuotedStr(AsciiToString(WordData[i][58])) +
                      '    , H59 = ' + QuotedStr(AsciiToString(WordData[i][59])) +
                      '    , H60 = ' + QuotedStr(AsciiToString(WordData[i][60])) +
                      '    , H61 = ' + QuotedStr(AsciiToString(WordData[i][61])) +
                      '    , H62 = ' + QuotedStr(AsciiToString(WordData[i][62])) +
                      '    , H63 = ' + QuotedStr(AsciiToString(WordData[i][63])) +
                      '    , H64 = ' + QuotedStr(AsciiToString(WordData[i][64])) +
                      '    , H65 = ' + QuotedStr(AsciiToString(WordData[i][65])) +
                      '    , H66 = ' + QuotedStr(AsciiToString(WordData[i][66])) +
                      '    , H67 = ' + QuotedStr(AsciiToString(WordData[i][67])) +
                      '    , H68 = ' + QuotedStr(AsciiToString(WordData[i][68])) +
                      '    , H69 = ' + QuotedStr(AsciiToString(WordData[i][69])) +
                      '    , H70 = ' + QuotedStr(AsciiToString(WordData[i][70])) +
                      '    , H71 = ' + QuotedStr(AsciiToString(WordData[i][71])) +
                      '    , H72 = ' + QuotedStr(AsciiToString(WordData[i][72])) +
                      '    , H73 = ' + QuotedStr(AsciiToString(WordData[i][73])) +
                      '    , H74 = ' + QuotedStr(AsciiToString(WordData[i][74])) +
                      '    , H75 = ' + QuotedStr(AsciiToString(WordData[i][75])) +
                      '    , H76 = ' + QuotedStr(AsciiToString(WordData[i][76])) +
                      '    , H77 = ' + QuotedStr(AsciiToString(WordData[i][77])) +
                      '    , H78 = ' + QuotedStr(AsciiToString(WordData[i][78])) +
                      '    , H79 = ' + QuotedStr(AsciiToString(WordData[i][79])) +
                      '    , H80 = ' + QuotedStr(AsciiToString(WordData[i][80])) +
                      '    , H81 = ' + QuotedStr(AsciiToString(WordData[i][81])) +
                      '    , H82 = ' + QuotedStr(AsciiToString(WordData[i][82])) +
                      '    , H83 = ' + QuotedStr(AsciiToString(WordData[i][83])) +
                      '    , H84 = ' + QuotedStr(AsciiToString(WordData[i][84])) +
                      '    , H85 = ' + QuotedStr(AsciiToString(WordData[i][85])) +
                      '    , H86 = ' + QuotedStr(AsciiToString(WordData[i][86])) +
                      '    , H87 = ' + QuotedStr(AsciiToString(WordData[i][87])) +
                      '    , H88 = ' + QuotedStr(AsciiToString(WordData[i][88])) +
                      '    , H89 = ' + QuotedStr(AsciiToString(WordData[i][89])) +
                      '    , H90 = ' + QuotedStr(AsciiToString(WordData[i][90])) +
                      '    , H91 = ' + QuotedStr(AsciiToString(WordData[i][91])) +
                      '    , H92 = ' + QuotedStr(AsciiToString(WordData[i][92])) +
                      '    , H93 = ' + QuotedStr(AsciiToString(WordData[i][93])) +
                      '    , H94 = ' + QuotedStr(AsciiToString(WordData[i][94])) +
                      '    , H95 = ' + QuotedStr(AsciiToString(WordData[i][95])) +
                      '    , H96 = ' + QuotedStr(AsciiToString(WordData[i][96])) +
                      '    , H97 = ' + QuotedStr(AsciiToString(WordData[i][97])) +
                      '    , H98 = ' + QuotedStr(AsciiToString(WordData[i][98])) +
                      '    , H99 = ' + QuotedStr(AsciiToString(WordData[i][99])) +
                      '    , UPD_DT = GETDATE() ' +
                     ' WHERE PORT_NO = ' + QuotedStr(IntToStr(i));
          SQL.Text := StrSQL;
          ExecSQL;
        end;
      except
        if TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active then
           TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active := False;
        if TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active then
           TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active := False;
      end;
    end;

  end;


  if Result = 0 then
  begin
    try




    except
      if TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qrySelect' + IntToStr(PLC_NO))).Active := False;
      if TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryUpdate' + IntToStr(PLC_NO))).Active := False;
    end;
  end else
  begin
    LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Read Fail , ErrorCode [' + IntToStr(Result) + '] ');
    ReConnect(PLC_NO);
  end;
end;

//==============================================================================
// PLC_WRITE_WORD : PLC 에 CV 지시 D-Word 정보를 전송한다.
//==============================================================================
procedure TfrmControl.PLC_WRITE_WORD1(PLC_NO:Integer);
var
  Result, Net_Size : Integer ;
  strSQL : String ;
  Net_Addr : WideString ;
  Buffer       : Array [0..9] of Word ;
  Buffer_Move  : Word ;
  Buffer_Clear : Array [0..10] of Word ;
  SCORD  : Array [START_PLCNO..End_PLCNO] of TSC_ORDER ;
begin
  try
    SCORD[PLC_NO].SCORD_NO :='';
    SCORD[PLC_NO].SCORD_D100 :=''; SCORD[PLC_NO].SCORD_D101 :=''; SCORD[PLC_NO].SCORD_D102 :='';
    SCORD[PLC_NO].SCORD_D103 :=''; SCORD[PLC_NO].SCORD_D104 :=''; SCORD[PLC_NO].SCORD_D105 :='';
    SCORD[PLC_NO].SCORD_D106 :=''; SCORD[PLC_NO].SCORD_D107 :=''; SCORD[PLC_NO].SCORD_D108 :='';
    SCORD[PLC_NO].SCORD_D109 :=''; SCORD[PLC_NO].SCORD_D110 :='';
    SCORD[PLC_NO].SCORD_ST   :=''; SCORD[PLC_NO].SCORD_DT   :='';


    while Get_PLC_JOB1(PLC_NO, SCORD[PLC_NO]) do
    begin
      //+++++++++++++++++++++++++++++++
      // 작업지시 D100 ~ D109
      //+++++++++++++++++++++++++++++++
      if ( SCORD[PLC_NO].SCORD_ST = '0' ) then
      begin
//        Buffer[00] := StrToInt('$' + SCORD[PLC_NO].SCORD_D100 );  // 적재 열
//        Buffer[01] := StrToInt('$' + SCORD[PLC_NO].SCORD_D101 );  // 적재 연
//        Buffer[02] := StrToInt('$' + SCORD[PLC_NO].SCORD_D102 );  // 적재 단
//        Buffer[03] := StrToInt('$' + SCORD[PLC_NO].SCORD_D103 );  // 하역 열
//        Buffer[04] := StrToInt('$' + SCORD[PLC_NO].SCORD_D104 );  // 하역 연
//        Buffer[05] := StrToInt('$' + SCORD[PLC_NO].SCORD_D105 );  // 하역 단
//        Buffer[06] := StrToInt('$' + SCORD[PLC_NO].SCORD_D106 );  // 예비
//        Buffer[07] := StrToInt('$' + SCORD[PLC_NO].SCORD_D107 );  // 예비
//        Buffer[08] := StrToInt('$' + SCORD[PLC_NO].SCORD_D108 );  // 예비
//        Buffer[09] := StrToInt('$' + SCORD[PLC_NO].SCORD_D109 );  // 예비


        Buffer[00] := StrToInt(SCORD[PLC_NO].SCORD_D100 );  // 적재 열
        Buffer[01] := StrToInt(SCORD[PLC_NO].SCORD_D101 );  // 적재 연
        Buffer[02] := StrToInt(SCORD[PLC_NO].SCORD_D102 );  // 적재 단
        Buffer[03] := StrToInt(SCORD[PLC_NO].SCORD_D103 );  // 하역 열
        Buffer[04] := StrToInt(SCORD[PLC_NO].SCORD_D104 );  // 하역 연
        Buffer[05] := StrToInt(SCORD[PLC_NO].SCORD_D105 );  // 하역 단
        Buffer[06] := StrToInt(SCORD[PLC_NO].SCORD_D106 );  // 예비
        Buffer[07] := StrToInt(SCORD[PLC_NO].SCORD_D107 );  // 예비
        Buffer[08] := StrToInt(SCORD[PLC_NO].SCORD_D108 );  // 예비
        Buffer[09] := StrToInt(SCORD[PLC_NO].SCORD_D109 );  // 예비

        Net_Addr := 'D100' ;
        Net_Size := 10 ;

        //Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer[0] ) ;
        //Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer[0]);
        Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer[0]);
      end else
      //+++++++++++++++++++++++++++++++
      // 기동지시 On D110
      //+++++++++++++++++++++++++++++++
      if (SCORD[PLC_NO].SCORD_ST = '1') then
      begin
        Buffer_Move := StrToInt('$' + SCORD[PLC_NO].SCORD_D110 ); // '0001'

        Net_Addr := 'D110' ;
        Net_Size := 1 ;

      //  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Move ) ;
      //  Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Move);
        Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Move);
      end else
      //+++++++++++++++++++++++++++++++
      // 기동지시 Off or 데이터초기화 (D100 ~ D110)
      //+++++++++++++++++++++++++++++++
      if ( SCORD[PLC_NO].SCORD_ST = '2' ) then
      begin
        Buffer_Clear[00] := StrToInt('$' + SCORD[PLC_NO].SCORD_D100 );  // '0000'
        Buffer_Clear[01] := StrToInt('$' + SCORD[PLC_NO].SCORD_D101 );  // '0000'
        Buffer_Clear[02] := StrToInt('$' + SCORD[PLC_NO].SCORD_D102 );  // '0000'
        Buffer_Clear[03] := StrToInt('$' + SCORD[PLC_NO].SCORD_D103 );  // '0000'
        Buffer_Clear[04] := StrToInt('$' + SCORD[PLC_NO].SCORD_D104 );  // '0000'
        Buffer_Clear[05] := StrToInt('$' + SCORD[PLC_NO].SCORD_D105 );  // '0000'
        Buffer_Clear[06] := StrToInt('$' + SCORD[PLC_NO].SCORD_D106 );  // '0000'
        Buffer_Clear[07] := StrToInt('$' + SCORD[PLC_NO].SCORD_D107 );  // '0000'
        Buffer_Clear[08] := StrToInt('$' + SCORD[PLC_NO].SCORD_D108 );  // '0000'
        Buffer_Clear[09] := StrToInt('$' + SCORD[PLC_NO].SCORD_D109 );  // '0000'
        Buffer_Clear[10] := StrToInt('$' + SCORD[PLC_NO].SCORD_D110 );  // '0000' or '0032'

        Net_Addr := 'D100' ;
        Net_Size := 11 ;

//        Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Clear[0] ) ;
//        Result := TActQJ71E71UDP(Self.FindComponent('ActQJ71E71UDP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Clear[0]);
        Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Clear[0]);
      end;

      if Result = 0 then
      begin
        LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Write Success');
        LogWriteStr(PLC_NO, 'Write Data [' + intToStr(Net_Size) + ']');

        if Del_PLC_JOB1(PLC_NO, SCORD[PLC_NO]) then
             LogWriteStr(PLC_NO, ' SC Order Delete Successfull : func Del_PLC_JOB:[' +
                                   SCORD[PLC_NO].SCORD_NO   + ',' +
                                   SCORD[PLC_NO].SCORD_D100 + ',' + SCORD[PLC_NO].SCORD_D101 + ',' + SCORD[PLC_NO].SCORD_D102 + ',' +
                                   SCORD[PLC_NO].SCORD_D103 + ',' + SCORD[PLC_NO].SCORD_D104 + ',' + SCORD[PLC_NO].SCORD_D105 + ',' +
                                   SCORD[PLC_NO].SCORD_D106 + ',' + SCORD[PLC_NO].SCORD_D107 + ',' + SCORD[PLC_NO].SCORD_D108 + ',' +
                                   SCORD[PLC_NO].SCORD_D109 + ',' + SCORD[PLC_NO].SCORD_D110 + ']')

        else LogWriteStr(PLC_NO, ' SC Order Delete Failed : func Del_PLC_JOB:[' +
                                   SCORD[PLC_NO].SCORD_NO   + ',' +
                                   SCORD[PLC_NO].SCORD_D100 + ',' + SCORD[PLC_NO].SCORD_D101 + ',' + SCORD[PLC_NO].SCORD_D102 + ',' +
                                   SCORD[PLC_NO].SCORD_D103 + ',' + SCORD[PLC_NO].SCORD_D104 + ',' + SCORD[PLC_NO].SCORD_D105 + ',' +
                                   SCORD[PLC_NO].SCORD_D106 + ',' + SCORD[PLC_NO].SCORD_D107 + ',' + SCORD[PLC_NO].SCORD_D108 + ',' +
                                   SCORD[PLC_NO].SCORD_D109 + ',' + SCORD[PLC_NO].SCORD_D110 + ']')
      end else
      begin
        LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Write Fail , ErrorCode [' + IntToStr(Result) + '] ');
      end;
    end;
  except
    on E:Exception do
    begin
      LogWriteStr(PLC_NO, ' Error : proc PLC_WRITE_WORD: PLC['+ IntToStr(PLC_NO)+ StrSQL + '], [' + E.Message + ']' ) ;
    end;
  end;
end;

//==============================================================================
// PLC_WRITE_WORD : PLC 에 CV 지시 D-Word 정보를 전송한다.
//==============================================================================
procedure TfrmControl.PLC_WRITE_WORD2(PLC_NO:Integer);
var
  Result, Net_Size, i, Idx : integer ;
  strSQL : String ;
  Net_Addr : WideString ;
  Buffer_Door : Word;
  Buffer_Clear : Array[0..32] of Word;
  PLC_ORD  : TPLC_ORDER ;
begin
  try
    PLC_ORD.D111 := '';
    PLC_ORD.ORD_ST := '';
    PLC_ORD.ORD_DT := '';

    while Get_PLC_JOB2(PLC_NO, PLC_ORD) do
    begin

      Idx := StrToInt(PLC_ORD.ORD_ST);

      //+++++++++++++++++++++++++++++++
      // 라이트커튼on/off(D111)
      //+++++++++++++++++++++++++++++++
      if (PLC_ORD.ORD_ST = '0') then
      begin
        Buffer_Door := StrToInt(PLC_ORD.D111);

        Net_Addr := 'D111' ;
        Net_Size := 1 ;

        //Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Door ) ;
        Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Door);
      end else
      //+++++++++++++++++++++++++++++++
      // RFID 1번 초기화
      //+++++++++++++++++++++++++++++++
      if (Idx in [1, 2, 3, 4, 5, 6]) then
      begin
        for i := 0 to 31 do
        begin
          Buffer_Clear[i] := StrToInt('$0000');
        end;

        case Idx of
          1 : Net_Addr := 'D1200';
          2 : Net_Addr := 'D1232';
          3 : Net_Addr := 'D1264';
          4 : Net_Addr := 'D1296';
          5 : Net_Addr := 'D1328';
          6 : Net_Addr := 'D1360';
        end;
        Net_Size := 32;

//        Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Clear[0] ) ;
        Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Clear[0]);
      end;

      if Result = 0 then
      begin
        LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Write Success');
        LogWriteStr(PLC_NO, 'Write Data [' + intToStr(Net_Size) + ']');

        if Del_PLC_JOB2(PLC_NO, PLC_ORD) then
             LogWriteStr(PLC_NO, ' PLC Order Delete Successfull : func Del_PLC_JOB2:[' +
                                   PLC_ORD.D111   + ']')

        else LogWriteStr(PLC_NO, ' PLC Order Delete Failed : func Del_PLC_JOB2:[' +
                                   PLC_ORD.D111   + ']')
      end else
      begin
        LogWriteStr(PLC_NO, Get_COMM_FLAG(PLC_NO) + 'PLC' + IntToStr(PLC_NO) + ' Memory Write Fail , ErrorCode [' + IntToStr(Result) + '] ');
      end;
    end;
  except
    on E:Exception do
    begin
      LogWriteStr(PLC_NO, ' Error : proc PLC_WRITE_WORD: PLC['+ IntToStr(PLC_NO)+ StrSQL + '], [' + E.Message + ']' ) ;
    end;
  end;
end;

//==============================================================================
// Get_PLC_JOB
//==============================================================================
function TfrmControl.Get_PLC_JOB1(PLC_NO:integer; var SCORD : TSC_ORDER): Boolean ;
var
  StrSQL : String ;
begin
  Result := False ;
  try
    // 작업지시할 데이터를 검색
    StrSQL := ' SELECT SCORD_NO, ' +
              '        SCORD_D100, SCORD_D101, SCORD_D102,  ' +
              '        SCORD_D103, SCORD_D104, SCORD_D105,  ' +
              '        SCORD_D106, SCORD_D107, SCORD_D108,  ' +
              '        SCORD_D109, SCORD_D110, SCORD_STATUS ' +
              '   FROM TT_SCORD ' +
              '  WHERE SC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
              '  ORDER BY SCORD_DT ' ;

    with TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))) do
    begin
      Close ;
      SQL.Text := StrSQL ;
      Open ;
      First ;
      if not (Bof and Eof ) then
      begin
        SCORD.SCORD_NO   := FieldByName('SCORD_NO'    ).AsString ;  // 작업번호
        SCORD.SCORD_D100 := FieldByName('SCORD_D100'  ).AsString ;  // 적재 열
        SCORD.SCORD_D101 := FieldByName('SCORD_D101'  ).AsString ;  // 적재 연
        SCORD.SCORD_D102 := FieldByName('SCORD_D102'  ).AsString ;  // 적재 단
        SCORD.SCORD_D103 := FieldByName('SCORD_D103'  ).AsString ;  // 하역 열
        SCORD.SCORD_D104 := FieldByName('SCORD_D104'  ).AsString ;  // 하역 연
        SCORD.SCORD_D105 := FieldByName('SCORD_D105'  ).AsString ;  // 하역 단
        SCORD.SCORD_D106 := FieldByName('SCORD_D106'  ).AsString ;  // 예비
        SCORD.SCORD_D107 := FieldByName('SCORD_D107'  ).AsString ;  // 예비
        SCORD.SCORD_D108 := FieldByName('SCORD_D108'  ).AsString ;  // 예비
        SCORD.SCORD_D109 := FieldByName('SCORD_D109'  ).AsString ;  // 예비
        SCORD.SCORD_D110 := FieldByName('SCORD_D110'  ).AsString ;  // 기동지시 and Data Reset
        SCORD.SCORD_ST   := FieldByName('SCORD_STATUS').AsString ;  // 지시타입
        Result := True ;
      end;
      Close ;
    end;
  except
    on E:Exception do
    begin
      if TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Close;
      LogWriteStr(PLC_NO, ' Error : func Get_PLC_JOB1:['+ StrSQL + '], [' + E.Message + ']') ;
    end;
  end;
end;

//==============================================================================
// Get_PLC_JOB2
//==============================================================================
function TfrmControl.Get_PLC_JOB2(PLC_NO: Integer; var PLC_ORD: TPLC_ORDER): Boolean ;
var
  StrSQL : String ;
begin
  Result := False ;
  try
    // 작업지시할 데이터를 검색
    StrSQL := ' SELECT D111, ' +
              '        ORD_STATUS ' +
              '   FROM TT_PLCORD ' +
              '  ORDER BY ORD_DT ' ;

    with TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))) do
    begin
      Close ;
      SQL.Text := StrSQL ;
      Open ;
      First ;
      if not (Bof and Eof ) then
      begin
        PLC_ORD.D111 := FieldByName('D111').AsString;
        PLC_ORD.ORD_ST := FieldByName('ORD_STATUS').AsString;
        Result := True ;
      end;
      Close ;
    end;
  except
    on E:Exception do
    begin
      if TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Close;
      LogWriteStr(PLC_NO, ' Error : func Get_PLC_JOB2:['+ StrSQL + '], [' + E.Message + ']') ;
    end;
  end;
end;



//==============================================================================
// Del_PLC_JOB1
//==============================================================================
function TfrmControl.Del_PLC_JOB1(PLC_NO:integer; SCORD : TSC_ORDER):Boolean ;
var
  ExecNo : Integer ;
  StrSQL : String ;
begin
  Result := False;
  try

    StrSQL := ' Delete From TT_SCORD ' +
              '  Where SC_NO = ''' + IntToStr(PLC_NO)      + ''' ' +  // SC호기
              '    and SCORD_NO     = ''' + SCORD.SCORD_NO + ''' ' +  // 작업번호
              '    and SCORD_STATUS = ''' + SCORD.SCORD_ST + ''' ' ;  // 지시타입

    with TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))) do
    begin
      Close ;
      SQL.Text := StrSQL ;
      ExecNo   := ExecSQL ;
      if ExecNo > 0 then
      begin
        Result := True ;
      end;
      Close ;
    end;
  except
    on E:Exception do
    begin
      if TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Close;
      LogWriteStr(PLC_NO, ' Error : func Del_PLC_JOB:['+StrSQL + '], [' + E.Message + ']' ) ;
    end;
  end;
end;

//==============================================================================
// Del_PLC_JOB2
//==============================================================================
function TfrmControl.Del_PLC_JOB2(PLC_NO: integer; PLC_ORD: TPLC_ORDER): Boolean;
var
  ExecNo : Integer ;
  StrSQL : String ;
begin
  Result := False;
  try

    StrSQL := ' Delete From TT_PLCORD ' +
              '  Where PLC_NO = ''' + IntToStr(PLC_NO)      + ''' ' +  // SC호기
              '    and ORD_STATUS = ''' + PLC_ORD.ORD_ST + ''' ' ;  // 지시타입

    with TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))) do
    begin
      Close ;
      SQL.Text := StrSQL ;
      ExecNo   := ExecSQL ;
      if ExecNo > 0 then
      begin
        Result := True ;
      end;
      Close ;
    end;
  except
    on E:Exception do
    begin
      if TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Active then
         TAdoQuery(Self.FindComponent('qryInfo' + IntToStr(PLC_NO))).Close;
      LogWriteStr(PLC_NO, ' Error : func Del_PLC_JOB:['+StrSQL + '], [' + E.Message + ']' ) ;
    end;
  end;
end;

//==============================================================================
// fnSet_Current : 파라메터 설정.
//==============================================================================
procedure TfrmControl.fnSet_Current(Cur_Name, FName, FValue: String);
var
  StrSQL : string;
begin
  StrSQL := '';
  try
    with qryTemp do
    begin
      Close;
      SQL.Clear;
      StrSQL := ' UPDATE TC_CURRENT' +
                   ' SET ' + FName + ' = ' + QuotedStr(FValue) +
                 ' WHERE CURRENT_NAME = ' + QuotedStr(Cur_Name);
      SQL.Text := StrSQL ;
      ExecSql ;
      Close ;
    end;
  except
    on E: Exception do
    begin
      qryTemp.Close ;
      LogWriteStr(1, 'Function fnSet_Current Cur_Name, FName, FValue(' + Cur_Name + ', ' + FName + ', ' + FValue + ') ' +
                     'Error[' + E.Message + '], ' + 'SQL [' + StrSQL + ']' ) ;
    end;
  end;

end;

end.
