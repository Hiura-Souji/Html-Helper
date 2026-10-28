#include-once
; =============================================================================
; Html Helper － QR Code
;
; 產生 QR 點陣 BMP（內嵌 quricol DLL），並開啟 QR 樣式工坊分頁。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 網站 QR Code：只在使用者確認後傳送網址給外部 QR 服務。
; 本機 CHM 的 127.0.0.1 位址無法在其他裝置存取，不產生誤導性 QR。
Func HH_ShowUrlQRCode()
    Local $tabId = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    Local $url = ""
    If $tabId > 0 Then $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tabId)
    If StringRegExp($url, "(?i)^https?://") And Not StringRegExp($url, "(?i)^https?://(127\.0\.0\.1|localhost)(:|/|$)") Then
        HH_GenerateQRCode(HH_QR_ShareableUrl($url))
    Else
        HH_GenerateQRCode("")
    EndIf
EndFunc

; 從設定抽屜進入時，內容空白且不產生 QR 圖片。
Func HH_ShowCustomQRCode()
    HH_GenerateQRCode("")
EndFunc

; 產生 QR 點陣圖並在新分頁開啟 QR 工坊。
Func HH_GenerateQRCode($content)
    If StringLen($content) > 3049 Then
        _ChmMessage("QR Code", "QR 內容過長，請縮短後重試。")
        Return
    EndIf
    $gQRInitialContent = $content
    $gQRHasImage = False
    Local $bmp = @TempDir & "\HH_QR_" & @AutoItPID & ".bmp"
    FileDelete($bmp)
    If $content <> "" Then
        If Not HH_QR_CreateBmp($content) Then Return
        $gQRHasImage = True
    EndIf
    If Not StartHttp() Then Return
    _UI_WebViewNewTab($gWnd, $gWeb, "http://127.0.0.1:" & $gPort & "/__helper_qr_view__")
EndFunc

; 產生 QR BMP，供首次開啟及 QR 設計頁內即時更新共用。
Func HH_QR_CreateBmp($url)
    ; 按下 QR Code 選項時才從原始 QRCode.au3 內嵌資料建立 DLL。
    ; 不預先編譯或隨 ZIP 提供 DLL，避免啟動時影響右鍵選單。
    Local $dll = @TempDir & "\HH_QR_" & @AutoItPID & "_quricol32.dll"
    Local $bmp = @TempDir & "\HH_QR_" & @AutoItPID & ".bmp"
    If Not FileExists($dll) Then HH_QR_CreateDll($dll)
    If Not FileExists($dll) Then
        _ChmMessage("QR Code", "無法從內嵌資料建立 DLL。")
        Return False
    EndIf
    ; Google 搜尋長網址帶有大量追蹤參數，超出部分 QR 解碼器的可靠容量。
    ; 僅對 Google 搜尋頁面保留原始 q 參數，讓 QR 仍開啟相同搜尋內容。
    Local $qrUrl = $url

    Local $encoded = HH_QR_AsciiUrl($qrUrl)
    FileDelete($bmp)
    Local $hDll = DllOpen($dll)
    If $hDll = -1 Then
        _ChmMessage("QR Code", "無法載入 QR DLL，請使用 32 位元 AutoIt。")
        Return False
    EndIf
    DllCall($hDll, "none", "GenerateBMP", "str", $bmp, "str", $encoded, "int", 2, "int", 4)
    Local $err = @error
    DllClose($hDll)
    If $err Or Not FileExists($bmp) Or FileGetSize($bmp) < 128 Then
        _ChmMessage("QR Code", "產生 QR Code 失敗。")
        Return False
    EndIf
    ; 使用 GDI+ 驗證既有 QR BMP 可正常讀取；實際樣式由離線 Canvas 設計器渲染。
    _GDIPlus_Startup()
    Local $hQrImage = _GDIPlus_ImageLoadFromFile($bmp)
    If $hQrImage = 0 Then
        _GDIPlus_Shutdown()
        _ChmMessage("QR Code", "GDI+ 無法讀取 QR 圖片。")
        Return False
    EndIf
    _GDIPlus_ImageDispose($hQrImage)
    _GDIPlus_Shutdown()
    Return True
EndFunc

; 只簡化 Google 搜尋結果的分享網址；其他網站維持原始網址。
; 原始 q 值已是 URL 百分比編碼，保留不重新編碼以避免雙重編碼。
Func HH_QR_ShareableUrl($url)
    If Not StringRegExp($url, "(?i)^https?://(www\.)?google\.[a-z.]+/search\?") Then Return $url
    Local $parts = StringSplit($url, "?", 2)
    If UBound($parts) < 2 Then Return $url
    Local $params = StringSplit($parts[1], "&", 2)
    For $i = 0 To UBound($params) - 1
        If StringLeft($params[$i], 2) = "q=" And StringLen($params[$i]) > 2 Then
            Return "https://www.google.com/search?" & $params[$i]
        EndIf
    Next
    Return $url
EndFunc

; 把網址中的非 ASCII 字元做 UTF-8 百分比編碼。
Func HH_QR_AsciiUrl($s)
    Local $out = ""
    For $i = 1 To StringLen($s)
        Local $c = StringMid($s, $i, 1)
        If AscW($c) >= 0 And AscW($c) < 128 Then
            $out &= $c
        Else
            $out &= HH_UrlEncodeUtf8($c)
        EndIf
    Next
    Return $out
EndFunc

; 接收 QR 工坊 POST 的 PNG（Base64 文字），驗證後交給主迴圈開啟存檔視窗。
; 回傳空字串表示成功，否則為錯誤原因。
Func HH_QR_ReceiveSave($hClient, $sRequest, $sFullUrl)
    Local $headEnd = StringInStr($sRequest, @CRLF & @CRLF)
    If $headEnd = 0 Then Return "標頭不完整"
    Local $m = StringRegExp(StringLeft($sRequest, $headEnd), "(?im)^Content-Length:\s*([0-9]+)", 1)
    If Not IsArray($m) Then Return "缺少 Content-Length"
    Local $need = Number($m[0])
    If $need <= 0 Or $need > 60000000 Then Return "資料大小不正確"
    Local $body = StringMid($sRequest, $headEnd + 4), $t = TimerInit(), $chunk
    While StringLen($body) < $need And TimerDiff($t) < 15000
        $chunk = TCPRecv($hClient, 65536)
        If @error Then ExitLoop
        If $chunk <> "" Then
            $body &= $chunk
            $t = TimerInit()
        Else
            Sleep(1)
        EndIf
    WEnd
    If StringLen($body) < $need Then Return "資料接收不完整"
    Local $png = HH_Base64Decode(StringStripWS(StringLeft($body, $need), 8))
    If BinaryLen($png) < 8 Or BinaryMid($png, 1, 8) <> Binary("0x89504E470D0A1A0A") Then Return "不是有效的 PNG"
    Local $name = "Html_Helper_QR.png", $n = StringRegExp($sFullUrl, "[?&]name=([^&]*)", 1)
    If IsArray($n) Then $name = StringRegExpReplace(UrlDecode($n[0]), '[\\/:*?"<>|]', "_")
    $gQRSaveData = $png
    $gQRSaveName = $name
    HH_Q("HH_QR_SaveNow")
    Return ""
EndFunc

; 主迴圈執行：顯示程式自己的「另存新檔」視窗並寫入 PNG。
Func HH_QR_SaveNow()
    If BinaryLen($gQRSaveData) = 0 Then Return
    Local $data = $gQRSaveData, $name = $gQRSaveName
    $gQRSaveData = Binary("")
    Local $dir = _IniRead($gIni, "QR", "SaveDir", @MyDocumentsDir)
    If Not FileExists($dir) Then $dir = @MyDocumentsDir
    Local $file = FileSaveDialog("儲存 QR Code PNG", $dir, "PNG 圖片 (*.png)", 2 + 16, $name, $gWnd)
    If @error Or $file = "" Then Return
    If Not StringRegExp($file, "(?i)\.png$") Then $file &= ".png"
    Local $h = FileOpen($file, 2 + 8 + 16)
    Local $ok = ($h <> -1)
    If $ok Then
        $ok = (FileWrite($h, $data) <> 0)
        FileClose($h)
    EndIf
    If $ok Then
        _IniWrite($gIni, "QR", "SaveDir", StringRegExpReplace($file, "[\\/][^\\/]*$", ""))
        _UI_Notify($gWnd, "QR Code 已儲存", $file, $AUI_NOTIFY_SUCCESS, 4000)
    Else
        _UI_Notify($gWnd, "QR Code 儲存失敗", "無法寫入：" & $file, $AUI_NOTIFY_WARNING, 6000)
    EndIf
EndFunc

