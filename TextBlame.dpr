{
  TextBlame
  
  This code provides an "blame" function based on files.

  --------------------------------------------------------------------
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  THE SOFTWARE IS PROVIDED "AS IS" AND WITHOUT WARRANTY
  Author: Peter Lorenz
  You find the code useful? Donate!
  Paypal webmaster@peter-ebe.de
  --------------------------------------------------------------------

}

program TextBlame;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$APPTYPE CONSOLE}
{$R *.res}

uses
  Classes,
  SysUtils,
  unicode_def_unit in 'share\unicode\unicode_def_unit.pas',
  TextFile_unit in 'share\file\TextFile_unit.pas',
  Diff in 'ext\Diff.pas',
  HashUnit in 'ext\HashUnit.pas';

resourcestring
  rsparaametermissing = 'Nicht genügend Parameter übergeben';
  rspathdoesnotexists = 'Pfad &s existiert nicht';
  rsmorethanonefilerequired = 'Der Blame benötigt zwei oder mehr Dateien';

const
  bIgnoreCase = false;
  bIgnoreWhiteSpace = true;
  csResultFile = 'diff.txt';

var
  path: string = '';
  ext: string = '';
  currentSource: TStringList = nil;
  currentBlame: TStringList = nil;

  // ---------------------------------------------------------------------

function FilenameToBlameTag(filename: string): string;
begin
  Result := Changefileext(ExtractFileName(filename), '');
end;

procedure Init(filename: string);
var
  i: Integer;
begin
  if Assigned(currentSource) then
  begin
    FreeAndNil(currentSource);
  end;
  if Assigned(currentBlame) then
  begin
    FreeAndNil(currentBlame);
  end;
  currentSource := TStringList.Create;
  currentSource.LoadFromFile(filename);
  currentBlame := TStringList.Create;
  for i := 0 to currentSource.Count - 1 do
  begin
    currentBlame.Add(FilenameToBlameTag(filename));
  end;
end;

procedure Diff(filename: string);
var
  difffileSource: TStringList;
  newSource: TStringList;
  newBlame: TStringList;
  Diff: TDiff;
  hashlist1, hashlist2: TList;
  i: Integer;
begin
  difffileSource := TStringList.Create;
  newSource := TStringList.Create;
  newBlame := TStringList.Create;

  hashlist1 := TList.Create;
  hashlist2 := TList.Create;
  Diff := TDiff.Create(nil);

  try
    difffileSource.LoadFromFile(filename);

    for i := 0 to currentSource.Count - 1 do
      hashlist1.Add(HashLine(currentSource[i], bIgnoreCase, bIgnoreWhiteSpace));
    for i := 0 to difffileSource.Count - 1 do
      hashlist2.Add(HashLine(difffileSource[i], bIgnoreCase,
        bIgnoreWhiteSpace));

    Diff.Execute(PInteger(hashlist1.list), PInteger(hashlist2.list),
      hashlist1.Count, hashlist2.Count);
    if Diff.Cancelled then
      exit;

    for i := 0 to Diff.Count - 1 do
    begin
      if Diff.Compares[i].Kind <> TChangeKind.ckDelete then
      begin
        if (Diff.Compares[i].Kind = TChangeKind.ckAdd) or
          (Diff.Compares[i].Kind = TChangeKind.ckModify) then
          newBlame.Add(FilenameToBlameTag(filename))
        else
          newBlame.Add(currentBlame.Strings[Diff.Compares[i].oldIndex1]);
        newSource.Add(difffileSource.Strings[Diff.Compares[i].oldIndex2]);
      end;
    end;

    currentSource.Assign(difffileSource);
    currentBlame.Assign(newBlame);
  finally
    FreeAndNil(difffileSource);
    FreeAndNil(newSource);
    FreeAndNil(newBlame);

    FreeAndNil(hashlist1);
    FreeAndNil(hashlist2);
    FreeAndNil(Diff);
  end;
end;

// ---------------------------------------------------------------------

procedure WriteResult;

  function fill(s: string; l: Integer): string;
  begin
    while length(s) < l do
      s := s + ' ';
    Result := s;
  end;

var
  f: TTextFileWriter;
  i, lenmax: Integer;
  s: string;
begin
  f := nil;
  try
    f := TTextFileWriter.Create(path + csResultFile, false);

    lenmax := 0;
    for i := 0 to currentBlame.Count - 1 do
    begin
      if length(currentBlame[i]) > lenmax then
        lenmax := length(currentBlame[i]);
    end;

    for i := 0 to currentSource.Count - 1 do
    begin
      s := fill(currentBlame.Strings[i], lenmax) + '|' +
        currentSource.Strings[i];
      f.WriteLine(s);
      writeln(s);
    end;
    // {$IFDEF DEBUG}
    // currentSource.SaveToFile(path + 'current.txt');
    // {$ENDIF}
  finally
    FreeAndNil(f);
  end;
end;

// ---------------------------------------------------------------------

var
  filelist: TStringList;
  res: Integer;
  sr: TSearchRec;
  i: Integer;

begin
{$IFNDEF FPC}
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := true;
  IsConsole := false;
  // Debug BUGfix, Memoryleaks werden als Dialog gezeigt und im Consolenmodus einfach verschluckt
{$ENDIF}
{$ENDIF}
  if ParamCount < 2 then
  begin
    writeln(rsparaametermissing);
    exit;
  end;
  path := IncludeTrailingPathDelimiter(paramstr(1));
  if not DirectoryExists(path) then
  begin
    writeln(format(rspathdoesnotexists, [path]));
    exit;
  end;
  ext := paramstr(2);

  filelist := TStringList.Create;
  filelist.Sorted := false;
  try
    res := FindFirst(path + '*.' + ext, faAnyFile, sr);
    while res = 0 do
    begin
      filelist.Add(path + sr.Name);
      res := FindNext(sr);
    end;
    if filelist.Count < 2 then
    begin
      writeln(format(rsmorethanonefilerequired, [path]));
      exit;
    end;
    filelist.Sort;

    Init(filelist.Strings[0]);
    for i := 1 to filelist.Count - 1 do
    begin
      Diff(filelist.Strings[i]);
    end;
    WriteResult;
  except
    on E: Exception do
    begin
      writeln(E.ClassName, ': ', E.Message);
    end;
  end;
  FreeAndNil(filelist);
  FreeAndNil(currentSource);
  FreeAndNil(currentBlame);

end.
