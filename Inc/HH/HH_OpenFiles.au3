#include-once
; =============================================================================
; Html Helper － 開檔流程
;
; 依路徑類型開啟網址、CHM、資料夾、PDF、文字檔與單一檔案；
; 包含舊版 hh.exe／7-Zip 解包與資料夾掃描。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 依路徑類型分派：網址、資料夾、CHM（先虛擬開啟，失敗才解包）、PDF、文字檔、其他檔案。
Func P133OpenPathCore($path)
    If StringRegExp($path, "(?i)^https?://") Then Return OpenWebsite($path)

    If Not FileExists($path) Then Return _ChmMessage("找不到路徑", $path)
    $gBrowserMode = False
    $gPdfMode = False
    _UI_WebViewSetZoom($gWnd, $gWeb, 1.0)
    If StringInStr(FileGetAttrib($path), "D") Then Return LoadFolder($path)
    If StringLower(StringRight($path, 4)) = ".chm" Then
        ; 僅在 CHM 讀取期間啟用原有網址列旋轉提示，保持 (3) 的渲染器不變。
        BeginBusy("正在開啟 " & StringRegExpReplace($path, "^.*[\\/]", ""))
        AdlibRegister("UpdateBusyIndicator", 180)
        Local $bVirtual = VChmOpen($path)
        If $bVirtual Then
            AdlibUnRegister("UpdateBusyIndicator")
            EndBusy()
            Return True
        EndIf
        BeginBusy("正在載入 CHM")
        Local $bFallback = LoadChm($path)
        AdlibUnRegister("UpdateBusyIndicator")
        ; 舊版解包流程可能仍在背景執行，保留原本的忙碌動畫。
        If Not $gScanActive And $gExtractPid = 0 Then EndBusy()
        Return $bFallback
    EndIf
    ; PDF 只顯示指定檔案，絕不掃描同資料夾或建立其他文件導航。
    If StringLower(StringRight($path, 4)) = ".pdf" Then Return LoadSinglePdf($path)
    ; 程式碼與一般文字檔獨立閱讀，不掃描同資料夾，也不建立左側目錄。
    If StringRegExp($path, "(?i)\.(au3|py|cs|c|h|cpp|hpp|js|jsx|ts|tsx|java|go|rs|rb|php|css|json|jsonc|yaml|yml|toml|ini|cfg|conf|bat|cmd|ps1|sh|sql|lua|xml|md|markdown|log|csv|txt|diff|patch|gitignore|dockerfile)$") Then Return LoadPlainText($path)
    ; 單一檔案：讓本機伺服器提供原檔及其相對資源。
    Return LoadSingleFile($path)
EndFunc

; 單一 HTML／圖片／影音：由本機服務提供原檔與相對資源，不建立側欄。
Func LoadSingleFile($path)
    ; 只有資料夾與 CHM 模式會建立左側目錄。
    If Not FileExists($path) Then Return False
    If StringRegExp($path, "(?i)\.(htm|html|xhtml|svg|png|jpe?g|gif|webp|bmp|ico|mp3|mp4|webm|wav|ogg)$") Then
        If Not StartHttp() Then Return False
        ; 單一檔案直接由本機服務提供，不建立側欄。
        $gRoot = StringRegExpReplace($path, "[\\/][^\\/]+$", "")
        $gPendingUrl = "http://127.0.0.1:" & $gPort & "/" & EncodeUrlPath(StringRegExpReplace($path, "^.*[\\/]", ""))
        Return True
    EndIf
    Return LoadPlainText($path)
EndFunc

; 在目前分頁以純文字檢視器開啟檔案。
Func LoadPlainText($path)
    If Not FileExists($path) Or StringInStr(FileGetAttrib($path), "D") Then Return False
    If Not StartHttp() Then Return False
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid < 1 Then Return False
    While UBound($gTextPaths) <= $tid
        ReDim $gTextPaths[UBound($gTextPaths) + 1]
    WEnd
    $gTextPaths[$tid] = $path
    $gScanActive = False
    $gScanCount = 0
    $gPendingUrl = "http://127.0.0.1:" & $gPort & "/__helper_text__/" & $tid
    _UI_SetText($gWnd, $gStatus, $path)
    Return True
EndFunc

; 依 BOM 判斷文字檔編碼（無 BOM 視為 UTF-8）。
Func HH_DetectTextEncoding($path)
    Local $h = FileOpen($path, 16)
    If $h = -1 Then Return "utf8"
    Local $head = FileRead($h, 4)
    FileClose($h)
    Local $hex = StringUpper(Hex($head))
    If StringLeft($hex, 6) = "EFBBBF" Then Return "utf8"
    If StringLeft($hex, 4) = "FFFE" Then Return "utf16le"
    If StringLeft($hex, 4) = "FEFF" Then Return "utf16be"
    Return "utf8"
EndFunc

; 產生純文字檢視頁面（保留縮排與換行，最多顯示 200 萬字元）。
Func HelperTextHtml($path, $encoding = "auto")
    ; 預設依 BOM 判斷 UTF-8 / UTF-16，無 BOM 則優先 UTF-8。
    ; 使用者手動選擇編碼時，查詢參數仍可覆蓋自動判斷。
    If StringLower($encoding) = "auto" Then $encoding = HH_DetectTextEncoding($path)
    Local $flags = 128
    Switch StringLower($encoding)
        Case "ansi"
            $flags = 0
        Case "utf16le"
            $flags = 256
        Case "utf16be"
            $flags = 512
    EndSwitch
    Local $h = FileOpen($path, $flags)
    If $h = -1 Then Return "<h3>無法開啟檔案</h3>"
    Local $source = FileRead($h)
    FileClose($h)
    ; 純文字模式：不執行語法上色或遞迴字串處理；保留縮排與換行。
    ; 限制一次渲染大小，避免數十 MB 的文字檔卡住 UI。
    If StringLen($source) > 2000000 Then $source = StringLeft($source, 2000000) & @CRLF & "（檔案過大，僅顯示前 200 萬字元）"
    Local $dark = HH_ContentIsDark()
    Local $bg = "#ffffff", $fg = "#24292f", $panel = "#f4f6f8", $line = "#d0d7de"
    If $dark Then
        $bg = "#1e1e1e"
        $fg = "#d4d4d4"
        $panel = "#252526"
        $line = "#454545"
    EndIf
    Local $css = "html,body{margin:0;min-height:100%;background:" & $bg & ";color:" & $fg & "}" & _
        "body{font:" & $gContentSize & "px/1.55 " & JsString($gContentFont) & ",Consolas,monospace}" & _
        "header{background:" & $panel & ";padding:8px 16px;color:" & $fg & ";border-bottom:1px solid " & $line & "}" & _
        "pre{font-family:inherit;font-size:inherit;line-height:inherit;box-sizing:border-box;margin:0;padding:14px 18px;white-space:pre-wrap;overflow-wrap:anywhere;tab-size:4;max-width:100%}"
    ; 宿主程式以 HH_WebFire 呼叫這兩個函式，即時套用字型與配色。
    Local $js = 'function setContentFont(f,n){document.body.style.fontFamily=f+",Consolas,monospace";document.body.style.fontSize=n+"px";document.getElementById("src").style.fontSize=n+"px";document.getElementById("src").style.fontFamily=f+",Consolas,monospace"}function htmlHelperSetContentTheme(n){document.documentElement.style.background=n===2?"#fff":"#1e1e1e";document.body.style.background=n===2?"#fff":"#1e1e1e";document.body.style.color=n===2?"#24292f":"#d4d4d4";document.getElementById("src").style.background=n===2?"#fff":"#1e1e1e";document.getElementById("src").style.color=n===2?"#24292f":"#d4d4d4"}'
    Return '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><style>' & $css & '</style></head><body><header>' & HtmlEscape($path) & '</header><pre id="src">' & HtmlEscape($source) & '</pre>' & '<script>' & $js & '</script></body></html>'
EndFunc

; 以 WebView2 內建 PDF 檢視器開啟單一 PDF。
Func LoadSinglePdf($path)
    $gPdfMode = True
    If Not StartHttp() Then Return False
    $gScanActive = False
    $gScanCount = 1
    ReDim $gPageFiles[1]
    ReDim $gPageNames[1]
    $gPageFiles[0] = StringRegExpReplace($path, "^.*[\\/]", "")
    $gPageNames[0] = $gPageFiles[0]
    $gRoot = StringRegExpReplace($path, "[\\/][^\\/]+$", "")
    $gDefaultTopic = ""
    $gTocHtml = ""
    $gKeywordHtml = ""
    $gRequestedPage = $gPageFiles[0]
    $gIndex = BuildIndex()
    $gPendingUrl = "http://127.0.0.1:" & $gPort & "/__html_helper_index__"
    _UI_SetText($gWnd, $gStatus, $path)
    Return True
EndFunc

; 舊版流程：以 7-Zip 或 hh.exe -decompile 把 CHM 解包到暫存資料夾（虛擬開啟失敗時才用）。
Func LoadChm($sChm)
    If Not FileExists($sChm) Then Return _ChmMessage("找不到檔案",$sChm)
    If $gScanActive Or $gExtractPid<>0 Then Return _ChmMessage("請稍候","正在讀取上一份說明檔案，請等待完成。")
    Local $h=FileOpen($sChm,16)
    If $h=-1 Then Return _ChmMessage("讀取失敗","無法讀取 CHM 檔案：" & $sChm)
    Local $magic=FileRead($h,4)
    FileClose($h)
    If $magic<>Binary("0x49545346") Then Return _ChmMessage("檔案格式不符","檔案開頭不是 CHM 的 ITSF 標記。請確認選取的是完整 CHM，不是改名的 HTML 或下載錯誤頁面。")
    Local $temp=@TempDir & "\Html_Helper_" & @AutoItPID & "_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & "_" & Random(1000,9999,1)
    If Not DirCreate($temp) Then Return _ChmMessage("解包失敗","無法建立暫存資料夾：" & $temp)
    If Not DirCreate($temp & "\pages") Then
        DirRemove($temp,1)
        Return _ChmMessage("解包失敗","無法建立輸出資料夾。")
    EndIf
    If Not FileCopy($sChm,$temp & "\source.chm",1) Then
        DirRemove($temp,1)
        Return _ChmMessage("解包失敗","無法複製 CHM 到暫存資料夾。")
    EndIf
    If FileGetSize($sChm)<>FileGetSize($temp & "\source.chm") Then
        DirRemove($temp,1)
        Return _ChmMessage("複製失敗","暫存 CHM 與來源檔案大小不同。")
    EndIf
    $gExtractTemp=$temp
    ; 只有執行檔路徑加引號；兩個參數都是 ASCII 相對名稱。
    ; 優先使用 7-Zip 解包，避免 hh.exe -decompile 遺漏 $tag 等特殊項目。
    ; 若電腦未安裝 7-Zip，警告 hh.exe 解包可能遺漏特殊 CHM 項目。
    Local $s7z = _HtmlHelperFind7Zip()
    If $s7z <> "" Then
        $gExtractCommand = '"' & $s7z & '" x -y -o"' & $temp & '\pages" "' & $temp & '\source.chm"'
    Else
        _ChmDiagnostic("WARNING: 7-Zip unavailable; hh.exe decompile may omit special CHM entries.")
        $gExtractCommand = '"' & @WindowsDir & '\hh.exe" -decompile pages source.chm'
    EndIf
    _ChmDiagnostic("START" & @CRLF & "CHM=" & $sChm & @CRLF & "Bytes=" & FileGetSize($sChm) & @CRLF & "CWD=" & $temp & @CRLF & "Command=" & $gExtractCommand,True)
    $gExtractPid=Run($gExtractCommand,$temp,@SW_HIDE)
    Local $runError=@error
    If $gExtractPid=0 Then
        _ChmDiagnostic("Run failed; @error=" & $runError)
        _ChmExtractFailed("無法啟動 Windows hh.exe。")
        Return
    EndIf
    $gExtractHandle=0
    Local $open=DllCall("kernel32.dll","handle","OpenProcess","dword",0x1000,"bool",False,"dword",$gExtractPid)
    If Not @error And IsArray($open) Then $gExtractHandle=$open[0]
    $gExtractStarted=TimerInit()
    $gExtractStableClock=TimerInit()
    $gExtractPollClock=TimerInit()
    $gExtractLastCount=-1
    _ChmDiagnostic("PID=" & $gExtractPid & " ProcessHandle=" & $gExtractHandle)
    BeginBusy("正在解包 CHM")
EndFunc

; 尋找 7z.exe／7zz.exe／7za.exe。
Func _HtmlHelperFind7Zip()
    Local $aPaths[5] = [@ProgramFilesDir & "\7-Zip\7z.exe", @ProgramFilesDir & "\7-Zip\7zz.exe", @ProgramFilesDir & "\7-Zip\7za.exe", @ScriptDir & "\7z.exe", @ScriptDir & "\7zz.exe"]
    For $i = 0 To UBound($aPaths) - 1
        If FileExists($aPaths[$i]) Then Return $aPaths[$i]
    Next
    Local $sX86 = EnvGet("ProgramFiles(x86)")
    If $sX86 <> "" And FileExists($sX86 & "\7-Zip\7z.exe") Then Return $sX86 & "\7-Zip\7z.exe"
    Return ""
EndFunc

; 主迴圈呼叫：監看解包程序，完成且檔案數穩定後載入資料夾。
Func PollChmExtraction()
    If $gExtractPid=0 Then Return
    If TimerDiff($gExtractPollClock)<750 Then Return
    $gExtractPollClock=TimerInit()
    Local $elapsed=TimerDiff($gExtractStarted)
    Local $count=_CountExtractedHtml($gExtractTemp & "\pages")
    If $count<>$gExtractLastCount Then
        $gExtractLastCount=$count
        $gExtractStableClock=TimerInit()
        _ChmDiagnostic("ElapsedMs=" & Round($elapsed) & " HTML=" & $count)
    EndIf
    $gBusyTitle="正在解包 CHM（" & $count & " 頁，" & Int($elapsed/1000) & " 秒）"
    If _ChmProcessRunning() Then
        If $elapsed>120000 Then _ChmExtractFailed("CHM 解包逾時（120 秒），未判定為成功。")
        Return
    EndIf
    If $count=0 Then
        ; 程序很快結束不代表解包完成或成功，要等到檔案出現。
        If $elapsed<30000 Then Return
        _ChmExtractFailed("等待 30 秒後仍沒有 HTM／HTML 檔案。" & @CRLF & "請先確認原 CHM 可由 Windows 說明檢視器開啟；必要時只對可信檔案解除封鎖。")
        Return
    EndIf
    If TimerDiff($gExtractStableClock)<2000 Then
        If $elapsed<120000 Then Return
        _ChmExtractFailed("輸出檔案數持續變動，超過等待上限。")
        Return
    EndIf
    Local $temp=$gExtractTemp
    _ChmDiagnostic("SUCCESS HTML=" & $count & " ExitCode=" & _ChmExitCode())
    _ChmCloseProcessHandle()
    $gExtractPid=0
    $gExtractTemp=""
    $gScanFromChm=True
    $gScanTempParent=$temp
    If Not LoadFolder($temp & "\pages",False) Then
        $gScanFromChm=False
        $gScanTempParent=""
        EndBusy()
        _ChmMessage("讀取失敗","CHM 已解包，但無法讀取輸出資料夾：" & $temp & "\pages")
    EndIf
EndFunc

; 計算資料夾內（含子資料夾）的 HTM／HTML 檔案數。
Func _CountExtractedHtml($sRoot)
    Local $aQueue[64], $iHead = 0, $iTail = 1, $iCount = 0
    $aQueue[0] = $sRoot
    While $iHead < $iTail
        Local $sDir = $aQueue[$iHead]
        $iHead += 1
        Local $hFind = FileFindFirstFile($sDir & "\*")
        If $hFind = -1 Then ContinueLoop
        While 1
            Local $sName = FileFindNextFile($hFind)
            If @error Then ExitLoop
            Local $sPath = $sDir & "\" & $sName
            If StringInStr(FileGetAttrib($sPath), "D") Then
                If $iTail >= UBound($aQueue) Then ReDim $aQueue[UBound($aQueue) * 2]
                $aQueue[$iTail] = $sPath
                $iTail += 1
            ElseIf StringRegExp($sName, "(?i)\.html?$") Then
                $iCount += 1
            EndIf
        WEnd
        FileClose($hFind)
    WEnd
    Return $iCount
EndFunc

; 解包失敗：結束程序、保留暫存資料夾並顯示原因與診斷紀錄位置。
Func _ChmExtractFailed($reason)
    Local $temp=$gExtractTemp
    _ChmDiagnostic("FAILED " & $reason & @CRLF & "ExitCode=" & _ChmExitCode() & @CRLF & "TemporaryFolder=" & $temp)
    If $gExtractPid<>0 And _ChmProcessRunning() Then ProcessClose($gExtractPid)
    _ChmCloseProcessHandle()
    $gExtractPid=0
    $gExtractTemp=""
    EndBusy()
    _ChmMessage("CHM 解包失敗",$reason & @CRLF & "暫存資料夾已保留：" & $temp & @CRLF & "診斷紀錄：" & $gDiagnostic)
EndFunc

; 開始忙碌提示（網址列顯示旋轉符號與說明）。
Func BeginBusy($sTitle)
    $gBusy = True
    $gBusyTitle = $sTitle
    $gBusyClock = TimerInit()
    $gBusyFrame = -1
    _UI_SetText($gWnd, $gStatus, $sTitle & "，請稍候…")
    _UI_PumpOnce()
EndFunc

; 更新網址列的忙碌旋轉符號。
Func UpdateBusyIndicator()
    If Not $gBusy Then Return
    Local $iFrame = Mod(Int(TimerDiff($gBusyClock) / 360), 2)
    If $iFrame = $gBusyFrame Then Return
    $gBusyFrame = $iFrame
    Local $aSpin[2] = ["/", "\\"]
    _UI_SetText($gWnd, $gStatus, $aSpin[$iFrame] & " " & $gBusyTitle & "，請稍候…")
EndFunc

; 結束忙碌提示。
Func EndBusy()
    $gBusy = False
EndFunc

; 開始以分段方式掃描資料夾，建立說明頁清單。
Func LoadFolder($sFolder, $bRemember = True)
    If $gExtractPid<>0 Then Return False
    If Not FileExists($sFolder) Then Return False
    If $gScanActive Then
        _UI_Notify($gWnd, "請稍候", "正在掃描上一份說明檔案。", $AUI_NOTIFY_WARNING, 3000)
        Return False
    EndIf
    If Not StartHttp() Then Return False
    $gScanRoot = $sFolder
    While StringRight($gScanRoot, 1) = "\"
        $gScanRoot = StringTrimRight($gScanRoot, 1)
    WEnd
    $gScanRemember = $bRemember
    $gScanHead = 0
    $gScanTail = 1
    ReDim $gScanQueue[128]
    $gScanQueue[0] = $gScanRoot
    $gScanCount = 0
    ReDim $gPageFiles[512]
    ReDim $gPageNames[512]
    $gScanActive = True
    BeginBusy("正在讀取資料夾")
    Return True
EndFunc

; 主迴圈呼叫：每輪掃描兩個資料夾，完成後建立目錄與閱讀器頁面。
Func PollFolderScan()
    If Not $gScanActive Then Return
    ; 每輪最多處理兩個資料夾，讓主迴圈能持續更新 GUI 與 WebView。
    Local $iBudget = 2
    While $gScanHead < $gScanTail And $iBudget > 0
        Local $sDir = $gScanQueue[$gScanHead]
        $gScanHead += 1
        $iBudget -= 1
        Local $hFind = FileFindFirstFile($sDir & "\*")
        If $hFind = -1 Then ContinueLoop
        While 1
            Local $sEntry = FileFindNextFile($hFind)
            If @error Then ExitLoop
            If $sEntry = "." Or $sEntry = ".." Then ContinueLoop
            Local $sPath = $sDir & "\" & $sEntry
            Local $sAttrib = FileGetAttrib($sPath)
            If StringInStr($sAttrib, "D") Then
                If $gScanTail >= UBound($gScanQueue) Then ReDim $gScanQueue[UBound($gScanQueue) * 2]
                $gScanQueue[$gScanTail] = $sPath
                $gScanTail += 1
            ElseIf StringRegExp($sEntry, "(?i)\.(html?|xhtml|pdf|svg|txt|xml|png|jpe?g|gif|webp|mp4|webm)$") Then
                If $gScanCount >= UBound($gPageFiles) Then
                    ReDim $gPageFiles[UBound($gPageFiles) * 2]
                    ReDim $gPageNames[UBound($gPageNames) * 2]
                EndIf
                Local $sRel = StringTrimLeft($sPath, StringLen($gScanRoot) + 1)
                $gPageFiles[$gScanCount] = StringReplace($sRel, "\", "/")
                $gPageNames[$gScanCount] = $sEntry
                $gScanCount += 1
            EndIf
        WEnd
        FileClose($hFind)
    WEnd
    If $gScanHead < $gScanTail Then
        $gBusyTitle = "正在掃描說明頁（已找到 " & $gScanCount & " 頁）"
        Return
    EndIf
    $gScanActive = False
    If $gScanCount = 0 Then
        EndBusy()
        _UI_Notify($gWnd, "沒有說明頁", "資料夾內沒有 .htm 或 .html 檔案。", $AUI_NOTIFY_WARNING, 4000)
        Return
    EndIf
    ReDim $gPageFiles[$gScanCount]
    ReDim $gPageNames[$gScanCount]
    Local $sOldTemp = $gTemp
    $gRoot = $gScanRoot
    $gBusyTitle = "正在建立目錄與索引"
    _UI_SetText($gWnd, $gStatus, $gBusyTitle & "，請稍候…")
    _UI_PumpOnce()
    LoadChmNavigation()
    $gIndex = BuildIndex()
    $gPendingUrl = "http://127.0.0.1:" & $gPort & "/__html_helper_index__"
    $gRetry = 0
    $gRequestedPage = ""
    If $gScanRemember Then _IniWrite($gIni, "Recent", "Folder", $gRoot)
    If $gScanFromChm Then
        $gTemp = $gScanTempParent
        $gScanTempParent = ""
        $gScanFromChm = False
    Else
        $gTemp = ""
    EndIf
    If $sOldTemp <> "" And $sOldTemp <> $gRoot Then DirRemove($sOldTemp, 1)
    EndBusy()
    _UI_SetText($gWnd, $gStatus, $gRoot & "（" & $gScanCount & " 頁）")
EndFunc

; 顯示 CHM 相關訊息，固定回傳 False。
Func _ChmMessage($title, $body)
    P135Info($title, $body)
    Return False
EndFunc

; 寫入解包診斷紀錄（Html_Helper_Extract.log）。
Func _ChmDiagnostic($text,$reset=False)
    Local $mode=129
    If $reset Then $mode=130
    Local $h=FileOpen($gDiagnostic,$mode)
    If $h=-1 Then Return False
    Local $ok=FileWrite($h,@YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & " " & $text & @CRLF)
    FileClose($h)
    Return $ok<>0
EndFunc

; 取得解包程序的結束代碼（259＝仍在執行）。
Func _ChmExitCode()
    If $gExtractHandle=0 Then Return -1
    Local $call=DllCall("kernel32.dll","bool","GetExitCodeProcess","handle",$gExtractHandle,"dword*",0)
    If @error Or Not IsArray($call) Then Return -1
    If Not $call[0] Then Return -1
    Return $call[2]
EndFunc

; 解包程序是否仍在執行。
Func _ChmProcessRunning()
    Local $code=_ChmExitCode()
    If $code<>-1 Then Return $code=259
    Return $gExtractPid<>0 And ProcessExists($gExtractPid)<>0
EndFunc

; 關閉解包程序的控制代碼。
Func _ChmCloseProcessHandle()
    If $gExtractHandle<>0 Then DllCall("kernel32.dll","bool","CloseHandle","handle",$gExtractHandle)
    $gExtractHandle=0
EndFunc

; 開啟路徑並加入最近文件。
Func OpenPath($path)
    Local $ok = P133OpenPathCore($path)
    If $ok And FileExists($path) Then HtmlHelperAddRecent($path)
    Return $ok
EndFunc
