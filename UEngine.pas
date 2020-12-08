unit UEngine;

interface

uses System.Classes, UConfig;

type
 TEngine = class(TThread)
  protected
    procedure Execute; override;
  private
    LastTick: Cardinal; //GPU update controller

    Queue: record
      Log: TStringList;
      Status: string;
      Percent: Byte;
    end;

    procedure Log(const Text: string; ForceUpdate: Boolean = True);
    procedure Status(const Text: string; ForceUpdate: Boolean = True);
    procedure Percent(Value: Byte);

    procedure DoDefinition(Def: TDefinition);
    procedure CheckForQueueFlush(ForceUpdate: Boolean);
    procedure CopyFile(SourceFile, DestinationFile: string);
  public
    constructor Create;
    destructor Destroy; override;
 end;

implementation

uses UFrmMain, System.SysUtils, System.IOUtils, DzDirSeek;

constructor TEngine.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;

  LastTick := GetTickCount;
  Queue.Log := TStringList.Create;
end;

destructor TEngine.Destroy;
begin
  Queue.Log.Free;

  inherited;

  Synchronize(
    procedure
    begin
      FrmMain.SetControlsState(True);
    end);
end;

procedure TEngine.Execute;
var
  D: TDefinition;
begin
  try
    for D in Config.LstDefinition do
      if D.Checked then DoDefinition(D);
  except
    on E: Exception do
      Log('#ERROR: '+E.Message);
  end;

  CheckForQueueFlush(True); //remaining log
end;

procedure TEngine.Log(const Text: string; ForceUpdate: Boolean);
begin
  Queue.Log.Add(Text);

  CheckForQueueFlush(ForceUpdate);
end;

procedure TEngine.Status(const Text: string; ForceUpdate: Boolean);
begin
  Queue.Status := Text;

  CheckForQueueFlush(ForceUpdate);
end;

procedure TEngine.Percent(Value: Byte);
begin
  Queue.Percent := Value;

  CheckForQueueFlush(False);
end;

procedure TEngine.CheckForQueueFlush(ForceUpdate: Boolean);
begin
  if ForceUpdate or (GetTickCount > LastTick+1000) then
  begin
    Synchronize(
      procedure
      var
        A: string;
      begin
        for A in Queue.Log do
          FrmMain.LLogs.Items.Add(A);

        FrmMain.LbStatus.Caption := Queue.Status;
        FrmMain.ProgressBar.Position := Queue.Percent;

        if not FrmMain.BtnStop.Enabled then
          raise Exception.Create('Process aborted by user');
      end);

    Queue.Log.Clear;

    //
    LastTick := GetTickCount;
  end;
end;

procedure TEngine.DoDefinition(Def: TDefinition);

  procedure PrepareDirSeek(DS: TDzDirSeek; const Dir: string; SubDir: Boolean;
    const Inclusions, Exclusions: string);
  begin
    DS.Dir := Dir;
    DS.SubDir := SubDir;
    DS.Sorted := True;
    DS.ResultKind := rkRelative;
    DS.UseMask := True;
    DS.Inclusions.Text := Inclusions;
    DS.Exclusions.Text := Exclusions;

    DS.List.CaseSensitive := False;
  end;

var
  DS_Src, DS_Dest: TDzDirSeek;
  A: string;
  SourceFile, DestFile: string;
begin
  Log('@'+Def.Name);
  Status(string.Empty);

  if not TDirectory.Exists(Def.Source) then
    raise Exception.Create('Source not found');

  if not TDirectory.Exists(Def.Destination) then
    raise Exception.Create('Destination not found');

  DS_Src := TDzDirSeek.Create(nil);
  DS_Dest := TDzDirSeek.Create(nil);
  try
    PrepareDirSeek(DS_Src, Def.Source, Def.Recursive, Def.Inclusions, Def.Exclusions);
    PrepareDirSeek(DS_Dest, Def.Destination, True, string.Empty, string.Empty);

    Status('Scanning source...');
    DS_Src.Seek;

    Status('Scanning destination...');
    DS_Dest.Seek;

    Status(string.Empty);

    for A in DS_Src.List do
    begin
      SourceFile := TPath.Combine(Def.Source, A);
      DestFile := TPath.Combine(Def.Destination, A);

      if DS_Dest.List.IndexOf(A) = -1 then
      begin
        //new file
        Log('+'+A, False);
        Status('Appending '+A, False);

        if not TDirectory.Exists(ExtractFilePath(DestFile)) then
          ForceDirectories(ExtractFilePath(DestFile));

        CopyFile(SourceFile, DestFile);
      end else
      begin
        //existent file
        if TFile.GetLastWriteTime(SourceFile) <>
           TFile.GetLastWriteTime(DestFile) then
        begin
          Log('~'+A, False);
          Status('Updating '+A, False);

          CopyFile(SourceFile, DestFile);
        end;
      end;

      Status(string.Empty, False);
      Percent(0);
    end;

    if Def.Delete then
    begin
      for A in DS_Dest.List do
      begin
        if DS_Src.List.IndexOf(A) = -1 then
        begin
          //removed file
          Log('-'+A, False);
          Status('Deleting '+A, False);

          TFile.Delete(TPath.Combine(Def.Destination, A));
        end;
      end;
    end;

  finally
    DS_Src.Free;
    DS_Dest.Free;
  end;

  Def.LastUpdate := Now;
end;

procedure TEngine.CopyFile(SourceFile, DestinationFile: string);
const
  MaxBufSize = $F000;
var
  SourceStm, DestStm: TFileStream;
  BufSize, N: Integer;
  Buffer: TBytes;
  Count: Int64;
begin
  SourceStm := TFileStream.Create(SourceFile, fmOpenRead);
  try
    DestStm := TFileStream.Create(DestinationFile, fmCreate);
    try
      Count := SourceStm.Size;
      if Count > MaxBufSize then BufSize := MaxBufSize else BufSize := Count;
      SetLength(Buffer, BufSize);
      try
        while Count <> 0 do
        begin
          if Count > BufSize then N := BufSize else N := Count;
          SourceStm.ReadBuffer(Buffer, N);
          DestStm.WriteBuffer(Buffer, N);
          Dec(Count, N);

          Percent(Trunc(DestStm.Size / SourceStm.Size * 100));
        end;
      finally
        SetLength(Buffer, 0);
      end;
    finally
      DestStm.Free;
    end;
  finally
    SourceStm.Free;
  end;

  TFile.SetLastWriteTime(DestinationFile, TFile.GetLastWriteTime(SourceFile));
end;

end.