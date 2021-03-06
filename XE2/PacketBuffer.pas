unit PacketBuffer;

interface

uses
  DynamicQueue,
  Classes, SysUtils, SyncObjs;

type
  {*
    List of [Pointer + Size] formed data.
    TPacketBuffer is similar to TPacketList.
    TPacketBuffer copy data and hold it in itself and TPacketList just hold reference of data in it.
  }
  TPacketBuffer = class
  private
    FList : TDynamicQueue;
    FCS : TCriticalSection;
    FSize: int64;
    FCount: integer;
    function GetIsEmpty: boolean;
  public
    // TODO: 스레드 세이프 옵션 처리
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    procedure Add(Data:pointer; Size:integer); overload;
    procedure Add(Data:pointer; Size:integer; ATag:pointer); overload;

    procedure AddStream(Stream:TStream);

    function GetPacket(var AData:pointer; var ASize:integer):boolean; overload;
    function GetPacket(var AData:pointer; var ASize:integer; var ATag:pointer):boolean; overload;

    property IsEmpty : boolean read GetIsEmpty;
    property Count : integer read FCount;
    property Size : int64 read FSize;
  end;

implementation

type
  TPacket = class
  private
  public
    Data : pointer;
    Size : integer;
    Tag : pointer;
    constructor Create(AData:pointer; ASize:integer); reintroduce; overload;
    constructor Create(AData:pointer; ASize:integer; ATag:pointer); reintroduce; overload;
  end;

{ TPacket }

constructor TPacket.Create(AData: pointer; ASize: integer);
begin
  inherited Create;

  // TODO : 중복 제거
  Size := ASize;
  if Size <= 0 then begin
    Data := nil;
  end else begin
    GetMem(Data, Size);
    Move(AData^, Data^, Size);
  end;

  Tag := nil;
end;

constructor TPacket.Create(AData: pointer; ASize: integer; ATag: pointer);
begin
  inherited Create;

  Size := ASize;
  if Size <= 0 then begin
    Data := nil;
  end else begin
    GetMem(Data, Size);
    Move(AData^, Data^, Size);
  end;

  Tag := ATag;
end;

{ TPacketBuffer }

procedure TPacketBuffer.Add(Data: pointer; Size: integer);
var
  Packet : TPacket;
begin
  FCS.Enter;
  try
    Packet := TPacket.Create(Data, Size);
    FList.Push(Packet);
    FCount := FCount + 1;
    if Size > 0 then FSize := FSize + Size;
  finally
    FCS.Leave;
  end;
end;

procedure TPacketBuffer.Add(Data: pointer; Size: integer; ATag: pointer);
var
  Packet : TPacket;
begin
  FCS.Enter;
  try
    Packet := TPacket.Create(Data, Size, ATag);
    FList.Push(Packet);
    FCount := FCount + 1;
    if Size > 0 then FSize := FSize + Size;
  finally
    FCS.Leave;
  end;
end;

procedure TPacketBuffer.AddStream(Stream: TStream);
var
  Data : pointer;
  Size : integer;
begin
  Size := Stream.Size;
  GetMem(Data, Size);
  try
    Stream.Position := 0;
    Stream.Read(Data^, Size);
    Add(Data, Size);
  finally
    FreeMem(Data);
  end;
end;

procedure TPacketBuffer.Clear;
var
  Packet : TPacket;
begin
  FCS.Enter;
  try
    while FList.Pop(Pointer(Packet)) do begin
      if Packet.Data <> nil then FreeMem(Packet.Data);
      Packet.Free;
    end;

    FCount := 0;
    FSize := 0;
  finally
    FCS.Leave;
  end;
end;

constructor TPacketBuffer.Create;
begin
  inherited;

  FCount := 0;
  FSize := 0;

  FList := TDynamicQueue.Create(false);
  FCS := TCriticalSection.Create;
end;

destructor TPacketBuffer.Destroy;
begin
  Clear;
  
  FreeAndNil(FCS);
  FreeAndNil(FList);

  inherited;
end;

function TPacketBuffer.GetIsEmpty: boolean;
begin
  Result := FList.IsEmpty;
end;

function TPacketBuffer.GetPacket(var AData: pointer;
  var ASize: integer): boolean;
var
  Tag: pointer;
begin
  Result := GetPacket(AData, ASize, Tag);
end;

function TPacketBuffer.GetPacket(var AData: pointer; var ASize: integer;
  var ATag: pointer): boolean;
var
  Packet : TPacket;
begin
  AData := nil;
  ASize := 0;
  ATag := nil;
  Result := false;

  FCS.Enter;
  try
    if not FList.Pop(Pointer(Packet)) then Exit;

    try
      ASize := Packet.Size;
      AData := Packet.Data;

      Result := true;
    finally
      Packet.Free;
    end;

    FCount := FCount - 1;
    if ASize > 0 then FSize := FSize - ASize;

    ATag := Packet.Tag;
  finally
    FCS.Leave;
  end;
end;

end.
