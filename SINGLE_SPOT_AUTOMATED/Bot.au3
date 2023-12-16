#include <WinAPIGdi.au3>
#include <Array.au3>
#include <Date.au3>
#include <File.au3>
#RequireAdmin

; #########
; User Variables
Global $JournalPath = "C:\Program Files (x86)\Ultima Online Outlands\ClassicUO\Data\Client\JournalLogs"
Global $APIKey = "ENTER API KEY HERE"
Global $FilesToUpload = 1
Global $PathToCURL = "C:\Windows\System32\curl.exe"
Global $QuitHotkey = "q"
Global $ClearGumpKey = "e"
Global $StartRazorHotkey = "w"


; ###########
; Program Variables
AutoItSetOption("PixelCoordMode", 2)
Global $scale = _WinAPI_EnumDisplaySettings('', $ENUM_CURRENT_SETTINGS)[0] / @DesktopWidth
Global $logoutGump = 4282424686
Global $atlasGumps[]
Global $atlasCoords = [350, 320, 370, 340]
Global $connectionLostColor = 8684667
ConsoleWrite("Scale = " & _WinAPI_EnumDisplaySettings('', $ENUM_CURRENT_SETTINGS)[0] & " / " & @DesktopWidth & " = " & $scale & @CRLF)
Global $GUI = GUICreate("Outlands Mall", 400, 300)
Global $GUICTRL = GUICtrlCreateEdit("", 0, 0, 400, 300)
GUISetState(@SW_SHOW)

Func Print($str)
	ConsoleWrite($str & @CRLF)
EndFunc

Func GUILog($str)
	$str = _NowTime() & " " & $str & @CRLF
	GUICtrlSetData($GUICTRL, $str, 1)
EndFunc

Func GetLogoutGumpCoords($wh)
	Local $size = WinGetClientSize($wh)
	Local $coords[4]
	$coords[0] = $size[0]/2-50
	$coords[1] = $size[1]/2+30
	$coords[2] = $size[0]/2+45
	$coords[3] = $size[1]/2+55
	return $coords
EndFunc

Func GetLogoutChecksum($wh)
	Send($QuitHotkey) ; QuitGame macro
	Sleep(2000)
	Local $coords = GetLogoutGumpCoords($wh)
	Local $cksum = GetScaledChecksum($coords[0], $coords[1], $coords[2], $coords[3], $wh)
	Print("Logout Checksum: " & $cksum)
	return $cksum
EndFunc

Func GetAtlasChecksum($wh)
	MouseMove(0, 0, 0)
	Sleep(1000)
	Send("{Enter}{ASC 091}atlas {ENTER}")
	Sleep(3000)
	Local $cksum = GetScaledChecksum($atlasCoords[0], $atlasCoords[1], $atlasCoords[2], $atlasCoords[3], $wh)
	return $cksum
EndFunc

Func GetScaledChecksum($left, $top, $right, $bottom, $wh)
	Local $cksum = PixelChecksum($left*$scale, $top*$scale, $right*$scale, $bottom*$scale, 1, $wh, 1)
	return $cksum
EndFunc

Func IsConnectionLost($wh)
	Local $size = WinGetClientSize($wh)
	WinActivate($wh)
	WinWaitActive($wh)
	MouseMove(0,0,0)
	Sleep(100)
	Local $color = PixelGetColor(($size[0]/2)*$scale,($size[1]/2)*$scale, $wh)
	Return $color == $connectionLostColor
EndFunc

Func LoginToUO($wh)
    GUILog("Logging back in  " & WinGetTitle($wh))
    While StringLeft(WinGetTitle($wh), 4) <> "UO -"
        WinActivate($wh)
        WinWaitActive($wh)
        Send("{ENTER}")
        Sleep(2000)
        GUILog("Enter and Wait  " & WinGetTitle($wh))
    WEnd
EndFunc

Func GetTZOffset()
	local $info = _Date_Time_GetTimeZoneInformation()
	local $offset = $info[1]
	If $info[0] == 2 Then
		$offset += $info[7]
	EndIf
	Return $offset
EndFunc

Func SyncJournals()
	GUILog("Syncing journals")
	local $journalFiles = _FileListToArray($JournalPath, "*.txt", 1, True)
	If Not IsArray($journalFiles) Then
		Msgbox(0,"","Sorry but " & $JournalPath & " has no files")
		Exit
	EndIf

	local $sortableFiles[10][2]
	ReDim $sortableFiles[$journalFiles[0]][2]
	Print("len" & $journalFiles[0])
	For $i=0 to $journalFiles[0]-1
		$sortableFiles[$i][0] = $journalFiles[$i+1]
		$sortableFiles[$i][1] = FileGetTime($journalFiles[$i+1],0,1)
	Next
	_ArraySort($sortableFiles,1,0,0,1)

	For $i=0 To UBound($sortableFiles)
		local $file = $sortableFiles[$i][0]
		If $i >= $FilesToUpload Then
			ExitLoop
		EndIf
		Local $TimeZoneOffset = GetTZOffset()*-60
		Local $command = $PathToCURL & ' --header "Authorization: Bearer ' & $APIKey & '" -X POST https://outlandmalls.com/uploads -F file=@"' & $file & '" -F tz=' & $TimeZoneOffset
		GUILog($command)
		Local $ok = RunWait($command)
		GUILog("Upload ok? " & String($ok == 0) & " file num: " & $i)
	Next
	;_ArrayDisplay($sortableFiles)

 EndFunc

Func GatherUOHandles()
	;"[CLASS:SDL_app]"
	Local $windows = WinList("UO - ")
	Local $UOHandles[$windows[0][0]]
	Local $numWindows = $windows[0][0]
	GUILog("UO Windows found: " & $numWindows)

	If $numWindows < 1 then
		Msgbox(0,"","NO UO Windows Found")
		Exit
	EndIf

	For $x = 1 to $windows[0][0]
		Print($windows[$x][1])
		_ArrayPush($UOHandles, $windows[$x][1])
	Next
	return $UOHandles
EndFunc

Func SyncAndLogin($wh)
	SyncJournals()
	Sleep(60000*30)
	LoginToUO($wh)
	Send($ClearGumpKey) ; Clear Gump
	GUILog("Waiting 180s before starting script")
	Sleep(60000*3)
	GUILog("Starting razor script " & WinGetTitle($wh))
	WinActivate($wh)
	WinWaitActive($wh)
	Send($StartRazorHotkey) ; Start Script macro
	Sleep(3000)
EndFunc

Func Main()
	Local $UOHandles = GatherUOHandles()

    For $wh in $UOHandles
		WinActivate($wh)
		WinWaitActive($wh)
		SendKeepActive($wh)
		Sleep(1000)
		$atlasGumps[$wh] = GetAtlasChecksum($wh)
		MouseClick("right", $atlasCoords[0], $atlasCoords[1])
		GUILog("Have atlas checksum for " & WinGetTitle($wh) & " " & $atlasGumps[$wh])
		GUILog("Starting script in window " & WinGetTitle($wh))
        Send($StartRazorHotkey) ; Start Script macro
        Sleep(3000)
    Next

	While True
		For $wh in $UOHandles
			GUILog("wh is " & $wh)
			GUILog("Checking for atlas " & winGetTitle($wh))

			Sleep(1000)
			SendKeepActive($wh)
			local $activated = WinActivate($wh)
			GUILog("activated? " & $activated)
			local $waitactive = WinWaitActive($wh)
			GUILog("waitactive? " & $waitactive)
			MouseMove(0,0,0)
			If GetScaledChecksum($atlasCoords[0], $atlasCoords[1], $atlasCoords[2], $atlasCoords[3], $wh) == $atlasGumps[$wh] Then
				GUILog("Sending Quit Hotkey for " & WinGetTitle($wh))
				Send($QuitHotkey) ; QuitGame macro
				Sleep(1000)
				Local $coords = GetLogoutGumpCoords($wh)
				MouseClick("", $coords[2], $coords[3])
				Sleep(2000)
				SyncAndLogin($wh)
			ElseIf IsConnectionLost($wh) Then
				Local $size = WinGetClientSize($wh)
				MouseClick("", $size[0]/2, ($size[1]/2)+90)
				Sleep(60000*15)
				SyncAndLogin($wh)
			Else
				Sleep(7000)
			EndIf
		Next
		SendKeepActive("")
	WEnd

EndFunc

Main()