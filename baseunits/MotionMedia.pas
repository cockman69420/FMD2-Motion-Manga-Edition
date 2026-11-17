{ FMD2 Motion Manga Edition - GPL-2.0-or-later.
  Header-only detection. Never decodes or rewrites the original media. }
unit MotionMedia;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

function MotionMediaExt(const Stream: TStream): String;
function MustPreserveMotion(const Stream: TStream): Boolean;
function MustPreserveMotionFile(const FileName: String): Boolean;

implementation

function BE32(const S: RawByteString; P: Integer): Cardinal;
begin
  Result := (Cardinal(Byte(S[P])) shl 24) or
    (Cardinal(Byte(S[P+1])) shl 16) or
    (Cardinal(Byte(S[P+2])) shl 8) or Byte(S[P+3]);
end;

function LE32(const S: RawByteString; P: Integer): Cardinal;
begin
  Result := Cardinal(Byte(S[P])) or (Cardinal(Byte(S[P+1])) shl 8) or
    (Cardinal(Byte(S[P+2])) shl 16) or (Cardinal(Byte(S[P+3])) shl 24);
end;

function Header(const Stream: TStream): RawByteString;
var Saved: Int64; N: LongInt;
begin
  Result := '';
  if Stream = nil then Exit;
  Saved := Stream.Position;
  try
    Stream.Position := 0;
    N := 65536;
    if Stream.Size < N then N := Stream.Size;
    SetLength(Result, N);
    if N > 0 then SetLength(Result, Stream.Read(Result[1], N));
  finally
    Stream.Position := Saved;
  end;
end;

function Detect(const S: RawByteString): String;
var P, BoxEnd: Integer; BoxSize: Cardinal; Brand: RawByteString;
  IsMP4: Boolean;
begin
  Result := '';
  if Length(S) < 12 then Exit;
  if (Copy(S, 1, 4) = 'RIFF') and (Copy(S, 9, 4) = 'WEBP') then Exit('webp');
  if (Copy(S, 1, 6) = 'GIF87a') or (Copy(S, 1, 6) = 'GIF89a') then Exit('gif');
  if Copy(S, 1, 8) = #137'PNG'#13#10#26#10 then Exit('png');
  if Copy(S, 5, 4) = 'ftyp' then
  begin
    BoxSize := BE32(S, 1);
    if (BoxSize < 16) or (BoxSize > Cardinal(Length(S))) or
      ((BoxSize mod 4) <> 0) then Exit;
    BoxEnd := BoxSize;
    P := 9;
    IsMP4 := False;
    while P + 3 <= BoxEnd do
    begin
      Brand := Copy(S, P, 4);
      if (Brand = 'avif') or (Brand = 'avis') then Exit('avif');
      if (Brand = 'isom') or (Brand = 'iso2') or (Brand = 'mp41') or
        (Brand = 'mp42') or (Brand = 'avc1') or (Brand = 'M4V ') or
        (Brand = 'dash') then IsMP4 := True;
      if P = 9 then P := 17 else Inc(P, 4); // skip minor_version
    end;
    if IsMP4 then Exit('mp4');
  end;
  // EBML DocType must be 'webm'; do not label arbitrary Matroska as WebM.
  if (Copy(S, 1, 4) = #$1A#$45#$DF#$A3) and
    (Pos(#$42#$82#$84'webm', Copy(S, 1, 4096)) > 0) then Exit('webm');
end;

function MotionMediaExt(const Stream: TStream): String;
begin
  Result := Detect(Header(Stream));
end;

function AnimatedPNG(const Stream: TStream): Boolean;
var Saved: Int64; H: RawByteString; Size: Cardinal;
begin
  // Ancillary metadata can be larger than the header buffer. Walk chunks by
  // seeking, without decoding or loading their contents.
  Result:=True;Saved:=Stream.Position;
  try
    Stream.Position:=8;SetLength(H,8);
    while Stream.Position+12<=Stream.Size do
    begin
      if Stream.Read(H[1],8)<>8 then Exit;
      if Copy(H,5,4)='acTL' then Exit;
      if Copy(H,5,4)='IDAT' then Exit(False);
      Size:=BE32(H,1);
      if Int64(Size)>Stream.Size-Stream.Position-4 then Exit;
      Stream.Seek(Int64(Size)+4,soCurrent);
    end;
  finally Stream.Position:=Saved;end;
end;

function MustPreserveMotion(const Stream: TStream): Boolean;
var S, Ext: RawByteString; P: Integer; ChunkSize: Cardinal;
begin
  S := Header(Stream);
  Ext := Detect(S);
  Result := (Ext = 'avif') or (Ext = 'mp4') or (Ext = 'webm') or (Ext = 'gif');
  if Result then Exit;
  if Ext = 'webp' then
  begin
    // VP8X animation flag is bit 1. ANIM is checked at chunk boundaries.
    P := 13;
    while P + 7 <= Length(S) do
    begin
      if Copy(S, P, 4) = 'ANIM' then Exit(True);
      if (Copy(S, P, 4) = 'VP8X') and (P + 8 <= Length(S)) and
        ((Byte(S[P+8]) and 2) <> 0) then Exit(True);
      ChunkSize := LE32(S, P+4);
      if ChunkSize > Cardinal(Length(S) - P - 7) then Break;
      Inc(P, 8 + Integer(ChunkSize) + Integer(ChunkSize mod 2));
    end;
  end
  else if Ext = 'png' then
    Result := AnimatedPNG(Stream);
end;

function MustPreserveMotionFile(const FileName: String): Boolean;
var Stream: TFileStream;
begin
  // Let I/O errors propagate: a failed check must never allow destructive conversion.
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := MustPreserveMotion(Stream);
  finally
    Stream.Free;
  end;
end;

end.
