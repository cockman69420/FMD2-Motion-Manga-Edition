{ FMD2 Motion Manga Edition, GPL-2.0-or-later. }
unit LuaMotionMedia;
{$mode objfpc}{$H+}
interface
implementation
uses Classes, SysUtils, LuaUtils, LuaPackage, uBaseUnit,
  {$ifdef luajit}lua{$else}{$ifdef lua54}lua54{$else}lua53{$endif}{$endif};

function SaveOriginal(L: Plua_State): Integer; cdecl;
var Name: String;
begin
  Name := '';
  if (lua_gettop(L) = 3) and lua_isuserdata(L, 1) then
    Name := SaveImageStreamToFile(TMemoryStream(luaToUserData(L, 1)),
      luaToString(L, 2), luaToString(L, 3), 0, True);
  lua_pushlstring(L, PChar(Name), Length(Name));
  Result := 1;
end;

const Methods: packed array[0..1] of luaL_Reg = (
  (name: 'SaveOriginal'; func: @SaveOriginal), (name: nil; func: nil));

function OpenMotion(L: Plua_State): Integer; cdecl;
begin
  luaNewLibTable(L, Methods);
  Result := 1;
end;

initialization
  LuaPackage.AddLib('motion', @OpenMotion);
end.
