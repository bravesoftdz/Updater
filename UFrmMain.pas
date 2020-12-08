unit UFrmMain;

interface

uses Vcl.Forms, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Controls, Vcl.CheckLst,
  System.ImageList, Vcl.ImgList, Vcl.ComCtrls, System.Classes, Vcl.ToolWin,
  //
  UConfig;

type
  TFrmMain = class(TForm)
    ToolBar: TToolBar;
    BtnNew: TToolButton;
    BtnEdit: TToolButton;
    BtnRemove: TToolButton;
    ToolButton4: TToolButton;
    BtnUp: TToolButton;
    BtnDown: TToolButton;
    ToolButton7: TToolButton;
    BtnMasks: TToolButton;
    ToolButton9: TToolButton;
    BtnExecute: TToolButton;
    IL: TImageList;
    LDefs: TCheckListBox;
    LLogs: TListBox;
    Splitter1: TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnNewClick(Sender: TObject);
    procedure BtnEditClick(Sender: TObject);
    procedure BtnRemoveClick(Sender: TObject);
    procedure BtnUpClick(Sender: TObject);
    procedure BtnDownClick(Sender: TObject);
    procedure LDefsClick(Sender: TObject);
    procedure LDefsClickCheck(Sender: TObject);
  private
    procedure FillDefinitions;
    procedure MoveDefinition(Flag: Integer);
    function AddDefinition(Def: TDefinition): Integer;
    function GetSelectedDefinition: TDefinition;
    procedure UpdateButtons;
  end;

var
  FrmMain: TFrmMain;

implementation

{$R *.dfm}

uses UFrmDefinition, System.SysUtils,
  Vcl.Dialogs, System.UITypes;

procedure TFrmMain.FormCreate(Sender: TObject);
begin
  Config := TConfig.Create;
  Config.LoadDefinitions;

  FillDefinitions;

  UpdateButtons;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
begin
  Config.SaveDefinitions;
  Config.Free;
end;

procedure TFrmMain.UpdateButtons;
var
  Sel: Boolean;
begin
  Sel := LDefs.ItemIndex <> -1;

  BtnEdit.Enabled := Sel;
  BtnRemove.Enabled := Sel;

  BtnUp.Enabled := Sel and (LDefs.ItemIndex > 0);
  BtnDown.Enabled := Sel and (LDefs.ItemIndex < LDefs.Count-1);
end;

procedure TFrmMain.LDefsClick(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TFrmMain.LDefsClickCheck(Sender: TObject);
var
  D: TDefinition;
begin
  D := GetSelectedDefinition;
  D.Checked := LDefs.Checked[LDefs.ItemIndex];
end;

function TFrmMain.GetSelectedDefinition: TDefinition;
begin
  Result := TDefinition(LDefs.Items.Objects[LDefs.ItemIndex]);
end;

function TFrmMain.AddDefinition(Def: TDefinition): Integer;
begin
  Result := LDefs.Items.AddObject(Def.Name, Def);
end;

procedure TFrmMain.FillDefinitions;
var
  D: TDefinition;
  Index: Integer;
begin
  for D in Config.LstDefinition do
  begin
    Index := AddDefinition(D);
    LDefs.Checked[Index] := D.Checked;
  end;
end;

procedure TFrmMain.BtnNewClick(Sender: TObject);
var
  D: TDefinition;
  Index: Integer;
begin
  if DoEditDefinition(False, D) then
  begin
    Index := AddDefinition(D);
    LDefs.ItemIndex := Index;

    UpdateButtons;
  end;
end;

procedure TFrmMain.BtnEditClick(Sender: TObject);
var
  D: TDefinition;
begin
  D := GetSelectedDefinition;
  if DoEditDefinition(True, D) then
  begin
    LDefs.Items[LDefs.ItemIndex] := D.Name;
  end;
end;

procedure TFrmMain.BtnRemoveClick(Sender: TObject);
var
  D: TDefinition;
begin
  D := GetSelectedDefinition;
  if MessageDlg('Do you want to remove definition "'+D.Name+'"?',
    mtConfirmation, mbYesNo, 0) = mrYes then
  begin
    Config.LstDefinition.Remove(D);
    LDefs.DeleteSelected;

    UpdateButtons;
  end;
end;

procedure TFrmMain.MoveDefinition(Flag: Integer);
var
  Index, NewIndex: Integer;
begin
  Index := LDefs.ItemIndex;
  NewIndex := Index + Flag;

  Config.LstDefinition.Exchange(Index, NewIndex);
  LDefs.Items.Exchange(Index, NewIndex);

  UpdateButtons;
end;

procedure TFrmMain.BtnUpClick(Sender: TObject);
begin
  MoveDefinition(-1);
end;

procedure TFrmMain.BtnDownClick(Sender: TObject);
begin
  MoveDefinition(+1);
end;

end.
