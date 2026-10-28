#include-once
; =============================================================================
; Html Helper － 整份 CHM／資料夾翻譯的 GUI
;
; 選擇來源、輸出、語言與選項後，以命令列子程序（--translate-chm）執行翻譯；
; API Key 透過環境變數傳遞後立即清除。進度透過共享記憶體顯示，
; 可隨時停止並續譯。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ===== 虛擬 CHM 結束 =====
; ===== 來源檔翻譯（純 AutoIt） =====
Func HH_SourceTranslateFolder()
    ; 改用 AUI 翻譯視窗；保留資料夾結構，支援直接選 CHM。
    P136OpenTranslate()
EndFunc

; ---------- AUI：CHM／資料夾翻譯 ----------
Func P136LangInfo($index, ByRef $code, ByRef $lcid)
    Local $codes[14] = ["zh-TW", "zh-CN", "en", "ja", "ko", "de", "fr", "es", "pt-BR", "ru", "vi", "th", "id", "it"]
    Local $ids[14] = [0x404, 0x804, 0x409, 0x411, 0x412, 0x407, 0x40C, 0xC0A, 0x416, 0x419, 0x42A, 0x41E, 0x421, 0x410]
    If $index < 0 Or $index > 13 Then
        $code = "custom"
        $lcid = 0
        Return
    EndIf
    $code = $codes[$index]
    $lcid = $ids[$index]
EndFunc

; 開啟整份翻譯視窗。
Func P136OpenTranslate($source = "")
    If $p136TransWnd <> 0 And _UI_IsAlive($p136TransWnd) Then
        _UI_WindowShow($p136TransWnd)
        Return
    EndIf
    $p136TransWnd = _UI_WindowCreateEx("Html Helper｜AI 翻譯 CHM／資料夾", 0, 0, 800, 770, BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $p136TransWnd = 0 Then Return
    Local $w = $p136TransWnd
    _UI_ThemeSetMode($w, HelperEffectiveTheme())
    _UI_WindowCenter($w)
    HH_Text($w, 0, "來源：已解包的 CHM 資料夾，或直接選 .chm（會先以 ITSS 解包）", 20, 44, 760, 24)
    $p136TransFields[0] = HH_Input($w, 0, "來源資料夾或 CHM", "", 20, 70, 500, 34)
    Local $bDir = HH_Button($w, 0, "選擇資料夾", $AUI_VAR_DEFAULT, 530, 70, 120, 34)
    Local $bChm = HH_Button($w, 0, "選擇 CHM", $AUI_VAR_DEFAULT, 660, 70, 120, 34)
    HH_Text($w, 0, "輸出資料夾（須不存在、空白，或是同一工作的續譯）", 20, 116, 760, 24)
    $p136TransFields[1] = HH_Input($w, 0, "輸出資料夾", "", 20, 142, 630, 34)
    Local $bOut = HH_Button($w, 0, "選擇…", $AUI_VAR_DEFAULT, 660, 142, 120, 34)
    HH_Text($w, 0, "目標語言", 20, 188, 370, 24)
    $p136TransFields[2] = HH_Combo($w, 0, $p136Languages, 0, 20, 214, 370, 34)
    HH_Text($w, 0, "自訂語言（AI 填名稱；Google 填代碼如 yue、fr-CA）", 410, 188, 370, 24)
    $p136TransFields[3] = HH_Input($w, 0, "例如：粵語（香港）或 yue", "", 410, 214, 370, 34)
    HH_Text($w, 0, "程式碼內註解", 20, 262, 370, 24)
    $p136TransFields[4] = HH_Combo($w, 0, "翻譯註解（; // #cs…#ce），程式碼不變|不翻譯，程式碼區塊完全保留", 0, 20, 288, 370, 34)
    HH_Text($w, 0, "目錄 .hhc", 410, 262, 370, 24)
    $p136TransFields[5] = HH_Combo($w, 0, "翻譯目錄名稱（Local 連結不變）|保留原文", 0, 410, 288, 370, 34)
    HH_Text($w, 0, "索引 .hhk", 20, 336, 370, 24)
    $p136TransFields[6] = HH_Combo($w, 0, "保留原文（關鍵字搜尋不變）|翻譯索引名稱", 0, 20, 362, 370, 34)
    HH_Text($w, 0, "HHP 專案", 410, 336, 370, 24)
    $p136TransFields[7] = HH_Combo($w, 0, "更新 Language 並翻譯 Title|完全保留", 0, 410, 362, 370, 34)
    HH_Text($w, 0, "翻譯引擎", 20, 410, 760, 24)
    $p136TransFields[9] = HH_Combo($w, 0, "AI 翻譯（使用 AI API 設定檔）|Google 翻譯（免費機器翻譯，免 Key）", (Number(_IniRead($p136Ini, "Translate", "Engine", "0")) = 1 ? 1 : 0), 20, 436, 370, 34)
    HH_Text($w, 0, "目前通道", 20, 482, 760, 24)
    $p136TransFields[8] = HH_Text($w, 0, "", 20, 508, 560, 34)
    Local $bApi = HH_Button($w, 0, "AI API 設定…", $AUI_VAR_DEFAULT, 590, 506, 190, 36)
    HH_Text($w, 0, "說明：資料夾結構與所有非文字檔逐位元組複製；HTML 只翻譯可見說明文字，script／style／pre／code 等程式碼原樣保留。" & @CRLF & "工作狀態與快取存在「輸出資料夾.hhtrans」，中斷後以相同設定再次執行即可續譯（可換引擎續譯）；輸出資料夾可直接用「將資料夾打包成 CHM」。", 20, 556, 760, 90)
    Local $start = HH_Button($w, 0, "開始翻譯", $AUI_VAR_PRIMARY, 420, 676, 200, 40)
    Local $close = HH_Button($w, 0, "關閉", $AUI_VAR_DEFAULT, 630, 676, 150, 40)
    _UI_OnClick($w, $bDir, "P136PickSourceDir")
    _UI_OnClick($w, $bChm, "P136PickSourceChm")
    _UI_OnClick($w, $bOut, "P136PickOutput")
    _UI_OnClick($w, $bApi, "P136TransApi")
    _UI_OnClick($w, $start, "P136StartTranslate")
    _UI_OnClick($w, $close, "P136CloseTranslate")
    _UI_OnValue($w, $p136TransFields[2], "P136LanguageChanged")
    _UI_OnValue($w, $p136TransFields[9], "P136EngineChanged")
    _UI_OnClose($w, "P136TranslateClosed")
    If $source <> "" Then P136SetSource($source)
    P136RefreshTranslateProfile()
    HH_ApplyChildFonts()
    _UI_WindowShowModal($w, $gWnd)
EndFunc

; 切換翻譯引擎（AI／Google）。
Func P136EngineChanged($id, $value)
    #forceref $id
    _IniWrite($p136Ini, "Translate", "Engine", String(Number($value) = 1 ? 1 : 0))
    P136RefreshTranslateProfile()
EndFunc

; 更新視窗中「目前通道」的說明。
Func P136RefreshTranslateProfile()
    If $p136TransWnd = 0 Or Not _UI_IsAlive($p136TransWnd) Then Return
    If _UI_ComboGetSelected($p136TransWnd, $p136TransFields[9]) = 1 Then
        _UI_SetText($p136TransWnd, $p136TransFields[8], "Google 翻譯（免費）｜免 Key｜機器翻譯品質低於 AI，術語不一定一致")
        Return
    EndIf
    Local $c = P136Load(P136Active())
    Local $state = P136Mask($c.Item("key"))
    If $c.Item("key") = "" And Not P136NeedsKey($c) Then $state = ($c.Item("protocol") = 4 ? "免費服務" : "本機服務")
    _UI_SetText($p136TransWnd, $p136TransFields[8], $c.Item("name") & "｜" & $c.Item("model") & "｜Key " & $state)
EndFunc

; 依來源與語言建議輸出資料夾名稱。
Func P136SuggestOutput()
    Local $src = StringStripWS(_UI_GetText($p136TransWnd, $p136TransFields[0]), 3)
    If $src = "" Then Return
    Local $code, $lcid
    P136LangInfo(_UI_ComboGetSelected($p136TransWnd, $p136TransFields[2]), $code, $lcid)
    Local $base = P133Path($src)
    If StringRegExp($base, "(?i)\.chm$") Then $base = StringTrimRight($base, 4)
    _UI_SetText($p136TransWnd, $p136TransFields[1], $base & "_" & $code)
EndFunc

; 設定來源並更新建議的輸出位置。
Func P136SetSource($path)
    _UI_SetText($p136TransWnd, $p136TransFields[0], P133Path($path))
    P136SuggestOutput()
EndFunc

; 「選擇資料夾」按鈕。
Func P136PickSourceDir($id)
    #forceref $id
    Local $s = FileSelectFolder("選擇已解包的 CHM 資料夾", "", 0)
    If @error Or $s = "" Then Return
    P136SetSource($s)
EndFunc

; 「選擇 CHM」按鈕。
Func P136PickSourceChm($id)
    #forceref $id
    Local $s = FileOpenDialog("選擇要翻譯的 CHM", @ScriptDir, "CHM (*.chm)", 1)
    If @error Or $s = "" Then Return
    P136SetSource($s)
EndFunc

; 「選擇輸出」按鈕。
Func P136PickOutput($id)
    #forceref $id
    Local $s = FileSelectFolder("選擇輸出資料夾（空白或新建）", "", 1)
    If @error Or $s = "" Then Return
    _UI_SetText($p136TransWnd, $p136TransFields[1], P133Path($s))
EndFunc

; 目標語言變更：輸出名稱仍是自動產生時一併更新。
Func P136LanguageChanged($id, $value)
    #forceref $id, $value
    Local $out = StringStripWS(_UI_GetText($p136TransWnd, $p136TransFields[1]), 3)
    If $out = "" Or StringRegExp($out, "_(zh-TW|zh-CN|en|ja|ko|de|fr|es|pt-BR|ru|vi|th|id|it|custom)$") Then P136SuggestOutput()
EndFunc

; 「AI API 設定…」按鈕。
Func P136TransApi($id)
    #forceref $id
    P136OpenSettings($p136TransWnd)
EndFunc

; 「關閉」按鈕。
Func P136CloseTranslate($id)
    #forceref $id
    _UI_WindowClose($p136TransWnd)
EndFunc

; 整份翻譯視窗已關閉的回呼。
Func P136TranslateClosed($id)
    #forceref $id
    HH_ClearChildFonts($p136TransWnd)
    $p136TransWnd = 0
EndFunc

; 子路徑是否位於父路徑內。
Func P136Inside($child, $parent)
    Local $a = StringLower(P133Path($child)) & "\", $b = StringLower(P133Path($parent)) & "\"
    Return StringLeft($a, StringLen($b)) = $b
EndFunc

; 檢查設定後啟動翻譯子程序並開啟進度視窗。
Func P136StartTranslate($id)
    #forceref $id
    Local $w = $p136TransWnd
    If $p136Pid Or $g133JobPid Or IsObj($g135Flow) Then
        _UI_Notify($w, "工作進行中", "請等待目前的翻譯或 CHM 工作完成。", $AUI_NOTIFY_WARNING, 5000)
        Return
    EndIf
    Local $src = StringStripWS(_UI_GetText($w, $p136TransFields[0]), 3), $dest = StringStripWS(_UI_GetText($w, $p136TransFields[1]), 3)
    If $src = "" Or Not FileExists($src) Then
        _UI_Notify($w, "來源不正確", "請選擇已解包資料夾或 CHM 檔。", $AUI_NOTIFY_WARNING, 5000)
        Return
    EndIf
    If $dest = "" Then
        _UI_Notify($w, "缺少輸出資料夾", "請指定輸出資料夾。", $AUI_NOTIFY_WARNING, 5000)
        Return
    EndIf
    $src = P133Path($src)
    $dest = P133Path($dest)
    Local $isChm = Not StringInStr(FileGetAttrib($src), "D")
    If $isChm And Not StringRegExp($src, "(?i)\.chm$") Then
        _UI_Notify($w, "來源不正確", "檔案來源只接受 .chm。", $AUI_NOTIFY_WARNING, 5000)
        Return
    EndIf
    If Not $isChm And (P136Inside($dest, $src) Or P136Inside($src, $dest)) Then
        _UI_Notify($w, "輸出位置不正確", "輸出資料夾不可位於來源內，也不可包含來源。", $AUI_NOTIFY_WARNING, 6000)
        Return
    EndIf
    Local $langIndex = _UI_ComboGetSelected($w, $p136TransFields[2]), $code, $lcid
    P136LangInfo($langIndex, $code, $lcid)
    Local $lang = ComboValue($w, $p136TransFields[2], "繁體中文（臺灣）")
    If $code = "custom" Then
        $lang = StringStripWS(_UI_GetText($w, $p136TransFields[3]), 3)
        If $lang = "" Then
            _UI_Notify($w, "缺少語言", "請輸入自訂目標語言。", $AUI_NOTIFY_WARNING, 5000)
            Return
        EndIf
    EndIf
    Local $profile = P136Active(), $c, $google = (_UI_ComboGetSelected($w, $p136TransFields[9]) = 1)
    If $google Then
        $c = P136GoogleConfig()
    Else
        $c = P136Load($profile)
        If $c.Item("protocol") = 4 Then $google = True
    EndIf
    If $google Then
        If $code = "custom" Then
            $code = P136CodeFor($lang)
            If $code = "" Then
                _UI_Notify($w, "需要語言代碼", "Google 翻譯的自訂語言請輸入語言代碼，例如 yue、fr-CA、zh-HK。", $AUI_NOTIFY_WARNING, 6000)
                Return
            EndIf
        EndIf
    ElseIf Not P136ValidEndpoint($c.Item("endpoint")) Or ($c.Item("model") = "" And $c.Item("protocol") <> 3) Then
        _UI_Notify($w, "AI 設定不完整", "請先在「AI API 設定」完成 Endpoint 與模型。", $AUI_NOTIFY_WARNING, 6000)
        P136OpenSettings($w)
        Return
    ElseIf $c.Item("key") = "" And P136NeedsKey($c) Then
        _UI_Notify($w, "缺少 API Key", "請先在「AI API 設定」輸入自己的 API Key。", $AUI_NOTIFY_WARNING, 6000)
        P136OpenSettings($w)
        Return
    EndIf
    Local $cmd = '"' & @ScriptFullPath & '"'
    If Not @Compiled Then $cmd = '"' & @AutoItExe & '" "' & @ScriptFullPath & '"'
    $cmd &= ' --translate-chm "' & $src & '" "' & $dest & '" --profile ' & $profile & ' --lang "' & StringReplace($lang, '"', "'") & '" --lcid ' & $lcid
    $cmd &= " --comments " & (_UI_ComboGetSelected($w, $p136TransFields[4]) = 0 ? 1 : 0)
    $cmd &= " --toc " & (_UI_ComboGetSelected($w, $p136TransFields[5]) = 0 ? 1 : 0)
    $cmd &= " --index " & (_UI_ComboGetSelected($w, $p136TransFields[6]) = 1 ? 1 : 0)
    $cmd &= " --hhp " & (_UI_ComboGetSelected($w, $p136TransFields[7]) = 0 ? 1 : 0)
    If $code <> "custom" Then $cmd &= ' --code "' & $code & '"'
    If _UI_ComboGetSelected($w, $p136TransFields[9]) = 1 Then $cmd &= " --engine google"
    FileDelete($dest & ".cancel")
    EnvSet("HH136_KEY", $c.Item("key"))
    Local $pid = Run($cmd, @ScriptDir, @SW_HIDE)
    Local $runError = @error
    EnvSet("HH136_KEY")
    If $runError Or Not $pid Then
        P136Info($w, "不能啟動翻譯", "無法啟動同一程式的命令模式。")
        Return
    EndIf
    ProcessSetPriority($pid, 1)
    _UI_WindowClose($w)
    P133Unmap($p136View, $p136Handle)
    $p136Pid = $pid
    $p136Dest = $dest
    $p136Log = $dest & "." & $pid & ".log"
    $p136Cancel = $dest & ".cancel"
    $p136LastSeq = -1
    $p136LastPct = -999
    $p136LastMode = -1
    $p136LastPhase = ""
    $p136LastDetail = ""
    P136ProgressWindow()
EndFunc

; 建立翻譯進度視窗。
Func P136ProgressWindow()
    If $p136ProgressWnd <> 0 And _UI_IsAlive($p136ProgressWnd) Then _UI_WindowClose($p136ProgressWnd)
    $p136ProgressWnd = _UI_WindowCreateEx("AI 翻譯 CHM／資料夾", 0, 0, 760, 360, BitOR($AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $p136ProgressWnd = 0 Then Return
    Local $w = $p136ProgressWnd
    _UI_ThemeSetMode($w, HelperEffectiveTheme())
    $p136Phase = _UI_Text($w, 0, "正在啟動…", 20, 45, 720, 30)
    $p136Bar = _UI_Progress($w, 0, 0, 20, 90, 720, 26)
    _UI_ProgressSetRange($w, $p136Bar, 0, 100)
    _UI_ProgressSetIndeterminate($w, $p136Bar, True)
    $p136LastMode = 1
    $p136Detail = _UI_Text($w, 0, $p136Dest, 20, 130, 720, 120)
    Local $stop = _UI_Button($w, 0, "停止翻譯", $AUI_VAR_DEFAULT, 20, 280, 150, 38)
    Local $log = _UI_Button($w, 0, "開啟工作紀錄", $AUI_VAR_DEFAULT, 180, 280, 160, 38)
    Local $open = _UI_Button($w, 0, "開啟輸出資料夾", $AUI_VAR_DEFAULT, 350, 280, 170, 38)
    Local $close = _UI_Button($w, 0, "關閉視窗（工作繼續）", $AUI_VAR_DEFAULT, 530, 280, 210, 38)
    _UI_OnClick($w, $stop, "P136StopJob")
    _UI_OnClick($w, $log, "P136OpenLog")
    _UI_OnClick($w, $open, "P136OpenOutput")
    _UI_OnClick($w, $close, "P136CloseProgress")
    _UI_OnClose($w, "P136ProgressClosed")
    _UI_SetFont($w, $p136Phase, $gAppFont, $gAppSize)
    _UI_SetFont($w, $p136Detail, $gAppFont, $gAppSize)
    _UI_WindowCenter($w)
    _UI_WindowShow($w)
EndFunc

; 「停止翻譯」：寫出取消檔，子程序完成目前請求後結束。
Func P136StopJob($id)
    #forceref $id
    If Not $p136Pid Then Return
    Local $h = FileOpen($p136Cancel, 2)
    If $h <> -1 Then
        FileWrite($h, "cancel")
        FileClose($h)
    EndIf
    If $p136ProgressWnd And _UI_IsAlive($p136ProgressWnd) Then _UI_SetText($p136ProgressWnd, $p136Phase, "正在停止（完成目前請求後結束）…")
EndFunc

; 開啟翻譯工作紀錄。
Func P136OpenLog($id)
    #forceref $id
    If FileExists($p136Log) Then ShellExecute($p136Log)
EndFunc

; 開啟輸出資料夾。
Func P136OpenOutput($id)
    #forceref $id
    If FileExists($p136Dest) Then ShellExecute($p136Dest)
EndFunc

; 關閉進度視窗（工作繼續）。
Func P136CloseProgress($id)
    #forceref $id
    If $p136ProgressWnd And _UI_IsAlive($p136ProgressWnd) Then _UI_WindowClose($p136ProgressWnd)
EndFunc

; 進度視窗已關閉的回呼。
Func P136ProgressClosed($id)
    #forceref $id
    $p136ProgressWnd = 0
EndFunc

; 主迴圈呼叫：處理 AI 設定的非同步請求、重新開啟設定視窗與翻譯工作輪詢。
Func P136Tick()
    If $gDrawerOpen Or TimerDiff($gDrawerTransitionClock) < $gDrawerAnimationMs Then Return
    P136PollHttp()
    If $p136State = "settings" And ($p136SetWnd = 0 Or Not _UI_IsAlive($p136SetWnd)) Then
        $p136State = ""
        $p136SetWnd = 0
        P136OpenSettings(($p136TransWnd <> 0 And _UI_IsAlive($p136TransWnd)) ? $p136TransWnd : $gWnd)
    EndIf
    P136PollJob()
EndFunc

; 從共享記憶體讀取翻譯進度；子程序結束後顯示結果。
Func P136PollJob()
    If Not $p136Pid Then Return
    If TimerDiff($p136Clock) < 120 Then Return
    $p136Clock = TimerInit()
    If Not $p136View Then $p136View = P133Map($p136Pid, False, $p136Handle)
    If $p136View Then
        Local $st = DllStructCreate($g133Tag, $p136View), $seq = DllStructGetData($st, "seq")
        If Mod($seq, 2) = 0 And $seq <> $p136LastSeq Then
            Local $pct = DllStructGetData($st, "percent"), $phase = DllStructGetData($st, "phase"), $item = DllStructGetData($st, "item")
            Local $done = DllStructGetData($st, "done"), $total = DllStructGetData($st, "total")
            If DllStructGetData($st, "seq") = $seq And $p136ProgressWnd And _UI_IsAlive($p136ProgressWnd) Then
                Local $mode = ($pct < 0 ? 1 : 0)
                If $mode <> $p136LastMode Then
                    _UI_ProgressSetIndeterminate($p136ProgressWnd, $p136Bar, $mode)
                    $p136LastMode = $mode
                EndIf
                If $pct >= 0 And $pct <> $p136LastPct Then
                    _UI_ProgressSetValue($p136ProgressWnd, $p136Bar, $pct)
                    $p136LastPct = $pct
                EndIf
                Local $p = $phase
                If $total > 0 Then $p &= "  " & $done & " / " & $total & "（" & StringFormat("%.1f", 100 * $done / $total) & "%）"
                If $p <> $p136LastPhase Then
                    _UI_SetText($p136ProgressWnd, $p136Phase, $p)
                    $p136LastPhase = $p
                EndIf
                If $item <> $p136LastDetail Then
                    _UI_SetText($p136ProgressWnd, $p136Detail, $item)
                    $p136LastDetail = $item
                EndIf
            EndIf
            $p136LastSeq = $seq
        EndIf
    EndIf
    If ProcessExists($p136Pid) Then Return
    Local $text = FileRead($p136Log), $code = -1, $m = StringRegExp($text, "(?m)^ExitCode=([0-9]+)", 1)
    If IsArray($m) Then $code = Number($m[0])
    Local $title = "翻譯完成", $body = $p136Dest, $kind = $AUI_NOTIFY_INFO
    Switch $code
        Case 0
        Case 20
            $title = "翻譯已停止"
            $body = "已完成的檔案與快取已保留，以相同設定再次執行即可續譯。"
            $kind = $AUI_NOTIFY_WARNING
        Case 21
            $title = "翻譯完成（部分段落保留原文）"
            $body = "詳細清單：" & $p136Dest & ".hhtrans\errors.txt"
            $kind = $AUI_NOTIFY_WARNING
        Case Else
            $title = "翻譯失敗，錯誤碼=" & $code
            $body = $p136Log
            $kind = $AUI_NOTIFY_WARNING
    EndSwitch
    If $p136ProgressWnd And _UI_IsAlive($p136ProgressWnd) Then
        _UI_ProgressSetIndeterminate($p136ProgressWnd, $p136Bar, False)
        _UI_ProgressSetValue($p136ProgressWnd, $p136Bar, (($code = 0 Or $code = 21) ? 100 : 0))
        _UI_SetText($p136ProgressWnd, $p136Phase, $title)
        _UI_SetText($p136ProgressWnd, $p136Detail, $body)
    EndIf
    Local $notifyWnd = $gWnd
    If $p136ProgressWnd And _UI_IsAlive($p136ProgressWnd) Then $notifyWnd = $p136ProgressWnd
    _UI_Notify($notifyWnd, $title, $body, $kind, 8000)
    P133Unmap($p136View, $p136Handle)
    FileDelete($p136Cancel)
    $p136Pid = 0
EndFunc
