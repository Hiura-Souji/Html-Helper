#include-once
; =============================================================================
; Html Helper － CHM 解包／打包的 GUI 流程
;
; 從「開啟 ▼」選單啟動解包或打包：逐步選擇來源、首頁、
; 輸出與編譯器（AUI 對話框為非同步，下一步在主迴圈排程），
; 再以命令列子程序執行並顯示進度視窗。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 關閉進度視窗（背景工作繼續）。
Func P133CloseProgress($id)
    #forceref $id
    If $g133ProgressWnd And _UI_IsAlive($g133ProgressWnd) Then _UI_WindowClose($g133ProgressWnd)
    $g133ProgressWnd = 0
EndFunc

; 開啟工作紀錄。
Func P133OpenLog($id)
    #forceref $id
    If FileExists($g133JobLog) Then ShellExecute($g133JobLog)
EndFunc

; 開始解包或打包流程（選擇來源與 HHP）。
Func P133StartJob($build)
    If $g133JobPid Or IsObj($g135Flow) Then
        P135Info("CHM 工作進行中", "請先完成目前設定或等待上一個工作完成。")
        Return
    EndIf
    $g135Flow = ObjCreate("Scripting.Dictionary")
    $g135Flow.Add("build", $build)
    $g135Flow.Add("src", "")
    $g135Flow.Add("dest", "")
    $g135Flow.Add("home", "")
    $g135Flow.Add("compiler", "")
    $g135Flow.Add("project", "")
    $g135Flow.Add("defaultOutput", "HtmlHelper_Rebuilt.chm")
    If Not $build Then
        Local $source = FileOpenDialog("選擇 ITSS 匯出的 CHM（會同時生成 HHP）", @ScriptDir, "CHM (*.chm)", 1)
        If @error Then
            P135EndFlow()
            Return
        EndIf
        Local $dest = FileSelectFolder("選擇空白輸出資料夾", "", 1)
        If @error Then
            P135EndFlow()
            Return
        EndIf
        If Not P133Empty($dest) Then
            P135EndFlow()
            P135Info("不能匯出", "目的資料夾已有內容，請選擇空白資料夾。")
            Return
        EndIf
        $g135Flow.Item("src") = $source
        $g135Flow.Item("dest") = $dest
        $g135Next = "launch"
        Return
    EndIf
    Local $src = FileSelectFolder("選擇打包來源資料夾", "", 0)
    If @error Then
        P135EndFlow()
        Return
    EndIf
    $src = P133Path($src)
    $g135Flow.Item("src") = $src
    Local $projects = P134Candidates($src)
    If @error Or Not IsArray($projects) Then
        P135EndFlow()
        P135Info("不能搜尋 HHP", "來源無法完整列舉。")
        Return
    EndIf
    Local $projectArg = ""
    If UBound($projects) = 1 Then
        $projectArg = $projects[0]
    ElseIf UBound($projects) > 1 Then
        $projectArg = FileOpenDialog("找到多個 HHP，請選擇專案", $src, "HTML Help Project (*.hhp)", 1)
        If @error Then
            P135EndFlow()
            Return
        EndIf
    Else
        $g135Dialog = P135Ask("來源沒有 HHP", "新版 ITSS 匯出會生成 HHP，可先重新匯出。" & @CRLF & "目前若仍繼續，將使用簡化專案，無法宣稱還原原視窗／MAP／ALIAS。", "繼續簡化重建|取消", "P135NoProjectReply", 1, 1)
        If Not $g135Dialog Then P135EndFlow()
        Return
    EndIf
    Local $projectRoot = "", $projectName = "", $why = ""
    If Not P134Locate($src, $projectArg, $projectRoot, $projectName, $why) Then
        P135EndFlow()
        P135Info("HHP 選擇錯誤", $why)
        Return
    EndIf
    $g135Flow.Item("src") = $projectRoot
    $g135Flow.Item("project") = $projectName
    Local $declared = P134Unquote(P134Option(P133ReadText(P134Prefix($projectRoot) & $projectName), "Compiled file"))
    $declared = StringRegExpReplace($declared, "^.*[\\/]", "")
    If StringRegExp($declared, "(?i)\.chm$") Then $g135Flow.Item("defaultOutput") = StringTrimRight($declared, 4) & "_Rebuilt.chm"
    $g135Next = "home"
EndFunc

; 主迴圈呼叫：從共享記憶體讀取子程序進度並更新進度視窗。
Func P133PollJob()
    If Not $g133JobPid Then Return
    If $gDrawerOpen Or TimerDiff($gDrawerTransitionClock) < $gDrawerAnimationMs Then Return
    If TimerDiff($g133PollClock) < 100 Then Return
    $g133PollClock = TimerInit()
    If Not $g133ParentPtr Then $g133ParentPtr = P133Map($g133JobPid, False, $g133ParentHandle)
    If $g133ParentPtr Then
        Local $st = DllStructCreate($g133Tag, $g133ParentPtr), $seq = DllStructGetData($st, "seq")
        If Mod($seq, 2) = 0 And $seq <> $g133LastSeq Then
            Local $pct = DllStructGetData($st, "percent"), $phase = DllStructGetData($st, "phase"), $item = DllStructGetData($st, "item")
            Local $done = DllStructGetData($st, "done"), $total = DllStructGetData($st, "total")
            If DllStructGetData($st, "seq") = $seq Then
                If $g133ProgressWnd And _UI_IsAlive($g133ProgressWnd) Then
                    Local $mode = ($pct < 0 ? 1 : 0)
                    If $mode <> $g133LastMode Then
                        _UI_ProgressSetIndeterminate($g133ProgressWnd, $g133ProgressBar, $mode)
                        $g133LastMode = $mode
                    EndIf
                    If $pct >= 0 And $pct <> $g133LastPct Then
                        _UI_ProgressSetValue($g133ProgressWnd, $g133ProgressBar, $pct)
                        $g133LastPct = $pct
                    EndIf
                    Local $p = $phase, $d = $item
                    If $total > 0 Then
                        $p &= "  " & StringFormat("%.1f", 100 * $done / $total) & "%"
                        $d &= @CRLF & (StringInStr($phase, "Local") ? "已核對 " : "已處理 ") & $done & " / " & $total & (StringInStr($phase, "Local") ? " 筆 Local" : "")
                    EndIf
                    If $p <> $g133LastPhase Then
                        _UI_SetText($g133ProgressWnd, $g133ProgressPhase, $p)
                        $g133LastPhase = $p
                    EndIf
                    If $d <> $g133LastDetail Then
                        _UI_SetText($g133ProgressWnd, $g133ProgressDetail, $d)
                        $g133LastDetail = $d
                    EndIf
                EndIf
                $g133LastSeq = $seq
            EndIf
        EndIf
    EndIf
    If ProcessExists($g133JobPid) Then Return
    Local $text = FileRead($g133JobLog), $code = -1, $m = StringRegExp($text, "(?m)^ExitCode=([0-9]+)", 1)
    If IsArray($m) Then $code = Number($m[0])
    If $g133ProgressWnd And _UI_IsAlive($g133ProgressWnd) Then
        _UI_ProgressSetIndeterminate($g133ProgressWnd, $g133ProgressBar, False)
        _UI_ProgressSetValue($g133ProgressWnd, $g133ProgressBar, ($code = 0 ? 100 : 0))
        _UI_SetText($g133ProgressWnd, $g133ProgressPhase, ($code = 0 ? "完成" : "失敗，錯誤碼=" & $code))
        _UI_SetText($g133ProgressWnd, $g133ProgressDetail, ($code = 0 ? $g133JobDest : $g133JobLog))
    EndIf
    _UI_Notify($gWnd, "CHM 工作", ($code = 0 ? "完成：" & $g133JobDest : "失敗，請查看：" & $g133JobLog), ($code = 0 ? $AUI_NOTIFY_INFO : $AUI_NOTIFY_WARNING), 7000)
    P133Unmap($g133ParentPtr, $g133ParentHandle)
    $g133JobPid = 0
EndFunc

; 結束並清除目前的設定流程。
Func P135EndFlow()
    $g135Flow = 0
    $g135Next = ""
    $g135Dialog = 0
    $g135Retry = ""
EndFunc

; 「來源沒有 HHP」對話框的回呼。
Func P135NoProjectReply($id, $value)
    If $id <> $g135Dialog Then Return
    $g135Dialog = 0
    If Number($value) = 0 Then
        $g135Next = "home"
    Else
        P135EndFlow()
    EndIf
EndFunc

; 「首頁設定方式」對話框的回呼。
Func P135HomeReply($id, $value)
    If $id <> $g135Dialog Then Return
    $g135Dialog = 0
    Switch Number($value)
        Case 0
            $g135Next = "output"
        Case 1
            $g135Next = "browse"
        Case Else
            P135EndFlow()
    EndSwitch
EndFunc

; 「重新選擇」對話框的回呼。
Func P135RetryReply($id, $value)
    If $id <> $g135Dialog Then Return
    $g135Dialog = 0
    If Number($value) = 0 Then
        $g135Next = $g135Retry
    Else
        P135EndFlow()
    EndIf
EndFunc

; 顯示可重新選擇的錯誤對話框。
Func P135RetryDialog($stage, $title, $body)
    $g135Retry = $stage
    $g135Dialog = P135Ask($title, $body, "重新選擇|取消", "P135RetryReply", 0, 1)
    If Not $g135Dialog Then P135EndFlow()
EndFunc

; 主迴圈呼叫：依流程階段顯示下一個對話框或檔案選擇。
Func P135UiTick()
    If Not IsObj($g135Flow) Then Return
    If $gDrawerOpen Or TimerDiff($gDrawerTransitionClock) < $gDrawerAnimationMs Then Return
    If $g135Dialog Then
        If TimerDiff($g135DialogClock) < 200 Then Return
        If Not _UI_DialogGetOpen($gWnd, $g135Dialog) And $g135Next = "" Then P135EndFlow()
        Return
    EndIf
    If $g135Next = "" Then Return
    Local $stage = $g135Next
    $g135Next = ""
    Switch $stage
        Case "home"
            $g135Dialog = P135Ask("CHM 打包首頁", "選擇首頁設定方式。" & @CRLF & "沿用專案首頁：保留原 HHP／預設視窗設定。" & @CRLF & "選擇 HTML 首頁：明確指定來源內的 HTML。", "沿用專案首頁|選擇 HTML 首頁|取消", "P135HomeReply", 0, 2)
            If Not $g135Dialog Then P135EndFlow()
        Case "browse"
            Local $src = $g135Flow.Item("src"), $prefix = P134Prefix($src)
            Local $picked = FileOpenDialog("選擇首頁 HTML（必須位於專案內）", $src, "HTML (*.htm;*.html)", 1)
            If @error Then
                P135EndFlow()
                Return
            EndIf
            $picked = P133Path($picked)
            If StringLeft(StringLower($picked), StringLen($prefix)) <> StringLower($prefix) Or Not StringRegExp($picked, "(?i)\.html?$") Then
                P135RetryDialog("browse", "首頁位置不正確", "請選擇專案資料夾或其子資料夾內的 .htm／.html。")
                Return
            EndIf
            $g135Flow.Item("home") = StringTrimLeft($picked, StringLen($prefix))
            $g135Next = "output"
        Case "output"
            Local $dest = FileSaveDialog("輸出新的 CHM（可放專案內；不覆寫）", $g135Flow.Item("src"), "CHM (*.chm)", 0, $g135Flow.Item("defaultOutput"))
            If @error Then
                P135EndFlow()
                Return
            EndIf
            If Not StringRegExp($dest, "(?i)\.chm$") Then $dest &= ".chm"
            If FileExists($dest) Then
                P135RetryDialog("output", "輸出檔已存在", "為保護原檔，請選擇新的 CHM 檔名。")
                Return
            EndIf
            $g135Flow.Item("dest") = $dest
            $g135Next = "compiler"
        Case "compiler"
            Local $compiler = P133Compiler("")
            If $compiler = "" Then
                $compiler = FileOpenDialog("指定 HTML Help Workshop hhc.exe", @ProgramFilesDir, "編譯器 (hhc.exe)", 1)
                If @error Then
                    P135EndFlow()
                    Return
                EndIf
            EndIf
            $g135Flow.Item("compiler") = $compiler
            $g135Next = "launch"
        Case "launch"
            P135LaunchFlow()
    EndSwitch
EndFunc

; 以命令列子程序啟動解包或打包，並開啟進度視窗。
Func P135LaunchFlow()
    If Not IsObj($g135Flow) Then Return
    Local $src = $g135Flow.Item("src"), $dest = $g135Flow.Item("dest"), $home = $g135Flow.Item("home"), $compiler = $g135Flow.Item("compiler")
    Local $build = $g135Flow.Item("build"), $projectArg = $g135Flow.Item("project"), $mode = ($build ? "--build-chm" : "--extract-chm")
    P135EndFlow()
    Local $cmd = '"' & @ScriptFullPath & '"'
    If Not @Compiled Then $cmd = '"' & @AutoItExe & '" "' & @ScriptFullPath & '"'
    $cmd &= " " & $mode & ' "' & $src & '" "' & $dest & '"'
    If $build Then $cmd &= ' --compiler "' & $compiler & '"'
    If $build And $home <> "" Then $cmd &= ' --home "' & $home & '"'
    If $build And $projectArg <> "" Then $cmd &= ' --project "' & $projectArg & '"'
    Local $pid = Run($cmd, @ScriptDir, @SW_HIDE)
    If @error Or Not $pid Then
        P135Info("不能啟動 CHM 工作", "無法啟動同一程式的命令模式。")
        Return
    EndIf
    ProcessSetPriority($pid, 1)
    P133Unmap($g133ParentPtr, $g133ParentHandle)
    $g133JobPid = $pid
    $g133JobDest = P133Path($dest)
    $g133JobLog = $g133JobDest & "." & $pid & ".log"
    $g133LastSeq = -1
    $g133LastPct = -99
    $g133LastPhase = ""
    $g133LastDetail = ""
    $g133LastMode = 1
    P133CloseProgress(0)
    $g133ProgressWnd = _UI_WindowCreateEx(($build ? "CHM 打包與驗證" : "CHM ITSS 匯出"), 0, 0, 720, 330, BitOR($AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $g133ProgressWnd Then
        _UI_ThemeSetMode($g133ProgressWnd, HelperEffectiveTheme())
        $g133ProgressPhase = _UI_Text($g133ProgressWnd, 0, "正在啟動…", 20, 45, 680, 30)
        $g133ProgressBar = _UI_Progress($g133ProgressWnd, 0, 0, 20, 90, 680, 26)
        _UI_ProgressSetRange($g133ProgressWnd, $g133ProgressBar, 0, 100)
        _UI_ProgressSetIndeterminate($g133ProgressWnd, $g133ProgressBar, True)
        $g133ProgressDetail = _UI_Text($g133ProgressWnd, 0, $g133JobDest & ($build ? @CRLF & "首頁：" & ($home <> "" ? $home : "自動判斷") : ""), 20, 130, 680, 100)
        Local $log = _UI_Button($g133ProgressWnd, 0, "開啟工作紀錄", $AUI_VAR_DEFAULT, 20, 250, 180, 36)
        Local $close = _UI_Button($g133ProgressWnd, 0, "關閉視窗（工作繼續）", $AUI_VAR_DEFAULT, 460, 250, 240, 36)
        _UI_OnClick($g133ProgressWnd, $log, "P133OpenLog")
        _UI_OnClick($g133ProgressWnd, $close, "P133CloseProgress")
        _UI_SetFont($g133ProgressWnd, $g133ProgressPhase, $gAppFont, $gAppSize)
        _UI_SetFont($g133ProgressWnd, $g133ProgressDetail, $gAppFont, $gAppSize)
        _UI_WindowCenter($g133ProgressWnd)
        _UI_WindowShow($g133ProgressWnd)
    EndIf
EndFunc
