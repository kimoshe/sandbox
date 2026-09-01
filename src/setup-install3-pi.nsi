; TODO List
; Consider whether Finish_Documentation_URL and Finish_Donate_URL should be a LANG string or !define
; Desired translations  German, Spanish, French, Italian, Portuguese and Chinese
; Where in the repo to store the translations file
; Review for consistent coding,
;       named variables versus internal $0 like one.
;       macros for common code
;       consistent comment format
;       useful comments
;       order of the various sections
;       remove unused LANG strings
;       remove unnecessary commented lines
;       remove unneeded !includes
;       remove any unneeded !macros
;       all strings in the LANG list
;       look for redundant ClearErrors
; Remove /RESIZETOFIT: The ${NSD_SetImage} macro does not accept /RESIZETOFIT.
;   That flag is for the standard MUI page logic. For custom pages,
;   use ${NSD_SetStretchedImage} if you need resizing, or ensure your BMP matches the
;   control size (109x193) exactly. <-- Size is not correct
; Should uninst.exe be renamed uninstall.exe?  (WriteUninstall command)
; Check that the tag line and the line show everywhere they are supposed to and not where they shouldn't
; ci setup needs to install NSIS v3.12
; Update SignArtisanExe.ahk to support the translation file and any other custom !includes
; Where in the repo to store the translations file and other needed includes like images and uninstall.ico

; 109u 193u approx. 0.5647668393  vs  164 314 approx. 0.5222929936
; 245x460 maybe  or 245x469 at 144
; 388ish at 120, trying 204x390

; Common Font Weight Values:
; 400: Normal (Regular)
; 700: Bold
; 600: Semi-Bold

; ABOUT
; NSIS script file for artisan Windows installer.
;
; COPYRIGHT (C) 2010-2026 The artisan team represented by
; Marko Luther <marko.luther@gmx.net> (maintainer) and all contributors
;
; LICENSE
; This program or module is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU Affero General Public License for more details.
;
; You should have received a copy of the GNU Affero General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
; the GNU General Public License for more details.
;
; AUTHOR
; Dave Baxter, Marko Luther 2023-2026
;

; .nsi command line options:
;    /DPRODUCT_VERSION=ww.xx.yy     -explicitly set the product version, default is 0.0.0
;    /DPRODUCT_BUILD=zz             -explicityl set the product build, default is 0
;    /DSIGN                         -Use with SignArtisan to prevent gernating new uninstall.exe
;                                    Note: SignArtisan is not a part of the ci process
;
; installer command line options
;    /S                             -silent operation

;  Artisan #RRGGBB is #2899c7

; -----------------------------------------------------------------------------
; INCLUDES
; -----------------------------------------------------------------------------
!include "x64.nsh"
!include "WinVer.nsh"
!include "FileFunc.nsh"
!include "MUI2.nsh"
; Note - the following are included by reference in MUI2
;   !include WinMessages.nsh
;   !include LogicLib.nsh
;   !include nsDialogs.nsh
;   !include LangFile.nsh

; -----------------------------------------------------------------------------
; COMPILER FLAGS
; -----------------------------------------------------------------------------
RequestExecutionLevel admin
SetCompressor /SOLID lzma
ManifestDPIAware true

; -----------------------------------------------------------------------------
; CHECK NSIS MINIMUM VERSION AT COMPILE TIME (DURING CI)
; -----------------------------------------------------------------------------
; 0x + Major(2 digits) + Minor(3 digits) + Revision(2 digits) + Build(1 digit)
!if ${NSIS_PACKEDVERSION} < 0x03011000  ; Require NSIS 3.12 or higher
  !error "NSIS 3.11 or higher is required to build this installer!"
!endif

; -----------------------------------------------------------------------------
; MACROS
; -----------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; Macros for making and removing associations
; ---------------------------------------------------------------------------
!macro APP_ASSOCIATE_URL FILECLASS DESCRIPTION COMMANDTEXT COMMAND
    WriteRegStr HKCR "${FILECLASS}" "" `${DESCRIPTION}`
    WriteRegStr HKCR "${FILECLASS}" "URL Protocol" ""
    WriteRegStr HKCR "${FILECLASS}\shell" "" "open"
    WriteRegStr HKCR "${FILECLASS}\shell\open" "" `${COMMANDTEXT}`
    WriteRegStr HKCR "${FILECLASS}\shell\open\command" "" `${COMMAND}`
!macroend

!macro APP_ASSOCIATE EXT FILECLASS DESCRIPTION ICON COMMANDTEXT COMMAND
    ; Backup the previously associated file class
    ReadRegStr $R0 HKCR ".${EXT}" ""
    WriteRegStr HKCR ".${EXT}" "${FILECLASS}_backup" "$R0"
    WriteRegStr HKCR ".${EXT}" "" "${FILECLASS}"
    WriteRegStr HKCR "${FILECLASS}" "" `${DESCRIPTION}`
    WriteRegStr HKCR "${FILECLASS}\DefaultIcon" "" `${ICON}`
    WriteRegStr HKCR "${FILECLASS}\shell" "" "open"
    WriteRegStr HKCR "${FILECLASS}\shell\open" "" `${COMMANDTEXT}`
    WriteRegStr HKCR "${FILECLASS}\shell\open\command" "" `${COMMAND}`
!macroend

!macro APP_UNASSOCIATE EXT FILECLASS
    ; Backup the previously associated file class
    ReadRegStr $R0 HKCR ".${EXT}" `${FILECLASS}_backup`
    WriteRegStr HKCR ".${EXT}" "" "$R0"
    DeleteRegKey HKCR `${FILECLASS}`
!macroend

!macro UPDATEFILEASSOC
; Using the system.dll plugin to call the SHChangeNotify Win32 API function so we
; can update the shell.
     System::Call "shell32::SHChangeNotify(i,i,i,i) (${SHCNE_ASSOCCHANGED}, ${SHCNF_FLUSH}, 0, 0)"
!macroend


; ---------------------------------------------------------------------------
; Macro to remove directory with wildcards
; ---------------------------------------------------------------------------
!macro Rmdir_Wildcard dir uid
    ; RMDIR with wildcard, dir in the form $INSTDIR\dir_with_wildcard, uid should be ${__LINE__}
    FindFirst $0 $1 ${dir}
    loop_${uid}:
        StrCmp $1 "" endloop_${uid}
        RMDIR /r "$INSTDIR\$1"
        FindNext $0 $1
        Goto loop_${uid}
    endloop_${uid}:
    FindClose $0
!macroend

; ---------------------------------------------------------------------------
; Macro to identify when an artisan instance is running
; ---------------------------------------------------------------------------
!macro IsRunning
    Delete "$TEMP\25b241e1.tmp"
    nsExec::Exec "cmd /c for /f $\"tokens=1,2$\" %i in ('tasklist') do (if /i %i EQU ${PRODUCT_NAME}.exe fsutil file createnew $TEMP\25b241e1.tmp 0)"
    IfFileExists $TEMP\25b241e1.tmp 0 notRunning
        ;we have at least one main window active
        MessageBox MB_OK|MB_ICONEXCLAMATION "$(Alert_App_IsRunning)" /SD IDOK
        Delete "$TEMP\25b241e1.tmp"
        Quit
    notRunning:
!macroend

; ---------------------------------------------------------------------------
; Macro to SetProgressBarColor   Note: FgColor is BBGGRR
; ---------------------------------------------------------------------------
!macro SetProgressBarColor FgColor BgColor
    ; Find the inner dialog of the current page
    FindWindow $0 "#32770" "" $HWNDPARENT

    ; Get the progress bar handle by Class Name
    FindWindow $1 "msctls_progress32" "" $0

    ${If} $1 <> 0
        ; Disable Visual Styles (Themes)
        System::Call 'UxTheme::SetWindowTheme(i $1, w "", w "")'
        ; Set the colors
        SendMessage $1 ${PBM_SETBARCOLOR} 0 "0x${FgColor}"
        SendMessage $1 ${PBM_SETBKCOLOR} 0 "0x${BgColor}"
    ${EndIf}
!macroend

; ---------------------------------------------------------------------------
; Macro to prevent running multiple instances
; ---------------------------------------------------------------------------
!macro CheckForRunningInstances
    System::Call 'KERNEL32::CreateMutex(i 0, i 0, t "${INSTALLMUTEX}") i .r1 ?e'
    Pop $0
    IntCmpU $0 183 anotherRunning noneRunning  ; ERROR_ALREADY_EXISTS = 183
    anotherRunning:
        MessageBox MB_OK "$(Another_Instance)"
        Abort
    noneRunning:
!macroend


; ---------------------------------------------------------------------------
;Unused macros
; ---------------------------------------------------------------------------
!macro APP_ASSOCIATE_EX EXT FILECLASS DESCRIPTION ICON VERB DEFAULTVERB SHELLNEW COMMANDTEXT COMMAND
    ; Backup the previously associated file class
    ReadRegStr $R0 HKCR ".${EXT}" ""
    WriteRegStr HKCR ".${EXT}" "${FILECLASS}_backup" "$R0"
    WriteRegStr HKCR ".${EXT}" "" "${FILECLASS}"
    StrCmp "${SHELLNEW}" "0" +2
    WriteRegStr HKCR ".${EXT}\ShellNew" "NullFile" ""
    WriteRegStr HKCR "${FILECLASS}" "" `${DESCRIPTION}`
    WriteRegStr HKCR "${FILECLASS}\DefaultIcon" "" `${ICON}`
    WriteRegStr HKCR "${FILECLASS}\shell" "" `${DEFAULTVERB}`
    WriteRegStr HKCR "${FILECLASS}\shell\${VERB}" "" `${COMMANDTEXT}`
    WriteRegStr HKCR "${FILECLASS}\shell\${VERB}\command" "" `${COMMAND}`
!macroend

!macro APP_ASSOCIATE_ADDVERB FILECLASS VERB COMMANDTEXT COMMAND
    WriteRegStr HKCR "${FILECLASS}\shell\${VERB}" "" `${COMMANDTEXT}`
    WriteRegStr HKCR "${FILECLASS}\shell\${VERB}\command" "" `${COMMAND}`
!macroend

!macro APP_ASSOCIATE_REMOVEVERB FILECLASS VERB
    DeleteRegKey HKCR `${FILECLASS}\shell\${VERB}`
!macroend

!macro APP_ASSOCIATE_GETFILECLASS OUTPUT EXT
    ReadRegStr ${OUTPUT} HKCR ".${EXT}" ""
!macroend
;End Unused macros ------


; -----------------------------------------------------------------------------
; PRODUCT AND GENERAL VARIABLES
; -----------------------------------------------------------------------------
; Declare global variables
Var PathToUninstaller
Var Dialog
Var ShowFinish
Var CheckboxState
Var CheckboxRunApp
Var CheckboxOpenDocs
Var CheckboxOpenDonate
Var UseInstallPath
Var UpgradeFlow
Var IsProgressMode      ; 1 = /SHOWPROGRESS mode
Var IsSilentMode        ; 1 = /S mode

!define pyinstallerOutputDir "dist/artisan"
;# dave  !define pyinstallerOutputDir '/temp/MungeArtisanNSI'
!define nsisLocalIncludesDir "nsis_local_includes"
!define PRODUCT_NAME "artisan"
!define PRODUCT_NAME_CAP "Artisan"
!define PRODUCT_PUBLISHER "The Artisan Team"
!define PRODUCT_WEB_SITE "https://github.com/artisan-roaster-scope/artisan/blob/master/README.md"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\${PRODUCT_NAME}.exe"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"
; The following gets transposed to "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\artisan-skeleton"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

!define Finish_Documentation_URL "https://artisan-scope.org/docs/"
!define Finish_Donate_URL "https://artisan-scope.org/donate/"

; Special commandline options
; Product version and build can be defined on the command line '/DPRODUCT_VERSION=ww.xx.yy'
;   and '/DPRODUCT_VERSION=zz' These will override the default version an build explicitly set below.

; #dave CHANGE THIS BACK TO 0.0.0
;!define /ifndef PRODUCT_VERSION "4.4.2"
!define /ifndef PRODUCT_VERSION "0.0.0"
!define /ifndef PRODUCT_BUILD "0"

!define /date CUR_YEAR "%Y"

; For use with SHChangeNotify, Note: !undef here to prevent makensis "symbol already defined" errors
!ifdef SHCNE_ASSOCCHANGED
    !undef SHCNE_ASSOCCHANGED
!endif
!define SHCNE_ASSOCCHANGED 0x08000000
!ifdef SHCNF_FLUSH
    !undef SHCNF_FLUSH
!endif
!define SHCNF_FLUSH 0x1000

; Font values
!define Font_Name "Segoe UI"
!define Font_Size_Title "12"
!define Font_Size_Body "10"
!define Font_Size_Option "9.5"
!define Font_Weight "600"
!define Font_Weight_Option "400"

; -----------------------------------------------------------------------------
; MUI CONFIGURATION
; -----------------------------------------------------------------------------
; General
!define MUI_ABORTWARNING
; #dave for test only
; #dave !define MUI_FINISHPAGE_NOAUTOCLOSE  ; Prevents auto-jump from InstFiles page to Finish page
;!define MUI_INSTALLCOLORS "C79928 FFFFFF"   #dave

; INSTALL
!define MUI_ICON "${PRODUCT_NAME}.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${nsisLocalIncludesDir}\header-install.bmp"
!define MUI_HEADERIMAGE_BITMAP_STRETCH "FitControl"
!define MUI_HEADERIMAGE_RIGHT
!define MUI_WELCOMEFINISHPAGE_BITMAP "${nsisLocalIncludesDir}\sidebar-install.bmp"
!define MUI_BGCOLOR "2899c7"
!define MUI_TEXTCOLOR "FFFFFF"
!define MUI_INSTFILESPAGE_PROGRESSBAR "colored"

; UNINSTALL
!define MUI_UNICON "${nsisLocalIncludesDir}\uninstall.ico"
!define MUI_HEADERIMAGE_UNBITMAP "${nsisLocalIncludesDir}\header-uninstall.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "${nsisLocalIncludesDir}\sidebar-uninstall.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP_STRETCH "FitControl"
!define MUI_FINISHPAGE_TITLE "$(UnFinish_Title)"  ;used only for uninstall
!define MUI_FINISHPAGE_TEXT "$(UnFinish_Text)"    ;used only for uninstall


; ============================================================================
; INSTALLER PAGES
; ============================================================================

; Welcome page
Page custom CustomWelcomeUpgradeCreator CustomWelcomeUpgradeLeave
Page custom CustomWelcomeFreshCreator CustomWelcomeFreshLeave

; Directory page
!define MUI_DIRECTORYPAGE_VARIABLE $UseInstallPath
!define MUI_PAGE_CUSTOMFUNCTION_PRE DirectoryPre
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DirectoryShow
!insertmacro MUI_PAGE_DIRECTORY

; Instfiles page
!define MUI_PAGE_CUSTOMFUNCTION_PRE InstFilesPre
!define MUI_PAGE_CUSTOMFUNCTION_SHOW CustomInstFilesCreator
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE InstFilesLeave
!insertmacro MUI_PAGE_INSTFILES

; Finish page
Page custom CustomFinishPageCreate CustomFinishPageLeave

; ============================================================================
; UNINSTALLER PAGES
; ============================================================================

; Un_Welcome page
UninstPage custom un.WelcomeShow un.WelcomeLeave

; Un_Instfiles page
!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.InstFilesShow
!insertmacro MUI_UNPAGE_INSTFILES

; Un_Finish page
!define MUI_PAGE_CUSTOMFUNCTION_PRE un.PreFinish
!define MUI_PAGE_CUSTOMFUNCTION_SHOW un.FinishShow
!insertmacro MUI_UNPAGE_FINISH

; ============================================================================
; LANGUAGE  (must come after MUI configuration))
; ============================================================================
!insertmacro MUI_LANGUAGE "English"
!include "${nsisLocalIncludesDir}\install_translations.nsh"

; MUI end ------

; ============================================================================
; SET VARIABLES
; ============================================================================
Name "${PRODUCT_NAME}"
OutFile "${PRODUCT_NAME}-win-x64-${PRODUCT_VERSION}-setup.exe"
InstallDir "C:\Program Files\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
ShowInstDetails show
ShowUnInstDetails show
UninstallCaption "$(Caption_Uninstall)"
BrandingText "$(Tag_Line)"

VIProductVersion "${PRODUCT_VERSION}.${PRODUCT_BUILD}"
VIAddVersionKey ProductName "${PRODUCT_NAME}"
VIAddVersionKey Comments "Installer for ${PRODUCT_NAME}"
VIAddVersionKey CompanyName ""
VIAddVersionKey LegalCopyright "Copyright 2010-${CUR_YEAR}, Artisan developers. GNU Affero General Public License"
VIAddVersionKey FileVersion "${PRODUCT_VERSION}.${PRODUCT_BUILD}"
VIAddVersionKey FileDescription "${PRODUCT_NAME} Installer"
VIAddVersionKey ProductVersion "${PRODUCT_VERSION}.${PRODUCT_BUILD}"

!define INSTALLMUTEX "{c2a7be4e-da57-44b9-b2cf-5b1f80c6b429}"
; #dave !define UNINSTALLMUTEX "{cfa406d5-b8d0-49f8-94ca-1834e490ced5}"

; ============================================================================
; INSTALL on.Init
; ============================================================================
Function .onInit
    ; Prevent multiple instances of install / uninstall
    !insertmacro CheckForRunningInstances

    ; Check for x64 Windows platform
    ${IfNot} ${RunningX64}
        MessageBox MB_OK "$(Alert_Windows_Arch)"
        Abort
    ${EndIf}

    ; Check the Windows version is appropriate
    ${IfNot} ${AtLeastWin10}
        MessageBox MB_ICONSTOP "$(Alert_Windows_Version)"
        Abort
    ${EndIf}

    ; Stop if there is a running instance of the app
    !insertmacro IsRunning

    StrCpy $ShowFinish 1

    ; Extract image
    InitPluginsDir
    File /oname=$PLUGINSDIR\sidebar.bmp "${MUI_WELCOMEFINISHPAGE_BITMAP}"

    ; Check for existing installation
    ReadRegStr $PathToUninstaller ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString"
    StrCmp $PathToUninstaller "" notInstalled isInstalled

    notInstalled:
        StrCpy $UpgradeFlow 0
        StrCpy $UseInstallPath "$INSTDIR"
        goto done

    isInstalled:
        ReadRegStr $UseInstallPath HKLM "${PRODUCT_DIR_REGKEY}" "Path"
        ; Fallback if registry key is empty
        StrCmp $UseInstallPath "" 0 +2
        StrCpy $UseInstallPath "$INSTDIR"
        StrCpy $UpgradeFlow 1
        goto done

  done:
FunctionEnd


; ============================================
; CUSTOM WELCOME PAGE - FRESH INSTALL
; ============================================
Function CustomWelcomeFreshCreator
    ${If} $UpgradeFlow == 1
        Abort
    ${EndIf}

    ; Set the caption
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Install)"

    ; Remove the back button
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}

    ; Hide branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_HIDE}

    ; Create dialog
    nsDialogs::Create 1044
    Pop $Dialog
;    nsDialogs::SetRTL $(^RTL)
    SetCtlColors $Dialog "" "2899C7"  ; blue background

    ; Image control (left sidebar bitmap)
    ${NSD_CreateBitmap} 0u 0u 109u 193u ""
    Pop $0
;    ${NSD_SetStretchedImage} $0 "${MUI_WELCOMEFINISHPAGE_BITMAP}" $1
    ${NSD_SetStretchedImage} $0 "$PLUGINSDIR\sidebar.bmp" $1

    ; Title
    ${NSD_CreateLabel} 120u 10u 195u 28u "$(Welcome_Install_Title)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"  ; white text, blue background
    CreateFont $1 "${Font_Name}" "${Font_Size_Title}" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    ; Body text
    ${NSD_CreateLabel} 120u 45u 195u 130u "$(Welcome_Install_Text)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"  ; white text, blue background
    CreateFont $1 "${Font_Name}" "${Font_Size_Body}" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    nsDialogs::Show
FunctionEnd

Function CustomWelcomeFreshLeave
FunctionEnd

; ============================================
; CUSTOM WELCOME PAGE - UPGRADE
; ============================================
Function CustomWelcomeUpgradeCreator
    ${If} $UpgradeFlow == 0
        Abort
    ${EndIf}

    ; Set the caption
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Upgrade)"

    ; Remove the back button
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}

    ; Change Next button to Upgrade
    GetDlgItem $0 $HWNDPARENT 1
    SendMessage $0 ${WM_SETTEXT} 0 "STR:$(Button_Upgrade)"

    ; Hide branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_HIDE}

    ; Create dialog
    nsDialogs::Create 1044
    Pop $Dialog
    nsDialogs::SetRTL $(^RTL)
    SetCtlColors $Dialog "" "2899C7"  ; blue background

    ; Image control (left sidebar bitmap)
    ${NSD_CreateBitmap} 0u 0u 109u 193u ""
    Pop $0
;    ${NSD_SetStretchedImage} $0 "${MUI_WELCOMEFINISHPAGE_BITMAP}" $1
    ${NSD_SetStretchedImage} $0 "$PLUGINSDIR\sidebar.bmp" $1

    ; Title
    ${NSD_CreateLabel} 120u 10u 195u 38u "$(Welcome_Upgrade_Title)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"  ; white text, blue background
    CreateFont $1 "${Font_Name}" "16" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    ; Body text
    ${NSD_CreateLabel} 120u 55u 195u 130u "$(Welcome_Upgrade_Text)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"  ; white text, blue background
    CreateFont $1 "${Font_Name}" "${Font_Size_Body}" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    nsDialogs::Show
FunctionEnd

Function CustomWelcomeUpgradeLeave
    StrCpy $IsProgressMode 1
    ExecWait '$PathToUninstaller /SHOWPROGRESS _?=$INSTDIR'
FunctionEnd


; ============================================
; CUSTOM DIRECTORY PAGE
; ============================================
Function DirectoryPre
    ; Skip this page if $UpgradeFlow is 1
    StrCmp $UpgradeFlow "1" 0 +2
    Abort
FunctionEnd

Function DirectoryShow
    ; Sets the window title to exactly this string
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Install)"

    ; Show branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_SHOW}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_SHOW}
FunctionEnd


; ============================================
; CUSTOM INSTFILES PAGE
; ============================================
Function InstFilesPre
    ; Set the caption
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Install)"
FunctionEnd

Function CustomInstFilesCreator
    ${If} $UpgradeFlow == 1
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Upgrade)"
    ${EndIf}

    ; Change progress bar color
    !insertmacro SetProgressBarColor "C79928" "FFFFFF"

    ; Remove the Back, Next and Cancel buttons
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 ${SW_HIDE}

    ; Show branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_SHOW}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_SHOW}

    ; Unconditional close on Complete
    SetAutoClose true
FunctionEnd

Function InstFilesLeave
FunctionEnd

; ============================================
; CUSTOM FINISH PAGE
; ============================================
Function CustomFinishPageCreate
    ${If} $UpgradeFlow == 1
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Upgrade)"
    ${Else}
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Install)"
    ${EndIf}

  ;#dave - could make the caption install or upgrade
    ;SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Install)"

    ; Remove the back button and Cancel button
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 ${SW_HIDE}

    ; Show the Close button
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 ${SW_SHOW}

    ; Change Close button label to Upgrade
    GetDlgItem $0 $HWNDPARENT 1
    SendMessage $0 ${WM_SETTEXT} 0 "STR:$(Button_Finish)"

    ; Hide branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_HIDE}

    ; Create dialog
    nsDialogs::Create 1044
    Pop $Dialog
    nsDialogs::SetRTL $(^RTL)
    SetCtlColors $Dialog "" "2899C7"  ; blue background

    ; Image control (left sidebar bitmap)
    ${NSD_CreateBitmap} 0u 0u 109u 193u ""
    Pop $0
;    ${NSD_SetStretchedImage} $0 "${MUI_WELCOMEFINISHPAGE_BITMAP}" $1
    ${NSD_SetStretchedImage} $0 "$PLUGINSDIR\sidebar.bmp" $1

    ; Title
    ${NSD_CreateLabel} 120u 10u 195u 38u "$(Finish_Title)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"  ; white text, blue background
    CreateFont $1 "${Font_Name}" "16" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    ; Body text
    ${If} $UpgradeFlow == 1
        ${NSD_CreateLabel} 120u 55u 195u 38u "$(Finish_Text_Upgrade)"
    ${Else}
        ${NSD_CreateLabel} 120u 55u 195u 38u "$(Finish_Text_Install)"
    ${EndIf}
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"  ; white text, blue background
    CreateFont $1 "${Font_Name}" "${Font_Size_Body}" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    ; Checkbox 1: Open the app (default checked)
    ${NSD_CreateCheckbox} 120u 100u 12u 12u ""
    Pop $CheckboxRunApp
    SetCtlColors $CheckboxRunApp "FFFFFF" "2899C7"
    ${NSD_SetState} $CheckboxRunApp ${BST_CHECKED}
    ${NSD_CreateLabel} 135u 100u 195u 12u "$(Finish_RunApp)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"
    CreateFont $1 "${Font_Name}" "${Font_Size_Option}" "${Font_Weight_Option}"
    SendMessage $0 ${WM_SETFONT} $1 0

    ; Checkbox 2: Open Documentation page
    ${NSD_CreateCheckbox} 120u 115u 12u 12u ""
    Pop $CheckboxOpenDocs
    SetCtlColors $CheckboxOpenDocs "FFFFFF" "2899C7"
    ${NSD_SetState} $CheckboxOpenDocs ${BST_UNCHECKED}
    ${NSD_CreateLabel} 135u 115u 195u 12u "$(Finish_OpenDocumentation)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"
    CreateFont $1 "${Font_Name}" "${Font_Size_Option}" "${Font_Weight_Option}"
    SendMessage $0 ${WM_SETFONT} $1 0

    ; Checkbox 3: Open Donate page
    ${NSD_CreateCheckbox} 120u 130u 12u 12u ""
    Pop $CheckboxOpenDonate
    SetCtlColors $CheckboxOpenDonate "FFFFFF" "2899C7"
    ${NSD_SetState} $CheckboxOpenDonate ${BST_UNCHECKED}
    ${NSD_CreateLabel} 135u 130u 195u 12u "$(Finish_OpenDonate)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"
    CreateFont $1 "${Font_Name}" "${Font_Size_Option}" "${Font_Weight_Option}"
    SendMessage $0 ${WM_SETFONT} $1 0

    nsDialogs::Show
FunctionEnd

Function CustomFinishPageLeave
    ; Check the state of each checkbox and execute actions
    ${NSD_GetState} $CheckboxRunApp $CheckboxState
    ${If} $CheckboxState == ${BST_CHECKED}
        ; Run the application
;     #dave    MessageBox MB_OK "CheckboxRunApp"
       ExecShell "open" "$INSTDIR\${PRODUCT_NAME}.exe"
    ${EndIf}

    ${NSD_GetState} $CheckboxOpenDocs $CheckboxState
    ${If} $CheckboxState == ${BST_CHECKED}
        ; Open Documentation URL
        ExecShell "open" "${Finish_Documentation_URL}"
    ${EndIf}

    ${NSD_GetState} $CheckboxOpenDonate $CheckboxState
    ${If} $CheckboxState == ${BST_CHECKED}
        ; Open Donate URL
        ExecShell "open" "${Finish_Donate_URL}"
    ${EndIf}
FunctionEnd

; ============================================================================
; UNINSTALL un.onInit
; ============================================================================
Function un.onInit
    StrCpy $IsProgressMode 0
    StrCpy $IsSilentMode 0

    ${GetParameters} $R0
    ClearErrors
    ${GetOptions} $R0 "/SHOWPROGRESS" $R1
    ${IfNot} ${Errors}
        ; started from the installer
        StrCpy $IsProgressMode 1
        SetAutoClose true
    ${Else}
        !insertmacro CheckForRunningInstances
    ${EndIf}

    ${If} ${Silent}
        StrCpy $IsSilentMode 1
        SetAutoClose true
        Return
    ${EndIf}

    ; Extract the bitmap to the plugins directory with a known name
    InitPluginsDir
    File /oname=$PLUGINSDIR\unsidebar.bmp "${MUI_UNWELCOMEFINISHPAGE_BITMAP}"

FunctionEnd

; ============================================
; CUSTOM UNINSTALL WELCOME PAGE
; ============================================
Function un.WelcomeShow
    ${If} $IsProgressMode == 1
        Abort
    ${EndIf}
    ${If} $IsSilentMode == 1
        Abort
    ${EndIf}

    ; Set Window Caption
    SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Uninstall)"

    ; Remove the back button
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}

    ; Hide branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_HIDE}

    ; Create Dialog (Use 1018 for client area)
    nsDialogs::Create 1044
    Pop $Dialog
    nsDialogs::SetRTL $(^RTL)
    SetCtlColors $Dialog "" "2899C7"

    ; Create Bitmap Control (Size: 109x193)
    ${NSD_CreateBitmap} 0u 0u 109u 193u ""
    Pop $0
    ${NSD_SetStretchedImage} $0 "$PLUGINSDIR\unsidebar.bmp" $1

    ; Title
    ${NSD_CreateLabel} 120u 10u 195u 28u "$(Welcome_Uninstall_Title)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"
    CreateFont $1 "${Font_Name}" "${Font_Size_Title}" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    ; Body text
    ${NSD_CreateLabel} 120u 45u 195u 130u "$(Welcome_Uninstall_Text)"
    Pop $0
    SetCtlColors $0 "FFFFFF" "2899C7"
    CreateFont $1 "${Font_Name}" "${Font_Size_Body}" "${Font_Weight}"
    SendMessage $0 ${WM_SETFONT} $1 0

    nsDialogs::Show
FunctionEnd

Function un.WelcomeLeave
FunctionEnd

; ============================================
; CUSTOM UNINSTALL INSTFILES PAGE
; ============================================
Function un.InstFilesShow
    ; Change progress bar color
    !insertmacro SetProgressBarColor "C79928" "FFFFFF"

    ; Change Caption when upgrading
    ${If} $IsProgressMode == 1
        SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:$(Caption_Upgrade)"
    ${EndIf}

    ; Remove the Back, Next and Cancel buttons
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 ${SW_HIDE}

    ; Show branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_SHOW}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_SHOW}

    SetAutoClose true
FunctionEnd

; ============================================
; CUSTOM UNINSTALL FINISH PAGE
; ============================================
Function un.PreFinish
    ; Skip finish page for /SHOWPROGRESS and /S
    ${If} $IsProgressMode == 1
        SetAutoClose true
        Abort
    ${EndIf}
    ${If} $IsSilentMode == 1
        SetAutoClose true
        Abort
    ${EndIf}
FunctionEnd

Function un.FinishShow
    ; Remove the back button and Cancel button
    GetDlgItem $0 $HWNDPARENT 3
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 2
    ShowWindow $0 ${SW_HIDE}

    ; Show the Close button
    GetDlgItem $0 $HWNDPARENT 1
    ShowWindow $0 ${SW_SHOW}

    ; Hide branding text (ID 1028) and line (ID 1045)
    GetDlgItem $0 $HWNDPARENT 1028
    ShowWindow $0 ${SW_HIDE}
    GetDlgItem $0 $HWNDPARENT 1045
    ShowWindow $0 ${SW_HIDE}

    ; Title Label
    CreateFont $0 "${Font_Name}" "${Font_Size_Title}" "${Font_Weight}"
    SendMessage $mui.FinishPage.Title ${WM_SETFONT} $0 1

    ; Text Label
    CreateFont $0 "${Font_Name}" "${Font_Size_Body}" "${Font_Weight}"
    SendMessage $mui.FinishPage.Text ${WM_SETFONT} $0 1
FunctionEnd



; ============================================================================
; INSTALL SECTIONS
; ============================================================================
Section "Install"
    SetShellVarContext all
    SetOutPath "$INSTDIR"
    SetOverwrite on
    File /r '${pyinstallerOutputDir}\*.*'

;  ; #dave Here only for temporary testing
;    ; Add delays to see the color
;    Sleep 2000  ;5000
;    File 'License.txt'
;;    File 'vc_redist.x64.exe'
;    ;File "/oname=$INSTDIR\artisan-skeleton.exe" "c:\program files\artisan\artisan.exe"
;    File "/oname=$INSTDIR\artisan-skeleton.exe" "C:\Users\dave\Dropbox\Artisan Roast Profiles\!NewArtisanInstaller\artisan-skeletonNSI.nsi"
;    File "/oname=$INSTDIR\artisan-skeletonProfile.ico" "c:\program files\artisan\artisanProfile.ico"

    CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\${PRODUCT_NAME}.exe"
    CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\${PRODUCT_NAME}.exe"
    !insertMacro UPDATEFILEASSOC

    ; Install Microsoft Visual C++ Redistributable Package (x64)
    ExecWait '$INSTDIR\vc_redist.x64.exe /install /passive /norestart'
    Delete '$INSTDIR\vc_redist.x64.exe'
SectionEnd

; #dave Section -AdditionalIcons
Section "-Install Hidden"
;    ; #dave temporary
;    ${If} $UpgradeFlow == "1"
;        File trimNSI.nsi  ; #dave
;    ${EndIf}

    SetShellVarContext all
    WriteIniStr "$INSTDIR\${PRODUCT_NAME}.url" "InternetShortcut" "URL" "${PRODUCT_WEB_SITE}"
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Website.lnk" "$INSTDIR\${PRODUCT_NAME}.url"
    CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe"

    ; When the file is signed copy it else generate a new one
    !ifndef SIGN
        WriteUninstaller "$INSTDIR\uninstall.exe"
    !else
        File "dist\artisan\uninstall.exe"
    !endif


    WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\${PRODUCT_NAME}.exe"
    WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "Path" "$INSTDIR"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\${PRODUCT_NAME}.exe"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}.${PRODUCT_BUILD}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
    WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"

    ; file associations
    !insertmacro APP_ASSOCIATE "alog" "${PRODUCT_NAME}.Profile" "${PRODUCT_NAME} Roast Profile" \
       "$INSTDIR\${PRODUCT_NAME}Profile.ico" "Open with ${PRODUCT_NAME}" "$INSTDIR\${PRODUCT_NAME}.exe $\"%1$\""

    !insertmacro APP_ASSOCIATE "alrm" "${PRODUCT_NAME}.Alarms" "${PRODUCT_NAME} Alarms" \
       "$INSTDIR\${PRODUCT_NAME}Alarms.ico" "Open with ${PRODUCT_NAME}" "$INSTDIR\${PRODUCT_NAME}.exe $\"%1$\""

    !insertmacro APP_ASSOCIATE "apal" "${PRODUCT_NAME}.Palettes" "${PRODUCT_NAME} Palettes" \
       "$INSTDIR\${PRODUCT_NAME}Palettes.ico" "Open with ${PRODUCT_NAME}" "$INSTDIR\${PRODUCT_NAME}.exe $\"%1$\""

    !insertmacro APP_ASSOCIATE "athm" "${PRODUCT_NAME}.Theme" "${PRODUCT_NAME} Theme" \
       "$INSTDIR\${PRODUCT_NAME}Theme.ico" "Open with ${PRODUCT_NAME}" "$INSTDIR\${PRODUCT_NAME}.exe $\"%1$\""

    !insertmacro APP_ASSOCIATE "aset" "${PRODUCT_NAME}.Settings" "${PRODUCT_NAME} Settings" \
       "$INSTDIR\${PRODUCT_NAME}Settings.ico" "Open with ${PRODUCT_NAME}" "$INSTDIR\${PRODUCT_NAME}.exe $\"%1$\""

    !insertmacro APP_ASSOCIATE "wg" "${PRODUCT_NAME}.Wheel" "${PRODUCT_NAME} Wheel" \
       "$INSTDIR\${PRODUCT_NAME}Wheel.ico" "Open with ${PRODUCT_NAME}" "$INSTDIR\${PRODUCT_NAME}.exe $\"%1$\""

    !insertmacro APP_ASSOCIATE_URL "${PRODUCT_NAME}" "URL:${PRODUCT_NAME} Protocol" \
       "Open with URL" "$INSTDIR\${PRODUCT_NAME}.exe $\"%1$\""
    Sleep 2000  ;5000

SectionEnd



; ============================================================================
; UNINSTALL SECTIONS
; ============================================================================
!ifndef SIGN  ;hide this section when using SignArtisan
Section Uninstall
; ---------------------------------------------
  ; #dave Here only for temporary testing
    ; Add delays to see the color
;    DetailPrint "IsProgressMode $IsProgressMode"
;    Sleep 2000

;; #dave We have to delete something in this test  <- Delete this
;Delete "$INSTDIR\artisan-skeleton.url"
;Delete "$INSTDIR\artisan-skeletonProfile.ico"
;Delete "$INSTDIR\artisan-skeleton.exe"
;Delete "$INSTDIR\License.txt"
;Delete "$INSTDIR\uninst.exe"
;delete "$INSTDIR\trimNSI.nsi"
;    Sleep 2000
;; ---------------------------------------------
    Delete "$INSTDIR\${PRODUCT_NAME}.url"
    Delete "$INSTDIR\uninstall.exe"
    Delete "$INSTDIR\${PRODUCT_NAME}.exe"
    Delete "$INSTDIR\${PRODUCT_NAME}.exe.manifest"
    Delete "$INSTDIR\*.pyd"
    Delete "$INSTDIR\*.dll"
    Delete "$INSTDIR\base_library.zip"

    RMDir /r "$INSTDIR\certifi"
    RMDir /r "$INSTDIR\charset_normalizer"
    RMDir /r "$INSTDIR\contourpy"
    RMDir /r "$INSTDIR\fontTools"
    RMDir /r "$INSTDIR\gevent"
    RMDir /r "$INSTDIR\google"
    RMDir /r "$INSTDIR\greenlet"
    RMDir /r "$INSTDIR\Icons"
    RMDir /r "$INSTDIR\Include"
    RMDir /r "$INSTDIR\kiwisolver"
    RMDir /r "$INSTDIR\lib"
    RMDir /r "$INSTDIR\lib2to3"
    RMDir /r "$INSTDIR\lxml"
    RMDir /r "$INSTDIR\Machines"
    RMDir /r "$INSTDIR\markupsafe"
    RMDir /r "$INSTDIR\matplotlib"
    RMDir /r "$INSTDIR\matplotlib.libs"
    RMDir /r "$INSTDIR\mpl-data"
    RMDir /r "$INSTDIR\numpy"
    RMDir /r "$INSTDIR\openpyxl"
    RMDir /r "$INSTDIR\PIL"
    RMDir /r "$INSTDIR\psutil"
    RMDir /r "$INSTDIR\pyinstaller"
    RMDir /r "$INSTDIR\pytz"
    RMDir /r "$INSTDIR\pywin32_system32"
    RMDir /r "$INSTDIR\scipy"
    RMDir /r "$INSTDIR\scipy.libs"
    RMDir /r "$INSTDIR\tcl"
    RMDir /r "$INSTDIR\tcl8"
    RMDir /r "$INSTDIR\Themes"
    RMDir /r "$INSTDIR\tk"
    RMDir /r "$INSTDIR\tornado"
    RMDir /r "$INSTDIR\translations"
    RMDir /r "$INSTDIR\wcwidth"
    RMDir /r "$INSTDIR\websockets"
    RMDir /r "$INSTDIR\Wheels"
    RMDir /r "$INSTDIR\win32com"
    RMDir /r "$INSTDIR\win32"
    RMDir /r "$INSTDIR\wx"
    RMDir /r "$INSTDIR\yaml"
    RMDir /r "$INSTDIR\yoctopuce"
    RMDir /r "$INSTDIR\zope"

    RMDir /r "$INSTDIR\_internal"

    !insertmacro Rmdir_Wildcard "$INSTDIR\PyQt*" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\qt*_plugins" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\altgraph*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\cffi*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\gevent*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\gevent*.egg-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\greenlet*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\importlib_metadata*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\importlib_metadata*.egg-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\keyring*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\keyring*.egg-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\prettytable*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\prettytable*.egg-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\pycparser*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\pyinstaller*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\python_snap7*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\setuptools*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\websockets*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\wheel*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\zope.event*.dist-info" ${__LINE__}
    !insertmacro Rmdir_Wildcard "$INSTDIR\zope.interface*.dist-info" ${__LINE__}

    Delete "$INSTDIR\artisan.png"
    Delete "$INSTDIR\LICENSE.txt"
    Delete "$INSTDIR\README.txt"
    Delete "$INSTDIR\artisanAlarms.ico"
    Delete "$INSTDIR\artisanProfile.ico"
    Delete "$INSTDIR\artisanPalettes.ico"
    Delete "$INSTDIR\artisanTheme.ico"
    Delete "$INSTDIR\artisanWheel.ico"
    Delete "$INSTDIR\artisanSettings.ico"
    Delete "$INSTDIR\Humor-Sans.ttf"
    Delete "$INSTDIR\dijkstra.ttf"
    Delete "$INSTDIR\xkcd-script.ttf"
    Delete "$INSTDIR\Nunito-Regular.ttf"
    Delete "$INSTDIR\NotoSansMono-Regular.ttf"
    Delete "$INSTDIR\ComicNeue-Regular.ttf"
    Delete "$INSTDIR\WenQuanYiZenHei-01.ttf"
    Delete "$INSTDIR\WenQuanYiZenHeiMonoMedium.ttf"
    Delete "$INSTDIR\SourceHanSansCN-Regular.otf"
    Delete "$INSTDIR\SourceHanSansHK-Regular.otf"
    Delete "$INSTDIR\SourceHanSansJP-Regular.otf"
    Delete "$INSTDIR\SourceHanSansKR-Regular.otf"
    Delete "$INSTDIR\SourceHanSansTW-Regular.otf"
    Delete "$INSTDIR\alarmclock.eot"
    Delete "$INSTDIR\alarmclock.svg"
    Delete "$INSTDIR\alarmclock.ttf"
    Delete "$INSTDIR\alarmclock.woff"
    Delete "$INSTDIR\roboto-300.woff2"
    Delete "$INSTDIR\roboto-600.woff2"
    Delete "$INSTDIR\roboto-regular.woff2"
    Delete "$INSTDIR\android-chrome-192x192.png"
    Delete "$INSTDIR\android-chrome-512x512.png"
    Delete "$INSTDIR\apple-touch-icon.png"
    Delete "$INSTDIR\browserconfig.xml"
    Delete "$INSTDIR\favicon-16x16.png"
    Delete "$INSTDIR\favicon-32x32.png"
    Delete "$INSTDIR\favicon.ico"
    Delete "$INSTDIR\mstile-150x150.png"
    Delete "$INSTDIR\safari-pinned-tab.svg"
    Delete "$INSTDIR\site.webmanifest"
    Delete "$INSTDIR\artisan.tpl"
    Delete "$INSTDIR\scale_widget.tpl"
    Delete "$INSTDIR\fitty_patched.js"
    Delete "$INSTDIR\bigtext.js"
    Delete "$INSTDIR\sorttable.js"
    Delete "$INSTDIR\report-template.htm"
    Delete "$INSTDIR\report-template-pdf.htm"
    Delete "$INSTDIR\roast-template.htm"
    Delete "$INSTDIR\roast-template-pdf.htm"
    Delete "$INSTDIR\ranking-template.htm"
    Delete "$INSTDIR\ranking-template-pdf.htm"
    Delete "$INSTDIR\jquery-1.11.1.min.js"
    Delete "$INSTDIR\qt.conf"
    Delete "$INSTDIR\vc_redist.x64.exe"
    Delete "$INSTDIR\logging.json"
    Delete "$INSTDIR\artisan_public_key.pem"
    Delete "$INSTDIR\uninst.exe"  ;if left around after upgrading an older version

    SetShellVarContext all

    Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall.lnk"
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\Website.lnk"
    Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"

    RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
    RMDir "$INSTDIR"

    DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
    DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
    DeleteRegKey HKCR ".alog"
    DeleteRegKey HKCR "${PRODUCT_NAME}.Profile\DefaultIcon"
    DeleteRegKey HKCR "${PRODUCT_NAME}.Profile\shell"
    DeleteRegKey HKCR "${PRODUCT_NAME}.Profile\shell\open\command"
    DeleteRegKey HKCR "${PRODUCT_NAME}.Profile"

    !insertmacro APP_UNASSOCIATE "alog" "${PRODUCT_NAME}.Profile"
    !insertmacro APP_UNASSOCIATE "alrm" "${PRODUCT_NAME}.Alarms"
    !insertmacro APP_UNASSOCIATE "apal" "${PRODUCT_NAME}.Palettes"
    !insertmacro APP_UNASSOCIATE "athm" "${PRODUCT_NAME}.Theme"
    !insertmacro APP_UNASSOCIATE "aset" "${PRODUCT_NAME}.Settings"
    !insertmacro APP_UNASSOCIATE "wg" "${PRODUCT_NAME}.Wheel"

    DeleteRegKey HKCR "${PRODUCT_NAME}\shell"
    DeleteRegKey HKCR "${PRODUCT_NAME}\shell\open\command"
    DeleteRegKey HKCR "${PRODUCT_NAME}"
SectionEnd
!endif
