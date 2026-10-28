#include-once
; =============================================================================
; Html Helper － 本機 HTTP 服務
;
; 127.0.0.1 上的閱讀服務：提供 CHM 內容、閱讀器頁面、QR 工坊、
; 單一執行個體轉交與網頁回報（歷史、網址、側欄寬度）。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 在 127.0.0.1:19860–19899 找一個可用連接埠啟動本機服務。
Func StartHttp()
    If $gServer <> -1 Then Return True
    For $p = 19860 To 19899
        Local $h = TCPListen("127.0.0.1", $p, 8)
        If $h <> -1 Then
            $gServer = $h
            $gPort = $p
            Return True
        EndIf
    Next
    P135Info("連線失敗", "無法在 127.0.0.1 建立本機閱讀服務。")
    Return False
EndFunc

; 每次主迴圈最多連續處理約 40 ms 的連線：CHM 頁面通常同時要求 HTML、CSS、JS 與多張圖片，
; 舊版一輪只接一個連線，資源一多就要等很多輪主迴圈（每輪含 Sleep(10) 與各種輪詢）。
Func ServiceHttp()
    If $gServer = -1 Then Return
    Local $budget = TimerInit(), $hClient
    While TimerDiff($budget) < 40
        $hClient = TCPAccept($gServer)
        If $hClient = -1 Then ExitLoop
        HH_HttpHandle($hClient)
    WEnd
EndFunc

; 處理單一 HTTP 連線：解析請求行後依路徑分派到各功能。
Func HH_HttpHandle($hClient)
    Local $sRequest = "", $t = TimerInit()
    While TimerDiff($t) < 250
        Local $chunk = TCPRecv($hClient, 4096)
        If @error Then ExitLoop
        If $chunk <> "" Then
            $sRequest &= $chunk
            If StringInStr($sRequest, @CRLF & @CRLF) Then ExitLoop
        EndIf
        Sleep(1)
    WEnd
    Local $sLine = StringRegExpReplace($sRequest, "\r\n[\s\S]*", "")
    Local $aReq = StringRegExp($sLine, "^(GET|HEAD|POST)\s+(\S+)\s+HTTP/", 1)
    If Not IsArray($aReq) Then
        SendResponse($hClient, 400, "text/plain; charset=utf-8", StringToBinary("Bad Request", 4))
        TCPCloseSocket($hClient)
        Return
    EndIf
    Local $sFullUrl = $aReq[1]
    Local $sUrl = StringRegExpReplace($sFullUrl, "\?.*$", "")
    ; QR 工坊儲存 PNG：網頁以 POST 傳來 Base64，由程式自己的「另存新檔」視窗儲存。
    If $sUrl = "/__helper_qr_save__" Then
        If $aReq[0] <> "POST" Then
            SendResponse($hClient, 400, "text/plain; charset=utf-8", StringToBinary("POST only", 4))
        Else
            Local $qrErr = HH_QR_ReceiveSave($hClient, $sRequest, $sFullUrl)
            If $qrErr = "" Then
                SendResponse($hClient, 200, "text/plain; charset=utf-8", StringToBinary("OK", 4))
            Else
                SendResponse($hClient, 400, "text/plain; charset=utf-8", StringToBinary($qrErr, 4))
            EndIf
        EndIf
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__helper_qr_initial__" Then
        SendResponse($hClient, 200, "text/plain; charset=utf-8", StringToBinary($gQRInitialContent, 4))
        TCPCloseSocket($hClient)
        Return
    EndIf
    ; QR 設計頁使用同源請求更新內容，重新產生 BMP，不另開分頁。
    If $sUrl = "/__helper_qr_set__" Then
        Local $payload = StringRegExp($sFullUrl, "[?&]data=([^&]*)", 1)
        If Not IsArray($payload) Then
            SendResponse($hClient, 400, "text/plain; charset=utf-8", StringToBinary("Missing data", 4))
        Else
            Local $content = UrlDecode($payload[0])
            If $content = "" Or StringLen($content) > 2000 Then
                SendResponse($hClient, 400, "text/plain; charset=utf-8", StringToBinary("Invalid content length", 4))
            ElseIf HH_QR_CreateBmp($content) Then
                $gQRInitialContent = $content
                $gQRHasImage = True
                SendResponse($hClient, 200, "text/plain; charset=utf-8", StringToBinary("OK", 4))
            Else
                SendResponse($hClient, 500, "text/plain; charset=utf-8", StringToBinary("QR generation failed", 4))
            EndIf
        EndIf
        TCPCloseSocket($hClient)
        Return
    EndIf
    ; 本機 QR 預覽：只允許讀取本程式 PID 對應的暫存 BMP，不接受任意檔案路徑。
    If $sUrl = "/__helper_qr_image__" Then
        Local $qrBmp = @TempDir & "\\HH_QR_" & @AutoItPID & ".bmp"
        If $gQRHasImage And FileExists($qrBmp) Then
            Local $fh = FileOpen($qrBmp, 16)
            If $fh <> -1 Then
                Local $bytes = FileRead($fh)
                FileClose($fh)
                SendResponse($hClient, 200, "image/bmp", $bytes)
            Else
                SendResponse($hClient, 404, "text/plain", Binary(""))
            EndIf
        Else
            SendResponse($hClient, 404, "text/plain", Binary(""))
        EndIf
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__helper_qr_view__" Then
        Local $html = HH_QR_DesignerHtml()
        SendResponse($hClient, 200, "text/html; charset=utf-8", StringToBinary($html, 4))
        TCPCloseSocket($hClient)
        Return
    EndIf
    ; 虛擬 CHM 使用 /__vchm__/文件ID/內部路徑，完全不使用全域 $gRoot。
    If StringLeft($sUrl, 10) = "/__vchm__/" Then
        VChmHttp($hClient, $sUrl)
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__helper_blank__" Then
        Local $blankBg = "#ffffff", $blankFg = "#222222"
        If HH_ContentIsDark() Then
            $blankBg = "#1e1e1e"
            $blankFg = "#dddddd"
        EndIf
        $html = '<!doctype html><html><head><meta charset="utf-8"><style>html,body{height:100%;margin:0;background:' & $blankBg & ';color:' & $blankFg & '}</style></head><body></body></html>'
        SendResponse($hClient, 200, "text/html; charset=utf-8", StringToBinary($html, 4))
        TCPCloseSocket($hClient)
        Return
    EndIf
    ; 中鍵連結由頁面以圖片請求傳送，不需要跨來源 fetch/CORS。
    If $sUrl = "/__helper_open__" Then
        Local $mTok = StringRegExp($sFullUrl, "[?&]t=([^&]*)", 1)
        If IsArray($mTok) And $gInstToken <> "" And $mTok[0] == $gInstToken Then
            Local $mPath = StringRegExp($sFullUrl, "[?&]p=([^&]*)", 1), $mPage = StringRegExp($sFullUrl, "[?&]g=([^&]*)", 1)
            Local $remotePath = "", $remotePage = ""
            If IsArray($mPath) Then $remotePath = UrlDecode($mPath[0])
            If IsArray($mPage) Then $remotePage = UrlDecode($mPage[0])
            $gRemoteOpen &= $remotePath & @LF & $remotePage & @CR
            SendResponse($hClient, 200, "text/plain; charset=utf-8", StringToBinary("HHOK", 4))
        Else
            SendResponse($hClient, 403, "text/plain; charset=utf-8", StringToBinary("Forbidden", 4))
        EndIf
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__helper_newtab__" Then
        Local $mLink = StringRegExp($sFullUrl, "[?&]u=([^&]*)", 1)
        If IsArray($mLink) Then
            Local $newUrl = UrlDecode($mLink[0])
            HH_LinkQueuePush($newUrl)
        EndIf
        SendResponse($hClient, 200, "image/gif", Binary("0x47494638396101000100800000000000FFFFFF21F90401000000002C00000000010001000002024401003B"))
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__helper_history__" Then
        Local $hist = StringRegExp($sFullUrl, "[?&]b=([01])&f=([01])", 1)
        If IsArray($hist) Then
            $gHistoryBack = Number($hist[0]) = 1
            $gHistoryForward = Number($hist[1]) = 1
            ; 此通知只反映 CHM 內文歷史；外部網站使用 WebView2 歷史。
            HH_SyncHistoryButtons()
        EndIf
        SendResponse($hClient, 200, "text/plain; charset=utf-8", StringToBinary("OK", 4))
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__helper_location__" Then
        Local $mLocation = StringRegExp($sFullUrl, "[?&]p=([^&]*)", 1)
        If IsArray($mLocation) Then
            Local $pageLocation = UrlDecode($mLocation[0])
            If StringLeft($pageLocation, 1) = "/" And StringInStr($pageLocation, "/__html_helper_index__") = 0 Then
                ; 網址列顯示檔案位置（CHM 為「檔案.chm::/內頁」），不顯示本機服務位址。
                Local $shownPath = HH_LocalDisplayPath($pageLocation)
                If $shownPath <> "" Then HH_AddressSet($shownPath)
            EndIf
        EndIf
        SendResponse($hClient, 200, "text/plain; charset=utf-8", StringToBinary("OK", 4))
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__helper_side__" Then
        Local $m = StringRegExp($sFullUrl, "[?&]w=([0-9]+)", 1)
        If IsArray($m) Then
            Local $w = Number($m[0])
            If $w >= 160 And $w <= 1400 Then
                $gSideWidth = $w
                _IniWrite($gIni, "Display", "SideWidth", $gSideWidth)
            EndIf
        EndIf
        SendResponse($hClient, 200, "text/plain; charset=utf-8", StringToBinary("OK", 4))
        TCPCloseSocket($hClient)
        Return
    EndIf
    If StringLeft($sUrl, 17) = "/__helper_text__/" Then
        Local $textId = Number(StringTrimLeft($sUrl, 17))
        If $textId > 0 And $textId < UBound($gTextPaths) And FileExists($gTextPaths[$textId]) Then
            Local $enc = "auto"
            Local $encMatch = StringRegExp($sFullUrl, "[?&]enc=(utf8|ansi|utf16le|utf16be)", 1)
            If IsArray($encMatch) Then $enc = $encMatch[0]
            SendResponse($hClient, 200, "text/html; charset=utf-8", StringToBinary(HelperTextHtml($gTextPaths[$textId], $enc), 4))
        Else
            SendResponse($hClient, 404, "text/plain; charset=utf-8", StringToBinary("Not Found", 4))
        EndIf
        TCPCloseSocket($hClient)
        Return
    EndIf
    If $sUrl = "/__html_helper_index__" Then
        SendResponse($hClient, 200, "text/html; charset=utf-8", StringToBinary($gIndex, 4))
    Else
        Local $sRel = UrlDecode($sUrl)
        ; CHM 的 $tag 是索引關鍵字，不是 html 檔案名稱。
        If StringRegExp(StringStripWS(StringReplace($sRel, "/", ""), 3), "(?i)^\$tag\b") Then
            SendResponse($hClient, 404, "text/html; charset=utf-8", StringToBinary('<!doctype html><meta charset="utf-8"><body style="font:16px Microsoft JhengHei;padding:24px"><h3>這是 CHM 索引標籤，不是實體頁面</h3><p>請從左側目錄或「所有頁面」選擇對應文件。</p></body>', 4))
            TCPCloseSocket($hClient)
            Return
        EndIf
        $sRel = StringReplace($sRel, "/", "\")
        While StringLeft($sRel, 1) = "\"
            $sRel = StringTrimLeft($sRel, 1)
        WEnd
        ; 禁止路徑穿越、Windows 磁碟路徑、冒號與空位元組。
        If $sRel = "" Or StringInStr($sRel, "..") Or StringInStr($sRel, ":") Or StringInStr($sRel, Chr(0)) Then
            SendResponse($hClient, 403, "text/plain; charset=utf-8", StringToBinary("Forbidden", 4))
        Else
            Local $sFile = $gRoot & "\" & $sRel
            If FileExists($sFile) And Not StringInStr(FileGetAttrib($sFile), "D") Then
                Local $hFile = FileOpen($sFile, 16)
                If $hFile <> -1 Then
                    Local $bData = FileRead($hFile)
                    FileClose($hFile)
                    SendResponse($hClient, 200, MimeType($sFile), $bData)
                Else
                    SendResponse($hClient, 404, "text/plain; charset=utf-8", StringToBinary("Not Found", 4))
                EndIf
            Else
                SendResponse($hClient, 404, "text/plain; charset=utf-8", StringToBinary("Not Found", 4))
            EndIf
        EndIf
    EndIf
    TCPCloseSocket($hClient)
EndFunc

; 送出 HTTP 回應（含標頭，內容以 32 KB 分段傳送）。
Func SendResponse($h, $code, $type, $bData)
    Local $sStatus = "OK"
    If $code = 403 Then $sStatus = "Forbidden"
    If $code = 404 Then $sStatus = "Not Found"
    If $code = 400 Then $sStatus = "Bad Request"
    Local $sHeader = "HTTP/1.1 " & $code & " " & $sStatus & @CRLF & _
        "Content-Type: " & $type & @CRLF & _
        "Content-Length: " & BinaryLen($bData) & @CRLF & _
        "Cache-Control: no-store" & @CRLF & _
        "X-Content-Type-Options: nosniff" & @CRLF & _
        "Connection: close" & @CRLF & @CRLF
    TCPSend($h, StringToBinary($sHeader, 1))
    Local $i = 1, $n = BinaryLen($bData)
    While $i <= $n
        Local $bPart = BinaryMid($bData, $i, 32768)
        Local $iSent = TCPSend($h, $bPart)
        If $iSent <= 0 Then ExitLoop
        $i += $iSent
    WEnd
EndFunc

; 依副檔名回傳 Content-Type。
Func MimeType($s)
    Local $e = StringLower(StringRegExpReplace($s, "^.*\.", ""))
    Switch $e
        Case "htm", "html", "xhtml"
            Return "text/html"
        Case "css"
            Return "text/css; charset=utf-8"
        Case "js"
            Return "application/javascript; charset=utf-8"
        Case "svg"
            Return "image/svg+xml"
        Case "png"
            Return "image/png"
        Case "jpg", "jpeg"
            Return "image/jpeg"
        Case "gif"
            Return "image/gif"
        Case "webp"
            Return "image/webp"
        Case "ico"
            Return "image/x-icon"
        Case "woff"
            Return "font/woff"
        Case "woff2"
            Return "font/woff2"
        Case "ttf"
            Return "font/ttf"
        Case "txt", "log", "md"
            Return "text/plain; charset=utf-8"
        Case "xml"
            Return "application/xml"
        Case "mp4"
            Return "video/mp4"
        Case "webm"
            Return "video/webm"
        Case "pdf"
            Return "application/pdf"
        Case Else
            Return "application/octet-stream"
    EndSwitch
EndFunc
