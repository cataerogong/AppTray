#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <TrayConstants.au3>
#include <StringConstants.au3>
#include <Misc.au3>

AutoItSetOption("MustDeclareVars", 1)

Global Const $APP_FULLNAME = "Apps in Tray"
Global Const $APP_VERSION = "v0.1.1"
Global Const $APP_COPYRIGHT = "Copyright (c) 2021 CataeroGong"
Global Const $APP_URL = "github.com/cataerogong/AppTray"
Global Const $APP_DESC = "Auto run apps and hide windows, control with one tray icon."
Global Const $APPNAME = StringRegExpReplace(@ScriptName, "\.[^\.]+$", "")

FileChangeDir(@ScriptDir)
SingleInstance()
LoadConfig()
InitAll()
AutoRun()
UpdateAll()
While 1
	UpdateAll()
	Sleep(500)
WEnd

Func SingleInstance()
	If _Singleton(StringRegExpReplace(@ScriptFullPath, "[\\]", "/"), 1) = 0 Then
		MsgBox($MB_ICONERROR, $APPNAME, "Only ONE instance allowed.")
		Exit
	EndIf
EndFunc

Func LoadConfig()
	Local $sIniFile = $APPNAME & ".ini"
	If Not FileExists($sIniFile) Then
		MsgBox($MB_ICONERROR, $APPNAME, "Can not open <" & $sIniFile & ">")
		Exit
	EndIf
	Local $aSections = IniReadSectionNames($sIniFile)
	If @error Then
		MsgBox($MB_SYSTEMMODAL, $APPNAME, "Error occurs when reading <" & $sIniFile & ">")
		Exit
	EndIf
	Global $g_i_AppNum = $aSections[0]
	Global $g_a_AppName[$g_i_AppNum]
	Global $g_a_CmdLine[$g_i_AppNum]
	Global $g_a_WorkDir[$g_i_AppNum]
	Global $g_a_AutoRun[$g_i_AppNum]
	Global $g_a_HideWin[$g_i_AppNum]
	Global $g_a_Console[$g_i_AppNum]
	Global $g_a_PID[$g_i_AppNum]
	Global $g_a_HWND[$g_i_AppNum]
	Global $g_a_RUNNING[$g_i_AppNum]
	Global $g_a_VISIBLE[$g_i_AppNum]
	Global $g_a_tiMenu[$g_i_AppNum] ; TrayItemId AppSubMenu
	Global $g_a_tiStart[$g_i_AppNum] ; TrayItemId StartStop
	Global $g_a_tiShow[$g_i_AppNum] ; TrayItemId ShowHide
	Global $g_a_tiDetail[$g_i_AppNum] ; TrayItemId Detail
	For $i = 1 To $g_i_AppNum
		$g_a_AppName[$i-1] = $aSections[$i]
		$g_a_CmdLine[$i-1] = IniRead($sIniFile, $aSections[$i], "CmdLine", "")
		If Not $g_a_CmdLine[$i-1] Then
			MsgBox($MB_SYSTEMMODAL, $APPNAME, "Can not get config from <" & $sIniFile & ">")
			Exit
		EndIf
		$g_a_WorkDir[$i-1] = IniRead($sIniFile, $aSections[$i], "WorkDir", "")
		$g_a_AutoRun[$i-1] = IniRead($sIniFile, $aSections[$i], "AutoRun", "1")
		$g_a_HideWin[$i-1] = IniRead($sIniFile, $aSections[$i], "HideWin", "1")
		$g_a_Console[$i-1] = IniRead($sIniFile, $aSections[$i], "Console", "1")
		$g_a_PID[$i-1] = 0
		$g_a_HWND[$i-1] = 0
		$g_a_RUNNING[$i-1] = False
		$g_a_VISIBLE[$i-1] = False
		$g_a_tiMenu[$i-1] = 0
		$g_a_tiStart[$i-1] = 0
		$g_a_tiShow[$i-1] = 0
		$g_a_tiDetail[$i-1] = 0
	Next

	Global $g_s_BaseInfo = $APPNAME & @CRLF & "================" & @CRLF & $g_i_AppNum & " App(s)"
	Global $g_b_Detail = False
EndFunc

Func InitApp($id)
	$g_a_tiMenu[$id] = TrayCreateMenu($g_a_AppName[$id])
	$g_a_tiStart[$id] = TrayCreateItem("Start", $g_a_tiMenu[$id])
	TrayItemSetOnEvent($g_a_tiStart[$id], "StartStop")
	$g_a_tiShow[$id] = TrayCreateItem("Show", $g_a_tiMenu[$id])
	TrayItemSetOnEvent($g_a_tiShow[$id], "ShowHide")
	$g_a_tiDetail[$id] = TrayCreateItem(" ", $g_a_tiMenu[$id])
	TrayItemSetState($g_a_tiDetail[$id], $TRAY_DISABLE)
EndFunc

Func InitAll()
	Opt("TrayMenuMode", 1+2)
	Opt("TrayAutoPause", 0)
	Opt("TrayOnEventMode", 1)

	Local $idTip = TrayCreateItem("r: running, v: visible")
	TrayItemSetState($idTip, $TRAY_DISABLE)

	TrayCreateItem("")

	For $i = 0 To $g_i_AppNum-1
		InitApp($i)
	Next

	TrayCreateItem("")

	TrayItemSetOnEvent(TrayCreateItem("Start All"), "StartAll")
	TrayItemSetOnEvent(TrayCreateItem("Stop All"), "StopAll")
	TrayItemSetOnEvent(TrayCreateItem("Show All"), "ShowAll")
	TrayItemSetOnEvent(TrayCreateItem("Hide All"), "HideAll")

	TrayCreateItem("")

	Global $g_id_TrayItemDetail = TrayCreateItem("Show detail")
	TrayItemSetOnEvent($g_id_TrayItemDetail, "Detail")
	Global $g_id_TrayItemAbout = TrayCreateItem("About")
	TrayItemSetOnEvent($g_id_TrayItemAbout, "About")
	Global $g_id_Exit = TrayCreateItem("Exit")
	TrayItemSetOnEvent($g_id_Exit, "ExitApp")

	TraySetState($TRAY_ICONSTATE_SHOW)
EndFunc

Func AutoRun()
	For $i = 0 To $g_i_AppNum-1
		If $g_a_AutoRun[$i] = "1" Then
			Start($i)
		EndIf
	Next
EndFunc

Func UpdateApp($id)
	If WinExists($g_a_HWND[$id]) Then
		$g_a_RUNNING[$id] = True
		$g_a_VISIBLE[$id] = BitAND($WIN_STATE_VISIBLE, WinGetState($g_a_HWND[$id], ""))
	Else
		$g_a_PID[$id] = 0
		$g_a_HWND[$id] = 0
		$g_a_RUNNING[$id] = False
		$g_a_VISIBLE[$id] = False
	EndIf
	;~ TrayItemSetText($g_a_tiMenu[$id], $g_a_AppName[$id] & ($g_a_RUNNING[$id]?(" (R" & ($g_a_VISIBLE[$id]?",V":"") & ")"):""))
	TrayItemSetText($g_a_tiMenu[$id], ($g_a_RUNNING[$id]?("(r," & ($g_a_VISIBLE[$id]?"v) ":"-) ")):"(-,-) ") & $g_a_AppName[$id])
	TrayItemSetText($g_a_tiStart[$id], $g_a_RUNNING[$id] ? "Stop" : "Start")
	TrayItemSetText($g_a_tiShow[$id], $g_a_VISIBLE[$id] ? "Hide" : "Show")
	TrayItemSetText($g_a_tiDetail[$id], $g_b_Detail ? ("PID=" & $g_a_PID[$id] & ",HWND=" & $g_a_HWND[$id]) : " ")
EndFunc

Func UpdateAll()
	Local $iRun = 0
	Local $iShow = 0
	For $i = 0 To $g_i_AppNum-1
		UpdateApp($i)
		If $g_a_RUNNING[$i] Then $iRun += 1
		If $g_a_VISIBLE[$i] Then $iShow += 1
	Next
	TrayItemSetState($g_id_TrayItemDetail, $g_b_Detail ? $TRAY_CHECKED : $TRAY_UNCHECKED)
	TraySetToolTip($g_s_BaseInfo & @CRLF & $iRun & " Running (" & $iShow & " Visible)")
EndFunc

Func Detail()
	$g_b_Detail = bitAND(TrayItemGetState($g_id_TrayItemDetail), $TRAY_CHECKED) ? False : True
	UpdateAll()
EndFunc

Func ProcessGetWinHandle($processid)
    If IsNumber($processid) And ProcessExists($processid) Then
        Local $wl = WinList()
        For $i = 1 To $wl[0][0]
            If WinGetProcess($wl[$i][1]) = $processid Then
                Return $wl[$i][1]
            EndIf
        Next
    EndIf
	Return 0
EndFunc

Func Start($id)
	If $g_a_HWND[$id] = 0 Then
		If $g_a_Console[$id] = 1 Then
			$g_a_PID[$id] = Run(@ComSpec & " /c " & $g_a_CmdLine[$id], $g_a_WorkDir[$id])
		Else
			$g_a_PID[$id] = Run($g_a_CmdLine[$id], $g_a_WorkDir[$id])
		EndIf
		Sleep(1000)
		$g_a_HWND[$id] = ProcessGetWinHandle($g_a_PID[$id])
		If $g_a_HWND[$id] Then
			If $g_a_Console[$id] = 1 Then
				;~ WinSetTitle($g_a_HWND[$id], "", "[" & $APPNAME & "] App: " & $g_a_AppName[$id] & " (PID=" & $g_a_PID[$id] & ", HWND=" & $g_a_HWND[$id] & ")")
				WinSetTitle($g_a_HWND[$id], "", "[" & $APPNAME & "] " & $g_a_AppName[$id])
			EndIf
			If $g_a_HideWin[$id] = 1 Then
				WinSetState($g_a_HWND[$id], "", @SW_HIDE)
			EndIf
		Else
			MsgBox($MB_ICONERROR, $APPNAME, "FATAL ERROR: Can't get window handle." & @CRLF & "  PID=" & $g_a_PID[$id])
		EndIf
	EndIf
	UpdateAll()
	Return $g_a_HWND[$id]
EndFunc

Func Stop($id)
	If $g_a_HWND[$id] Then
		WinClose($g_a_HWND[$id])
		WinWaitClose($g_a_HWND[$id], "", 10)
		If WinExists($g_a_HWND[$id]) Then
			MsgBox($MB_ICONERROR, $APPNAME, "ERROR: Can't stop app <" & $g_a_AppName[$id] & ">." & @CRLF & "Close it by yourself." &@CRLF&@CRLF& "  PID=" & $g_a_PID[$id] & @CRLF & "  HWND=" & $g_a_HWND[$id])
			Show($id)
			WinFlash($g_a_HWND[$id])
		Else
			$g_a_PID[$id] = 0
			$g_a_HWND[$id] = 0
			$g_a_RUNNING[$id] = False
			$g_a_VISIBLE[$id] = False
		EndIf
	EndIf
	UpdateAll()
	Return $g_a_HWND[$id]
EndFunc

Func StartStop()
	For $i = 0 To $g_i_AppNum-1
		If $g_a_tiStart[$i] = @TRAY_ID Then
			If $g_a_HWND[$i] Then
				Stop($i)
			Else
				Start($i)
			EndIf
			ExitLoop
		EndIf
	Next
EndFunc

Func Show($id)
	If $g_a_HWND[$id] Then
		WinSetState($g_a_HWND[$id], "", @SW_SHOW)
		WinActivate($g_a_HWND[$id])
	EndIf
	UpdateAll()
EndFunc

Func Hide($id)
	If $g_a_HWND[$id] Then
		WinSetState($g_a_HWND[$id], "", @SW_HIDE)
	EndIf
	UpdateAll()
EndFunc

Func ShowHide()
	For $i = 0 To $g_i_AppNum-1
		If $g_a_tiShow[$i] = @TRAY_ID Then
			If $g_a_VISIBLE[$i] Then
				Hide($i)
			Else
				Show($i)
			EndIf
		EndIf
	Next
EndFunc

Func StartAll()
	For $i = 0 To $g_i_AppNum-1
		Start($i)
	Next
EndFunc

Func StopAll()
	For $i = 0 To $g_i_AppNum-1
		Stop($i)
	Next
EndFunc

Func ShowAll()
	For $i = 0 To $g_i_AppNum-1
		Show($i)
	Next
EndFunc

Func HideAll()
	For $i = 0 To $g_i_AppNum-1
		Hide($i)
	Next
EndFunc

Func About()
	MsgBox(0, $APPNAME, $APP_FULLNAME & " " & $APP_VERSION &@CRLF&@CRLF& $APP_COPYRIGHT &@CRLF&@CRLF& $APP_URL &@CRLF&@CRLF& $APP_DESC)
EndFunc

Func ExitApp()
	For $i = 0 To $g_i_AppNum-1
		Stop($i)
	Next
	Exit
EndFunc