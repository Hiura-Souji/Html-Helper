#include-once
; =============================================================================
; Html Helper － 網址列與導覽
;
; 網址列顯示與輸入、上一頁／下一頁／首頁（CHM 用 iframe 內部歷史，
; 網站用 WebView2 歷史）。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 依目前 WebView2 分頁實際 URL 同步網址列，涵蓋頁面內連結、返回、前進與首頁。
; 使用者正在輸入時保留輸入內容，不被定時同步覆蓋。
Func HH_AddressSet($url)
    If $gWnd = 0 Or $gStatus = 0 Then Return
    ; 任何本機服務位址一律改成檔案位置，不在網址列暴露 127.0.0.1。
    If StringRegExp($url, "(?i)^https?://(127\.0\.0\.1|localhost):" & $gPort & "/") Then
        $url = HH_LocalDisplayPath(StringRegExpReplace($url, "(?i)^https?://[^/]+", ""))
        If $url = "" Then Return
    EndIf
    If _UI_GetText($gWnd, $gStatus) <> $url Then _UI_SetText($gWnd, $gStatus, $url)
    $gAddressLastShown = $url
EndFunc

; 依目前分頁的實際網址同步網址列（使用者正在輸入時不覆蓋）。
Func HH_SyncAddressBar()
    If $gWnd = 0 Or $gWeb = 0 Or $gStatus = 0 Then Return
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return
    If $tid <> $gAddressTabId Then
        $gAddressTabId = $tid
        $gAddressEditHold = False
        ; 分頁切換後以該分頁實際網址為準。
        $gAddressLastShown = _UI_GetText($gWnd, $gStatus)
    EndIf
    Local $shown = _UI_GetText($gWnd, $gStatus)
    If Not $gAddressEditHold And $shown <> $gAddressLastShown Then $gAddressEditHold = True
    If $gAddressEditHold Then Return
    Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
    If $url = "about:blank" Or StringInStr($url, "/__helper_blank__") Or StringInStr($url, "/__helper_text__/") Then
        $url = ""
    ElseIf StringInStr($url, "/__vchm__/") Or StringInStr($url, "/__html_helper_index__") Then
        ; CHM 及本機索引保留現有顯示路徑，不暴露內部 HTTP 路由。
        Return
    ElseIf $gPort And StringInStr($url, "127.0.0.1:" & $gPort & "/") Then
        ; 本機資料夾／單一檔案改顯示實際檔案位置。
        Local $local = HH_LocalDisplayPath(StringRegExpReplace($url, "(?i)^https?://127\.0\.0\.1:[0-9]+", ""))
        If $local = "" Then Return
        $url = $local
    EndIf
    HH_AddressSet($url)
EndFunc

; 將本機服務路徑（/__vchm__/N/page.htm 或 /page.htm）轉為檔案位置；內部路由傳回空字串。
Func HH_LocalDisplayPath($loc)
    Local $hash = "", $i = StringInStr($loc, "#")
    If $i Then
        $hash = UrlDecode(StringMid($loc, $i))
        $loc = StringLeft($loc, $i - 1)
    EndIf
    $i = StringInStr($loc, "?")
    If $i Then $loc = StringLeft($loc, $i - 1)
    Local $m = StringRegExp($loc, "^/__vchm__/([0-9]+)/(.*)$", 1)
    If IsArray($m) Then
        Local $id = Number($m[0]), $page = UrlDecode($m[1])
        If $id < 1 Or $id >= UBound($gVChmPaths) Or $gVChmPaths[$id] = "" Then Return ""
        If $page = "" Or StringLeft($page, 2) = "__" Then Return $gVChmPaths[$id]
        Return $gVChmPaths[$id] & "::/" & $page & $hash
    EndIf
    If StringLeft($loc, 3) = "/__" Or $gRoot = "" Then Return ""
    Local $rel = StringReplace(UrlDecode(StringMid($loc, 2)), "/", "\")
    If $rel = "" Then Return $gRoot
    Return $gRoot & "\" & $rel & $hash
EndFunc

 ; 導覽按鈕必須以目前 WebView 分頁為準。外部網站的歷史不會回報
; /__helper_history__，因此不能沿用 CHM 的 $gHistoryBack/$gHistoryForward 來禁用按鈕。
; AUI 未提供可直接查詢 CanGoBack/CanGoForward 的介面，網站分頁先維持
; 按鈕可操作，由 WebView2 自身決定是否存在可返回/前進的歷史紀錄。
Func HH_IsChmHistoryPage($url)
    ; 只有真正的 CHM 文件檢視頁面才使用 iframe 內部歷史。
    ; about:blank 與 /__helper_blank__ 是 WebView2 原生歷史節點。
    If StringInStr($url, "/__vchm__/") Then Return True
    If StringInStr($url, "/html/") Then
        Local $idx = _UI_TabsGetSelected($gWnd, $gBrowserTabs)
        If $idx >= 0 And $idx < UBound($gTabSources) Then
            If StringRegExp($gTabSources[$idx], "(?i)\.chm$") Then Return True
        EndIf
    EndIf
    Return False
EndFunc

; 切換分頁後請目前 CHM 分頁重新回報自己的上一頁／下一頁狀態。
Func HH_RefreshChmHistory()
    $gHistoryBack = True
    $gHistoryForward = True
    HH_WebFire("if(window.helperHistoryUpdate)helperHistoryUpdate();")
    HH_SyncHistoryButtons()
EndFunc

; 依目前分頁更新「上一頁」「下一頁」按鈕的可用狀態。
Func HH_SyncHistoryButtons()
    If $gWnd = 0 Or $gWeb = 0 Then Return
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return
    Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
    Local $back = True, $forward = True
    If HH_IsChmHistoryPage($url) Then
        $back = $gHistoryBack
        $forward = $gHistoryForward
    EndIf
    ; 空白頁及一般網站均交由 WebView2 原生歷史處理。
    ; 若 AUI 未提供 CanGoBack/CanGoForward 查詢，保持可按，由 WebView2 決定是否有紀錄。
    _UI_SetEnabled($gWnd, $gBackButton, $back)
    _UI_SetEnabled($gWnd, $gNextButton, $forward)
EndFunc

; 在目前分頁開啟網站（自動補 https://）。
Func OpenWebsite($sUrl)
    $sUrl = StringStripWS($sUrl, 3)
    If Not StringRegExp($sUrl, "(?i)^https?://") Then $sUrl = "https://" & $sUrl
    $gBrowserMode = True
    $gPdfMode = False
    $gPendingUrl = ""
    ; 同一分頁切換網站後，標籤名稱改由 WebView 的網頁 Title 決定。
    Local $idx = _UI_TabsGetSelected($gWnd, $gBrowserTabs)
    If $idx >= 0 And $idx < UBound($gTabSources) Then
        $gTabSources[$idx] = ""

    EndIf
    HH_AddressSet($sUrl)
    $gAddressEditHold = False
    _UI_WebViewSetZoom($gWnd, $gWeb, $gZoom / 100)
    ; 分頁建立與重用一律交給 HelperOpenDropped，避免重複開頁。
    Return _UI_WebViewNavigate($gWnd, $gWeb, $sUrl)
EndFunc

; 網址列按 Enter：開啟網址、本機檔案或「檔案.chm::/內頁」。
Func HelperAddressKey($id, $vk, $mods)
    #forceref $id, $mods
    If $vk <> 13 Then Return
    If TimerDiff($gAddressEnterClock) < 400 Then Return
    $gAddressEnterClock = TimerInit()
    $gAddressEditHold = False
    Local $address = StringStripWS(_UI_GetText($gWnd, $gStatus), 3)
    If $address = "" Then Return
    ; 網址列顯示的「檔案.chm::/內頁」可直接按 Enter 回到該頁。
    Local $mChm = StringRegExp($address, "(?i)^(.+?\.chm)::/?(.*)$", 1)
    If IsArray($mChm) And FileExists($mChm[0]) Then
        If HH_AddressOpenChmPage($mChm[0], $mChm[1]) Then Return
        HelperOpenDropped($mChm[0])
        Return
    EndIf
    If FileExists($address) Then
        ; 直接輸入本機檔案時遵循一般開啟流程（目前空白頁優先重用）。
        HelperOpenDropped($address)
        Return
    EndIf
    If Not StringRegExp($address, "(?i)^https?://") Then
        If StringInStr($address, ".") And Not StringInStr($address, " ") Then
            $address = "https://" & $address
        Else
            Return
        EndIf
    EndIf
    ; 網址列 Enter = 在目前頁面導覽；絕不新增空白分頁。
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return
    Local $old = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
    If StringLower($old) = StringLower($address) Then Return
    $gBrowserMode = True
    $gPdfMode = False
    ; 網址列從 CHM 導覽至網站時，解除此分頁的 CHM 檔名綁定。
    Local $idx = _UI_TabsGetSelected($gWnd, $gBrowserTabs)
    If $idx >= 0 And $idx < UBound($gTabSources) Then
        $gTabSources[$idx] = ""

    EndIf
    _UI_WebViewNavigate($gWnd, $gWeb, $address)
    _UI_SetText($gWnd, $gStatus, $address)
    $gAddressLastShown = $address
EndFunc

; 在已開啟的 CHM 閱讀器中直接切到指定內頁。
Func HH_AddressOpenChmPage($chm, $page)
    If $page = "" Or Not $gPort Then Return False
    Local $docId = 0
    For $j = 1 To UBound($gVChmPaths) - 1
        If StringLower($gVChmPaths[$j]) = StringLower($chm) Then $docId = $j
    Next
    If $docId = 0 Then Return False
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return False
    Local $base = "http://127.0.0.1:" & $gPort & "/__vchm__/" & $docId & "/"
    If Not StringInStr(_UI_WebViewGetTabUrl($gWnd, $gWeb, $tid), $base & "__index__") Then Return False
    Local $js = '(function(){var f=document.getElementById("docframe");if(!f)return 0;f.src=' & JsString($base & EncodeUrlPath(StringReplace($page, "\", "/"))) & ';return 1;})()'
    Return HH_WebExec($js) > 0
EndFunc

; 首頁必須由目前 WebView 分頁判定，不能使用跨分頁共用的 $gBrowserMode。
; 導覽只依目前分頁的文件 ID，不讀取其他分頁的共用 CHM 狀態。
Func HH_NavigateChmHome($docId)
    If $docId < 1 Or $docId >= UBound($gVChmHomes) Then Return False
    If $gVChmPaths[$docId] = "" Or $gVChmHomes[$docId] = "" Then Return False
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return False
    Local $base = "http://127.0.0.1:" & $gPort & "/__vchm__/" & $docId & "/"
    Local $current = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
    Local $home = $base & EncodeUrlPath($gVChmHomes[$docId])
    ; BuildIndex 的右側 iframe ID 是 docframe。直接導覽內頁，不重新產生側欄。
    If StringInStr($current, $base & "__index__") Then
        Local $js = '(function(){var f=document.getElementById("docframe");if(!f)return "no-frame";var u=' & JsString($home) & ';if(f.contentWindow && f.contentWindow.location.href===u)return "already-home";f.src=u;return "navigating";})()'
        Local $request = HH_WebFire($js)
        ; 回傳的是請求 ID，不代表 JavaScript 已成功執行。
        If $request > 0 Then Return True
        Return False
    EndIf
    ; 直接顯示虛擬 CHM 內頁時，回到該 CHM 的閱讀器。
    If StringInStr($current, $base) Then
        If StringInStr($current, $home) Then Return True
        Return _UI_WebViewNavigate($gWnd, $gWeb, $base & "__index__") > 0
    EndIf
    Return False
EndFunc

; 「首頁」按鈕：CHM 回到首頁，網站開 Google，其他回到空白頁。
Func GoHome($iId)
    #forceref $iId
    $gAddressEditHold = False
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return
    Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
    Local $match = StringRegExp($url, "(?i)/__vchm__/([0-9]+)/", 1)
    If IsArray($match) Then
        If HH_NavigateChmHome(Number($match[0])) Then Return
        ; 目前仍是 CHM，不得錯誤導覽至空白頁。
        Return
    EndIf
    ; 兼容舊版 /html/ 解包路由：從目前分頁的來源找對應 CHM。
    Local $idx = _UI_TabsGetSelected($gWnd, $gBrowserTabs)
    If $idx >= 0 And $idx < UBound($gTabSources) Then
        Local $source = $gTabSources[$idx]
        If StringRegExp($source, "(?i)\.chm$") Then
            For $j = UBound($gVChmPaths) - 1 To 1 Step -1
                If StringLower($gVChmPaths[$j]) = StringLower($source) Then
                    If HH_NavigateChmHome($j) Then Return
                    ; 舊 /html/ 頁面不含 docframe 的情況，切換至該 CHM 的獨立閱讀器。
                    Local $vindex = "http://127.0.0.1:" & $gPort & "/__vchm__/" & $j & "/__index__"
                    If Not StringInStr($url, $vindex) Then _UI_WebViewNavigate($gWnd, $gWeb, $vindex)
                    Return
                EndIf
            Next
            ; 尚未建立 ITSS 對應時，不誤用另一份 CHM 的首頁。
            Return
        EndIf
    EndIf
    If StringRegExp($url, "(?i)^https?://") And Not StringInStr($url, "127.0.0.1:" & $gPort & "/") Then
        _UI_WebViewNavigate($gWnd, $gWeb, "https://www.google.com/")
        HH_AddressSet("https://www.google.com/")
        Return
    EndIf
    If StringInStr($url, "/html/") Then Return
    If $gPort Then _UI_WebViewNavigate($gWnd, $gWeb, "http://127.0.0.1:" & $gPort & "/__helper_blank__")
EndFunc

; 一般網站直接使用目前 WebView 文件的瀏覽器歷史，避免 AUI 封裝的
; _UI_WebViewBack/Forward 在部分版本未轉送命令卻沒有回報錯誤。
; CHM 的 iframe 歷史仍交由 htmlHelperHistory 處理。
Func HH_WebNavigateHistory($direction)
    If $gWnd = 0 Or $gWeb = 0 Then Return False
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return False
    Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
    If HH_IsChmHistoryPage($url) Then
        ; 不用快取的 $gHistoryBack／$gHistoryForward 擋下指令：這兩個值是全視窗共用，
        ; 背景分頁載入時會被覆寫。頁面內 htmlHelperHistory 本身會檢查是否還有上一頁／下一頁。
        Local $request = HH_WebFire("if(window.htmlHelperHistory)htmlHelperHistory(" & $direction & ");")
        Return $request <> 0
    EndIf
    ; 包含 about:blank、/__helper_blank__、網頁及非 CHM 的本機文件。
    ; 不可用目前 URL 判定 WebView2 是否具有上一頁／下一頁歷史。
    Local $result = 0
    If $direction < 0 Then
        $result = _UI_WebViewBack($gWnd, $gWeb)
    Else
        $result = _UI_WebViewForward($gWnd, $gWeb)
    EndIf
    $gAddressEditHold = False
    Return $result
EndFunc

; 「上一頁」按鈕與滑鼠側鍵。
Func GoBack($iId)
    #forceref $iId
    $gAddressEditHold = False
    Return HH_WebNavigateHistory(-1)
EndFunc

; 「下一頁」按鈕與滑鼠側鍵。
Func GoForward($iId)
    #forceref $iId
    $gAddressEditHold = False
    Return HH_WebNavigateHistory(1)
EndFunc
