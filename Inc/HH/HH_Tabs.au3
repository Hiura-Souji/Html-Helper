#include-once
; =============================================================================
; Html Helper － 分頁
;
; 自繪方形分頁列（可拖曳排序）、分頁開關與切換、最近關閉分頁、
; 拖放佇列與鍵盤／滑鼠快捷鍵。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 尋找已開啟同一來源檔案的分頁位置（找不到回傳 -1）。
Func HelperFindOpenSource($source)
    Local $needle = StringLower(StringStripWS(StringReplace($source, "/", "\\"), 3))
    For $i = 0 To UBound($gTabSources) - 1
        If StringLower($gTabSources[$i]) = $needle Then Return $i
    Next
    Return -1
EndFunc

; 開啟檔案：已開過就切過去，否則用目前空白分頁或新分頁（先排入佇列）。
Func HelperOpenDropped($source)
    If $source = "" Or $source = "__HH_BLANK_TAB__" Then
        HelperNewTab(0)
        Return
    EndIf
    If Not StringRegExp($source, "(?i)^https?://") And Not FileExists($source) Then
        _ChmMessage("開啟失敗", "檔案或資料夾不存在：" & $source)
        Return
    EndIf
    Local $found = HelperFindOpenSource($source)
    If $found >= 0 Then
        Local $existing = _UI_WebViewGetTabIdAt($gWnd, $gWeb, $found)
        If $existing > 0 Then
            _UI_WebViewSwitchTab($gWnd, $gWeb, $existing)
            _UI_TabsSetSelected($gWnd, $gBrowserTabs, $found)
            Return
        EndIf
    EndIf
    ; 在 WebView 分頁真正建立前，只排入佇列，不能呼叫 OpenPath。
    Local $currentId = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    Local $currentIndex = _UI_TabsGetSelected($gWnd, $gBrowserTabs)
    Local $currentSource = "", $currentUrl = ""
    If $currentIndex >= 0 And $currentIndex < UBound($gTabSources) Then $currentSource = $gTabSources[$currentIndex]
    If $currentId > 0 Then $currentUrl = _UI_WebViewGetTabUrl($gWnd, $gWeb, $currentId)
    Local $targetId = 0
    If UBound($gDropSources) = 0 And $gPendingUrl = "" And $currentId > 0 And $currentSource = "" And ($currentUrl = "" Or $currentUrl = "about:blank" Or StringInStr($currentUrl, "/__helper_blank__")) Then
        $targetId = $currentId
    Else
        $targetId = HelperNewTab(0)
    EndIf
    If $targetId <= 0 Then Return
    Local $n = UBound($gDropSources)
    ReDim $gDropSources[$n + 1]
    ReDim $gDropIds[$n + 1]
    $gDropSources[$n] = $source
    $gDropIds[$n] = $targetId
EndFunc

; 主迴圈呼叫：分頁建立完成後，依序把佇列中的檔案載入對應分頁。
Func HH_PumpDropQueue()
    If UBound($gDropSources) = 0 Or $gPendingUrl <> "" Or $gExtractPid <> 0 Or $gScanActive Then Return
    Local $id = $gDropIds[0]
    ; 新增分頁是非同步的；未就緒時不允許導覽現有分頁。
    If Not _UI_WebViewSwitchTab($gWnd, $gWeb, $id) Then Return
    Local $source = $gDropSources[0]
    _ArrayDelete($gDropSources, 0)
    _ArrayDelete($gDropIds, 0)
    Local $index = -1
    For $i = 0 To _UI_WebViewGetTabCount($gWnd, $gWeb) - 1
        If _UI_WebViewGetTabIdAt($gWnd, $gWeb, $i) = $id Then
            $index = $i
            ExitLoop
        EndIf
    Next
    If $index < 0 Then Return
    _UI_TabsSetSelected($gWnd, $gBrowserTabs, $index)
    If Not OpenPath($source) Then Return
    ; OpenPath 可能非同步載入；明確指定導航目標。
    If $gPendingUrl <> "" Then $gPendingTabId = $id
    While UBound($gTabSources) <= $index
        ReDim $gTabSources[UBound($gTabSources) + 1]
    WEnd
    ; 網站網址必須保留大小寫與路徑，且以 WebView 實際 URL 儲存。
    ; gTabSources 僅追蹤本機檔案，避免網站換頁後還原舊網址。
    If StringRegExp($source, "(?i)^https?://") Then
        $gTabSources[$index] = ""
    Else
        $gTabSources[$index] = StringLower(StringStripWS(StringReplace($source, "/", "\"), 3))
    EndIf

EndFunc

; 切換或關閉分頁時取消背景翻譯，避免舊 HTTP 結果套用到新分頁。
; 不呼叫還原原文：已翻譯的內容仍留在原分頁。
Func HH_CancelTranslationOnTabChange()
    $gAiPaused = False
    If $gGooglePageMode Or IsObj($gGoogleHttp) Or $gGooglePageRequest <> 0 Then HH_GoogleStopPage()
    If $gAiPageMode Then HH_AI_PageStop()
    If IsObj($gAiHttp) Or $gAiPageRequest <> 0 Or $gAiBusyRetryDelay > 0 Then
        $gAiPageRequest = 0
        $gAiRequest = 0
        $gAiBusyRetryDelay = 0
        $gAiBusyRetryCount = 0
        $gAiBusyRetryText = ""
        $gAiPendingText = ""
        If IsObj($gAiHttp) Then $gAiHttp.Abort()
        $gAiHttp = 0
    EndIf
EndFunc

; 分頁列右側的前後切換鍵：循環切換目前已存在的 WebView2 分頁。
; 不新增歷史節點，也不變更目前分頁內的網頁導覽紀錄。
Func HH_SwitchTabRelative($delta)
    If $gWnd = 0 Or $gWeb = 0 Then Return False
    Local $n = P133SyncOrder()
    If $n < 2 Then Return False
    Local $pos = P133OrderPos(_UI_WebViewGetCurrentTab($gWnd, $gWeb))
    If $pos < 0 Then $pos = 0
    Return P133SwitchToOrder(Mod($pos + $delta + $n, $n))
EndFunc

; 全域瀏覽器操作：僅在本程式擁有前景視窗時攔截，避免影響其他應用程式。
; 使用按下沿觸發，按住按鍵不會在每個 GUI 迴圈重複建立／關閉分頁。
Func HH_PollBrowserShortcuts()
    If Not HH_MainUsable() Then
        $gHHShortcutLatch = ""
        $gHHMouseBackHeld = False
        $gHHMouseForwardHeld = False
        Return
    EndIf

    Local $mb = _IsPressed("05"), $mf = _IsPressed("06")
    If $mb And Not $gHHMouseBackHeld Then GoBack(0)
    If $mf And Not $gHHMouseForwardHeld Then GoForward(0)
    $gHHMouseBackHeld = $mb
    $gHHMouseForwardHeld = $mf

    Local $key = ""
    If _IsPressed("11") Then ; Ctrl
        If _IsPressed("09") Or _IsPressed("22") Or _IsPressed("21") Then ; Tab / PageDown / PageUp
            If _IsPressed("21") Or (_IsPressed("09") And _IsPressed("10")) Then
                $key = "previous"
            Else
                $key = "next"
            EndIf
        ElseIf _IsPressed("54") Then ; Ctrl+T
            If _IsPressed("10") Then
                $key = "reopen" ; Ctrl+Shift+T
            Else
                $key = "new"
            EndIf
        ElseIf _IsPressed("57") Then ; Ctrl+W
            $key = "close"
        Else
            ; Ctrl+1~8 切到指定分頁；Ctrl+9 切到最後分頁。
            For $digit = 1 To 9
                If _IsPressed(Hex(0x30 + $digit, 2)) Then
                    $key = "tab:" & $digit
                    ExitLoop
                EndIf
            Next
        EndIf
    EndIf
    If $key = "" Then
        $gHHShortcutLatch = ""
        Return
    EndIf
    If $key = $gHHShortcutLatch Then Return
    $gHHShortcutLatch = $key
    Switch $key
        Case "previous"
            HelperPreviousTab(0)
        Case "next"
            HelperNextTab(0)
        Case "new"
            HelperNewTab(0)
        Case "close"
            HelperCloseTab(0)
        Case "reopen"
            HH92_ReopenClosedTab()
        Case Else
            If StringLeft($key, 4) = "tab:" Then HH_SelectTabNumber(Number(StringTrimLeft($key, 4)))
    EndSwitch
EndFunc

; 分頁標題超過 48 字時截斷加上「…」。
Func HH112_DisplayTitle($title, $count)
    #forceref $count
    Local $s = StringLeft($title, 48)
    If StringLen($title) > 48 Then $s &= "…"
    Return $s
EndFunc

; 螢幕座標是否落在分頁列範圍內。
Func HH99_IsHeaderPoint($sx, $sy)
    If Not WinActive($gWnd) Or $gDrawerOpen Then Return False
    Local $p = P133Point($sx, $sy), $b = _UI_GetBounds($gWnd, $gTabPrevButton)
    If Not IsArray($p) Or Not IsArray($b) Then Return False
    Return $p[0] >= 12 And $p[0] < $b[0] - 8 And $p[1] >= 109 And $p[1] < 149
EndFunc

; 關閉指定位置的分頁（最後一個分頁改成空白頁，不真的關閉）。
Func HH93_CloseTabAt($index)
    Local $count = _UI_WebViewGetTabCount($gWnd, $gWeb)
    If $index < 0 Or $index >= $count Then Return
    Local $tabId = _UI_WebViewGetTabIdAt($gWnd, $gWeb, $index)
    If $tabId <= 0 Then Return
    Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tabId)
    If $count = 1 Then
        ; 最後一個分頁維持原本行為（改成空白頁），並記入最近關閉清單。
        HH92_RememberClosedTab($url)
        _UI_WebViewNavigate($gWnd, $gWeb, "http://127.0.0.1:" & $gPort & "/__helper_blank__")
        _UI_TabsSetItemText($gWnd, $gBrowserTabs, $index, "新分頁")
        ReDim $gTabSources[0]
        $gPendingUrl = ""
        _UI_SetText($gWnd, $gStatus, "")
        Return
    EndIf
    If _UI_WebViewCloseTab($gWnd, $gWeb, $tabId) Then
        HH92_RememberClosedTab($url)
        _UI_TabsRemoveItem($gWnd, $gBrowserTabs, $index)
        If $index < UBound($gTabSources) Then _ArrayDelete($gTabSources, $index)
    EndIf
EndFunc

; Ctrl+1～8 切到指定分頁，Ctrl+9 切到最後一個。
Func HH_SelectTabNumber($number)
    Local $count = P133SyncOrder()
    If $count < 1 Or $number < 1 Then Return False
    Local $pos = $number - 1
    If $number = 9 Then $pos = $count - 1
    If $pos >= $count Then Return False
    Return P133SwitchToOrder($pos)
EndFunc

; 「◀」按鈕：切到前一個分頁。
Func HelperPreviousTab($id)
    #forceref $id
    Return HH_SwitchTabRelative(-1)
EndFunc

; 「▶」按鈕：切到下一個分頁。
Func HelperNextTab($id)
    #forceref $id
    Return HH_SwitchTabRelative(1)
EndFunc

; 「✚」按鈕：新增空白分頁（分頁建立是非同步的）。
Func HelperNewTab($id)
    #forceref $id
    HH_CancelTranslationOnTabChange()
    Local $blank = "about:blank"
    If StartHttp() Then $blank = "http://127.0.0.1:" & $gPort & "/__helper_blank__"
    Local $i = _UI_WebViewNewTab($gWnd, $gWeb, $blank)
    If $i <= 0 Then Return 0
    _UI_SetText($gWnd, $gStatus, "")
    ; AUI 分頁建立是非同步的；不能立即假設 GetTabCount 已包含新頁。
    Local $count = _UI_WebViewGetTabCount($gWnd, $gWeb)
    #forceref $count
    ; 不在此立即新增 UI 標籤：WebView 分頁非同步建立，由 HelperSyncTabs 統一同步。
    ; 不立刻切換未就緒的分頁，也不修改 UI 選取項；交由主迴圈處理。
    Return $i
EndFunc

; 「✖」按鈕：關閉目前分頁並記入最近關閉清單。
Func HelperCloseTab($id)
    #forceref $id
    HH_CancelTranslationOnTabChange()
    Local $i = _UI_TabsGetSelected($gWnd, $gBrowserTabs)
    Local $tid = _UI_WebViewGetTabIdAt($gWnd, $gWeb, $i)
    If $tid <= 0 Then Return
    ; 關閉前先記下網址；本機服務與內部空白頁不記錄。
    Local $hh92ClosedUrl = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
    If _UI_WebViewGetTabCount($gWnd, $gWeb) <= 1 Then
        HH92_RememberClosedTab($hh92ClosedUrl)
        ; 最後一頁關閉時直接重用 WebView 原生分頁，不要關閉後再建一頁。
        _UI_WebViewNavigate($gWnd, $gWeb, "http://127.0.0.1:" & $gPort & "/__helper_blank__")
        _UI_TabsSetItemText($gWnd, $gBrowserTabs, $i, "新分頁")
        ReDim $gTabSources[0]

        $gPendingUrl = ""
        _UI_SetText($gWnd, $gStatus, "")
        Return
    EndIf
    If _UI_WebViewCloseTab($gWnd, $gWeb, $tid) Then
        HH92_RememberClosedTab($hh92ClosedUrl)
        _UI_TabsRemoveItem($gWnd, $gBrowserTabs, $i)
        If $i < UBound($gTabSources) Then _ArrayDelete($gTabSources, $i)

    EndIf
EndFunc

; 記住剛關閉的網站網址，供 Ctrl+Shift+T 重新開啟（最多 15 筆，只存在記憶體）。
Func HH92_RememberClosedTab($url)
    If Not StringRegExp($url, "(?i)^https?://") Then Return
    ; 本機服務的網址是暫時的，絕不能當成網站重新開啟。
    If StringRegExp($url, "(?i)^https?://(127\.0\.0\.1|localhost)(:|/|$)") Then Return
    If StringLen($url) > 4096 Then Return
    Local $n = UBound($gHH92ClosedUrls)
    If $n >= $gHH92RestoreMax Then
        _ArrayDelete($gHH92ClosedUrls, 0)
        $n -= 1
    EndIf
    ReDim $gHH92ClosedUrls[$n + 1]
    $gHH92ClosedUrls[$n] = $url
EndFunc

; 重新開啟最近關閉的網站分頁。
Func HH92_ReopenClosedTab()
    Local $n = UBound($gHH92ClosedUrls)
    If $n < 1 Then Return
    Local $url = $gHH92ClosedUrls[$n - 1]
    ReDim $gHH92ClosedUrls[$n - 1]
    If Not StringRegExp($url, "(?i)^https?://") Then Return
    Local $created = _UI_WebViewNewTab($gWnd, $gWeb, $url)
    If $created <= 0 Then
        ; 新分頁建立失敗時，把網址放回清單。
        HH92_RememberClosedTab($url)
        Return
    EndIf
EndFunc

; 隱藏分頁元件的選取變更：切換 WebView 分頁並更新網址列。
Func HelperTabChanged($id, $value)
    #forceref $id
    HH_CancelTranslationOnTabChange()
    $gAddressEditHold = False
    Local $tid = _UI_WebViewGetTabIdAt($gWnd, $gWeb, Number($value))
    If $tid > 0 Then
        _UI_WebViewSwitchTab($gWnd, $gWeb, $tid)
        HH_RefreshChmHistory()
        Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
        If $url = "about:blank" Then $url = ""
        Local $idx = Number($value)
        If $idx >= 0 And $idx < UBound($gTabSources) And $gTabSources[$idx] <> "" Then
            HH_AddressSet($gTabSources[$idx])
        ElseIf $url = "" Or $url = "about:blank" Or StringInStr($url, "/__helper_blank__") Or StringInStr($url, "/__helper_text__/") Then
            HH_AddressSet("")
        ElseIf StringInStr($url, "/__html_helper_index__") = 0 Then
            HH_AddressSet($url)
        EndIf
    EndIf
EndFunc

; 同步隱藏分頁元件與 WebView 分頁（數量、標題、選取項）。
Func HelperSyncTabs()
    Local $n = _UI_WebViewGetTabCount($gWnd, $gWeb)
    If $n < 1 Then Return
    Local $guard = 0
    While _UI_TabsGetItemCount($gWnd, $gBrowserTabs) > $n And $guard < 64
        _UI_TabsRemoveItem($gWnd, $gBrowserTabs, _UI_TabsGetItemCount($gWnd, $gBrowserTabs) - 1)
        $guard += 1
    WEnd
    $guard = 0
    While _UI_TabsGetItemCount($gWnd, $gBrowserTabs) < $n And $guard < 64
        _UI_TabsAddItem($gWnd, $gBrowserTabs, "載入中")
        $guard += 1
    WEnd
    For $i = 0 To $n - 1
        Local $tid = _UI_WebViewGetTabIdAt($gWnd, $gWeb, $i)
        If $tid <= 0 Then ContinueLoop
        Local $title = _UI_WebViewGetTabTitle($gWnd, $gWeb, $tid)
        If $i < UBound($gTabSources) And $gTabSources[$i] <> "" Then $title = StringRegExpReplace($gTabSources[$i], "^.*[\\/]", "")
        Local $tabUrl = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
        If StringInStr($tabUrl, "127.0.0.1:" & $gPort & "/__helper_blank__") Or $tabUrl = "about:blank" Then
            $title = "新分頁"
        ElseIf StringInStr($tabUrl, "127.0.0.1:" & $gPort & "/__vchm__/") And ($title = "" Or StringInStr($title, "127.0.0.1")) Then
            Local $m = StringRegExp($tabUrl, "(?i)/__vchm__/([0-9]+)/", 1)
            If IsArray($m) Then
                Local $di = Number($m[0])
                If $di > 0 And $di < UBound($gVChmPaths) Then $title = StringRegExpReplace($gVChmPaths[$di], "^.*[\\/]", "")
            EndIf
        EndIf
        If $title = "" Or StringInStr($title, "127.0.0.1:") Then
            If StringRegExp($tabUrl, "(?i)^https?://") And Not StringInStr($tabUrl, "127.0.0.1:" & $gPort & "/") Then
                $title = StringRegExpReplace($tabUrl, "(?i)^https?://([^/]+).*$", "$1")
            Else
                $title = "新分頁"
            EndIf
        EndIf
        Local $displayTitle = HH112_DisplayTitle($title, $n)
        If _UI_TabsGetItemText($gWnd, $gBrowserTabs, $i) <> $displayTitle Then _UI_TabsSetItemText($gWnd, $gBrowserTabs, $i, $displayTitle)
        If $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb) Then
            If _UI_TabsGetSelected($gWnd, $gBrowserTabs) <> $i Then _UI_TabsSetSelected($gWnd, $gBrowserTabs, $i)
            Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tid)
            #forceref $url
            ; 網址只在切換分頁或使用者送出後更新，不能每秒覆蓋正在輸入的內容。
        EndIf
    Next
EndFunc

; 螢幕座標轉成主視窗的邏輯座標（已除以 DPI 縮放）。
Func P133Point($sx, $sy)
    Local $p = DllStructCreate("long x;long y")
    DllStructSetData($p, 1, $sx)
    DllStructSetData($p, 2, $sy)
    Local $r = DllCall("user32.dll", "bool", "ScreenToClient", "hwnd", $gWnd, "ptr", DllStructGetPtr($p))
    If @error Or Not IsArray($r) Then Return 0
    If Not $r[0] Then Return 0
    Local $scale = _UI_GetDpiScale($gWnd)
    If @error Or $scale <= 0 Then $scale = 1
    Local $xy[2] = [DllStructGetData($p, 1) / $scale, DllStructGetData($p, 2) / $scale]
    Return $xy
EndFunc

; WebView 分頁 ID 轉成位置索引（找不到回傳 -1）。
Func P133Index($tid)
    If $tid <= 0 Then Return -1
    For $i = 0 To _UI_WebViewGetTabCount($gWnd, $gWeb) - 1
        If _UI_WebViewGetTabIdAt($gWnd, $gWeb, $i) = $tid Then Return $i
    Next
    Return -1
EndFunc

; 分頁顯示順序（可拖曳排序）：WebView 本身不支援移動分頁，因此另存一份顯示用的分頁 ID 順序。
Func P133SyncOrder()
    Local $n = _UI_WebViewGetTabCount($gWnd, $gWeb), $live = "|"
    For $i = 0 To $n - 1
        $live &= _UI_WebViewGetTabIdAt($gWnd, $gWeb, $i) & "|"
    Next
    Local $keep[$n + 1], $k = 0, $have = "|"
    For $i = 0 To UBound($gTabOrder) - 1
        If $k < $n And StringInStr($live, "|" & $gTabOrder[$i] & "|") And Not StringInStr($have, "|" & $gTabOrder[$i] & "|") Then
            $keep[$k] = $gTabOrder[$i]
            $have &= $gTabOrder[$i] & "|"
            $k += 1
        EndIf
    Next
    For $i = 0 To $n - 1
        Local $tid = _UI_WebViewGetTabIdAt($gWnd, $gWeb, $i)
        If $k < $n And Not StringInStr($have, "|" & $tid & "|") Then
            $keep[$k] = $tid
            $have &= $tid & "|"
            $k += 1
        EndIf
    Next
    ReDim $keep[$k]
    $gTabOrder = $keep
    Return $k
EndFunc

; 分頁 ID 在顯示順序中的位置。
Func P133OrderPos($tid)
    For $i = 0 To UBound($gTabOrder) - 1
        If $gTabOrder[$i] = $tid Then Return $i
    Next
    Return -1
EndFunc

; 依顯示順序切換分頁（◀ ▶、Ctrl+Tab、Ctrl+數字）。
Func P133SwitchToOrder($pos)
    If $pos < 0 Or $pos >= UBound($gTabOrder) Then Return False
    Local $tid = $gTabOrder[$pos], $index = P133Index($tid)
    If $tid <= 0 Or $index < 0 Then Return False
    HH_CancelTranslationOnTabChange()
    _UI_WebViewSwitchTab($gWnd, $gWeb, $tid)
    HH_RefreshChmHistory()
    _UI_TabsSetSelected($gWnd, $gBrowserTabs, $index)
    $gAddressEditHold = False
    HH_SyncAddressBar()
    HH_SyncHistoryButtons()
    $g133TabSignature = ""
    Return True
EndFunc

; 拖曳中：游標移到哪個位置，就把拖曳的分頁移到那裡（即時重排）。
Func P133DragTo($sx, $sy)
    #forceref $sy
    If $g133TabCount <= 0 Or $g133TabWidth <= 0 Then Return
    Local $lp = P133Point($sx, $sy)
    If Not IsArray($lp) Then Return
    Local $k = Int(($lp[0] - 12) / ($g133TabWidth + 2))
    If $k < 0 Then $k = 0
    If $k > $g133TabCount - 1 Then $k = $g133TabCount - 1
    Local $target = $g133TabFirst + $k, $cur = P133OrderPos($g133DragTid)
    If $cur < 0 Or $target = $cur Or $target >= UBound($gTabOrder) Then Return
    Local $moving = $gTabOrder[$cur]
    If $target > $cur Then
        For $i = $cur To $target - 1
            $gTabOrder[$i] = $gTabOrder[$i + 1]
        Next
    Else
        For $i = $cur To $target + 1 Step -1
            $gTabOrder[$i] = $gTabOrder[$i - 1]
        Next
    EndIf
    $gTabOrder[$target] = $moving
    $g133TabSignature = ""
    P133Tabs()
EndFunc

; 螢幕座標落在第幾個可見分頁上（-1＝不在分頁上）。
Func P133Slot($sx, $sy)
    If Not HH99_IsHeaderPoint($sx, $sy) Then Return -1
    Local $p = P133Point($sx, $sy)
    If Not IsArray($p) Then Return -1
    For $i = 0 To $g133TabCount - 1
        If $p[0] >= $g133TabLeft[$i] And $p[0] < $g133TabLeft[$i] + $g133TabWidth Then Return $i
    Next
    Return -1
EndFunc

; 點選分頁回呼。
Func P133TabClick($id)
    If Not HH_MainUsable() Then Return
    For $i = 0 To $g133TabCount - 1
        If $g133TabButtons[$i] <> $id And $g133TabTexts[$i] <> $id And $g133TabBars[$i] <> $id Then ContinueLoop
        P133ActivateSlot($i)
        Return
    Next
EndFunc

; 切換到指定位置的分頁；已是目前分頁時不動作（避免重複切換而取消進行中的翻譯）。
Func P133ActivateSlot($i)
    If $i < 0 Or $i >= $g133TabCount Then Return
    If $g133TabIds[$i] <= 0 Or $g133TabIds[$i] = _UI_WebViewGetCurrentTab($gWnd, $gWeb) Then Return
    Local $index = P133Index($g133TabIds[$i])
    If $index < 0 Then Return
    HelperTabChanged($gBrowserTabs, $index)
    _UI_TabsSetSelected($gWnd, $gBrowserTabs, $index)
    $g133TabSignature = ""
    P133Tabs()
EndFunc

; 方形分頁沒有原生按鈕的按下／滑過效果：以輪詢處理左鍵點選與滑過提示色。
Func P133TabMouseTick()
    If $gDrawerOpen Or $g133TabCount <= 0 Or Not HH_MainUsable() Then
        ; 對話視窗（設定、字型）開著時主視窗停用，不可透過輪詢切換分頁。
        $g133LeftHeld = _IsPressed("01")
        $g133LeftSlot = -1
        $g133DragTid = 0
        $g133Dragging = False
        Return
    EndIf
    Local $p = MouseGetPos(), $slot = P133Slot($p[0], $p[1])
    Local $down = _IsPressed("01")
    If $down And Not $g133LeftHeld Then
        $g133LeftSlot = $slot
        $g133DragTid = 0
        If $slot >= 0 Then $g133DragTid = $g133TabIds[$slot]
        $g133DragX = $p[0]
        $g133Dragging = False
    ElseIf $down And $g133LeftHeld And $g133DragTid > 0 Then
        If Not $g133Dragging Then
            Local $scale = _UI_GetDpiScale($gWnd)
            If @error Or $scale <= 0 Then $scale = 1
            If Abs($p[0] - $g133DragX) > 10 * $scale Then $g133Dragging = True
        EndIf
        If $g133Dragging Then P133DragTo($p[0], $p[1])
    ElseIf Not $down And $g133LeftHeld Then
        If $g133Dragging Then
            ; 拖曳結束：切換到被拖曳的分頁。
            Local $pos = P133OrderPos($g133DragTid)
            If $g133DragTid <> _UI_WebViewGetCurrentTab($gWnd, $gWeb) Then P133SwitchToOrder($pos)
            $g133TabSignature = ""
            P133Tabs()
        ElseIf $slot >= 0 And $slot = $g133LeftSlot Then
            P133ActivateSlot($slot)
        EndIf
        $g133LeftSlot = -1
        $g133DragTid = 0
        $g133Dragging = False
    EndIf
    $g133LeftHeld = $down
    If $slot <> $g133TabHover Then
        Local $old = $g133TabHover
        $g133TabHover = $slot
        If $old >= 0 Then P133TabStyle($old)
        If $slot >= 0 Then P133TabStyle($slot)
    EndIf
EndFunc

; 讀取 AUI 主題色票；讀不到時依亮暗主題使用相近的預設色。
Func P133ThemeColor($token, $light, $dark)
    Local $c = _UI_ThemeGetColor($gWnd, $token)
    If @error Or $c = 0 Then Return (HelperEffectiveTheme() = $AUI_THEME_DARK ? $dark : $light)
    If BitAND($c, 0xFF000000) = 0 Then $c = BitOR($c, 0xFF000000)
    Return $c
EndFunc

; 依字元實際寬度估算可顯示長度：中日韓全形字約 1 個字級寬，英數半形約 0.56 個字級寬。
; 原本一律以全形寬度計算，英文標題會過早被截斷。
Func P133CharWidth($c, $size)
    Local $code = AscW($c)
    If $code >= 0x2E80 Or ($code >= 0x1100 And $code <= 0x11FF) Then Return $size
    If $c = " " Or $c = "i" Or $c = "l" Or $c = "j" Or $c = "." Or $c = "," Or $c = ":" Or $c = "|" Or $c = "!" Or $c = "'" Then Return $size * 0.3
    If StringIsUpper($c) Or $c = "m" Or $c = "w" Then Return $size * 0.7
    Return $size * 0.56
EndFunc

; 依可用寬度截斷分頁標題並加上「…」。
Func P133FitLabel($title, $avail)
    Local $size = ($gAppSize > 0 ? $gAppSize : 14), $total = 0, $n = StringLen($title)
    For $k = 1 To $n
        $total += P133CharWidth(StringMid($title, $k, 1), $size)
    Next
    If $total <= $avail Then Return $title
    Local $limit = $avail - $size, $used = 0, $out = ""
    For $k = 1 To $n
        Local $c = StringMid($title, $k, 1), $cw = P133CharWidth($c, $size)
        If $used + $cw > $limit Then ExitLoop
        $out &= $c
        $used += $cw
    Next
    If $out = "" Then $out = StringLeft($title, 1)
    Return $out & "…"
EndFunc

; 套用分頁的底色、文字色與選中時的強調線。
Func P133TabStyle($i)
    If $i < 0 Or $i > 31 Or Not $g133TabButtons[$i] Then Return
    Local $isActive = ($g133TabIds[$i] > 0 And $g133TabIds[$i] = $g133TabActive)
    Local $bg, $fg
    If $isActive Then
        $bg = P133ThemeColor("selected_bg", 0xFFFFFFFF, 0xFF3A3A3A)
        $fg = P133ThemeColor("text_primary", 0xFF1B1B1B, 0xFFF3F3F3)
    ElseIf $i = $g133TabHover Then
        $bg = P133ThemeColor("hover_bg", 0xFFE5E5E5, 0xFF353535)
        $fg = P133ThemeColor("text_primary", 0xFF1B1B1B, 0xFFF3F3F3)
    Else
        $bg = P133ThemeColor("panel_bg", 0xFFF0F0F0, 0xFF2B2B2B)
        $fg = P133ThemeColor("text_secondary", 0xFF5C5C5C, 0xFFC5C5C5)
    EndIf
    _UI_SetColor($gWnd, $g133TabButtons[$i], $bg, $fg)
    If $g133TabTexts[$i] Then _UI_SetColor($gWnd, $g133TabTexts[$i], 0, $fg)
    If $g133TabBars[$i] Then
        If $isActive Then _UI_SetColor($gWnd, $g133TabBars[$i], P133ThemeColor("accent", 0xFF0078D4, 0xFF4CC2FF), 0)
        _UI_SetVisible($gWnd, $g133TabBars[$i], $isActive)
    EndIf
EndFunc

; 重建可見的方形分頁（內容有變動時才重繪）。
Func P133Tabs()
    If $gDrawerOpen Or TimerDiff($gDrawerTransitionClock) < $gDrawerAnimationMs Then Return
    If $gHH89MiddleHeld Or _IsPressed("04") Then Return
    If Not $gWeb Or Not $gTabPrevButton Then Return
    Local $b = _UI_GetBounds($gWnd, $gTabPrevButton)
    If Not IsArray($b) Then Return
    Local $space = $b[0] - 20, $n = _UI_WebViewGetTabCount($gWnd, $gWeb), $cap = Int(($space + 4) / 164)
    If $cap < 1 Then $cap = 1
    If $cap > 32 Then $cap = 32
    Local $count = $n
    If $count > $cap Then $count = $cap
    If $space < 36 Then $count = 0
    If P133SyncOrder() <> $n Then $n = UBound($gTabOrder)
    If $count > $n Then $count = $n
    Local $active = _UI_WebViewGetCurrentTab($gWnd, $gWeb), $sel = P133OrderPos($active)
    If $count > 0 And $sel >= 0 And Not $g133Dragging Then
        If $sel < $g133TabFirst Then $g133TabFirst = $sel
        If $sel >= $g133TabFirst + $count Then $g133TabFirst = $sel - $count + 1
    EndIf
    If $g133TabFirst + $count > $n Then $g133TabFirst = $n - $count
    If $g133TabFirst < 0 Then $g133TabFirst = 0
    Local $sig = $space & ":" & $n & ":" & $active & ":" & $g133TabFirst & ":" & $gAppFont & ":" & $gAppSize & ":" & $gAppliedTheme
    For $j = 0 To $count - 1
        Local $t = _UI_TabsGetItemText($gWnd, $gBrowserTabs, P133Index($gTabOrder[$g133TabFirst + $j]))
        $sig &= ":" & StringLen($t) & ":" & $t & ":" & $gTabOrder[$g133TabFirst + $j]
    Next
    If $sig = $g133TabSignature Then Return
    $g133TabSignature = $sig
    Local $w = 0
    If $count > 0 Then $w = Int(($space - 2 * ($count - 1)) / $count)
    If $w > 260 Then $w = 260
    $g133TabActive = $active
    Local $textH = Int(($gAppSize > 0 ? $gAppSize : 14) * 1.6) + 2
    If $textH > 38 Then $textH = 38
    Local $textY = Int((40 - $textH) / 2)
    For $i = 0 To 31
        If $i >= $count Then
            If $g133TabButtons[$i] Then _UI_SetVisible($gWnd, $g133TabButtons[$i], False)
            $g133TabIds[$i] = 0
            ContinueLoop
        EndIf
        Local $idx = $g133TabFirst + $i, $tid = $gTabOrder[$idx], $title = _UI_TabsGetItemText($gWnd, $gBrowserTabs, P133Index($tid))
        If $title = "" Then $title = "新分頁"
        Local $label = P133FitLabel($title, $w - 24), $x = 12 + $i * ($w + 2)
        ; 方形分頁：Panel（直角底色）＋文字＋選中時底部 3px 主題強調色線。
        If Not $g133TabButtons[$i] Then
            $g133TabButtons[$i] = _UI_Panel($gWnd, 0, $x, 109, $w, 40)
            $g133TabTexts[$i] = _UI_Text($gWnd, $g133TabButtons[$i], $label, 12, $textY, $w - 24, $textH)
            $g133TabBars[$i] = _UI_Panel($gWnd, $g133TabButtons[$i], 0, 37, $w, 3)
            If $g133TabTexts[$i] Then _UI_SetWrap($gWnd, $g133TabTexts[$i], False)
            _UI_OnClick($gWnd, $g133TabButtons[$i], "P133TabClick")
            If $g133TabTexts[$i] Then _UI_OnClick($gWnd, $g133TabTexts[$i], "P133TabClick")
        EndIf
        _UI_SetBounds($gWnd, $g133TabButtons[$i], $x, 109, $w, 40)
        If $g133TabTexts[$i] Then
            _UI_SetBounds($gWnd, $g133TabTexts[$i], 12, $textY, $w - 24, $textH)
            _UI_SetFont($gWnd, $g133TabTexts[$i], $gAppFont, $gAppSize)
            _UI_SetText($gWnd, $g133TabTexts[$i], $label)
            _UI_TooltipSetText($gWnd, $g133TabTexts[$i], $title)
        EndIf
        If $g133TabBars[$i] Then _UI_SetBounds($gWnd, $g133TabBars[$i], 0, 37, $w, 3)
        _UI_TooltipSetText($gWnd, $g133TabButtons[$i], $title)
        $g133TabIds[$i] = $tid
        $g133TabLeft[$i] = $x
        P133TabStyle($i)
        _UI_SetVisible($gWnd, $g133TabButtons[$i], True)
    Next
    $g133TabCount = $count
    $g133TabWidth = $w
EndFunc
