//**********************************************************************************************************************
//  $Id: Main.pas,v 1.6 2006-06-17 04:19:28 dale Exp $
//----------------------------------------------------------------------------------------------------------------------
//  DKLang Localization Package
//  Copyright 2002-2006 DK Software, http://www.dk-soft.org
//**********************************************************************************************************************
unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, DKLang;

type
  TfMain = class(TForm)
    bTest: TButton;
    cbLanguage: TComboBox;
    lcMain: TDKLanguageController;
    lSampleMessage: TLabel;
    procedure bTestClick(Sender: TObject);
    procedure cbLanguageChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  end;

var
  fMain: TfMain;

resourcestring
  STestMessage    = 'This is a test message';
  SMessageCaption = 'Message';

implementation
{$R *.dfm}

  procedure TfMain.bTestClick(Sender: TObject);
  begin
    Application.MessageBox(PChar(STestMessage), PChar(SMessageCaption), MB_ICONINFORMATION or MB_OK);
  end;

  procedure TfMain.cbLanguageChange(Sender: TObject);
  var iIndex: Integer;
  begin
    iIndex := cbLanguage.ItemIndex;
    if iIndex<0 then iIndex := 0; // When there's no valid selection in cbLanguage we use the default language (Index=0)
    LangManager.LanguageID := LangManager.LanguageIDs[iIndex];
  end;

  procedure TfMain.FormCreate(Sender: TObject);
  var i: Integer;
  begin
     // Scan for language files in the app directory and register them in the LangManager object
    LangManager.ScanForLangFiles(ExtractFileDir(ParamStr(0)), '*.lng', False);
     // Fill cbLanguage with available languages
    for i := 0 to LangManager.LanguageCount-1 do cbLanguage.Items.Add(LangManager.LanguageNames[i]);
     // Index=0 always means the default language
    cbLanguage.ItemIndex := 0; 
  end;

end.
