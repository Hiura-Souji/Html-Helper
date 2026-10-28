#include-once
; =============================================================================
; Html Helper － 共用工具
;
; 回呼佇列、WebView 腳本執行、字串／URL／HTML 編碼與文字解碼。
; 其他模組都會用到，不依賴特定功能。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ---------------------------------------------------------------------------
; 回呼佇列（參照 LineageAUI 的 _Queue62／_Drain62）：AUI 回呼內只記錄，主迴圈再執行。
; 同一函式連續排入時只保留最後一筆參數（例如快速捲動字型清單）。
; ---------------------------------------------------------------------------
Func HH_Q($funcName, $argc = 0, $a = 0, $b = 0)
    If $gHHQTail > $gHHQHead Then
        Local $last = Mod($gHHQTail - 1, UBound($gHHQ))
        If $gHHQ[$last][0] = $funcName And $gHHQ[$last][1] = $argc Then
            $gHHQ[$last][2] = $a
            $gHHQ[$last][3] = $b
            Return
        EndIf
    EndIf
    If $gHHQTail - $gHHQHead >= UBound($gHHQ) Then
        Return
    EndIf
    Local $slot = Mod($gHHQTail, UBound($gHHQ))
    $gHHQ[$slot][0] = $funcName
    $gHHQ[$slot][1] = $argc
    $gHHQ[$slot][2] = $a
    $gHHQ[$slot][3] = $b
    $gHHQTail += 1
EndFunc

; 主迴圈呼叫：依序執行佇列中的工作，每輪最多約 30 ms。
Func HH_QDrain()
    If $gHHQHead = $gHHQTail Then Return
    Local $limit = $gHHQTail, $budget = TimerInit()
    While $gHHQHead < $limit
        Local $slot = Mod($gHHQHead, UBound($gHHQ))
        Local $funcName = $gHHQ[$slot][0], $argc = $gHHQ[$slot][1], $a = $gHHQ[$slot][2], $b = $gHHQ[$slot][3]
        $gHHQHead += 1
        Switch $argc
            Case 0
                Call($funcName)
            Case 1
                Call($funcName, $a)
            Case Else
                Call($funcName, $a, $b)
        EndSwitch
        If TimerDiff($budget) >= 30 Then ExitLoop
    WEnd
    If $gHHQHead = $gHHQTail Then
        $gHHQHead = 0
        $gHHQTail = 0
    EndIf
EndFunc

; URL 參數編碼：除英數與 - . _ 以外全部百分比編碼。
Func HH_UrlEncodeAll($s)
    Local $b = StringToBinary($s, 4), $out = ""
    For $i = 1 To BinaryLen($b)
        Local $n = Int(BinaryMid($b, $i, 1))
        If ($n >= 65 And $n <= 90) Or ($n >= 97 And $n <= 122) Or ($n >= 48 And $n <= 57) Or $n = 45 Or $n = 46 Or $n = 95 Then
            $out &= Chr($n)
        Else
            $out &= "%" & Hex($n, 2)
        EndIf
    Next
    Return $out
EndFunc

; 主視窗是否為目前前景且可操作（設定、字型等對話視窗開著時為 False）。
Func HH_MainUsable()
    If $gWnd = 0 Then Return False
    If Not WinActive($gWnd) Then Return False
    Return BitAND(WinGetState($gWnd), 4) <> 0
EndFunc

; URL 百分比解碼（UTF-8）。
Func UrlDecode($s)
    Local $bBytes = Binary(""), $i = 1
    While $i <= StringLen($s)
        Local $c = StringMid($s, $i, 1)
        If $c = "%" And $i + 2 <= StringLen($s) Then
            Local $hex = StringMid($s, $i + 1, 2)
            If StringRegExp($hex, "^[0-9a-fA-F]{2}$") Then
                $bBytes &= Binary("0x" & $hex)
                $i += 3
                ContinueLoop
            EndIf
        EndIf
        $bBytes &= StringToBinary($c, 4)
        $i += 1
    WEnd
    Return BinaryToString($bBytes, 4)
EndFunc

; HTML 特殊字元跳脫（& < > "）。
Func HtmlEscape($s)
    $s = StringReplace($s, "&", "&amp;")
    $s = StringReplace($s, "<", "&lt;")
    $s = StringReplace($s, ">", "&gt;")
    $s = StringReplace($s, '"', "&quot;")
    Return $s
EndFunc

; 讀取前先檢查 BOM、HTML charset 與編碼有效性。
; 無宣告的舊版繁體中文 CHM 優先採用 Big5/CP950；UTF-8 有效時使用 UTF-8。
Func _ReadHelpText($sFile)
    Local $h = FileOpen($sFile, 16)
    If $h = -1 Then Return ""
    Local $b = FileRead($h)
    FileClose($h)
    If BinaryLen($b) >= 3 And BinaryMid($b, 1, 3) = Binary("0xEFBBBF") Then Return BinaryToString($b, 4)
    If BinaryLen($b) >= 2 Then
        If BinaryMid($b, 1, 2) = Binary("0xFFFE") Then Return BinaryToString($b, 2)
        If BinaryMid($b, 1, 2) = Binary("0xFEFF") Then Return BinaryToString($b, 3)
    EndIf
    Local $sHead = BinaryToString(BinaryMid($b, 1, 2048), 1)
    Local $aCharset = StringRegExp($sHead, "(?i)charset\s*=\s*['" & Chr(34) & "]?([a-z0-9_-]+)", 1)
    If IsArray($aCharset) Then
        Switch StringLower($aCharset[0])
            Case "utf-8", "utf8"
                Return BinaryToString($b, 4)
            Case "big5", "big-5", "cp950", "windows-950"
                Return _DecodeCodepage($b, 950)
            Case "gb2312", "gbk", "gb18030", "cp936"
                Return _DecodeCodepage($b, 936)
            Case "windows-1252", "iso-8859-1"
                Return _DecodeCodepage($b, 1252)
        EndSwitch
    EndIf
    Local $sUtf8 = BinaryToString($b, 4)
    If StringToBinary($sUtf8, 4) = $b Then Return $sUtf8
    Local $sBig5 = _DecodeCodepage($b, 950)
    Local $sGbk = _DecodeCodepage($b, 936)
    ; GBK 誤解 Big5 常會產生 Unicode 私用區字元。
    Local $iBig5Bad = StringLen(StringRegExpReplace($sBig5, "[^\x{E000}-\x{F8FF}\x{FFFD}]", ""))
    Local $iGbkBad = StringLen(StringRegExpReplace($sGbk, "[^\x{E000}-\x{F8FF}\x{FFFD}]", ""))
    If $iGbkBad < $iBig5Bad Then Return $sGbk
    Return $sBig5
EndFunc

; 以指定 Windows 字碼頁（0＝系統 ANSI）把位元組解碼成字串。
Func _DecodeCodepage($b, $iPage)
    Local $iBytes = BinaryLen($b)
    If $iBytes = 0 Then Return ""
    Local $tSrc = DllStructCreate("byte[" & $iBytes & "]")
    DllStructSetData($tSrc, 1, $b)
    Local $aSize = DllCall("kernel32.dll", "int", "MultiByteToWideChar", "uint", $iPage, "dword", 0, "ptr", DllStructGetPtr($tSrc), "int", $iBytes, "ptr", 0, "int", 0)
    If @error Or Not IsArray($aSize) Or $aSize[0] <= 0 Then Return BinaryToString($b, 1)
    Local $tDest = DllStructCreate("wchar[" & ($aSize[0] + 1) & "]")
    Local $aResult = DllCall("kernel32.dll", "int", "MultiByteToWideChar", "uint", $iPage, "dword", 0, "ptr", DllStructGetPtr($tSrc), "int", $iBytes, "ptr", DllStructGetPtr($tDest), "int", $aSize[0])
    If @error Or Not IsArray($aResult) Or $aResult[0] <= 0 Then Return BinaryToString($b, 1)
    Return DllStructGetData($tDest, 1)
EndFunc

; 還原常見的 HTML 實體（&quot; &apos; &lt; &gt; &amp;）。
Func _HtmlUnescape($s)
    $s = StringReplace($s, "&quot;", '"')
    $s = StringReplace($s, "&apos;", "'")
    $s = StringReplace($s, "&lt;", "<")
    $s = StringReplace($s, "&gt;", ">")
    $s = StringReplace($s, "&amp;", "&")
    Return $s
EndFunc

; URL 路徑編碼：保留安全 ASCII，其餘以 UTF-8 百分比編碼，# 之後的片段原樣保留。
Func EncodeUrlPath($s)
    ; 只保留 URL 安全 ASCII，其餘以 UTF-8 百分比編碼。
    ; 純 ASCII 安全路徑直接回傳；其餘逐字元處理（舊版逐位元組 BinaryMid＋Dec(Hex()) 在大型索引上很慢）。
    Local $sFragment = ""
    Local $iHash = StringInStr($s, "#")
    If $iHash Then
        $sFragment = StringMid($s, $iHash)
        $s = StringLeft($s, $iHash - 1)
    EndIf
    If Not StringRegExp($s, "[^A-Za-z0-9/_.~-]") Then Return $s & $sFragment
    Local $out = "", $n = StringLen($s), $i = 1, $c, $w, $hx
    While $i <= $n
        $c = StringMid($s, $i, 1)
        $w = AscW($c)
        If ($w >= 65 And $w <= 90) Or ($w >= 97 And $w <= 122) Or ($w >= 48 And $w <= 57) Or $w = 47 Or $w = 45 Or $w = 95 Or $w = 46 Or $w = 126 Then
            $out &= $c
        Else
            If $w >= 0xD800 And $w <= 0xDBFF And $i < $n Then
                $i += 1
                $c &= StringMid($s, $i, 1)
            EndIf
            $hx = Hex(StringToBinary($c, 4))
            For $k = 1 To StringLen($hx) Step 2
                $out &= "%" & StringMid($hx, $k, 2)
            Next
        EndIf
        $i += 1
    WEnd
    Return $out & $sFragment
EndFunc

; AUI 的非同步腳本結果若不釋放會累積，達上限後所有腳本（含中鍵查詢）都會送不出去；
; 不需要結果的腳本一律經由這裡，完成後立即釋放。
Func HH_WebFire($js)
    If $gWnd = 0 Or $gWeb = 0 Then Return 0
    Local $req = _UI_WebViewExecuteScriptAsync($gWnd, $gWeb, $js, "HH_WebFireDone")
    Return $req
EndFunc

; HH_WebFire 的完成回呼：釋放 AUI 保留的腳本結果。
Func HH_WebFireDone($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
EndFunc

; 執行頁面腳本；失敗時讓 AUI 處理訊息後重試，避免偶發性回傳 0。
Func HH_WebExec($js, $callback = "")
    Local $req = 0
    For $i = 1 To 15
        If $callback = "" Then
            $req = _UI_WebViewExecuteScriptAsync($gWnd, $gWeb, $js, "HH_WebFireDone")
        Else
            $req = _UI_WebViewExecuteScriptAsync($gWnd, $gWeb, $js, $callback)
        EndIf
        If $req > 0 Then Return $req
        _UI_PumpOnce()
        Sleep(40)
    Next
    Return 0
EndFunc

; 一次掃描解碼 HTML 實體（只解一層，&amp;lt; 會變成 &lt;）。
Func HH_ExportDecodeEntities($s)
    ; 一次掃描：HTML 實體只解碼一層。&amp;lt; 必須變成 &lt;，不能再變成 <。
    Local $out = "", $pos = 1, $n = StringLen($s)
    While $pos <= $n
        Local $ch = StringMid($s, $pos, 1)
        If $ch <> "&" Then
            $out &= $ch
            $pos += 1
            ContinueLoop
        EndIf
        Local $semi = StringInStr($s, ";", 0, 1, $pos + 1)
        If $semi = 0 Or $semi - $pos > 12 Then
            $out &= "&"
            $pos += 1
            ContinueLoop
        EndIf
        Local $entity = StringMid($s, $pos, $semi - $pos + 1), $value = ""
        Switch StringLower($entity)
            Case "&amp;"
                $value = "&"
            Case "&lt;"
                $value = "<"
            Case "&gt;"
                $value = ">"
            Case "&quot;"
                $value = '"'
            Case "&apos;", "&#39;"
                $value = "'"
            Case "&nbsp;"
                $value = ChrW(160)
            Case Else
                If StringRegExp($entity, "^&#[0-9]+;$") Then
                    Local $cp = Number(StringTrimRight(StringMid($entity, 3), 1))
                    If $cp > 0 And $cp <= 65535 And Not ($cp >= 55296 And $cp <= 57343) Then $value = ChrW($cp)
                ElseIf StringRegExp($entity, "(?i)^&#x[0-9a-f]+;$") Then
                    $cp = Dec(StringTrimRight(StringMid($entity, 4), 1))
                    If $cp > 0 And $cp <= 65535 And Not ($cp >= 55296 And $cp <= 57343) Then $value = ChrW($cp)
                EndIf
        EndSwitch
        If $value <> "" Then
            $out &= $value
            $pos = $semi + 1
        Else
            $out &= "&"
            $pos += 1
        EndIf
    WEnd
    Return $out
EndFunc

; 把字串轉成 JSON 字串常值（含引號）。
Func HH_AI_JsonQuote($value)
    Local $s = StringReplace($value, "\", "\\")
    $s = StringReplace($s, '"', '\"')
    $s = StringReplace($s, @CRLF, "\n")
    $s = StringReplace($s, @CR, "\n")
    $s = StringReplace($s, @LF, "\n")
    $s = StringReplace($s, @TAB, "\t")
    Return '"' & $s & '"'
EndFunc

; 解析 JSON 字串跳脫（只解碼擷取的 JSON string，不執行回傳內容）。
Func HH_AI_Unescape($s)
    Local $out = "", $i = 1, $n = StringLen($s)
    While $i <= $n
        Local $c = StringMid($s, $i, 1)
        If $c = "\" And $i < $n Then
            $i += 1
            Local $esc = StringMid($s, $i, 1)
            Switch $esc
                Case "n"
                    $out &= @LF
                Case "r"
                    $out &= @CR
                Case "t"
                    $out &= @TAB
                Case '"', "\", "/"
                    $out &= $esc
                Case "u"
                    If $i + 4 <= $n Then
                        Local $hex = StringMid($s, $i + 1, 4)
                        If StringRegExp($hex, "(?i)^[0-9a-f]{4}$") Then
                            $out &= ChrW(Dec($hex))
                            $i += 4
                        EndIf
                    EndIf
                Case Else
                    $out &= $esc
            EndSwitch
        Else
            $out &= $c
        EndIf
        $i += 1
    WEnd
    Return $out
EndFunc

; URL 轉為 UTF-8 百分比編碼，供 QR 服務使用。
Func HH_UrlEncodeUtf8($s)
    Local $b = StringToBinary($s, 4), $hex = StringTrimLeft(String($b), 2), $out = ""
    For $i = 1 To StringLen($hex) Step 2
        Local $part = StringMid($hex, $i, 2), $n = Dec($part)
        If ($n >= 65 And $n <= 90) Or ($n >= 97 And $n <= 122) Or ($n >= 48 And $n <= 57) Or $n = 45 Or $n = 46 Or $n = 95 Or $n = 126 Then
            $out &= Chr($n)
        Else
            $out &= "%" & $part
        EndIf
    Next
    Return $out
EndFunc

; 把 AutoIt 字串轉成 JavaScript 字串常值（含引號）。
Func JsString($s)
    Return '"' & StringReplace(StringReplace(StringReplace($s, "\", "\\"), '"', '\"'), @CRLF, " ") & '"'
EndFunc

; Base64 解碼（Windows CryptStringToBinaryW）。
Func HH_Base64Decode($b64)
    If $b64 = "" Then Return Binary("")
    Local $r = DllCall("crypt32.dll", "bool", "CryptStringToBinaryW", "wstr", $b64, "dword", 0, "dword", 1, "ptr", 0, "dword*", 0, "ptr", 0, "ptr", 0)
    If @error Or Not IsArray($r) Or Not $r[0] Or $r[5] = 0 Then Return Binary("")
    Local $buf = DllStructCreate("byte[" & $r[5] & "]")
    $r = DllCall("crypt32.dll", "bool", "CryptStringToBinaryW", "wstr", $b64, "dword", 0, "dword", 1, "struct*", $buf, "dword*", $r[5], "ptr", 0, "ptr", 0)
    If @error Or Not IsArray($r) Or Not $r[0] Then Return Binary("")
    Return BinaryMid(DllStructGetData($buf, 1), 1, $r[5])
EndFunc
