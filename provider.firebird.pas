unit provider.firebird;

interface

uses
  provider,
  Data.DB,
  FireDAC.Stan.Def,
  FireDAC.Phys.FBDef,
  FireDAC.Stan.Intf,
  FireDAC.Stan.ASync,
  FireDAC.Phys,
  FireDAC.Phys.IBBase,
  FireDAC.Phys.FB,
  FireDAC.DApt,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.VCLUI.Wait,
  System.Classes;

type

  TProviderFirebird = class(TInterfacedObject, IProviderDatabase)
  private
    FConnection: TFDConnection;
    FQuery: TFDQuery;
    FDataSet: TFDMemTable;
    procedure LoadDatabaseParams;
  public

    constructor Create;
    destructor Destroy; override;

    function FillTableNames(const AList: TStrings): IProviderDatabase;
    function FillFieldNames(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillIndexNames(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillPrimaryKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillForeignKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillSequences(const AList: TStrings): IProviderDatabase;

    function ExistsField(const ATableName, AFieldName: string): boolean;

    function ConnectionString: string;

    function Clear: IProviderDatabase;
    function SetSQL(const ASQL: string): IProviderDatabase; overload;
    function SetSQL(const ASQL: TStrings): IProviderDatabase; overload;
    function SetDateTimeParam(const AName: string; const AValue: TDateTime): IProviderDatabase;
    function SetStringParam(const AName: string; const AValue: string): IProviderDatabase;
    function SetIntegerParam(const AName: string; const AValue: integer): IProviderDatabase;
    function SetDataset(ADataSet: TFDMemTable): IProviderDatabase;
    function Open: IProviderDatabase;
    function Execute: IProviderDatabase; overload;
    function Execute(out ARowsAffected: integer): IProviderDatabase; overload;
  end;

implementation

uses
  System.IOUtils,
  System.IniFiles,
  System.SysUtils,
  FireDAC.Phys.Intf;

{ TProviderFirebird }

function TProviderFirebird.Clear: IProviderDatabase;
begin
  Result := Self;
  FDataSet := nil;
  if FQuery.Active then
  begin
    FQuery.Close;
  end;
  FQuery.SQL.Clear;
end;

function TProviderFirebird.ConnectionString: string;
begin
  Result := FConnection.ConnectionString;
end;

constructor TProviderFirebird.Create;
begin
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'FB';
  FQuery := TFDQuery.Create(FConnection);
  FQuery.Connection := FConnection;
  LoadDatabaseParams;
end;

destructor TProviderFirebird.Destroy;
begin
  FQuery.Free;

  if FConnection.Connected then
    FConnection.Connected := False;

  FConnection.Free;
  inherited;
end;

function TProviderFirebird.Execute(out ARowsAffected: integer): IProviderDatabase;
begin
  Result := Self;
  ARowsAffected := -1;
  FQuery.ExecSQL;
  ARowsAffected := FQuery.RowsAffected;
end;

function TProviderFirebird.ExistsField(const ATableName, AFieldName: string): boolean;
var
  vList: TStrings;
begin
  vList := TStringList.Create;
  try
    FConnection.GetFieldNames(EmptyStr, EmptyStr, ATableName, EmptyStr, vList);
    Result := vList.IndexOf(UpperCase(AFieldName)) <> -1;
  finally
    vList.Free;
  end;
end;

function TProviderFirebird.FillFieldNames(const ATableName: string; AList: TStrings): IProviderDatabase;
begin
  Result := Self;

  if not Assigned(AList) then
    Exit;

  if ATableName.Trim.IsEmpty then
    Exit;

  AList.Clear;
  FConnection.GetFieldNames(EmptyStr, EmptyStr, ATableName, EmptyStr, AList);
end;

function TProviderFirebird.FillForeignKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
var
  vMetaInfoQuery: TFDMetaInfoQuery;
begin

  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;

  vMetaInfoQuery := TFDMetaInfoQuery.Create(FConnection);
  try
    vMetaInfoQuery.Connection := FConnection;
    vMetaInfoQuery.MetaInfoKind := mkForeignKeys;
    vMetaInfoQuery.ObjectName := ATableName;
    vMetaInfoQuery.Open;

    if not vMetaInfoQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not vMetaInfoQuery.Eof do
        begin
          AList.Add(vMetaInfoQuery.FieldByName('FKEY_NAME').AsString);
          vMetaInfoQuery.Next;
        end;
      finally
        AList.EndUpdate;
      end;
    end;

  finally
    vMetaInfoQuery.Free;
  end;
end;

function TProviderFirebird.FillIndexNames(const ATableName: string; AList: TStrings): IProviderDatabase;
begin
  Result := Self;
  if not Assigned(AList) then
    Exit;

  AList.Clear;
  FConnection.GetIndexNames(EmptyStr, EmptyStr, ATableName, EmptyStr, AList);
end;

function TProviderFirebird.FillPrimaryKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
var
  vMetaInfoQuery: TFDMetaInfoQuery;
begin
  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;
  vMetaInfoQuery := TFDMetaInfoQuery.Create(FConnection);
  try
    vMetaInfoQuery.Connection := FConnection;
    vMetaInfoQuery.MetaInfoKind := mkPrimaryKey;
    vMetaInfoQuery.ObjectName := ATableName;
    vMetaInfoQuery.Open;

    if not vMetaInfoQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not vMetaInfoQuery.Eof do
        begin
          AList.Add(vMetaInfoQuery.FieldByName('CONSTRAINT_NAME').AsString);
          vMetaInfoQuery.Next;
        end;
      finally
        AList.EndUpdate;
      end;
    end;

  finally
    vMetaInfoQuery.Free;
  end;
end;

function TProviderFirebird.FillSequences(const AList: TStrings): IProviderDatabase;
var
  vMetaInfoQuery: TFDMetaInfoQuery;
begin

  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;

  vMetaInfoQuery := TFDMetaInfoQuery.Create(FConnection);
  try
    vMetaInfoQuery.Connection := FConnection;
    vMetaInfoQuery.MetaInfoKind := mkGenerators;
    vMetaInfoQuery.Open;

    if not vMetaInfoQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not vMetaInfoQuery.Eof do
        begin
          AList.Add(vMetaInfoQuery.FieldByName('GENERATOR_NAME').AsString);
          vMetaInfoQuery.Next;
        end;
      finally
        AList.EndUpdate;
      end;
    end;

  finally
    vMetaInfoQuery.Free;
  end;
end;

function TProviderFirebird.FillTableNames(const AList: TStrings): IProviderDatabase;
begin
  Result := Self;
  if not Assigned(AList) then
    Exit;
  AList.Clear;
  FConnection.GetTableNames(EmptyStr, EmptyStr, EmptyStr, AList, [osMy], [tkTable]);
end;

function TProviderFirebird.Execute: IProviderDatabase;
var
  vRowsAffected: integer;
begin
  Result := Execute(vRowsAffected);
end;

function TProviderFirebird.Open: IProviderDatabase;
begin
  Result := Self;
  if Assigned(FDataSet) then
  begin
    if FDataSet.Active then
    begin
      FDataSet.EmptyDataSet;
    end;
    FQuery.Open;
    FDataSet.CloneCursor(FQuery);
  end;
end;

procedure TProviderFirebird.LoadDatabaseParams;
var
  vServerName,
  vPath : String;
  vIniFile: TIniFile;
begin
  vIniFile := TIniFile.Create(ChangeFileExt(ParamStr(0), '.conf'));
  try
    vServerName := vIniFile.ReadString( 'BANCO', 'SERVIDOR', '127.0.0.1' );
    vPath := vIniFile.ReadString( 'BANCO', 'PATHPAR', '');
  finally
    vIniFile.Free;
  end;

  FConnection.Params.Values['Database']:= vPath;
  FConnection.Params.Values['Server']:= vServerName;
  FConnection.Params.UserName := 'sysdba';
  FConnection.Params.Password := 'masterkey';
end;

function TProviderFirebird.SetDataset(ADataSet: TFDMemTable): IProviderDatabase;
begin
  Result := Self;
  FDataSet := ADataSet;
end;

function TProviderFirebird.SetDateTimeParam(const AName: string; const AValue: TDateTime): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsDateTime := AValue;
end;

function TProviderFirebird.SetIntegerParam(const AName: string; const AValue: integer): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsInteger := AValue;
end;

function TProviderFirebird.SetSQL(const ASql: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.SQL.Text := ASql;
end;

function TProviderFirebird.SetSQL(const ASql: TStrings): IProviderDatabase;
begin
  Result := SetSQL(ASql.Text);
end;

function TProviderFirebird.SetStringParam(const AName, AValue: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsString := AValue;
end;

end.
