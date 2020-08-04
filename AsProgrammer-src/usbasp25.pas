unit usbasp25;

{$mode objfpc}

interface

uses
  Classes, Forms, SysUtils, libusb, usbhid, CH341DLL, utilfunc;

const
  // ISP SCK speed identifiers
  USBASP_ISP_SCK_AUTO         = 0;
  USBASP_ISP_SCK_0_5          = 1;   // 500 Hz
  USBASP_ISP_SCK_1            = 2;   //   1 kHz
  USBASP_ISP_SCK_2            = 3;   //   2 kHz
  USBASP_ISP_SCK_4            = 4;   //   4 kHz
  USBASP_ISP_SCK_8            = 5;   //   8 kHz
  USBASP_ISP_SCK_16           = 6;   //  16 kHz
  USBASP_ISP_SCK_32           = 7;   //  32 kHz
  USBASP_ISP_SCK_93_75        = 8;   //  93.75 kHz
  USBASP_ISP_SCK_187_5        = 9;   // 187.5  kHz
  USBASP_ISP_SCK_375          = 10;  // 375 kHz
  USBASP_ISP_SCK_750          = 11;  // 750 kHz
  USBASP_ISP_SCK_1500         = 12;  // 1.5 MHz
  USBASP_ISP_SCK_3000         = 13;   // 3 Mhz
  USBASP_ISP_SCK_6000         = 14;   // 6 Mhz

  USBASP_FUNC_GETCAPABILITIES = 127;

  USBASP_FUNC_DISCONNECT         = 2;
  USBASP_FUNC_TRANSMIT           = 3;
  USBASP_FUNC_SETISPSCK          = 10;

  USBASP_FUNC_25_CONNECT         = 50;
  USBASP_FUNC_25_READ            = 51;
  USBASP_FUNC_25_WRITE  	 = 52;

  WT_PAGE = 0;
  WT_SSTB = 1;
  WT_SSTW = 2;
type

  MEMORY_ID = record
    ID9FH: array[0..2] of byte;
    ID90H: array[0..1] of byte;
    IDABH: byte;
    ID15H: array[0..1] of byte;
  end;

function UsbAsp25_Busy(devHandle: Pusb_dev_handle): boolean;

procedure EnterProgMode25(devHandle: Pusb_dev_handle);
procedure ExitProgMode25(devHandle: Pusb_dev_handle);

function UsbAsp25_Read(devHandle: Pusb_dev_handle; Opcode: Byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Read32bitAddr(devHandle: Pusb_dev_handle; Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Write(devHandle: Pusb_dev_handle; Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Write32bitAddr(devHandle: Pusb_dev_handle; Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;

function UsbAsp25_ReadID(devHandle: Pusb_dev_handle; var ID: MEMORY_ID): integer;

function UsbAsp25_Wren(devHandle: Pusb_dev_handle): integer;
function UsbAsp25_Wrdi(devHandle: Pusb_dev_handle): integer;
function UsbAsp25_ChipErase(devHandle: Pusb_dev_handle): integer;

function UsbAsp25_WriteSR(devHandle: Pusb_dev_handle; sreg: byte; opcode: byte = $01): integer;
function UsbAsp25_WriteSR_2byte(devHandle: Pusb_dev_handle; sreg1, sreg2: byte): integer;
function UsbAsp25_ReadSR(devHandle: Pusb_dev_handle; var sreg: byte; opcode: byte = $05): integer;

function UsbAsp_SetISPSpeed(devHandle: Pusb_dev_handle; speed: byte): integer;

function UsbAsp25_WriteSSTB(devHandle: Pusb_dev_handle; Opcode: byte; Data: byte): integer;
function UsbAsp25_WriteSSTW(devHandle: Pusb_dev_handle; Opcode: byte; Data1, Data2: byte): integer;

function UsbAsp25_EN4B(devHandle: Pusb_dev_handle): integer;
function UsbAsp25_EX4B(devHandle: Pusb_dev_handle): integer;

function SPIRead(devHandle: Pusb_dev_handle; CS: byte; BufferLen: integer; out buffer: array of byte): integer;
function SPIWrite(devHandle: Pusb_dev_handle; CS: byte; BufferLen: integer; buffer: array of byte): integer;

implementation

uses Main, avrispmk2;

//Пока отлипнет ромка
function UsbAsp25_Busy(devHandle: Pusb_dev_handle): boolean;
var
  sreg: byte;
begin
  Result := True;
  sreg := $FF;

  UsbAsp25_ReadSR(devHandle, sreg);
  if not IsBitSet(sreg, 0) then Result := False;
end;

//Вход в режим программирования
procedure EnterProgMode25(devHandle: Pusb_dev_handle);
var
  dummy: byte;
begin
  case Current_HW of
  CH341:
    begin
      CH341SetStream(0, %10000001);
      exit;
    end;
  AVRISP:
    begin
      avrisp_enter_progmode();
      exit;
    end;
  USBASP:
      USBSendControlMessage(devHandle, USB2PC, USBASP_FUNC_25_CONNECT, 0, 0, 0, dummy);
  end;
  sleep(50);

  //release power-down
  SPIWrite(hUSBDev, 1, 1, $AB);
  sleep(2);
end;

//Выход из режима программирования
procedure ExitProgMode25(devHandle: Pusb_dev_handle);
var
  dummy: byte;
begin
  if Current_HW = CH341 then
  begin
     CH341Set_D5_D0(0, 0, 0);
     exit;
  end;

  if Current_HW = AVRISP then
  begin
    if devHandle <> nil then avrisp_leave_progmode();
    exit;
  end;

  if devHandle <> nil then
    USBSendControlMessage(devHandle, USB2PC, USBASP_FUNC_DISCONNECT, 0, 0, 0, dummy);
end;

//Читает id и заполняет структуру
function UsbAsp25_ReadID(devHandle: Pusb_dev_handle; var ID: MEMORY_ID): integer;
var
  buffer: array[0..3] of byte;
begin
  //9F
  buffer[0] := $9F;
  SPIWrite(devHandle, 0, 1, buffer);
  FillByte(buffer, 4, $FF);
  result := SPIRead(devHandle, 1, 3, buffer);
  move(buffer, ID.ID9FH, 3);
  //90
  FillByte(buffer, 4, 0);
  buffer[0] := $90;
  SPIWrite(devHandle, 0, 4, buffer);
  result := SPIRead(devHandle, 1, 2, buffer);
  move(buffer, ID.ID90H, 2);
  //AB
  FillByte(buffer, 4, 0);
  buffer[0] := $AB;
  SPIWrite(devHandle, 0, 4, buffer);
  result := SPIRead(devHandle, 1, 1, buffer);
  move(buffer, ID.IDABH, 1);
  //15
  buffer[0] := $15;
  SPIWrite(devHandle, 0, 1, buffer);
  FillByte(buffer, 4, $FF);
  result := SPIRead(devHandle, 1, 2, buffer);
  move(buffer, ID.ID15H, 2);
end;

//Возвращает сколько байт прочитали
function UsbAsp25_Read(devHandle: Pusb_dev_handle; Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
begin

  buff[0] := Opcode;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);

  SPIWrite(devHandle, 0, 4, buff);
  result := SPIRead(devHandle, 1, bufflen, buffer);
end;

function UsbAsp25_Read32bitAddr(devHandle: Pusb_dev_handle; Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin

  buff[0] := Opcode;
  buff[1] := hi(hi(addr));
  buff[2] := lo(hi(addr));
  buff[3] := hi(lo(addr));
  buff[4] := lo(lo(addr));

  SPIWrite(devHandle, 0, 5, buff);
  result := SPIRead(devHandle, 1, bufflen, buffer);
end;


function UsbAsp_SetISPSpeed(devHandle: Pusb_dev_handle; speed: byte): integer;
var
  buff: byte;
begin

  if Current_HW = CH341 then
  begin
    result := 0;
    exit;
  end;

  if Current_HW = AVRISP then
  begin
    if avrisp_set_ckl(speed) then result := 0 else result := -1;
    exit;
  end;

  buff := $FF;
  USBSendControlMessage(devHandle, USB2PC, USBASP_FUNC_SETISPSCK, speed, 0, 1, buff);
  result := buff;

end;

function UsbAsp25_Wren(devHandle: Pusb_dev_handle): integer;
var
  buff: byte;
begin
  buff:= $06;
  result := SPIWrite(devHandle, 1, 1, buff);
end;

function UsbAsp25_Wrdi(devHandle: Pusb_dev_handle): integer;
var
  buff: byte;
begin
  buff:= $04;
  result := SPIWrite(devHandle, 1, 1, buff);
end;

function UsbAsp25_ChipErase(devHandle: Pusb_dev_handle): integer;
var
  buff: byte;
begin
  //Некоторые atmel'ы требуют 62H
  buff:= $62;
  SPIWrite(devHandle, 1, 1, buff);
  //Старые SST требуют 60H
  buff:= $60;
  SPIWrite(devHandle, 1, 1, buff);
  buff:= $C7;
  result := SPIWrite(devHandle, 1, 1, buff);
end;

function UsbAsp25_WriteSR(devHandle: Pusb_dev_handle; sreg: byte; opcode: byte = $01): integer;
var
  buff: array[0..1] of byte;
begin
  //Старые SST требуют Enable-Write-Status-Register (50H)
  Buff[0] := $50;
  SPIWrite(devHandle, 1, 1, buff);
  //
  Buff[0] := opcode;
  Buff[1] := sreg;
  result := SPIWrite(devHandle, 1, 2, buff);
end;

function UsbAsp25_WriteSR_2byte(devHandle: Pusb_dev_handle; sreg1, sreg2: byte): integer;
var
  buff: array[0..2] of byte;
begin
  //Старые SST требуют Enable-Write-Status-Register (50H)
  Buff[0] := $50;
  SPIWrite(devHandle, 1, 1, buff);

  //Если регистр из 2х байт
  Buff[0] := $01;
  Buff[1] := sreg1;
  Buff[2] := sreg2;
  result := SPIWrite(devHandle, 1, 3, buff);
end;

function UsbAsp25_ReadSR(devHandle: Pusb_dev_handle; var sreg: byte; opcode: byte = $05): integer;
begin
  SPIWrite(devHandle, 0, 1, opcode);
  result := SPIRead(devHandle, 1, 1, sreg);
end;

//Возвращает сколько байт записали
function UsbAsp25_Write(devHandle: Pusb_dev_handle; Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
begin

  buff[0] := Opcode;
  buff[1] := lo(hi(addr));
  buff[2] := hi(lo(addr));
  buff[3] := lo(lo(addr));

  SPIWrite(devHandle, 0, 4, buff);
  result := SPIWrite(devHandle, 1, bufflen, buffer);
end;

function UsbAsp25_Write32bitAddr(devHandle: Pusb_dev_handle; Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin

  buff[0] := Opcode;
  buff[1] := hi(hi(addr));
  buff[2] := lo(hi(addr));
  buff[3] := hi(lo(addr));
  buff[4] := lo(lo(addr));

  SPIWrite(devHandle, 0, 5, buff);
  result := SPIWrite(devHandle, 1, bufflen, buffer);
end;

function UsbAsp25_WriteSSTB(devHandle: Pusb_dev_handle; Opcode: byte; Data: byte): integer;
var
  buff: array[0..1] of byte;
begin
  buff[0] := Opcode;
  buff[1] := Data;

  result := SPIWrite(devHandle, 1, 2, buff)-1;
end;

function UsbAsp25_WriteSSTW(devHandle: Pusb_dev_handle; Opcode: byte; Data1, Data2: byte): integer;
var
  buff: array[0..2] of byte;
begin
  buff[0] := Opcode;
  buff[1] := Data1;
  buff[2] := Data2;

  result := SPIWrite(devHandle, 1, 3, buff)-1;
end;

//Enter 4-byte mode
function UsbAsp25_EN4B(devHandle: Pusb_dev_handle): integer;
var
  buff: byte;
begin
  buff:= $B7;
  result := SPIWrite(devHandle, 1, 1, buff);
end;

//Exit 4-byte mode
function UsbAsp25_EX4B(devHandle: Pusb_dev_handle): integer;
var
  buff: byte;
begin
  buff:= $E9;
  result := SPIWrite(devHandle, 1, 1, buff);
end;

function SPIRead(devHandle: Pusb_dev_handle; CS: byte; BufferLen: integer; out buffer: array of byte): integer;
begin
  result := USBSendControlMessage(devHandle, USB2PC, USBASP_FUNC_25_READ, CS, 0, BufferLen, buffer);
end;

function SPIWrite(devHandle: Pusb_dev_handle; CS: byte; BufferLen: integer; buffer: array of byte): integer;
begin
  result := USBSendControlMessage(devHandle, PC2USB, USBASP_FUNC_25_WRITE, CS, 0, BufferLen, buffer);
end;

end.

