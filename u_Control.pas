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
    Button2: TButton;

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
    procedure Button2Click(Sender: TObject);

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
    for i := START_PLCNO to END_PLCNO do
    begin
//      if TCheckBox(Self.FindComponent('cbUsed'+IntToStr(i))).Checked then
//         bbCommClick(TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))));
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
    // Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(i))).Open ;
       Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(i))).Open ;

      if Result <> 0 then
      begin
        TBitBtn(Self.FindComponent('bbComm'+IntToStr(i))).Caption := '통신시작' ;
     // TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(i))).Close ;
        TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(i))).Close;
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
      Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(i))).Close ;
   // Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(i))).Close ;
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
    Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).Open ;

    if Result <> 0 then
    begin
      TBitBtn(Self.FindComponent('bbComm'+IntToStr(PLC_NO))).Caption  := '통신시작';
      //TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).Close;
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
    CVR_D_W3 : PLC_READ_WORD3(PLC_NO) ; //  Read D Word(RFID data area);
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

  Exit;

  TTimer(Self.FindComponent('tmSendRecv'+IntToStr(PLC_NO))).Enabled := False;
  TTimer(Self.FindComponent('tmTimeOut' +IntToStr(PLC_NO))).Enabled := True ;
  TPanel(Self.FindComponent('plTimeOut' +IntToStr(PLC_NO))).Color := clLime ;

  try
    i := Get_COMM_FLAGNo(PLC_NO) ;

    SetOnCommPNL(PLC_NO, i) ; // LED ON

    case COMM_FLAG[PLC_NO] of
      CVR_D_W1, CVR_D_W2 :
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
    if MainDatabase.Connected then MainDataBase.Close ;
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
  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;
//Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).ReadDeviceBlock2(Net_Addr, Net_Size, Buffer[0] ) ;


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
  Buffer : Array [0..2] of integer ;
  WordData : Array [0..2] of String;
begin
  FillChar(Buffer, sizeof(Buffer), 0 );

  //++++++++++++++++++++++++++++++
  // CH04 ~ CH05 : SC D(Bit)영역
  //++++++++++++++++++++++++++++++
  Net_Addr := 'D0210' ;
  Net_Size := 3 ;

  //++++++++++++
  // Data Read
  //++++++++++++
  Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).ReadDeviceBlock(Net_Addr, Net_Size, Buffer[0] ) ;
//Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).ReadDeviceBlock2(Net_Addr, Net_Size, Buffer[0] ) ;

  if Result = 0 then
  begin
    LogWriteStr(PLC_NO, '[PLC' + IntToStr(PLC_NO) + ']: '+ Get_COMM_FLAG(PLC_NO) + ' Memory Read Success');

    for i := Low(WordData) to High(WordData) do
    begin
      //0000000000000000
      WordData[i] := HexaReverse(PLC_NO, IntToHex(Buffer[i], 4 )) ;
    end;

    LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Read1 Data [' + intToStr(Net_Size) + ']');

    try
      strSQL   := ' Select * from TT_SCC ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ' ;

      tempSQL  := '';
      tempSQL2 := '';
      tempSQL3 := '';

      i := 0 ; j := 4 ;
      while j <= 6 do
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
//Result := TActQNUDECPUTCP(Self.FindComponent('ActQNUDECPUTCP' + IntToStr(PLC_NO))).ReadDeviceBlock2(Net_Addr, Net_Size, Buffer[0] ) ;


 // st1 IN
  // CH 06 word 영역
  Buffer[0] := 16976;    // j = 6 , i = 12
  Buffer[1] := 12337;
  Buffer[2] := 11603;
  Buffer[3] := 9008;

  // CH 07 word 영역
  Buffer[4] := 12337;    // j = 7 , i = 16
  Buffer[5] := 8224;
  Buffer[6] := 8224;
  Buffer[7] := 8224;

  // CH 08 word 영역
  Buffer[8] := 19506;    // j = 8 , i = 20
  Buffer[9] := 12848;
  Buffer[10] := 12848;
  Buffer[11] := 14128;

  // CH 09 word 영역
  Buffer[12] := 12336;    // j = 9 , i = 24
  Buffer[13] := 12613;
  Buffer[14] := 8224;
  Buffer[15] := 8224;

  // CH 10 word 영역
  Buffer[16] := 21042;    // j = 10 , i = 28
  Buffer[17] := 12848;
  Buffer[18] := 12848;
  Buffer[19] := 14128;

  // CH 11 word 영역
  Buffer[20] := 12336;    // j = 11 , i = 32
  Buffer[21] := 12613;
  Buffer[22] := 8224;
  Buffer[23] := 8224;

  // CH 12 word 영역
  Buffer[24] := 17238;
  Buffer[25] := 12337;
  Buffer[26] := 8224;
  Buffer[27] := 8224;

  // CH 13 word 영역
  Buffer[28] := 12337;
  Buffer[29] := 8224;
  Buffer[30] := 8224;
  Buffer[31] := 8224;

  // st 1 OUT
  // CH 14 word 영역
  Buffer[32] := 16976;    // j = 6 , i = 12
  Buffer[33] := 12337;
  Buffer[34] := 11603;
  Buffer[35] := 9008;

  // CH 15 word 영역
  Buffer[36] := 12337;    // j = 7 , i = 16
  Buffer[37] := 8224;
  Buffer[38] := 8224;
  Buffer[39] := 8224;

  // CH 16 word 영역
  Buffer[40] := 19506;    // j = 8 , i = 20
  Buffer[41] := 12848;
  Buffer[42] := 12848;
  Buffer[43] := 14128;

  // CH 17 word 영역
  Buffer[44] := 12336;    // j = 9 , i = 24
  Buffer[45] := 12613;
  Buffer[46] := 8224;
  Buffer[47] := 8224;

  // CH 18 word 영역
  Buffer[48] := 21042;    // j = 10 , i = 28
  Buffer[49] := 12848;
  Buffer[50] := 12848;
  Buffer[51] := 14128;

  // CH 19 word 영역
  Buffer[52] := 12336;    // j = 11 , i = 32
  Buffer[53] := 12613;
  Buffer[54] := 8224;
  Buffer[55] := 8224;

  // CH 20 word 영역
  Buffer[56] := 17238;
  Buffer[57] := 12337;
  Buffer[58] := 8224;
  Buffer[59] := 8224;

  // CH 21 word 영역
  Buffer[60] := 12337;
  Buffer[61] := 8224;
  Buffer[62] := 8224;
  Buffer[63] := 8224;

  //st 2 IN
  // CH 22 word 영역
  Buffer[64] := 16976;    // j = 6 , i = 12
  Buffer[65] := 12337;
  Buffer[66] := 11603;
  Buffer[67] := 9008;

  // CH 23 word 영역
  Buffer[68] := 12337;    // j = 7 , i = 16
  Buffer[69] := 8224;
  Buffer[70] := 8224;
  Buffer[71] := 8224;

  // CH 24 word 영역
  Buffer[72] := 19506;    // j = 8 , i = 20
  Buffer[73] := 12848;
  Buffer[74] := 12848;
  Buffer[75] := 14128;

  // CH 25 word 영역
  Buffer[76] := 12336;    // j = 9 , i = 24
  Buffer[77] := 12613;
  Buffer[78] := 8224;
  Buffer[79] := 8224;

  // CH 26 word 영역
  Buffer[80] := 21042;    // j = 10 , i = 28
  Buffer[81] := 12848;
  Buffer[82] := 12848;
  Buffer[83] := 14128;

  // CH 27 word 영역
  Buffer[84] := 12336;    // j = 11 , i = 32
  Buffer[85] := 12613;
  Buffer[86] := 8224;
  Buffer[87] := 8224;

  // CH 28 word 영역
  Buffer[88] := 17238;
  Buffer[89] := 12337;
  Buffer[90] := 8224;
  Buffer[91] := 8224;

  // CH 29 word 영역
  Buffer[92] := 12337;
  Buffer[93] := 8224;
  Buffer[94] := 8224;
  Buffer[95] := 8224;

  // ST 2 OUT
  // CH 30 word 영역
  Buffer[96] := 16976;    // j = 6 , i = 12
  Buffer[97] := 12337;
  Buffer[98] := 11603;
  Buffer[99] := 9008;

  // CH 31 word 영역
  Buffer[100] := 12337;    // j = 7 , i = 16
  Buffer[101] := 8224;
  Buffer[102] := 8224;
  Buffer[103] := 8224;

  // CH 32 word 영역
  Buffer[104] := 19506;    // j = 8 , i = 20
  Buffer[105] := 12848;
  Buffer[106] := 12848;
  Buffer[107] := 14128;

  // CH 33 word 영역
  Buffer[108] := 12336;    // j = 9 , i = 24
  Buffer[109] := 12613;
  Buffer[110] := 8224;
  Buffer[111] := 8224;

  // CH 34 word 영역
  Buffer[112] := 21042;    // j = 10 , i = 28
  Buffer[113] := 12848;
  Buffer[114] := 12848;
  Buffer[115] := 14128;

  // CH 35 word 영역
  Buffer[116] := 12336;    // j = 11 , i = 32
  Buffer[117] := 12613;
  Buffer[118] := 8224;
  Buffer[119] := 8224;

  // CH 36 word 영역
  Buffer[120] := 17238;
  Buffer[121] := 12337;
  Buffer[122] := 8224;
  Buffer[123] := 8224;

  // CH 37 word 영역
  Buffer[124] := 12337;
  Buffer[125] := 8224;
  Buffer[126] := 8224;
  Buffer[127] := 8224;

  //st 3 IN
  // CH 38 word 영역
  Buffer[128] := 16976;    // j = 6 , i = 12
  Buffer[129] := 12337;
  Buffer[130] := 11603;
  Buffer[131] := 9008;

  // CH 39 word 영역
  Buffer[132] := 12337;    // j = 7 , i = 16
  Buffer[133] := 8224;
  Buffer[134] := 8224;
  Buffer[135] := 8224;

  // CH 40 word 영역
  Buffer[136] := 19506;    // j = 8 , i = 20
  Buffer[137] := 12848;
  Buffer[138] := 12848;
  Buffer[139] := 14128;

  // CH 41 word 영역
  Buffer[140] := 12336;    // j = 9 , i = 24
  Buffer[141] := 12613;
  Buffer[142] := 8224;
  Buffer[143] := 8224;

  // CH 42 word 영역
  Buffer[144] := 21042;    // j = 10 , i = 28
  Buffer[145] := 12848;
  Buffer[146] := 12848;
  Buffer[147] := 14128;

  // CH 43 word 영역
  Buffer[148] := 12336;    // j = 11 , i = 32
  Buffer[149] := 12613;
  Buffer[150] := 8224;
  Buffer[151] := 8224;

  // CH 44 word 영역
  Buffer[152] := 17238;
  Buffer[153] := 12337;
  Buffer[154] := 8224;
  Buffer[155] := 8224;

  // CH 45 word 영역
  Buffer[156] := 12337;
  Buffer[157] := 8224;
  Buffer[158] := 8224;
  Buffer[159] := 8224;

  // ST 2 OUT
  // CH 46 word 영역
  Buffer[160] := 16976;    // j = 6 , i = 12
  Buffer[161] := 12337;
  Buffer[162] := 11603;
  Buffer[163] := 9008;

  // CH 47 word 영역
  Buffer[164] := 12337;    // j = 7 , i = 16
  Buffer[165] := 8224;
  Buffer[166] := 8224;
  Buffer[167] := 8224;

  // CH 48 word 영역
  Buffer[168] := 19506;    // j = 8 , i = 20
  Buffer[169] := 12848;
  Buffer[170] := 12848;
  Buffer[171] := 14128;

  // CH 49 word 영역
  Buffer[172] := 12336;    // j = 9 , i = 24
  Buffer[173] := 12613;
  Buffer[174] := 8224;
  Buffer[175] := 8224;

  // CH 50 word 영역
  Buffer[176] := 21042;    // j = 10 , i = 28
  Buffer[177] := 12848;
  Buffer[178] := 12848;
  Buffer[179] := 14128;

  // CH 51 word 영역
  Buffer[180] := 12336;    // j = 11 , i = 32
  Buffer[181] := 12613;
  Buffer[182] := 8224;
  Buffer[183] := 8224;

  // CH 52 word 영역
  Buffer[184] := 17238;
  Buffer[185] := 12337;
  Buffer[186] := 8224;
  Buffer[187] := 8224;

  // CH 53 word 영역
  Buffer[188] := 12337;
  Buffer[189] := 8224;
  Buffer[190] := 8224;
  Buffer[191] := 8224;


  if Result = 0 then
  begin
    LogWriteStr(PLC_NO, '[PLC' + IntToStr(PLC_NO) + ']: '+ Get_COMM_FLAG(PLC_NO) + ' Memory Read Success');

    for i := Low(WordData) to High(WordData) do
    begin
      //0000
      WordData[i] := HexaReverse(PLC_NO, IntToHex(Buffer[i], 4 )) ;
    end;

    LogWriteStr(PLC_NO, 'PLC' + IntToStr(PLC_NO) + ' Read1 Data [' + intToStr(Net_Size) + ']');

    try
      strSQL   := ' Select * from TT_SCC ' +
                  '  Where SCC_NO = ''' + IntToStr(PLC_NO) + ''' ' +
                  '    and SCC_SR = ''R'' ' ;

      tempSQL  := '';
      tempSQL2 := '';
      tempSQL3 := '';

      i := 0 ; j := 6 ;
      while j <= 53 do
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
  Result, Net_Size : integer ;
  strSQL : String ;
  Net_Addr : WideString ;
  Buffer       : Array [0..9] of Word ;
  Buffer_Move  : Word ;
  Buffer_Clear : Array [0..10] of Word ;
  Buffer_Door  : Word;
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

        Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer[0] ) ;
      end else
      //+++++++++++++++++++++++++++++++
      // 기동지시 On D110
      //+++++++++++++++++++++++++++++++
      if (SCORD[PLC_NO].SCORD_ST = '1') then
      begin
        Buffer_Move := StrToInt('$' + SCORD[PLC_NO].SCORD_D110 ); // '0001'

        Net_Addr := 'D110' ;
        Net_Size := 1 ;

        Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Move ) ;
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

        Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Clear[0] ) ;
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
  Result, Net_Size : integer ;
  strSQL : String ;
  Net_Addr : WideString ;
  Buffer_Door  : Word;
  PLC_ORD  : TPLC_ORDER ;
begin
  try
    PLC_ORD.D111 := '';
    PLC_ORD.ORD_ST := '';
    PLC_ORD.ORD_DT := '';

    while Get_PLC_JOB2(PLC_NO, PLC_ORD) do
    begin

      //+++++++++++++++++++++++++++++++
      // 라이트커튼on/off(D111)
      //+++++++++++++++++++++++++++++++
      Buffer_Door := StrToInt('$' + PLC_ORD.D111);

      Net_Addr := 'D111' ;
      Net_Size := 1 ;

      Result := TActQJ71E71TCP(Self.FindComponent('ActQJ71E71TCP' + IntToStr(PLC_NO))).WriteDeviceBlock2(Net_Addr, Net_Size, Buffer_Door ) ;

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
              '  WHERE SC_NO= ''' + IntToStr(PLC_NO) + ''' ' +
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

procedure TfrmControl.Button2Click(Sender: TObject);
begin
  PLC_READ_WORD3(1);
end;

end.
