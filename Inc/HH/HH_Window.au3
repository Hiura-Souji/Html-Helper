#include-once
; =============================================================================
; Html Helper － 主視窗
;
; 主視窗的工具列選單、左側設定抽屜、最小化處理、視窗尺寸調整、
; 拖放與結束清理。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 實驗性 Win32 最小化相容處理：先還原，再最小化；還原時恢復最大化。
; 返回 GUI_RUNDEFMSG 交給 AUI 原本的 WndProc，不攔截其他視窗訊息。
; 最小化前先從 AUI hit-test 與 WebView2 顯示樹移除 WebView，避免渲染表面留在桌面。
; 保留 Acrylic，不銷毀 WebView/分頁，不操作其他 Chrome 視窗。
Func HH_HideWebForMinimize()
    If $gHHWebHiddenForMinimize Or $gWnd = 0 Or $gWeb = 0 Then Return
    _UI_SetVisible($gWnd, $gWeb, False)
    $gHHWebHiddenForMinimize = True
EndFunc

; 視窗還原後重新顯示 WebView。
Func HH_RestoreWebAfterMinimize()
    If Not $gHHWebHiddenForMinimize Or $gWnd = 0 Or $gWeb = 0 Then Return
    ; 避免主視窗仍最小化時提早顯示 WebView。
    If BitAND(WinGetState($gWnd), 16) Then Return
    $gHHWebHiddenForMinimize = False
    If Not $gMenuHidden Then _UI_SetVisible($gWnd, $gWeb, True)
EndFunc

; AUI 可能自行處理最小化，故同時在主迴圈輪詢 WinGetState。
Func HH_SyncWebMinimizeState()
    If $gWnd = 0 Then Return
    Local $bIconic = (BitAND(WinGetState($gWnd), 16) <> 0)
    If $bIconic Then
        HH_HideWebForMinimize()
    ElseIf $gHHWebHiddenForMinimize Then
        HH_RestoreWebAfterMinimize()
    EndIf
EndFunc

; WM_SYSCOMMAND：按下最小化時先隱藏 WebView，再交回 AUI 處理。
Func HelperSysCommand($hWnd, $iMsg, $wParam, $lParam)
    #forceref $iMsg, $lParam
    If $hWnd <> $gWnd Then Return $GUI_RUNDEFMSG
    If BitAND($wParam, 0xFFF0) = $HH_SC_MINIMIZE Then
        HH_HideWebForMinimize()
        ; 交回原本 AUI/Windows 最小化程序；不再先還原後最小化。
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc

; WM_SIZE：依最小化／還原狀態隱藏或顯示 WebView。
Func HelperWindowSize($hWnd, $iMsg, $wParam, $lParam)
    #forceref $iMsg, $lParam
    If $hWnd <> $gWnd Then Return $GUI_RUNDEFMSG
    If $wParam = $HH_SIZE_MINIMIZED Then
        HH_HideWebForMinimize()
    ElseIf $wParam = $HH_SIZE_RESTORED Or $wParam = 2 Then
        HH_RestoreWebAfterMinimize()
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc

; 「開啟 CHM」：選擇 CHM 檔案後開啟。
Func OpenChm($iId)
    #forceref $iId
    Local $s = FileOpenDialog("選取 AutoIt CHM 說明檔", @ScriptDir, "CHM 說明檔 (*.chm)", 1)
    If @error Then Return
    HelperOpenDropped($s)
EndFunc

; 「開啟資料夾」：選擇已解包的資料夾後開啟。
Func OpenFolder($iId)
    #forceref $iId
    Local $s = FileSelectFolder("選取已解包的 CHM 資料夾", "", 2)
    If @error Then Return
    HelperOpenDropped($s)
EndFunc

; AUI 的 ContextMenu 需要先建立，再用 ShowAt 顯示；選項從 OnValue 取得（從 0 起算）。
Func OpenMenu($iId)
    #forceref $iId
    _UI_ContextMenuShowAt($gWnd, $gOpenMenu, 12, 100)
EndFunc

; 開啟選單的選項處理（從 0 起算）。
Func OpenMenuSelected($iId, $value)
    #forceref $iId
    Switch Number($value)
        Case 0
            OpenChm(0)
        Case 1
            OpenFolder(0)
        Case 2
            Local $f = FileOpenDialog("開啟檔案", @ScriptDir, "所有檔案 (*.*)", 1)
            If Not @error Then HelperOpenDropped($f)
        Case 3
            P136OpenUrl()
        Case 4
            P133StartJob(False)
        Case 5
            P133StartJob(True)
    EndSwitch
EndFunc

; 「☰」按鈕：開關左側設定抽屜。
Func SettingsMenu($iId)
    #forceref $iId
    HH_DrawerToggle()
EndFunc

; 開關左側設定抽屜，並記錄動畫時間讓主迴圈暫停重工作。
Func HH_DrawerToggle()
    If $gSettingsDrawer <= 0 Then Return
    If $gDrawerOpen Then
        If _UI_DrawerClose($gWnd, $gSettingsDrawer) Then
            $gDrawerOpen = False
            $gDrawerTransitionClock = TimerInit()
            $gDrawerSyncPending = True
            $gDrawerResizePending = True
            $gTabClock = TimerInit()
        EndIf
    Else
        $gDrawerOpen = (_UI_DrawerOpen($gWnd, $gSettingsDrawer) <> 0)
        If $gDrawerOpen Then $gDrawerTransitionClock = TimerInit()
    EndIf
EndFunc

; 關閉設定抽屜，排定關閉後的同步與尺寸校正。
Func HH_DrawerClose($id)
    #forceref $id
    If $gSettingsDrawer > 0 And $gDrawerOpen Then _UI_DrawerClose($gWnd, $gSettingsDrawer)
    $gDrawerOpen = False
    $gDrawerTransitionClock = TimerInit()
    $gDrawerSyncPending = True
    $gDrawerResizePending = True
    $gTabClock = TimerInit()
EndFunc

; 抽屜「設定」：關閉抽屜並開啟軟體設定視窗。
Func HH_DrawerAppearance($id)
    #forceref $id
    HH_DrawerClose(0)
    OpenAppearanceSettings(0)
EndFunc

; 抽屜「建立 QR Code」：開啟空白的 QR 樣式工坊。
Func HH_DrawerQR($id)
    #forceref $id
    HH_DrawerClose(0)
    HH_ShowCustomQRCode()
EndFunc

; 抽屜「關於」：開啟關於視窗。
Func HH_DrawerAbout($id)
    #forceref $id
    HH_DrawerClose(0)
    OpenAboutDialog(0)
EndFunc

; 抽屜「命令列說明」：開啟命令列說明視窗。
Func HH_DrawerCliHelp($id)
    #forceref $id
    HH_DrawerClose(0)
    HH_Q("HH_CliHelpOpen")
EndFunc

; 抽屜「AI API 設定」：開啟 AI 設定視窗。
Func HH_DrawerAISettings($id)
    #forceref $id
    HH_DrawerClose(0)
    HH_AI_Settings()
EndFunc

; 抽屜「AI 翻譯 CHM／資料夾」：開啟整份翻譯視窗。
Func HH_DrawerSource($id)
    #forceref $id
    HH_DrawerClose(0)
    HH_SourceTranslateFolder()
EndFunc

; 「頁面大小 ▼」按鈕：顯示縮放選單。
Func ZoomMenu($iId)
    #forceref $iId
    _UI_ContextMenuShowAt($gWnd, $gZoomMenu, 228, 100)
EndFunc

; 套用縮放比例並寫入 INI（PDF／網站用 WebView 縮放，CHM 用內文 CSS）。
Func ZoomMenuSelected($iId, $value)
    #forceref $iId
    Switch Number($value)
        Case 0
            $gZoom = 150
        Case 1
            $gZoom = 125
        Case 2
            $gZoom = 100
        Case 3
            $gZoom = 85
        Case 4
            $gZoom = 70
        Case Else
            Return
    EndSwitch
    _IniWrite($gIni, "Display", "Zoom", $gZoom)
    If $gPdfMode Or $gBrowserMode Then
        _UI_WebViewSetZoom($gWnd, $gWeb, $gZoom / 100)
    Else
        HH_WebFire("if(window.setContentZoom)setContentZoom(" & $gZoom & ");")
    EndIf
    _UI_Notify($gWnd, "內容縮放", $gZoom & "%", $AUI_NOTIFY_INFO, 2000)
EndFunc

; AUI 檔案拖放回呼：每個拖入的檔案或資料夾各開一個分頁。
Func HtmlHelperAuiDrop($hWnd, $iTargetId, $aFiles, $iX, $iY)
    #forceref $hWnd, $iTargetId, $iX, $iY
    If Not IsArray($aFiles) Then Return
    If UBound($aFiles) = 0 Then Return
    ; 每個拖入項目各自排隊，不能靜默捨棄第二個以後的文件。
    For $i = 0 To UBound($aFiles) - 1
        HelperOpenDropped($aFiles[$i])
    Next
EndFunc

; 視窗尺寸改變時重新排列 WebView、網址列、分頁列與分頁按鈕。
Func ResizeViewer()
    Local $aBounds = _UI_WindowGetBounds($gWnd)
    If Not IsArray($aBounds) Then Return
    Local $iW = $aBounds[2], $iH = $aBounds[3]
    If $iW = $gLastWidth And $iH = $gLastHeight Then Return
    If $iW < 300 Or $iH < 180 Then Return
    $gLastWidth = $iW
    $gLastHeight = $iH
    _UI_SetBounds($gWnd, $gWeb, 12, 156, $iW - 24, $iH - 164)
    _UI_SetBounds($gWnd, $gStatus, 662, 64, ($iW > 694 ? $iW - 677 : 30), 36)
    ; 分頁列右側只保留 8px 給第一個浮動按鈕（x = 寬度 - 208）。
    _UI_SetBounds($gWnd, $gBrowserTabs, 12, 109, ($iW > 285 ? $iW - 216 : 60), 40)
    _UI_SetBounds($gWnd, $gTabPrevButton, $iW - 208, 109, 38, 40)
    _UI_SetBounds($gWnd, $gTabNextButton, $iW - 164, 109, 38, 40)
    _UI_SetBounds($gWnd, $gNewTabButton, $iW - 120, 109, 38, 40)
    _UI_SetBounds($gWnd, $gCloseTabButton, $iW - 76, 109, 38, 40)
    HH_DrawerAboutLayout($iH)
EndFunc

; 抽屜內容區約為視窗高度扣除標題列；「關於」貼齊底部，且不與上方按鈕重疊。
Func HH_DrawerAboutLayout($iH)
    If $gSettingsDrawer <= 0 Or $gDrawerSpacer <= 0 Then Return
    ; 可用高度約為視窗高度扣除抽屜標題與上下留白；上方 4 個按鈕 + 下方 2 個按鈕。
    Local $h = $iH - 76 - 24 - 6 * 53 - 30
    If $h < 0 Then $h = 0
    _UI_SetBounds($gWnd, $gDrawerSpacer, 0, 0, 320, $h)
EndFunc

; 「重新整理」按鈕。
Func ReloadPage($iId)
    #forceref $iId
    _UI_WebViewReload($gWnd, $gWeb)
EndFunc

; 主視窗關閉回呼（AUI 會自行結束 _UI_PumpOnce 迴圈）。
Func OnClose($hWnd)
    #forceref $hWnd
    ; AUI 將在關閉視窗後結束 _UI_PumpOnce 迴圈。
EndFunc

; 程式結束清理：結束解包程序、刪除暫存資料夾、關閉 ITSS 控制代碼與 TCP 服務。
Func Cleanup()
    Local $docKeys = $gVChmDocs.Keys()
    For $dk In $docKeys
        VChmDocClose($dk)
    Next
    If $gExtractPid<>0 And _ChmProcessRunning() Then ProcessClose($gExtractPid)
    _ChmCloseProcessHandle()
    If $gExtractTemp<>"" Then DirRemove($gExtractTemp,1)
    If $gScanTempParent<>"" Then DirRemove($gScanTempParent,1)
    If $gServer<>-1 Then TCPCloseSocket($gServer)
    TCPShutdown()
    If $gTemp<>"" Then DirRemove($gTemp,1)
EndFunc
