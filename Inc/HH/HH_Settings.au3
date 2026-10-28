#include-once
; =============================================================================
; Html Helper － 軟體設定
;
; 軟體設定視窗（字型、主題、內容配色、檔案關聯）、關於視窗、子視窗字型管理，
; 以及外觀變更的延遲套用。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 參照附件的 AUI 原生模態視窗，避免 WebView 蓋住設定視窗。
; 字型與大小改為三個「字型選擇」按鈕，各自開啟 LineageAUI 式字型視窗（清單＋篩選＋大小＋範例）。
Func OpenAppearanceSettings($id)
    #forceref $id
    If $gSettingsWnd <> 0 And _UI_IsAlive($gSettingsWnd) Then
        HH_ApplyChildFonts()
        _UI_WindowShowModal($gSettingsWnd, $gWnd)
        Return
    EndIf
    $gSettingsWnd = _UI_WindowCreateEx("Html Helper｜軟體設定", 0, 0, 600, 600, BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $gSettingsWnd = 0 Then Return
    _UI_ThemeSetMode($gSettingsWnd, HelperEffectiveTheme())
    _UI_WindowCenter($gSettingsWnd)
    HH_Text($gSettingsWnd, 0, "軟體介面字型與大小", 18, 45, 557, 24)
    $gSettingFontBtn[1] = HH_Button($gSettingsWnd, 0, HH_FontTargetLabel(1), $AUI_VAR_DEFAULT, 18, 72, 557, 36)
    HH_Text($gSettingsWnd, 0, "左側導航字型與大小（獨立）", 18, 122, 557, 24)
    $gSettingFontBtn[2] = HH_Button($gSettingsWnd, 0, HH_FontTargetLabel(2), $AUI_VAR_DEFAULT, 18, 149, 557, 36)
    HH_Text($gSettingsWnd, 0, "文件內文字型與大小（不影響程式碼等寬字型）", 18, 199, 557, 24)
    $gSettingFontBtn[3] = HH_Button($gSettingsWnd, 0, HH_FontTargetLabel(3), $AUI_VAR_DEFAULT, 18, 226, 557, 36)
    HH_Text($gSettingsWnd, 0, "主題", 18, 276, 557, 24)
    $gSettingThemeInput = HH_Combo($gSettingsWnd, 0, "亮色|暗色|自動", 0, 18, 303, 557, 34)
    Local $themeIdx = 0
    If $gThemeMode = $AUI_THEME_DARK Then $themeIdx = 1
    If $gThemeMode = $AUI_THEME_AUTO Then $themeIdx = 2
    _UI_ComboSetSelected($gSettingsWnd, $gSettingThemeInput, $themeIdx)
    HH_Text($gSettingsWnd, 0, "文件內容配色（與軟體主題獨立）", 18, 353, 557, 24)
    $gSettingContentThemeInput = HH_Combo($gSettingsWnd, 0, "不動作（維持原樣）|暗黑模式（舒適閱讀）|高亮模式（亮色閱讀）", 0, 18, 380, 557, 34)
    _UI_ComboSetSelected($gSettingsWnd, $gSettingContentThemeInput, $gContentTheme)
    Local $associate = HH_Button($gSettingsWnd, 0, "註冊為預設程式", $AUI_VAR_DEFAULT, 18, 440, 272, 36)
    Local $unassociate = HH_Button($gSettingsWnd, 0, "還原（移除註冊）", $AUI_VAR_DEFAULT, 303, 440, 272, 36)
    Local $close = HH_Button($gSettingsWnd, 0, "關閉", $AUI_VAR_PRIMARY, 18, 492, 557, 38)
    _UI_OnValue($gSettingsWnd, $gSettingThemeInput, "AppearanceChanged")
    _UI_OnValue($gSettingsWnd, $gSettingContentThemeInput, "AppearanceChanged")
    _UI_OnClick($gSettingsWnd, $gSettingFontBtn[1], "PickAppFont")
    _UI_OnClick($gSettingsWnd, $gSettingFontBtn[2], "PickSideFont")
    _UI_OnClick($gSettingsWnd, $gSettingFontBtn[3], "PickContentFont")
    _UI_OnClick($gSettingsWnd, $associate, "RegisterAssociations")
    _UI_OnClick($gSettingsWnd, $unassociate, "UnregisterAssociations")
    _UI_OnClick($gSettingsWnd, $close, "CloseAppearanceSettings")
    _UI_OnClose($gSettingsWnd, "AppearanceSettingsClosed")
    HH_ApplyChildFonts()
    _UI_WindowShowModal($gSettingsWnd, $gWnd)
EndFunc

; 在下拉選單中選取指定文字的項目。
Func SelectFontCombo($h, $combo, $value)
    Local $idx = _UI_ComboFindItem($h, $combo, $value)
    If $idx >= 0 Then _UI_ComboSetSelected($h, $combo, $idx)
EndFunc

; 取得下拉選單目前選取的文字（未選取時回傳預設值）。
Func ComboValue($h, $combo, $fallback)
    Local $idx = _UI_ComboGetSelected($h, $combo)
    If $idx < 0 Then Return $fallback
    Return _UI_ComboGetItemText($h, $combo, $idx)
EndFunc

; 「軟體介面字型」按鈕：開啟字型選擇視窗。
Func PickAppFont($id)
    #forceref $id
    HH_Q("HH_FontWinOpen", 1, 1)
EndFunc

; 「左側導航字型」按鈕：開啟字型選擇視窗。
Func PickSideFont($id)
    #forceref $id
    HH_Q("HH_FontWinOpen", 1, 2)
EndFunc

; 「文件內文字型」按鈕：開啟字型選擇視窗。
Func PickContentFont($id)
    #forceref $id
    HH_Q("HH_FontWinOpen", 1, 3)
EndFunc

; 文件內容目前是否使用深色配色。
Func HH_ContentIsDark()
    If $gContentTheme = 1 Then Return True
    If $gContentTheme = 2 Then Return False
    Return HelperEffectiveTheme() = $AUI_THEME_DARK
EndFunc

; 實際主題：「自動」時依 Windows 應用程式亮暗設定。
Func HelperEffectiveTheme()
    If $gThemeMode <> $AUI_THEME_AUTO Then Return $gThemeMode
    Local $v = RegRead("HKCU64\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
    If @error Then Return $AUI_THEME_LIGHT
    If Number($v) = 0 Then Return $AUI_THEME_DARK
    Return $AUI_THEME_LIGHT
EndFunc

; 連續調整（滾輪或方向鍵快速切換）時只記錄，停止 300 ms 後在主迴圈合併套用一次，避免重複重設與重繪而死當。
Func AppearanceChanged($id, $value = "")
    #forceref $id, $value
    $gAppearancePending = True
    $gAppearanceClock = TimerInit()
EndFunc

; 主迴圈呼叫：套用字型選擇結果與延遲的外觀變更。
Func HH_AppearanceTick()
    HH_FontApplyTick()
    If Not $gAppearancePending Or $gAppearanceBusy Then Return
    If TimerDiff($gAppearanceClock) < 300 Then Return
    $gAppearancePending = False
    If $gSettingsWnd = 0 Or Not _UI_IsAlive($gSettingsWnd) Then Return
    SaveAppearanceSettings(0)
EndFunc

; 儲存並套用外觀設定（避免重入）。
Func SaveAppearanceSettings($id)
    #forceref $id
    If $gAppearanceBusy Then
        $gAppearancePending = True
        Return
    EndIf
    $gAppearanceBusy = True
    HH_SaveAppearanceCore()
    $gAppearanceBusy = False
EndFunc

; 實際套用主題與內容配色並寫入 INI。
Func HH_SaveAppearanceCore()
    Local $themeIdx = _UI_ComboGetSelected($gSettingsWnd, $gSettingThemeInput)
    Local $theme = $AUI_THEME_LIGHT
    If $themeIdx = 1 Then $theme = $AUI_THEME_DARK
    If $themeIdx = 2 Then $theme = $AUI_THEME_AUTO
    Local $contentTheme = _UI_ComboGetSelected($gSettingsWnd, $gSettingContentThemeInput)
    If $contentTheme < 0 Then $contentTheme = $gContentTheme
    If $contentTheme <> $gContentTheme Then
        $gContentTheme = $contentTheme
        _IniWrite($gIni, "Display", "ContentTheme", $gContentTheme)
        HH_WebFire("if(window.htmlHelperSetContentTheme)htmlHelperSetContentTheme(" & $gContentTheme & ");")
        Local $ctid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
        If $ctid > 0 Then
            Local $cu = _UI_WebViewGetTabUrl($gWnd, $gWeb, $ctid)
            If StringInStr($cu, "/__helper_blank__") Or StringInStr($cu, "/__helper_text__/") Then _UI_WebViewReload($gWnd, $gWeb)
        EndIf
    EndIf
    If $theme <> $gThemeMode Then
        $gThemeMode = $theme
        _IniWrite($gIni, "Display", "Theme", $gThemeMode)
        _UI_ThemeSetMode($gWnd, $gThemeMode)
        _UI_ThemeSetMode($gSettingsWnd, HelperEffectiveTheme())
        HH_WebFire("if(window.htmlHelperSetTheme)htmlHelperSetTheme(" & HelperEffectiveTheme() & ");")
    EndIf
EndFunc

; 「關閉」按鈕。
Func CloseAppearanceSettings($id)
    #forceref $id
    HH_Q("HH_SettingsCloseNow")
EndFunc

; 關閉軟體設定視窗（含開著的字型選擇視窗）。
Func HH_SettingsCloseNow()
    If $gFontWin <> 0 Then HH_FontWinCancelNow()
    If $gSettingsWnd <> 0 And _UI_IsAlive($gSettingsWnd) Then _UI_WindowClose($gSettingsWnd)
EndFunc

; 軟體設定視窗已關閉的回呼。
Func AppearanceSettingsClosed($id)
    #forceref $id
    HH_ClearChildFonts($gSettingsWnd)
    $gSettingsWnd = 0
EndFunc

; 開啟關於視窗。
Func OpenAboutDialog($id)
    #forceref $id
    If $gAboutWnd <> 0 And _UI_IsAlive($gAboutWnd) Then
        HH_ApplyChildFonts()
        _UI_WindowShowModal($gAboutWnd, $gWnd)
        Return
    EndIf
    $gAboutWnd = _UI_WindowCreateEx("關於 " & $HH_APP_NAME, 0, 0, 470, 420, BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $gAboutWnd = 0 Then Return
    _UI_ThemeSetMode($gAboutWnd, $gThemeMode)
    _UI_WindowCenter($gAboutWnd)
    HH_Text($gAboutWnd, 0, $HH_APP_NAME & "　" & $HH_APP_VERSION, 20, 55, 430, 36)
    HH_Text($gAboutWnd, 0, "grayfree 2026 Unlicense.", 20, 98, 430, 30)
    Local $site = HH_Button($gAboutWnd, 0, $HH_APP_SITE, $AUI_VAR_DEFAULT, 20, 134, 430, 38)
    _UI_OnClick($gAboutWnd, $site, "HH_AboutOpenSite")
    HH_Text($gAboutWnd, 0, "ＡＩ　　　 ：Perplexity", 20, 190, 430, 30)
    HH_Text($gAboutWnd, 0, "ＡＵＩ 版本：" & HH_AuiVersion(), 20, 225, 430, 30)
    HH_Text($gAboutWnd, 0, "ＡＵ３ 版本：" & @AutoItVersion, 20, 260, 430, 30)
    Local $close = HH_Button($gAboutWnd, 0, "關閉", $AUI_VAR_PRIMARY, 20, 330, 430, 40)
    _UI_OnClick($gAboutWnd, $close, "CloseAboutDialog")
    _UI_OnClose($gAboutWnd, "AboutDialogClosed")
    HH_ApplyChildFonts()
    _UI_WindowShowModal($gAboutWnd, $gWnd)
EndFunc

; 關於視窗：開啟官網。
Func HH_AboutOpenSite($id)
    #forceref $id
    ShellExecute($HH_APP_SITE)
EndFunc

; AUI 版本：由 AUI.au3 的 _UI_Version() 取得。
Func HH_AuiVersion()
    Local $v = _UI_Version()
    If @error Or String($v) = "" Then Return "未提供"
    Return String($v)
EndFunc

; 關於視窗「關閉」按鈕。
Func CloseAboutDialog($id)
    #forceref $id
    _UI_WindowClose($gAboutWnd)
EndFunc

; 關於視窗已關閉的回呼。
Func AboutDialogClosed($id)
    #forceref $id
    HH_ClearChildFonts($gAboutWnd)
    $gAboutWnd = 0
EndFunc

; 字型／主題只會送到目前分頁；記下版本，其他分頁被切換到時再補套用一次。
Func HH_StyleBump()
    $gStyleEpoch += 1
    If $gWnd = 0 Or $gWeb = 0 Then Return
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid > 0 Then $gTabStyleEpoch.Item(String($tid)) = $gStyleEpoch
EndFunc

; 主迴圈呼叫：目前分頁的外觀版本落後時補套用字型與主題。
Func HH_TabStyleTick()
    If $gStyleEpoch = 0 Or $gDrawerOpen Or $gWnd = 0 Or $gWeb = 0 Then Return
    If TimerDiff($gStyleClock) < 250 Then Return
    $gStyleClock = TimerInit()
    Local $tid = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tid <= 0 Then Return
    Local $k = String($tid)
    If $gTabStyleEpoch.Exists($k) Then
        If $gTabStyleEpoch.Item($k) = $gStyleEpoch Then Return
    EndIf
    $gTabStyleEpoch.Item($k) = $gStyleEpoch
    HH_WebFire("if(window.setContentFont)setContentFont(" & JsString($gContentFont) & "," & $gContentSize & ");" & _
        "if(window.setSideFont)setSideFont(" & JsString($gSideFont) & "," & $gSideSize & ");" & _
        "if(window.htmlHelperSetTheme)htmlHelperSetTheme(" & $gAppliedTheme & ");")
EndFunc

; 介面字型與文件字型分離。設定寫入 INI 後立即套用所有工具列控制項。
Func ApplyAppFont()
    For $i = 0 To UBound($gToolbarIds) - 1
        If $gToolbarIds[$i] <> 0 Then
            ; 原生圖示按鈕不套用一般介面字型，避免圖示被覆蓋。
            If $gToolbarIds[$i] = $gToolbarIds[1] Then ContinueLoop
            _UI_SetFont($gWnd, $gToolbarIds[$i], $gAppFont, $gAppSize)
            _UI_SetFontSize($gWnd, $gToolbarIds[$i], $gAppSize)
        EndIf
    Next
    If $gBrowserTabs <> 0 Then _UI_SetFont($gWnd, $gBrowserTabs, $gAppFont, $gAppSize)
    ; 分頁四顆按鈕統一用符號字型，◀ ▶ ✚ ✖ 大小與粗細一致。
    If $gTabPrevButton <> 0 Then _UI_SetFont($gWnd, $gTabPrevButton, $HH_SYMBOL_FONT, $gAppSize)
    If $gTabNextButton <> 0 Then _UI_SetFont($gWnd, $gTabNextButton, $HH_SYMBOL_FONT, $gAppSize)
    If $gNewTabButton <> 0 Then _UI_SetFont($gWnd, $gNewTabButton, $HH_SYMBOL_FONT, $gAppSize)
    If $gCloseTabButton <> 0 Then _UI_SetFont($gWnd, $gCloseTabButton, $HH_SYMBOL_FONT, $gAppSize)
    If $gToolbarIds[1] <> 0 Then _UI_SetFont($gWnd, $gToolbarIds[1], $HH_SYMBOL_FONT, 20)
EndFunc

; 註冊為預設程式（僅目前使用者，HKCU）：建立 ProgID、開啟方式與 Capabilities，
; 讓 Html Helper 出現在 Windows「預設應用程式」清單；最後一步須由使用者在系統設定確認（Windows 不允許程式自行指定）。
Func RegisterAssociations($id)
    #forceref $id
    HH_Q("HH_AssocRegisterNow")
EndFunc

; 「還原（移除註冊）」按鈕。
Func UnregisterAssociations($id)
    #forceref $id
    HH_Q("HH_AssocUnregisterNow")
EndFunc

; 要註冊的副檔名清單。
Func HH_AssocExts()
    Local $exts[5] = [".chm", ".htm", ".html", ".mht", ".mhtml"]
    Return $exts
EndFunc

; 檔案關聯操作的通知。
Func HH_AssocNotify($title, $text, $level)
    Local $w = $gSettingsWnd
    If $w = 0 Or Not _UI_IsAlive($w) Then $w = $gWnd
    _UI_Notify($w, $title, $text, $level, 5500)
EndFunc

; 在 HKCU64 註冊 ProgID、開啟方式與 Capabilities，再開啟 Windows 預設應用程式設定。
Func HH_AssocRegisterNow()
    If @Compiled = 0 Then
        HH_AssocNotify("需先編譯", "請先將 Html_Helper.au3 編譯成 EXE，再註冊為預設程式。", $AUI_NOTIFY_INFO)
        Return
    EndIf
    Local $cmd = '"' & @ScriptFullPath & '" "%1"'
    Local $prog = "HKCU64\Software\Classes\HtmlHelper.Document"
    Local $ok = RegWrite($prog, "", "REG_SZ", "Html Helper 文件")
    RegWrite($prog, "FriendlyTypeName", "REG_SZ", "Html Helper 文件")
    RegWrite($prog & "\DefaultIcon", "", "REG_SZ", '"' & @ScriptFullPath & '",0')
    RegWrite($prog & "\shell\open\command", "", "REG_SZ", $cmd)
    Local $app = "HKCU64\Software\Classes\Applications\" & @ScriptName
    RegWrite($app, "FriendlyAppName", "REG_SZ", $HH_APP_NAME)
    RegWrite($app & "\shell\open\command", "", "REG_SZ", $cmd)
    Local $cap = "HKCU64\Software\HtmlHelper\Capabilities"
    RegWrite($cap, "ApplicationName", "REG_SZ", $HH_APP_NAME)
    RegWrite($cap, "ApplicationDescription", "REG_SZ", "CHM／HTML／MHT 檢視、解包與 AI 翻譯")
    RegWrite($cap, "ApplicationIcon", "REG_SZ", '"' & @ScriptFullPath & '",0')
    Local $exts = HH_AssocExts()
    For $i = 0 To UBound($exts) - 1
        RegWrite($app & "\SupportedTypes", $exts[$i], "REG_SZ", "")
        RegWrite("HKCU64\Software\Classes\" & $exts[$i] & "\OpenWithProgids", "HtmlHelper.Document", "REG_SZ", "")
        RegWrite($cap & "\FileAssociations", $exts[$i], "REG_SZ", "HtmlHelper.Document")
    Next
    RegWrite("HKCU64\Software\RegisteredApplications", $HH_APP_NAME, "REG_SZ", "Software\HtmlHelper\Capabilities")
    DllCall("shell32.dll", "none", "SHChangeNotify", "long", 0x08000000, "uint", 0, "ptr", 0, "ptr", 0)
    If Not $ok Then
        HH_AssocNotify("註冊失敗", "無法寫入登錄（HKCU）。請確認沒有被防毒或權限阻擋。", $AUI_NOTIFY_DANGER)
        Return
    EndIf
    HH_AssocNotify("已註冊", "已加入 .chm／.htm／.html／.mht／.mhtml 的開啟方式。請在接著開啟的 Windows 設定中把 " & $HH_APP_NAME & " 設為預設。", $AUI_NOTIFY_SUCCESS)
    ShellExecute("ms-settings:defaultapps?registeredAppUser=" & StringReplace($HH_APP_NAME, " ", "%20"))
EndFunc

; 還原：移除本程式寫入的所有註冊。若某副檔名目前預設就是本程式，Windows 會在下次開啟時改回詢問或系統預設。
Func HH_AssocUnregisterNow()
    Local $exts = HH_AssocExts(), $app = "HKCU64\Software\Classes\Applications\" & @ScriptName
    For $i = 0 To UBound($exts) - 1
        RegDelete("HKCU64\Software\Classes\" & $exts[$i] & "\OpenWithProgids", "HtmlHelper.Document")
        RegDelete($app & "\SupportedTypes", $exts[$i])
    Next
    RegDelete($app)
    RegDelete("HKCU64\Software\Classes\HtmlHelper.Document")
    RegDelete("HKCU64\Software\RegisteredApplications", $HH_APP_NAME)
    RegDelete("HKCU64\Software\HtmlHelper\Capabilities")
    DllCall("shell32.dll", "none", "SHChangeNotify", "long", 0x08000000, "uint", 0, "ptr", 0, "ptr", 0)
    HH_AssocNotify("已還原", "已移除 " & $HH_APP_NAME & " 的檔案關聯與預設程式註冊。若要改回其他程式，可在接著開啟的 Windows 設定中選擇。", $AUI_NOTIFY_SUCCESS)
    ShellExecute("ms-settings:defaultapps")
EndFunc

; 子視窗建立控制項時直接套用軟體字型設定，無需依賴 WebView CSS。
Func HH_Text($wnd, $parent, $value, $x, $y, $w, $h)
    Local $id = _UI_Text($wnd, $parent, $value, $x, $y, $w, $h)
    If $id > 0 Then HH_RegisterChildFont($wnd, $id)
    Return $id
EndFunc

; 建立按鈕並套用介面字型。
Func HH_Button($wnd, $parent, $value, $variant, $x, $y, $w, $h)
    Local $id = _UI_Button($wnd, $parent, $value, $variant, $x, $y, $w, $h)
    If $id > 0 Then HH_RegisterChildFont($wnd, $id)
    Return $id
EndFunc

; 建立下拉選單並套用介面字型。
Func HH_Combo($wnd, $parent, $items, $selected, $x, $y, $w, $h)
    Local $id = _UI_Combo($wnd, $parent, $items, $selected, $x, $y, $w, $h)
    If $id > 0 Then HH_RegisterChildFont($wnd, $id)
    Return $id
EndFunc

; 建立輸入框並套用介面字型。
Func HH_Input($wnd, $parent, $title, $placeholder, $x, $y, $w, $h)
    Local $id = _UI_Input($wnd, $parent, $title, $placeholder, $x, $y, $w, $h)
    If $id > 0 Then HH_RegisterChildFont($wnd, $id)
    Return $id
EndFunc

; AUI 子視窗的控制項不是主視窗的子 ID，必須以自己的 HWND 更新。
; 儲存 ID 可在設定變更後即時更新已開啟的設定、字型選擇、關於視窗。
Func HH_RegisterChildFont($wnd, $id)
    If $wnd = 0 Or $id <= 0 Then Return
    Local $n = UBound($gChildFontId)
    ReDim $gChildFontId[$n + 1]
    ReDim $gChildFontWnd[$n + 1]
    $gChildFontId[$n] = $id
    $gChildFontWnd[$n] = $wnd
    _UI_SetFont($wnd, $id, $gAppFont, $gAppSize)
    _UI_SetFontSize($wnd, $id, $gAppSize)
EndFunc

; 把介面字型重新套用到所有已記錄的子視窗控制項。
Func HH_ApplyChildFonts()
    If $gChildFontBusy Then Return
    $gChildFontBusy = True
    For $i = 0 To UBound($gChildFontId) - 1
        Local $wnd = $gChildFontWnd[$i]
        If $wnd = 0 Or Not _UI_IsAlive($wnd) Then ContinueLoop
        _UI_SetFont($wnd, $gChildFontId[$i], $gAppFont, $gAppSize)
        _UI_SetFontSize($wnd, $gChildFontId[$i], $gAppSize)
    Next
    $gChildFontBusy = False
EndFunc

; 子視窗關閉時移除它的控制項記錄。
Func HH_ClearChildFonts($wnd)
    For $i = UBound($gChildFontWnd) - 1 To 0 Step -1
        If $gChildFontWnd[$i] = $wnd Then
            _ArrayDelete($gChildFontWnd, $i)
            _ArrayDelete($gChildFontId, $i)
        EndIf
    Next
EndFunc
