; Groovy Installer Script for NSIS

;--------------------------------
; Version (passed via /DGROOVY_VERSION=x.x.x from CI/script, or fallback)

!ifndef GROOVY_VERSION
  !define GROOVY_VERSION "1.0.65"
!endif

;--------------------------------
; Includes

!include "MUI2.nsh"
!include "FileFunc.nsh"

;--------------------------------
; General

; Name and file
Name "Groovy"
OutFile "Groovy-Setup.exe"

; Default installation folder
InstallDir "$PROGRAMFILES64\Groovy"

; Get installation folder from registry if available
InstallDirRegKey HKCU "Software\Groovy" ""

; Request application privileges for Windows
RequestExecutionLevel admin

;--------------------------------
; Variables

Var StartMenuFolder

;--------------------------------
; Interface Settings

!define MUI_ABORTWARNING
!define MUI_ICON "windows\runner\resources\app_icon.ico"
!define MUI_UNICON "windows\runner\resources\app_icon.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "assets\installer_header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "assets\installer_header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\installer_welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "assets\installer_welcome.bmp"

;--------------------------------
; Pages

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_DIRECTORY

; Start Menu Folder Page Configuration
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKCU" 
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\Groovy" 
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"

!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder

!insertmacro MUI_PAGE_INSTFILES

; Option to run Groovy after installation
!define MUI_FINISHPAGE_RUN "$INSTDIR\groovy.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Ejecutar Groovy ahora"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
; Languages

!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Installer Sections

Section "Groovy" SecMain

  ; Close any running instances before updating files
  nsExec::Exec 'taskkill /F /IM groovy.exe'
  Sleep 500

  SetOutPath "$INSTDIR"
  
  ; Copy all files from Release folder
  File /r "build\windows\x64\runner\Release\*.*"
  File "windows\runner\resources\app_icon.ico"
  
  ; Store installation folder
  WriteRegStr HKCU "Software\Groovy" "" $INSTDIR
  
  ; Create uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  
  ; Create Start Menu shortcuts
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Groovy.lnk" "$INSTDIR\groovy.exe" "" "$INSTDIR\app_icon.ico" 0
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Desinstalar Groovy.lnk" "$INSTDIR\Uninstall.exe"
  
  !insertmacro MUI_STARTMENU_WRITE_END
  
  ; Create Desktop shortcut
  CreateShortcut "$DESKTOP\Groovy.lnk" "$INSTDIR\groovy.exe" "" "$INSTDIR\app_icon.ico" 0
  
  ; Write registry keys for Add/Remove Programs
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy" \
                   "DisplayName" "Groovy - Modern Music Streaming Player"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy" \
                   "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy" \
                   "DisplayIcon" "$INSTDIR\app_icon.ico"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy" \
                   "Publisher" "Danx016"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy" \
                   "DisplayVersion" "${GROOVY_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy" \
                   "URLInfoAbout" "https://github.com/Danx016/Groovy"
  
  ; Calculate and write size
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy" \
                     "EstimatedSize" "$0"

SectionEnd

;--------------------------------
; Uninstaller Section

Section "Uninstall"

  ; Remove files
  RMDir /r "$INSTDIR"
  
  ; Remove Start Menu shortcuts
  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  
  Delete "$SMPROGRAMS\$StartMenuFolder\Groovy.lnk"
  Delete "$SMPROGRAMS\$StartMenuFolder\Desinstalar Groovy.lnk"
  RMDir "$SMPROGRAMS\$StartMenuFolder"
  
  ; Remove Desktop shortcut
  Delete "$DESKTOP\Groovy.lnk"
  
  ; Remove registry keys
  DeleteRegKey HKCU "Software\Groovy"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Groovy"

SectionEnd
