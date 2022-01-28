program MESLE_SC;

uses
  Forms,
  u_Control in 'u_Control.pas' {frmControl},
  h_ReferLib in 'h_ReferLib.pas';

{$E .EXE}

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'SC Ελ½Ε';
  Application.CreateForm(TfrmControl, frmControl);
  Application.Run;
end.
