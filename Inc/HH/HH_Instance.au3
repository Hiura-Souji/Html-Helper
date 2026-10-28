#include-once
; =============================================================================
; Html Helper － 單一執行個體與工作列
;
; 同一時間只開一個主視窗：後開的程序把檔案交給既有視窗開在新分頁；
; 工作列 AppUserModelID 與最近文件。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; Windows 7+ 工作列群組識別：編譯 EXE 後固定使用同一 AppUserModelID。
; 注意：這只處理工作列圖示群組，不會自行建立 Jump List。
; ---------------------------------------------------------------------------
; 單一視窗（單一執行個體）
; ---------------------------------------------------------------------------
Func HH_SingleInstance()
    Local $r = DllCall("kernel32.dll", "handle", "CreateMutexW", "ptr", 0, "bool", False, "wstr", "Local\HtmlHelper.Reader.SingleInstance")
    If @error Or Not IsArray($r) Then Return
    $gInstMutex = $r[0]
    Local $le = DllCall("kernel32.dll", "dword", "GetLastError")
    If @error Or Not IsArray($le) Or $le[0] <> 183 Then Return ; 183 = ERROR_ALREADY_EXISTS：已有執行個體
    Local $path = "", $page = ""
    If $CmdLine[0] >= 1 Then $path = $CmdLine[1]
    If $CmdLine[0] >= 2 Then $page = StringReplace($CmdLine[2], "\", "/")
    If $path <> "" And Not StringRegExp($path, "(?i)^https?://") And FileExists($path) Then $path = _PathFull($path)
    ; 另一個執行個體可能剛啟動、尚未建立服務：最多等 10 秒。
    Local $t = TimerInit()
    TCPStartup()
    While TimerDiff($t) < 10000
        If HH_InstanceSend($path, $page) Then
            TCPShutdown()
            Exit
        EndIf
        Sleep(150)
    WEnd
    ; 等不到就自己開一個視窗（例如前一個執行個體已當掉）。
EndFunc

; 透過本機 HTTP 與權杖，把要開的檔案送給既有執行個體。
Func HH_InstanceSend($path, $page)
    If Not FileExists($HH_INST_FILE) Then Return False
    Local $a = StringSplit(StringStripWS(FileRead($HH_INST_FILE), 3), "|", 2)
    If UBound($a) < 3 Then Return False
    Local $pid = Number($a[0]), $port = Number($a[1]), $token = $a[2]
    If $pid <= 0 Or $pid = @AutoItPID Or Not ProcessExists($pid) Or $port <= 0 Then Return False
    DllCall("user32.dll", "bool", "AllowSetForegroundWindow", "dword", $pid)
    Local $sock = TCPConnect("127.0.0.1", $port)
    If $sock = -1 Or @error Then Return False
    Local $req = "GET /__helper_open__?t=" & $token & "&p=" & HH_UrlEncodeAll($path) & "&g=" & HH_UrlEncodeAll($page) & " HTTP/1.1" & @CRLF & "Host: 127.0.0.1" & @CRLF & "Connection: close" & @CRLF & @CRLF
    TCPSend($sock, StringToBinary($req, 4))
    Local $resp = "", $t = TimerInit()
    While TimerDiff($t) < 3000
        Local $chunk = TCPRecv($sock, 2048)
        If @error Then ExitLoop
        If $chunk <> "" Then
            $resp &= $chunk
            If StringInStr($resp, "HHOK") Then ExitLoop
        EndIf
        Sleep(10)
    WEnd
    TCPCloseSocket($sock)
    Return StringInStr($resp, "HHOK") > 0
EndFunc

; 主執行個體：服務啟動後寫出 PID｜連接埠｜權杖，供之後開啟的程序轉交檔案。
Func HH_InstanceRegister()
    If Not StartHttp() Then Return
    $gInstToken = ""
    For $i = 1 To 32
        $gInstToken &= StringMid("0123456789abcdefghijklmnopqrstuvwxyz", Random(1, 36, 1), 1)
    Next
    Local $h = FileOpen($HH_INST_FILE, 2)
    If $h = -1 Then Return
    FileWrite($h, @AutoItPID & "|" & $gPort & "|" & $gInstToken)
    FileClose($h)
    $gInstWritten = True
    OnAutoItExitRegister("HH_InstanceCleanup")
EndFunc

; 程式結束時刪除自己寫的執行個體資訊檔。
Func HH_InstanceCleanup()
    If Not $gInstWritten Then Return
    Local $a = StringSplit(FileRead($HH_INST_FILE), "|", 2)
    If UBound($a) >= 1 And Number($a[0]) = @AutoItPID Then FileDelete($HH_INST_FILE)
EndFunc

; 另一個程序轉交的檔案：喚回視窗並開在新分頁（目前是空白分頁時直接使用它）。
Func HH_RemoteOpen($path, $page)
    If BitAND(WinGetState($gWnd), 16) Then WinSetState($gWnd, "", @SW_RESTORE)
    WinActivate($gWnd)
    If $path = "" Then Return
    If $page <> "" Then $gRequestedPage = $page
    HelperOpenDropped($path)
EndFunc

; 啟動參數的檔案：等 AUI 第一個分頁建立後才開，讓它載入到第一個分頁。
Func HH_StartupOpenTick()
    If $gRemoteOpen <> "" And $gStartupOpen = "" Then
        Local $items = StringSplit(StringTrimRight($gRemoteOpen, 1), @CR, 2)
        $gRemoteOpen = ""
        For $i = 0 To UBound($items) - 1
            Local $pair = StringSplit($items[$i], @LF, 2)
            If UBound($pair) >= 2 Then HH_RemoteOpen($pair[0], $pair[1])
        Next
    EndIf
    If $gStartupOpen = "" Then Return
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 And TimerDiff($gStartupClock) < 5000 Then Return
    If _UI_TabsGetItemCount($gWnd, $gBrowserTabs) < 1 And TimerDiff($gStartupClock) < 5000 Then Return
    Local $path = $gStartupOpen
    $gStartupOpen = ""
    HelperOpenDropped($path)
EndFunc

; 設定固定的工作列 AppUserModelID（僅編譯後的 EXE）。
Func HH_TaskbarInitialize()
    If @Compiled = 0 Then Return ; AU3 直譯執行時避免與 AutoIt3.exe 的工作列群組混淆
    Local $aCall = DllCall("shell32.dll", "long", "SetCurrentProcessExplicitAppUserModelID", "wstr", "HtmlHelper.Reader")
    If @error Or Not IsArray($aCall) Then Return
EndFunc

; 把開過的檔案加入 Windows 最近文件與 INI 最近清單（最多 12 筆）。
Func HtmlHelperAddRecent($sPath)
    ; Windows Shell 最近使用文件清單：必須搭配已註冊的開啟方式，
    ; 才可能在工作列 Jump List 顯示；由 Windows 控制顯示結果。
    If Not FileExists($sPath) Then Return
    P133JumpAdd($sPath)
    Local $sOld = _IniRead($gIni, "Recent", "Items", "")
    Local $sNew = $sPath
    Local $aOld = StringSplit($sOld, "|", 2)
    Local $iCount = 1
    For $i = 0 To UBound($aOld) - 1
        If $aOld[$i] = "" Or StringLower($aOld[$i]) = StringLower($sPath) Then ContinueLoop
        $sNew &= "|" & $aOld[$i]
        $iCount += 1
        If $iCount >= 12 Then ExitLoop
    Next
    _IniWrite($gIni, "Recent", "Items", $sNew)
EndFunc

; COM QueryInterface 小工具。
Func P133JQuery($p, $iid)
    Local $g = __ITSS_Guid($iid)
    If Not IsDllStruct($g) Then Return 0
    Local $r = DllCallAddress("long", __ITSS_Method($p, 0), "ptr", $p, "ptr", DllStructGetPtr($g), "ptr*", 0)
    If @error Then Return 0
    If $r[0] < 0 Then Return 0
    Return $r[3]
EndFunc

; 呼叫 IShellLinkW 的字串設定方法（路徑、參數、工作目錄、說明）。
Func P133JString($p, $slot, $text)
    Local $r = DllCallAddress("long", __ITSS_Method($p, $slot), "ptr", $p, "wstr", $text)
    If @error Then Return False
    Return $r[0] >= 0
EndFunc

; 在捷徑的屬性存放區寫入字串屬性（標題、AppUserModelID）。
Func P133JProperty($link, $guid, $pid, $text)
    Local $store = P133JQuery($link, "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}")
    If Not $store Then Return False
    Local $g = __ITSS_Guid($guid)
    If Not IsDllStruct($g) Then
        __ITSS_Release($store)
        Return False
    EndIf
    Local $key = DllStructCreate("byte fmtid[16];dword pid"), $str = DllStructCreate("wchar[" & (StringLen($text) + 1) & "]")
    DllStructSetData($key, 1, DllStructGetData($g, 1))
    DllStructSetData($key, 2, $pid)
    DllStructSetData($str, 1, $text)
    Local $pv = DllStructCreate("byte[" & (@AutoItX64 ? 24 : 16) & "]"), $vt = DllStructCreate("ushort", DllStructGetPtr($pv)), $value = DllStructCreate("ptr", DllStructGetPtr($pv) + 8)
    DllStructSetData($vt, 1, 31)
    DllStructSetData($value, 1, DllStructGetPtr($str))
    Local $r = DllCallAddress("long", __ITSS_Method($store, 6), "ptr", $store, "ptr", DllStructGetPtr($key), "ptr", DllStructGetPtr($pv)), $ok = False
    If Not @error Then $ok = ($r[0] >= 0)
    If $ok Then
        $r = DllCallAddress("long", __ITSS_Method($store, 7), "ptr", $store)
        If @error Then
            $ok = False
        Else
            $ok = ($r[0] >= 0)
        EndIf
    EndIf
    __ITSS_Release($store)
    Return $ok
EndFunc

; 建立指向本程式（可附文件）的 IShellLinkW 物件。
Func P133JLink($document = "")
    Local $cls = __ITSS_Guid("{00021401-0000-0000-C000-000000000046}"), $iid = __ITSS_Guid("{000214F9-0000-0000-C000-000000000046}")
    If Not IsDllStruct($cls) Or Not IsDllStruct($iid) Then Return 0
    Local $r = DllCall("ole32.dll", "long", "CoCreateInstance", "ptr", DllStructGetPtr($cls), "ptr", 0, "dword", 1, "ptr", DllStructGetPtr($iid), "ptr*", 0)
    If @error Then Return 0
    If $r[0] < 0 Then Return 0
    Local $p = $r[5], $exe = @ScriptFullPath, $args = ""
    If Not @Compiled Then
        $exe = @AutoItExe
        $args = '"' & @ScriptFullPath & '"'
    EndIf
    If $document <> "" Then
        If $args <> "" Then $args &= " "
        $args &= '"' & $document & '"'
    EndIf
    Local $ok = P133JString($p, 20, $exe), $title = "Html Helper"
    If Not P133JString($p, 11, $args) Then $ok = False
    If Not P133JString($p, 9, @ScriptDir) Then $ok = False
    If $document <> "" Then $title = StringRegExpReplace($document, "^.*[\\/]", "")
    P133JString($p, 7, $title)
    If Not P133JProperty($p, "{F29F85E0-4FF9-1068-AB91-08002B27B3D9}", 2, $title) Then $ok = False
    If Not P133JProperty($p, "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", 5, "HtmlHelper.Reader.Desktop") Then $ok = False
    If Not $ok Then
        __ITSS_Release($p)
        Return 0
    EndIf
    Return $p
EndFunc

; 設定 AppUserModelID，並在開始功能表建立 Html Helper 捷徑（工作列跳躍清單需要）。
Func P133JumpInit()
    DllCall("ole32.dll", "long", "CoInitializeEx", "ptr", 0, "dword", 2)
    Local $r = DllCall("shell32.dll", "long", "SetCurrentProcessExplicitAppUserModelID", "wstr", "HtmlHelper.Reader.Desktop")
    If @error Then Return False
    If $r[0] < 0 Then Return False
    Local $p = P133JLink()
    If Not $p Then Return False
    Local $persist = P133JQuery($p, "{0000010B-0000-0000-C000-000000000046}"), $ok = False
    If $persist Then
        DirCreate(@ProgramsDir)
        $r = DllCallAddress("long", __ITSS_Method($persist, 6), "ptr", $persist, "wstr", @ProgramsDir & "\Html Helper.lnk", "bool", True)
        If Not @error Then $ok = ($r[0] >= 0)
        __ITSS_Release($persist)
    EndIf
    __ITSS_Release($p)
    Return $ok
EndFunc

; 把檔案加入此程式的工作列跳躍清單（SHAddToRecentDocs）。
Func P133JumpAdd($file)
    If Not FileExists($file) Then Return False
    If StringInStr(FileGetAttrib($file), "D") Then Return False
    Local $p = P133JLink(_PathFull($file))
    If Not $p Then Return False
    Local $id = DllStructCreate("wchar[" & (StringLen("HtmlHelper.Reader.Desktop") + 1) & "]"), $info = DllStructCreate("ptr link;ptr appid")
    DllStructSetData($id, 1, "HtmlHelper.Reader.Desktop")
    DllStructSetData($info, 1, $p)
    DllStructSetData($info, 2, DllStructGetPtr($id))
    DllCall("shell32.dll", "none", "SHAddToRecentDocs", "uint", 7, "ptr", DllStructGetPtr($info))
    Local $e = @error
    __ITSS_Release($p)
    Return $e = 0
EndFunc
