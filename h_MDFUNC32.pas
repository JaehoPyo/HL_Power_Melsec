unit h_MDFUNC32;

interface

uses
  Windows, Messages, SysUtils;

const
  //============================================================================
  // Const -> Device value List
  //============================================================================

  DevB   = 23    ;
  DevW   = 24    ;

  //============================================================================
  //  function prototypes
  //============================================================================
  //  dll Name : "MDFUNC32.dll"
  //============================================================================
  function mdOpen   (Chan : Smallint;  Mode : Smallint; Path : PInteger): Integer ; stdcall ;
  function mdClose  (Path : PInteger): Integer; stdcall ;
  function mdSend   (Path : PInteger; Stno , Devtyp , devno : Smallint; size : PInteger; buf : PInteger): Integer ; stdcall ;
  function mdReceive(Path : PInteger; Stno , Devtyp , devno : Smallint; size : PInteger; buf : PInteger): Integer ; stdcall ;

  implementation

  {*** from MdFunc.h ************************************************************}
  //==============================================================================
  function mdOpen;        external 'MDFUNC32.DLL' name 'mdopen'    ;  // Opens a communication line.
  function mdClose;       external 'MDFUNC32.DLL' name 'mdclose'   ;  // Close a communication line.
  function mdSend;        external 'MDFUNC32.DLL' name 'mdsend'    ;  // Batch writes devices. Sends data (SEND function). Q/QnA dedicated instruction
  function mdReceive;     external 'MDFUNC32.DLL' name 'mdreceive' ;  // Batch reads  devices. Receives data (RECV function). Q/QnA dedicated instruction
  //==============================================================================

end.



