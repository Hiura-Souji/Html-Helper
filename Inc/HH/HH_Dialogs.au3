#include-once
; =============================================================================
; Html Helper － 對話框與通知
;
; AUI 訊息對話框、可複製內容的對話框，
; 以及網頁翻譯共用的通知（同一則原地更新）。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 網頁右鍵翻譯（AI／Google）的訊息一律用 AUI 通知；同一則通知原地更新，不會一直疊加。
Func HH_TrNotify($title, $body = "", $variant = $AUI_NOTIFY_INFO, $duration = 3000)
    If $gWnd = 0 Then Return 0
    If $gTrNotifyId <> 0 And _UI_NotifyGetOpen($gWnd, $gTrNotifyId) Then
        If _UI_NotifyUpdate($gWnd, $gTrNotifyId, $title, $body, $variant, $duration) Then Return $gTrNotifyId
    EndIf
    $gTrNotifyId = _UI_Notify($gWnd, $title, $body, $variant, $duration)
    Return $gTrNotifyId
EndFunc

; 翻譯用警告通知（顯示 6 秒），固定回傳 False 方便直接 Return。
Func HH_TrMsg($title, $body)
    HH_TrNotify($title, $body, $AUI_NOTIFY_WARNING, 6000)
    Return False
EndFunc

; 翻譯進度通知，最多每 400 ms 更新一次。
Func HH_TrProgress($title, $body)
    If $gTrNotifyClock <> 0 And TimerDiff($gTrNotifyClock) < 400 Then Return
    $gTrNotifyClock = TimerInit()
    HH_TrNotify($title, $body, $AUI_NOTIFY_INFO, 5000)
EndFunc

; 關閉翻譯通知並重設狀態。
Func HH_TrNotifyClose()
    If $gTrNotifyId <> 0 And $gWnd <> 0 Then _UI_NotifyClose($gWnd, $gTrNotifyId)
    $gTrNotifyId = 0
    $gTrNotifyClock = 0
EndFunc

; 在主視窗顯示只有「確定」的訊息對話框（AUI 對話框不會阻塞，後續動作由主迴圈排程）。
Func P135Info($title, $body)
    If $gWnd = 0 Then Return _UI_MessageBox(0, $title, $body, $AUI_ICON_ERROR, $AUI_BTN_OK)
    Local $d = _UI_Dialog($gWnd, $title, $body, "確定")
    If $d Then
        _UI_DialogSetDefaultButton($gWnd, $d, 0)
        _UI_DialogSetCancelButton($gWnd, $d, 0)
    Else
        _UI_Notify($gWnd, $title, $body, $AUI_NOTIFY_WARNING, 7000)
    EndIf
    Return $d
EndFunc

; 在指定子視窗顯示訊息對話框（避免蓋在主視窗後面點不到）。
Func P136Info($wnd, $title, $body)
    ; 訊息顯示在發出請求的子視窗（AI 設定／翻譯視窗）上，避免蓋在主視窗造成無法點按。
    If $wnd = 0 Or Not _UI_IsAlive($wnd) Then Return P135Info($title, $body)
    Local $d = _UI_Dialog($wnd, $title, $body, "確定")
    If $d Then
        _UI_DialogSetDefaultButton($wnd, $d, 0)
        _UI_DialogSetCancelButton($wnd, $d, 0)
    Else
        _UI_Notify($wnd, $title, $body, $AUI_NOTIFY_WARNING, 7000)
    EndIf
    Return $d
EndFunc

; 顯示多按鈕對話框，選擇結果由 $callback 處理。
Func P135Ask($title, $body, $buttons, $callback, $defaultIndex, $cancelIndex)
    Local $d = _UI_Dialog($gWnd, $title, $body, $buttons)
    $g135DialogClock = TimerInit()
    If Not $d Then
        P135Info("不能建立對話框", $title)
        Return 0
    EndIf
    _UI_DialogSetDefaultButton($gWnd, $d, $defaultIndex)
    _UI_DialogSetCancelButton($gWnd, $d, $cancelIndex)
    _UI_OnValue($gWnd, $d, $callback)
    Return $d
EndFunc

; 顯示內容並提供「複製完整內容」按鈕（翻譯結果用）。
Func P135ClipboardDialog($title, $text)
    Local $d = P135Ask($title, StringLeft($text, 3500) & @CRLF & @CRLF & "可複製完整譯文或直接關閉。", "複製完整譯文|關閉", "P135ClipboardReply", 0, 1)
    If $d Then $g135Clipboard.Item(String($d)) = $text
EndFunc

; P135ClipboardDialog 的按鈕回呼：需要時把完整內容放進剪貼簿。
Func P135ClipboardReply($id, $value)
    Local $key = String($id)
    If Not $g135Clipboard.Exists($key) Then Return
    If Number($value) = 0 Then ClipPut($g135Clipboard.Item($key))
    $g135Clipboard.Remove($key)
EndFunc
