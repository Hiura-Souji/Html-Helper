#Region ;**** 由 AutoIt3Wrapper_GUI 建立的指令 ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Icon=HtmlHelper.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Comment=Html Helper
#AutoIt3Wrapper_Res_Description=Html Helper
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductName=Html Helper
#AutoIt3Wrapper_Res_ProductVersion=2026.10.28
#AutoIt3Wrapper_Res_CompanyName=格雷資訊
#AutoIt3Wrapper_Res_LegalCopyright=grayfree.tw 2026 Unlicense.
#AutoIt3Wrapper_Res_LegalTradeMarks=grayfree.tw
#AutoIt3Wrapper_Res_Language=1028
#AutoIt3Wrapper_Res_requestedExecutionLevel=highestAvailable
#AutoIt3Wrapper_Res_CLASS=gWinUI
#AutoIt3Wrapper_Res_HiDpi=y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6 -w 7
#EndRegion ;**** 由 AutoIt3Wrapper_GUI 建立的指令 ****
#NoTrayIcon ;不顯示系統匣圖示
#RequireAdmin ;請求管理員權限

#include "Inc\AUI.au3"
#include "Inc\_Ini.au3"
#include "Inc\ITSS.au3"
#include "Inc\HHQRCodeEmbedded.au3"
#include <File.au3>
#include <GDIPlus.au3>
#include <Crypt.au3>
#include <Array.au3>
#include <WinAPIFiles.au3>
#include <WinAPIGdi.au3>
#include <GUIConstantsEx.au3>
#include <Constants.au3>
#include <Misc.au3> ; 滑鼠側鍵與瀏覽器快捷鍵

; =============================================================================
; Html Helper
; CHM／HTML／PDF／文字檔閱讀器（AUI 介面＋WebView2），同一個 EXE 兼具：
;   · 命令列 CHM 解包（--extract-chm）與打包（--build-chm）
;   · 命令列整份 AI／Google 翻譯（--translate-chm）
; 解包時重建 HHP 與 MAP／ALIAS；缺少的中繼資料只回報、不臆造。
;
; 檔案結構（Inc\HH\）
;   HH_Globals.au3         全域變數（依模組分組）
;   HH_Core.au3            回呼佇列、WebView 腳本、字串／URL／編碼工具
;   HH_Dialogs.au3         對話框與翻譯通知
;   HH_Window.au3          主視窗、工具列選單、設定抽屜、最小化、結束清理
;   HH_Instance.au3        單一執行個體、工作列、跳躍清單
;   HH_Http.au3            127.0.0.1 本機 HTTP 服務
;   HH_OpenFiles.au3       開檔流程、資料夾掃描、舊版解包
;   HH_Reader.au3          閱讀器頁面（側欄目錄／索引＋內文）
;   HH_VChm.au3            虛擬 CHM（不解包直接讀）、磁碟快取
;   HH_Tabs.au3            自繪分頁列、分頁切換與快捷鍵
;   HH_Navigation.au3      網址列、上一頁／下一頁／首頁
;   HH_LinkPolicy.au3      中鍵開新分頁
;   HH_WebMenu.au3         網頁右鍵選單
;   HH_TranslateAI.au3     網頁 AI 翻譯（選取文字、整頁）
;   HH_TranslateGoogle.au3 網頁 Google 免費翻譯
;   HH_QR.au3              QR 點陣產生
;   HH_QRDesigner.au3      QR 樣式工坊頁面
;   HH_Settings.au3        軟體設定、關於、檔案關聯、子視窗字型
;   HH_FontPicker.au3      字型選擇視窗（DirectWrite 列舉）
;   HH_CliHelp.au3         命令列說明視窗
;   HH_ChmPack.au3         CHM 解包／打包核心（命令列）
;   HH_ChmProject.au3      HHP 處理與重建
;   HH_ChmJobUI.au3        解包／打包的 GUI 流程與進度
;   HH_AIConfig.au3        AI 設定檔、API Key 加密、請求組裝
;   HH_AISettingsUI.au3    AI 設定、目的語言、開啟網址視窗
;   HH_TranslateJobUI.au3  整份翻譯的 GUI 與進度
;   HH_TranslateEngine.au3 整份翻譯引擎（命令列）
;   HH_TranslateHtml.au3   HTML／目錄／專案的翻譯切分與寫回
; =============================================================================

; 全域變數必須在命令列分流前載入（命令列模式也會用到）。
#include "Inc\HH\HH_Globals.au3"

; ---------------------------------------------------------------------------
; 命令列模式：不建立視窗，執行完直接以結束代碼離開。
; ---------------------------------------------------------------------------
If $CmdLine[0] > 0 Then
    If StringLower($CmdLine[1]) = "--translate-chm" Then Exit P136Main()
    If StringLeft($CmdLine[1], 2) = "--" Then Exit P133Main()
EndIf

; ---------------------------------------------------------------------------
; GUI 模式
; ---------------------------------------------------------------------------
; 已有主視窗在執行時，把要開的檔案交給它開在新分頁，本程序直接結束。
HH_SingleInstance()
; 在建立任何 AUI 視窗前指定固定的工作列應用程式識別碼。
HH_TaskbarInitialize()
TCPStartup()
P133JumpInit()
HH_BuildMainWindow()
HH_StartupNavigate()
HH_InstanceRegister()
HH_MainLoop()
Cleanup()
Exit

; 建立主視窗：工具列、網址列、分頁列、WebView、選單與設定抽屜，並載入顯示設定。
Func HH_BuildMainWindow()
    $gWnd = _UI_WindowCreateEx("Html Helper", 0, 0, 1180, 790, $AUI_WIN_ACRYLIC)
    If $gWnd = 0 Then
        _UI_MessageBox(0, "啟動失敗", "無法建立 AUI 視窗，請確認 AUI.au3 的執行環境。", $AUI_ICON_ERROR, $AUI_BTN_OK)
        Exit
    EndIf
    _UI_WindowSetIcon($gWnd, @ScriptDir & '\HtmlHelper')
    $gThemeMode = Number(_IniRead($gIni, "Display", "Theme", $AUI_THEME_LIGHT))
    If $gThemeMode <> $AUI_THEME_DARK And $gThemeMode <> $AUI_THEME_AUTO Then $gThemeMode = $AUI_THEME_LIGHT
    _UI_ThemeSetMode($gWnd, $gThemeMode) ; 預設亮色，可由標題列切換
    ; AUI 使用自繪標題列，控制項 Y 座標必須避開頂部標題列。
    ; 工具列自 Y=64 起，WebView 自 Y=116 起，避免遮住視窗標題及右上角按鈕。
    ; 設定選單改為 AUI 原生圖示按鈕，固定在工具列最左側。
    ; 設定按鈕改為一般外框按鈕＋較大符號字型，比原本的透明圖示按鈕清楚。
    Local $bSettings = _UI_Button($gWnd, 0, "☰", $AUI_VAR_DEFAULT, 12, 64, 44, 36)
    _UI_TooltipSetText($gWnd, $bSettings, "開啟左側設定抽屜")
    Local $bOpen = _UI_Button($gWnd, 0, "開啟 ▼", $AUI_VAR_DEFAULT, 64, 64, 100, 36)
    Local $bZoom = _UI_Button($gWnd, 0, "頁面大小 ▼", $AUI_VAR_DEFAULT, 172, 64, 125, 36)
    Local $bHome = _UI_Button($gWnd, 0, "首頁", $AUI_VAR_DEFAULT, 305, 64, 65, 36)
    Local $bBack = _UI_Button($gWnd, 0, "上一頁", $AUI_VAR_DEFAULT, 378, 64, 80, 36)
    Local $bNext = _UI_Button($gWnd, 0, "下一頁", $AUI_VAR_DEFAULT, 466, 64, 80, 36)
    $gBackButton = $bBack
    $gNextButton = $bNext
    Local $bReload = _UI_Button($gWnd, 0, "重新整理", $AUI_VAR_DEFAULT, 554, 64, 100, 36)
    $gStatus = _UI_Input($gWnd, 0, "輸入網址或檔案路徑…", "", 662, 64, 503, 36)
    ; AUI 原生編輯框功能：從其他控制項點入網址列時，自動選取全部文字。
    _UI_EditSetSelectAllOnFocus($gWnd, $gStatus, True)
    $gBrowserTabs = _UI_Tabs($gWnd, 0, "首頁", 0, 12, 109, 850, 40)
    _UI_SetVisible($gWnd, $gBrowserTabs, False)
    $gTabPrevButton = _UI_Button($gWnd, 0, "◀", $AUI_VAR_DEFAULT, 870, 109, 38, 40)
    $gTabNextButton = _UI_Button($gWnd, 0, "▶", $AUI_VAR_DEFAULT, 914, 109, 38, 40)
    $gNewTabButton = _UI_Button($gWnd, 0, "✚", $AUI_VAR_DEFAULT, 958, 109, 38, 40)
    $gCloseTabButton = _UI_Button($gWnd, 0, "✖", $AUI_VAR_DEFAULT, 1002, 109, 38, 40)
    $gWeb = _UI_WebView($gWnd, 0, "about:blank", 12, 156, 1153, 600)
    ; 由程式自行管理網址輸入框，避免 AUI 原生綁定與同步迴圈搶走鍵盤焦點。
    _UI_OnKey($gWnd, $gStatus, "HelperAddressKey")
    _UI_SetFont($gWnd, $gBrowserTabs, "Microsoft JhengHei", 17)
    _UI_OnValue($gWnd, $gBrowserTabs, "HelperTabChanged")
    _UI_OnClick($gWnd, $gTabPrevButton, "HelperPreviousTab")
    _UI_OnClick($gWnd, $gTabNextButton, "HelperNextTab")
    _UI_OnClick($gWnd, $gNewTabButton, "HelperNewTab")
    _UI_OnClick($gWnd, $gCloseTabButton, "HelperCloseTab")
    ; AUI 原生控制項字型必須逐一套用，WebView CSS 只影響網頁。
    $gToolbarIds[0] = $bOpen
    $gToolbarIds[1] = $bSettings
    $gToolbarIds[2] = $bZoom
    $gToolbarIds[3] = $bHome
    $gToolbarIds[4] = $bBack
    $gToolbarIds[5] = $bNext
    $gToolbarIds[6] = $bReload
    $gToolbarIds[7] = $gStatus
    $gOpenMenu = _UI_ContextMenu($gWnd, $bOpen, "開啟 CHM|開啟資料夾|開啟其他檔案|開啟網址|ITSS 完整匯出 CHM|將資料夾打包成 CHM")
    ; 設定使用 AUI 原生左側抽屜；網頁翻譯匯出維持 WebView 右鍵選單
    $gZoomMenu = _UI_ContextMenu($gWnd, $bZoom, "最大（150%）|大（125%）|中（100%）|小（85%）|最小（70%）")
    ; 使用 AUI 原生右鍵選單，直接附加至 WebView 控制項，不建立 HTML 假選單。
    $gWebContextMenu = _UI_ContextMenu($gWnd, $gWeb, "上一頁|下一頁|重新整理|複製選取文字|網址 QR Code|CHM 內文編碼切換|CHM 左側欄編碼切換|AI 翻譯選取文字|AI 翻譯本頁|AI 還原原文|Google 翻譯選取文字|Google 翻譯本頁|停止整頁翻譯|翻譯目的語言…")
    _UI_OnValue($gWnd, $gOpenMenu, "OpenMenuSelected")
    ; 設定抽屜按鈕分別綁定 OnClick
    _UI_OnValue($gWnd, $gZoomMenu, "ZoomMenuSelected")
    _UI_OnValue($gWnd, $gWebContextMenu, "HH_WebContextSelected")
    _UI_OnClick($gWnd, $bOpen, "OpenMenu")
    _UI_OnClick($gWnd, $bSettings, "SettingsMenu")
    _UI_OnClick($gWnd, $bZoom, "ZoomMenu")
    _UI_OnClick($gWnd, $bHome, "GoHome")
    _UI_OnClick($gWnd, $bBack, "GoBack")
    _UI_OnClick($gWnd, $bNext, "GoForward")
    _UI_OnClick($gWnd, $bReload, "ReloadPage")
    ; 使用 AUI 原生左側 Drawer，所有設定項目都是 Drawer 子控制項。
    $gSettingsDrawer = _UI_Drawer($gWnd, "設定", $AUI_DRAWER_LEFT, 360)
    If $gSettingsDrawer <= 0 Then
        _UI_MessageBox($gWnd, "Html Helper", "無法建立 AUI 設定抽屜。請確認 AUI 版本支援 _UI_Drawer。", $AUI_ICON_ERROR, $AUI_BTN_OK)
    EndIf
    ; 抽屜不放「關閉設定」按鈕；點抽屜外或再按 ☰ 即可關閉。
    $gDrawerControls[0] = 0
    ; AUI 抽屜是由上往下自動排列（X／Y 會被忽略），順序取決於建立順序；
    ; 「設定」「關於」最後建立，前面放一個依視窗高度調整的空白區，讓兩者貼齊底部。
    $gDrawerControls[2] = _UI_Button($gWnd, $gSettingsDrawer, "建立 QR Code", $AUI_VAR_DEFAULT, 0, 0, 320, 44)
    _UI_OnClick($gWnd, $gDrawerControls[2], "HH_DrawerQR")
    $gDrawerControls[3] = _UI_Button($gWnd, $gSettingsDrawer, "AI API 設定（各家 API／自有 Key）", $AUI_VAR_DEFAULT, 0, 0, 320, 44)
    _UI_OnClick($gWnd, $gDrawerControls[3], "HH_DrawerAISettings")
    $gDrawerControls[4] = _UI_Button($gWnd, $gSettingsDrawer, "AI 翻譯 CHM／資料夾（保留結構）", $AUI_VAR_DEFAULT, 0, 0, 320, 44)
    _UI_OnClick($gWnd, $gDrawerControls[4], "HH_DrawerSource")
    $gDrawerControls[6] = _UI_Button($gWnd, $gSettingsDrawer, "命令列說明（解包／打包／翻譯）", $AUI_VAR_DEFAULT, 0, 0, 320, 44)
    _UI_OnClick($gWnd, $gDrawerControls[6], "HH_DrawerCliHelp")
    $gDrawerSpacer = _UI_Panel($gWnd, $gSettingsDrawer, 0, 0, 320, 10)
    $gDrawerControls[1] = _UI_Button($gWnd, $gSettingsDrawer, "設定", $AUI_VAR_DEFAULT, 0, 0, 320, 44)
    _UI_OnClick($gWnd, $gDrawerControls[1], "HH_DrawerAppearance")
    $gDrawerControls[5] = _UI_Button($gWnd, $gSettingsDrawer, "關於", $AUI_VAR_DEFAULT, 0, 0, 320, 44)
    _UI_OnClick($gWnd, $gDrawerControls[5], "HH_DrawerAbout")
    Local $aDrawerBounds = _UI_WindowGetBounds($gWnd)
    If IsArray($aDrawerBounds) Then HH_DrawerAboutLayout($aDrawerBounds[3])
    ; 匯出操作改回 WebView 右鍵選單，抽屜只保留設定及整份來源翻譯。
    $gAppFont = _IniRead($gIni, "Display", "AppFont", $gAppFont)
    $gAppSize = Number(_IniRead($gIni, "Display", "AppSize", "14"))
    $gSideFont = _IniRead($gIni, "Display", "SideFont", $gSideFont)
    $gContentFont = _IniRead($gIni, "Display", "ContentFont", $gContentFont)
    $gContentSize = Number(_IniRead($gIni, "Display", "ContentSize", String($gContentSize)))
    $gSideSize = Number(_IniRead($gIni, "Display", "SideSize", "14"))
    $gZoom = Number(_IniRead($gIni, "Display", "Zoom", "100"))
    $gSideWidth = Number(_IniRead($gIni, "Display", "SideWidth", "310"))
    $gContentTheme = Number(_IniRead($gIni, "Display", "ContentTheme", "0"))
    If $gContentTheme < 0 Or $gContentTheme > 2 Then $gContentTheme = 0
    ApplyAppFont()
    P136ApplyActive()
    HH_WebLangLoad()
    _UI_SetEnabled($gWnd, $gBackButton, False)
    _UI_SetEnabled($gWnd, $gNextButton, False)
    _UI_OnClose($gWnd, "OnClose")
    ; 只監聽主視窗；若 AUI 使用自己的最小化路徑，可能不會觸發此訊息。
    GUIRegisterMsg($HH_WM_SYSCOMMAND, "HelperSysCommand")
    GUIRegisterMsg($HH_WM_SIZE, "HelperWindowSize")
    _UI_WindowShow($gWnd)
    _UI_WindowMaximizeToggle($gWnd) ; 預設最大化，維持 Acrylic 樣式
    ; 恢復 Acrylic 外觀；另行試驗最小化前還原視窗。
    ; 接受拖放到主視窗的檔案與資料夾（WebView 子視窗可能攔截其區域的拖放）。
    _UI_OnFileDrop($gWnd, 0, "HtmlHelperAuiDrop")
    ; WebView 為獨立接收區域，另行註冊，避免網頁內容攔截拖放。
    _UI_OnFileDrop($gWnd, $gWeb, "HtmlHelperAuiDrop")
    ; WebView2 自身可能使用 OLE 拖放目標，主視窗標題列及工具列仍可接受 WM_DROPFILES。
EndFunc

; 命令列帶入的檔案：先載入空白頁，等 AUI 第一個分頁建立後再開（HH_StartupOpenTick）。
Func HH_StartupNavigate()
    If $CmdLine[0] > 0 Then
        If $CmdLine[0] >= 2 Then $gRequestedPage = StringReplace($CmdLine[2], "\", "/")
        ; AUI 的第一個分頁是非同步建立的；等它出現後直接載入到這個分頁，不另開一個空白分頁。
        If StartHttp() Then _UI_WebViewNavigate($gWnd, $gWeb, "http://127.0.0.1:" & $gPort & "/__helper_blank__")
        $gStartupOpen = $CmdLine[1]
        $gStartupClock = TimerInit()
    Else
        ; AUI 內建初始分頁：只替換其內容，不另外建立分頁。
        If StartHttp() Then _UI_WebViewNavigate($gWnd, $gWeb, "http://127.0.0.1:" & $gPort & "/__helper_blank__")
        ; 不自動載入上次資料夾，以免單檔模式誤顯示舊側欄。
    EndIf
EndFunc

; 主迴圈：不使用阻塞的 _UI_Run，讓本機 HTTP 服務、翻譯與解包輪詢在 AUI 訊息之間持續運作。
; 抽屜動畫期間暫停重工作；命令列說明視窗開著時只保留 HTTP 服務。
Func HH_MainLoop()
    Local $nativeDrawerOpen, $drawerAnimating, $sDrop, $newTheme, $effectiveTheme, $ready
    While 1
        If _UI_PumpOnce() < 0 Then ExitLoop
        ; AUI 回呼只排入佇列，實際動作在這裡執行，避免在回呼內重設字型、開關視窗造成重入而死當。
        HH_QDrain()
        HH_FontPreviewTick()
        HH_StartupOpenTick()
        ; 命令列說明視窗開著時，暫停主視窗的分頁同步、網頁注入、尺寸校正等輪詢，
        ; 以免主視窗搶走焦點使說明視窗的捲動卡住；只保留本機 HTTP 服務供網頁使用。
        If $gCliHelpWnd <> 0 And Not _UI_IsAlive($gCliHelpWnd) Then
            HH_ClearChildFonts($gCliHelpWnd)
            $gCliHelpWnd = 0
        EndIf
        If $gCliHelpWnd <> 0 Then
            ServiceHttp()
            Sleep(10)
            ContinueLoop
        EndIf
        ; 視窗最小化狀態不必每 10ms 呼叫 WinGetState；降低抽屜動畫期間的 Win32 輪詢。
        If TimerDiff($gWindowStateClock) > ($gDrawerOpen ? 400 : 180) And TimerDiff($gDrawerTransitionClock) >= $gDrawerAnimationMs Then
            HH_SyncWebMinimizeState()
            $gWindowStateClock = TimerInit()
        EndIf
        ; AUI 抽屜可由遮罩或 Esc 關閉，定期同步實際狀態以免背景任務永久暫停。
        If $gSettingsDrawer > 0 And TimerDiff($gDrawerStateClock) > 80 Then
            $nativeDrawerOpen = (_UI_DrawerGetOpen($gWnd, $gSettingsDrawer) <> 0)
            If $nativeDrawerOpen <> $gDrawerOpen Then
                $gDrawerOpen = $nativeDrawerOpen
                $gDrawerTransitionClock = TimerInit()
                If Not $gDrawerOpen Then
                    $gTabClock = TimerInit()
                    $gDrawerSyncPending = True
                    $gDrawerResizePending = True
                EndIf
            EndIf
            $gDrawerStateClock = TimerInit()
        EndIf
        $drawerAnimating = (TimerDiff($gDrawerTransitionClock) < $gDrawerAnimationMs)
        ; 抽屜滑動動畫期間不執行 TCP、翻譯輪詢、解包與目錄掃描，動畫結束後自動恢復。
        If $drawerAnimating Then
            Sleep(8)
            ContinueLoop
        EndIf
        If Not $gDrawerOpen Then
            P135UiTick()
            P133PollJob()
            P136Tick()
            If Not $gHH89MiddleHeld And TimerDiff($g133TabClock) >= 200 Then
                P133Tabs()
                $g133TabClock = TimerInit()
            EndIf
            If TimerDiff($g133HoverClock) >= 30 Then
                P133TabMouseTick()
                $g133HoverClock = TimerInit()
            EndIf
        EndIf
        If Not $gDrawerOpen Then HH_PollBrowserShortcuts()
        If $gPendingDropPath <> "" Then
            $sDrop = $gPendingDropPath
            $gPendingDropPath = ""
            HelperOpenDropped($sDrop)
        EndIf
        If $gMenuHidden And Not $gHHWebHiddenForMinimize And TimerDiff($gMenuClock) > 650 Then
            _UI_SetVisible($gWnd, $gWeb, True)
            $gMenuHidden = False
        EndIf
        ; 關閉抽屜後只同步一次，避免動畫尚未結束時連續更新分頁與網址列。
        If Not $gDrawerOpen And Not $drawerAnimating And ($gDrawerSyncPending Or TimerDiff($gTabClock) > 1100) Then
            $gDrawerSyncPending = False
            HelperSyncTabs()
            HH_SyncAddressBar()
            HH_SyncHistoryButtons()
            $gTabClock = TimerInit()
        EndIf
        If $gFontWin <> 0 And $gFontFilter <> 0 Then HH_FontFilterNow()
        ServiceHttp()
        HH_VChmIdleTick()
        If Not $drawerAnimating Then HH_PumpLinkTabQueue()
        HH89_PollNativeMiddle()
        If Not $drawerAnimating And TimerDiff($gHHLinkPolicyClock) > 650 Then
            ; 抽屜開啟時暫停非必要的 WebView JavaScript 注入，減少動畫卡頓。
            If Not $gDrawerOpen Then HH_InstallLinkPolicy()
            $gHHLinkPolicyClock = TimerInit()
        EndIf
        If Not $drawerAnimating And TimerDiff($gThemeClock) > ($gDrawerOpen ? 1600 : 500) Then
            $newTheme = _UI_ThemeGetMode($gWnd)
            ; Auto 是持久偏好，不能被 AUI 回報的目前亮/暗外觀覆蓋。
            If $gThemeMode <> $AUI_THEME_AUTO And ($newTheme = $AUI_THEME_LIGHT Or $newTheme = $AUI_THEME_DARK) Then
                If $newTheme <> $gThemeMode Then
                    $gThemeMode = $newTheme
                    _IniWrite($gIni, "Display", "Theme", $gThemeMode)
                EndIf
            EndIf
            $effectiveTheme = HelperEffectiveTheme()
            If $effectiveTheme <> $gAppliedTheme Then
                $gAppliedTheme = $effectiveTheme
                HH_WebFire("if(window.htmlHelperSetTheme)htmlHelperSetTheme(" & $effectiveTheme & ");")
                HH_StyleBump()
            EndIf
            $gThemeClock = TimerInit()
        EndIf
        HH_AppearanceTick()
        HH_WebMenuTick()
        HH_AI_PollHttp()
        HH_AI_PageTick()
        HH_AI_GooglePoll()
        HH_TabStyleTick()
        If $gAiPageMode And Not $gDrawerOpen And TimerDiff($gAiProgressClock) > 1600 Then
            HH_AI_ShowProgress()
            $gAiProgressClock = TimerInit()
        EndIf
        ; 保留 HTTP、翻譯與解包輪詢，但把高頻 UI 重繪延後到抽屜動畫結束。
        PollChmExtraction()
        PollFolderScan()
        If Not $drawerAnimating Then UpdateBusyIndicator()
        If Not $drawerAnimating And (TimerDiff($gResizeClock) > 450 Or $gDrawerResizePending) Then
            ; 抽屜關閉後延遲一次性校正；正常狀態僅每 450ms 查詢視窗尺寸。
            If Not $gDrawerOpen Then
                ResizeViewer()
                $gDrawerResizePending = False
            EndIf
            $gResizeClock = TimerInit()
        EndIf
        HH_PumpDropQueue()
        If $gPendingUrl <> "" Then
            $ready = True
            If $gPendingTabId > 0 Then
                $ready = _UI_WebViewSwitchTab($gWnd, $gWeb, $gPendingTabId)
            EndIf
            If $ready And _UI_WebViewNavigate($gWnd, $gWeb, $gPendingUrl) Then
                If $gPdfMode Then _UI_WebViewSetZoom($gWnd, $gWeb, $gZoom / 100)
                $gPendingUrl = ""
                $gPendingTabId = 0
                $gRetry = 0
            Else
                $gRetry += 1
                If $gRetry > 200 Then
                    $gPendingUrl = ""
                    $gPendingTabId = 0
                EndIf
            EndIf
        EndIf
        Sleep(10)
    WEnd
EndFunc

; ---------------------------------------------------------------------------
; 功能模組（只包含函式）
; ---------------------------------------------------------------------------
#include "Inc\HH\HH_Core.au3"
#include "Inc\HH\HH_Dialogs.au3"
#include "Inc\HH\HH_Window.au3"
#include "Inc\HH\HH_Instance.au3"
#include "Inc\HH\HH_Http.au3"
#include "Inc\HH\HH_OpenFiles.au3"
#include "Inc\HH\HH_Reader.au3"
#include "Inc\HH\HH_VChm.au3"
#include "Inc\HH\HH_Tabs.au3"
#include "Inc\HH\HH_Navigation.au3"
#include "Inc\HH\HH_LinkPolicy.au3"
#include "Inc\HH\HH_WebMenu.au3"
#include "Inc\HH\HH_TranslateAI.au3"
#include "Inc\HH\HH_TranslateGoogle.au3"
#include "Inc\HH\HH_QR.au3"
#include "Inc\HH\HH_QRDesigner.au3"
#include "Inc\HH\HH_Settings.au3"
#include "Inc\HH\HH_FontPicker.au3"
#include "Inc\HH\HH_CliHelp.au3"
#include "Inc\HH\HH_ChmPack.au3"
#include "Inc\HH\HH_ChmProject.au3"
#include "Inc\HH\HH_ChmJobUI.au3"
#include "Inc\HH\HH_AIConfig.au3"
#include "Inc\HH\HH_AISettingsUI.au3"
#include "Inc\HH\HH_TranslateJobUI.au3"
#include "Inc\HH\HH_TranslateEngine.au3"
#include "Inc\HH\HH_TranslateHtml.au3"
