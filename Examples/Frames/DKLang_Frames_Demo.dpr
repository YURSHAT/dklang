//**********************************************************************************************************************
//  $Id: DKLang_Frames_Demo.dpr,v 1.3 2006-06-17 04:19:28 dale Exp $
//----------------------------------------------------------------------------------------------------------------------
//  DKLang Localization Package
//  Copyright 2002-2006 DK Software, http://www.dk-soft.org
//**********************************************************************************************************************
program DKLang_Frames_Demo;

uses
  Forms,
  Main in 'Main.pas' {fMain},
  ufrFontSettings in 'ufrFontSettings.pas' {frFontSettings: TFrame};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.Run;
end.
