{ FMD2 Motion Manga Edition, GPL-2.0-or-later. }
unit MotionUpdatePolicy;
{$mode objfpc}{$H+}
interface
uses Classes;
const MOTION_VERSION = '0.1.0.0';
function IsProtectedMotionModule(const Path: String): Boolean;
function IsMotionUpdatePackage(const URL: String): Boolean;
function MotionPackageHashMatches(const Stream: TStream; const Expected: String): Boolean;
implementation
uses SysUtils, DCPsha256;
function IsProtectedMotionModule(const Path: String): Boolean;
var S: String;
begin
  S := LowerCase(StringReplace(Path, '\', '/', [rfReplaceAll]));
  Result := (S = 'modules/mangadistrict.lua') or (Copy(S, 1, 7) = 'motion/');
end;
function IsMotionUpdatePackage(const URL: String): Boolean;
var S: String;
begin
  S := LowerCase(URL);
  Result := (Copy(S, 1, 19) = 'https://github.com/') and
    (Pos('/releases/download/', S) > 0) and
    (Pos('/fmd-motion_', S) > 0) and
    (Pos('https://github.com/dazedcat19/fmd2/', S) <> 1) and
    ((Copy(S, Length(S)-2, 3) = '.7z') or (Copy(S, Length(S)-3, 4) = '.zip'));
end;
function MotionPackageHashMatches(const Stream: TStream; const Expected: String): Boolean;
var Hash: TDCP_sha256; Digest: array[0..31] of Byte;
  Buffer: array[0..65535] of Byte; Saved: Int64; N, I: Integer; Actual: String;
begin
  Result := False;
  if (Stream=nil) or (Length(Expected)<>64) then Exit;
  Saved:=Stream.Position;Hash:=TDCP_sha256.Create(nil);
  try
    Stream.Position:=0;Hash.Init;
    repeat N:=Stream.Read(Buffer,SizeOf(Buffer));if N>0 then Hash.Update(Buffer,N);until N=0;
    Hash.Final(Digest);Actual:='';
    for I:=0 to High(Digest) do Actual+=LowerCase(IntToHex(Digest[I],2));
    Result:=SameText(Actual,Expected);
  finally Hash.Free;Stream.Position:=Saved;end;
end;
end.
