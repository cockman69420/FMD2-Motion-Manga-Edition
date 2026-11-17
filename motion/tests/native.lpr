program MotionNativeTests;
{$mode objfpc}{$H+}
uses FMDOptions, Interfaces, Forms, uBaseUnit, FMDVars, webp, CheckUpdate,
  DBUpdater, SelfUpdater, uDownloadsManager, LuaWebsiteModules, LuaBase,
  SimpleException, Classes, SysUtils, frmMain, Controls, StdCtrls, Zipper,
  MotionMedia, MotionUpdatePolicy, ImgInfos, uPacker,
  LuaPackage, LuaUtils, lua54, LuaClass, LuaStrings, LuaHTTPSend,
  httpsendthread, ssl_openssl_lib, ssl_openssl, blcksock, fileinfo;
var Root, Fixtures, Temp: String; Passed: Integer = 0;

procedure Check(OK: Boolean; const Name: String);
begin
  if not OK then raise Exception.Create('FAIL: ' + Name);
  Inc(Passed); WriteLn('PASS: ', Name);
end;

function ReadFile(const FileName: String): RawByteString;
var F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try SetLength(Result, F.Size); if F.Size>0 then F.ReadBuffer(Result[1], F.Size);
  finally F.Free; end;
end;

procedure HeaderTest(const Bytes, Expected: RawByteString; Protected: Boolean; const Name: String);
var S: TMemoryStream;
begin
  S := TMemoryStream.Create;
  try
    if Bytes<>'' then S.WriteBuffer(Bytes[1], Length(Bytes));
    S.Position := S.Size;
    Check(MotionMediaExt(S)=Expected, Name+' format');
    Check(MustPreserveMotion(S)=Protected, Name+' preservation');
    Check(S.Position=S.Size, Name+' stream position');
  finally S.Free; end;
end;

procedure SaveTest(const Name, Ext: String; Protected: Boolean);
var S: TMemoryStream; Saved, Original: RawByteString;
begin
  S := TMemoryStream.Create;
  try
    S.LoadFromFile(Fixtures+Name); Original:=ReadFile(Fixtures+Name);
    Check(MustPreserveMotion(S)=Protected, Name+' detection');
    Saved := SaveImageStreamToFile(S, Temp+'saved', Name);
    Check(ExtractFileExt(Saved)='.'+Ext, Name+' saved extension');
    if Protected then Check(ReadFile(Saved)=Original, Name+' all original bytes and timing retained');
  finally S.Free; end;
end;

procedure PackTest(Motion: Boolean; Format: TPackerFormat; const TestName: String);
var P: TPacker; Z: TUnZipper; Source, Saved, OutDir, A, B: String; S: TMemoryStream;
begin
  Source:=Temp+TestName+PathDelim; ForceDirectories(Source);
  OutDir:=Temp+TestName+'-unpacked'+PathDelim; ForceDirectories(OutDir);
  if Motion then A:='animated.avif' else A:='static.jpg';
  B:='animated.webp';
  S:=TMemoryStream.Create;
  try
    S.LoadFromFile(Fixtures+A); S.SaveToFile(Source+A);
    if Motion then begin S.LoadFromFile(Fixtures+B); S.SaveToFile(Source+B); end;
  finally S.Free; end;
  P:=TPacker.Create;
  try
    P.Path:=Source; P.FileName:=Temp+TestName; P.Format:=Format;
    P.CompressionQuality:=90;
    Check(P.Execute, TestName+' pack success'); Saved:=P.SavedFileName;
    if Motion or (Format=pfCBZ) then begin
      Check(ExtractFileExt(Saved)='.cbz', TestName+' safe CBZ format');
      Z:=TUnZipper.Create;
      try Z.FileName:=Saved; Z.OutputPath:=OutDir; Z.UnZipAllFiles;
      finally Z.Free; end;
      Check(ReadFile(OutDir+A)=ReadFile(Fixtures+A), TestName+' archive bytes match');
      if Motion then Check(ReadFile(OutDir+B)=ReadFile(Fixtures+B), TestName+' mixed original bytes match');
    end else Check(Copy(ReadFile(Saved),1,5)='%PDF-', TestName+' ordinary PDF preserved');
    Check(not FileExists(Source+A), TestName+' source removed only after pack success');
  finally P.Free; end;
end;

procedure LuaTests;
var L: Plua_State; Script: String;
begin
  LuaLibDir:=Root+'lua'+PathDelim;
  L:=LuaNewBaseState;
  try
    lua_pushlstring(L, PChar(Fixtures), Length(Fixtures)); lua_setglobal(L,'FIXTURES');
    Script:=ReadFile(Root+'motion'+PathDelim+'tests'+PathDelim+'parser-tests.lua');
    Check(luaL_loadstring(L, PChar(Script))=0,'Lua test script compiles');
    if lua_pcall(L,0,0,0)<>0 then raise Exception.Create(luaToString(L,-1));
    Check(True,'real FMD2 Lua/XPath parser: mixed media, no duplicates, URL resolution, empty/stream failures');
    if (ParamCount>1) and FileExists(ParamStr(2)) then begin
      Script:=ReadFile(ParamStr(2));
      lua_pushlstring(L,PChar(Script),Length(Script));lua_setglobal(L,'LIVE_HTML');
      Script:='local m=require "motion.MangaDistrict"; local l={Count=0,Clear=function() end,Add=function(s) print(s) end}; '+
        'l.Add=function(s) l.Count=l.Count+1; print(s) end; assert(m.Extract(CreateTXQuery(LIVE_HTML),"https://mangadistrict.com/series/test/chapter-1/",l)); print("LIVE pages: "..l.Count); assert(l.Count>5)';
      Check(luaL_loadstring(L,PChar(Script))=0,'live parser script compiles');
      if lua_pcall(L,0,0,0)<>0 then raise Exception.Create(luaToString(L,-1));
      Check(True,'live MangaDistrict HTML parsed by real module');
    end;
  finally lua_close(L); end;
end;

procedure HashTests;
var S: TStringStream;
begin
  S:=TStringStream.Create('abc');
  try
    S.Position:=2;
    Check(MotionPackageHashMatches(S,'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),'SHA-256 known vector');
    Check(S.Position=2,'SHA-256 restores stream position');
    Check(not MotionPackageHashMatches(S,StringOfChar('0',64)),'corrupt update package rejected');
    Check(not MotionPackageHashMatches(S,''),'missing update checksum rejected');
    Check(NewerVersion(StrToProgramVersion('0.1.1.0'),StrToProgramVersion(MOTION_VERSION)),'motion-only version updates detected');
  finally S.Free;end;
end;

procedure LiveTests;
var SeriesURL: String; L: Plua_State; HTTP: THTTPSendThread; Pages, ChapterLinks, ChapterNames: TStringList;
  I, AVIFCount: Integer; TotalBytes: Int64; Source, Saved, OriginalDir, SavedDir, UnpackedDir: String;
  P: TPacker; Z: TUnZipper;
  procedure Run(const Script: String);
  begin
    if luaL_loadstring(L,PChar(Script))<>0 then raise Exception.Create(luaToString(L,-1));
    if lua_pcall(L,0,0,0)<>0 then raise Exception.Create(luaToString(L,-1));
  end;
begin
  SeriesURL:=GetEnvironmentVariable('MOTION_LIVE_SERIES_URL');
  if Copy(SeriesURL,1,33)<>'https://mangadistrict.com/series/' then
    raise Exception.Create('Set MOTION_LIVE_SERIES_URL to the public MangaDistrict series URL to test.');
  if SeriesURL[Length(SeriesURL)]<>'/' then SeriesURL+='/';
  if IsSSLloaded then DestroySSLInterface;
  DLLSSLName:=ExtractFilePath(ParamStr(0))+'libssl-1_1-x64.dll';
  DLLUtilName:=ExtractFilePath(ParamStr(0))+'libcrypto-1_1-x64.dll';
  Check(InitSSLInterface,'live SSL initialized');SSLImplementation:=TSSLOpenSSL;
  HTTP:=THTTPSendThread.Create;HTTP.Timeout:=30000;HTTP.RetryCount:=1;
  Pages:=TStringList.Create;ChapterLinks:=TStringList.Create;ChapterNames:=TStringList.Create;
  L:=LuaNewBaseState;
  OriginalDir:=Temp+'live-originals'+PathDelim;SavedDir:=Temp+'live-saved'+PathDelim;
  UnpackedDir:=Temp+'live-unpacked'+PathDelim;
  ForceDirectories(OriginalDir);ForceDirectories(SavedDir);ForceDirectories(UnpackedDir);
  try
    luaClassPushObject(L,HTTP,'HTTP',False,@luaHTTPSendThreadAddMetaTable);
    luaClassPushObject(L,Pages,'PAGES',False,@luaStringsAddMetaTable);
    luaClassPushObject(L,ChapterLinks,'CHAPTER_LINKS',False,@luaStringsAddMetaTable);
    luaClassPushObject(L,ChapterNames,'CHAPTER_NAMES',False,@luaStringsAddMetaTable);
    Run('MODULE={RootURL="https://mangadistrict.com"}; TASK={PageLinks=PAGES}; '+
      'MANGAINFO={URL="'+SeriesURL+'",ChapterLinks=CHAPTER_LINKS,ChapterNames=CHAPTER_NAMES}; URL=MANGAINFO.URL; '+
      'local t=require "templates.Madara"; t.GetInfo(); assert(MANGAINFO.Title~="" and CHAPTER_LINKS.Count>0);');
    Check(ChapterLinks.Count>0,'live series info and chapter discovery');
    WriteLn('LIVE chapters: ',ChapterLinks.Count);Flush(Output);
    Source:=ReadFile(Root+'lua'+PathDelim+'modules'+PathDelim+'MangaDistrict.lua');
    Run(Source);
    Run('URL="'+SeriesURL+'chapter-1/"; assert(GetPageNumber())');
    Check(Pages.Count>0,'live chapter discovered through actual HTTP and module');
    WriteLn('LIVE pages: ',Pages.Count);Flush(Output);
    Pages.SaveToFile(Temp+'live-links.txt');
    TotalBytes:=0;AVIFCount:=0;
    P:=TPacker.Create;
    try
      for I:=0 to Pages.Count-1 do begin
        HTTP.Reset;HTTP.AcceptImage;Run('BeforeDownloadImage()');
        Check(HTTP.GET(Pages[I]),'live GET page '+IntToStr(I+1));
        Source:=GetImageStreamExt(HTTP.Document);
        Check(Source<>'','live recognized page '+IntToStr(I+1));
        if Source='avif' then Inc(AVIFCount);
        Inc(TotalBytes,HTTP.Document.Size);
        HTTP.Document.SaveToFile(OriginalDir+Format('%.4d',[I])+'.'+Source);
        luaPushStringGlobal(L,'PATH',SavedDir);luaPushStringGlobal(L,'FILENAME',Format('%.4d',[I]));
        Run('SAVED_FILE=SaveImage();assert(SAVED_FILE~="")');
        lua_getglobal(L,'SAVED_FILE');Saved:=luaToString(L,-1);lua_pop(L,1);
        Check(ReadFile(Saved)=ReadFile(OriginalDir+ExtractFileName(Saved)), 'live original bytes page '+IntToStr(I+1));
        P.FileList.Add(Saved);WriteLn('LIVE downloaded ',I+1,'/',Pages.Count);Flush(Output);
      end;
      P.Path:=SavedDir;P.FileName:=Temp+'live-chapter';P.Format:=pfPDF;
      Check(P.Execute,'live chapter archived');
      Check(ExtractFileExt(P.SavedFileName)='.cbz','live mixed chapter uses safe CBZ fallback');
      Z:=TUnZipper.Create;
      try Z.FileName:=P.SavedFileName;Z.OutputPath:=UnpackedDir;Z.UnZipAllFiles;
      finally Z.Free; end;
      for I:=0 to P.FileList.Count-1 do begin
        Saved:=ExtractFileName(P.FileList[I]);
        Check(ReadFile(UnpackedDir+Saved)=ReadFile(OriginalDir+Saved),'live CBZ identical page '+IntToStr(I+1));
      end;
      WriteLn('LIVE RESULT: ',Pages.Count,' pages, ',AVIFCount,' AVIF, ',TotalBytes,' original bytes; all hashes/bytes preserved');
    finally P.Free; end;
  finally lua_close(L);Pages.Free;ChapterLinks.Free;ChapterNames.Free;HTTP.Free;end;
end;

begin
  try
    Root:=IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
    Fixtures:=Root+'motion'+PathDelim+'tests'+PathDelim+'fixtures'+PathDelim;
    Temp:=IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)))+'test-results'+PathDelim;
    ForceDirectories(Temp);
    Application.Initialize;
    DLLWebPName:=ExtractFilePath(ParamStr(0))+'libwebp.dll';
    InitWebPModule;
    MainForm:=TMainForm.CreateNew(nil);
    MainForm.cbOptionEnableLongNamePaths:=TCheckBox.Create(MainForm);
    MainForm.cbOptionEnableLongNamePaths.Checked:=False;
    OptionPNGSaveAsJPEG:=True; OptionWebPSaveAs:=2; OptionJPEGQuality:=90;
    HashTests;
    HeaderTest('', '', False, 'empty');
    HeaderTest('<html>error</html>', '', False, 'HTML rejection');
    HeaderTest(#0#0#0#24'ftypmif1'#0#0#0#0'avifmiaf', 'avif', True, 'compatible AVIF brand');
    HeaderTest(#0#0#0#20'ftypavis'#0#0#0#0'msf1', 'avif', True, 'AVIF sequence brand');
    HeaderTest(#0#0#0#24'ftypisom'#0#0#0#0'mp42avc1', 'mp4', True, 'MP4');
    HeaderTest(#0#0#0#24'ftypisom', '', False, 'truncated BMFF');
    HeaderTest(#$1A#$45#$DF#$A3#$8F#$42#$82#$84'webm'#$42#$87#$81#2, 'webm', True, 'WebM');
    HeaderTest(#$1A#$45#$DF#$A3#$8F#$42#$82#$88'matroska', '', False, 'Matroska rejection');
    HeaderTest(#137'PNG'#13#10#26#10+#0#1#$11#$70'tEXt'+StringOfChar('x',70000)+#0#0#0#0+#0#0#0#8'acTL'+StringOfChar(#0,12),'png',True,'APNG after large metadata');
    SaveTest('animated.avif','avif',True);
    SaveTest('animated.webp','webp',True);
    SaveTest('animated.gif','gif',True);
    SaveTest('animated.png','png',True);
    SaveTest('animated.mp4','mp4',True);
    SaveTest('animated.webm','webm',True);
    SaveTest('static.png','jpg',False);
    SaveTest('static.webp','jpg',False);
    Check(IsProtectedMotionModule('modules/MangaDistrict.lua'),'MangaDistrict updater protection');
    Check(IsProtectedMotionModule('motion/MangaDistrict.lua'),'motion helper updater protection');
    Check(not IsProtectedMotionModule('modules/MangaDex.lua'),'ordinary module updates allowed');
    Check(not IsMotionUpdatePackage('https://github.com/dazedcat19/FMD2/releases/download/3/fmd_3.7z'),'official binary blocked');
    Check(not IsMotionUpdatePackage('https://github.com.evil.test/x/f/releases/download/3/fmd-motion_3.7z'),'lookalike host blocked');
    Check(IsMotionUpdatePackage('https://github.com/example/fork/releases/download/3/fmd-motion_3.7z'),'motion package accepted');
    PackTest(True,pfPDF,'motion-pdf');
    PackTest(True,pfEPUB,'motion-epub');
    PackTest(True,pfCBZ,'motion-cbz');
    PackTest(False,pfPDF,'static-pdf');
    LuaTests;
    if (ParamCount>2) and (ParamStr(3)='--live') then LiveTests;
    MainForm.Free; MainForm:=nil;
    WriteLn('RESULT: ',Passed,' checks passed');
  except on E: Exception do begin WriteLn(E.ClassName,': ',E.Message); Halt(1); end; end;
end.
