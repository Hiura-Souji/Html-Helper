#include-once
; =============================================================================
; Html Helper － 命令列說明視窗
;
; 左側選單切換各指令說明，指令可一鍵複製；文字依顯示寬度自動斷行。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ---------------------------------------------------------------------------
; 命令列說明（AUI 視窗）：每條指令放在可編輯的輸入框，按「複製」複製框內目前文字。
; ---------------------------------------------------------------------------
Func HH_CliExe()
    If @Compiled Then Return '"' & @ScriptFullPath & '"'
    Return '"' & @AutoItExe & '" "' & @ScriptFullPath & '"'
EndFunc

; 開啟命令列說明視窗。
Func HH_CliHelpOpen()
    If $gCliHelpWnd <> 0 And _UI_IsAlive($gCliHelpWnd) Then
        _UI_WindowShowModal($gCliHelpWnd, $gWnd)
        Return
    EndIf
    Local $exe = HH_CliExe()
    Local $titles[9] = ["開啟 CHM", "開啟並跳到指定頁面", "解包 CHM", "打包成 CHM", "打包（指定編譯器）", _
        "AI 翻譯", "Google 免費翻譯", "顯示所有參數", "結束代碼與紀錄"]
    Local $descs[9] = ["用本程式開啟 CHM；程式已在執行時，會開在同一視窗的新分頁。", _
        "第二個參數是 CHM 內的頁面路徑，開啟後直接顯示該頁。", _
        "把 CHM 解成資料夾，保留原始檔名與資料夾結構，並另存還原用對照表。", _
        "把資料夾編譯成 CHM，自動尋找 hhc.exe 與 .hhp。", _
        "自行指定編譯器、首頁與專案檔。", _
        "用 AI 翻譯 CHM 或解包資料夾，保留資料夾結構，程式碼維持原樣。", _
        "用 Google 免費翻譯，不需要 API Key。", _
        "在命令提示字元列出所有參數。", _
        "批次檔可依結束代碼（%ERRORLEVEL%）判斷結果。"]
    Local $cmds[9] = [$exe & ' "D:\Docs\AutoIt.chm"', _
        $exe & ' "D:\Docs\AutoIt.chm" "html/functions/MsgBox.htm"', _
        $exe & ' --extract-chm "D:\Docs\AutoIt.chm" "D:\Work\AutoIt_src"', _
        $exe & ' --build-chm "D:\Work\AutoIt_src" "D:\Work\AutoIt_new.chm"', _
        $exe & ' --build-chm "D:\Work\AutoIt_src" "D:\Work\AutoIt_new.chm" --compiler "C:\Program Files (x86)\HTML Help Workshop\hhc.exe" --home "html\index.htm" --project "AutoIt.hhp"', _
        $exe & ' --translate-chm "D:\Docs\AutoIt.chm" "D:\Work\AutoIt_zh" --profile 1 --lang "繁體中文（臺灣）" --lcid 1028 --comments 1 --toc 1 --index 0 --hhp 1', _
        $exe & ' --translate-chm "D:\Work\AutoIt_src" "D:\Work\AutoIt_zh" --engine google --code zh-TW', _
        $exe & ' --help', _
        'start /wait "" ' & $exe & ' --extract-chm "D:\Docs\AutoIt.chm" "D:\Work\AutoIt_src"']
    Local $notes[9] = ["可把本程式設為 .chm 的預設程式，直接按兩下開啟。" & @LF & "多個 CHM 會開在同一視窗的不同分頁，分頁可拖曳排序。", _
        "頁面路徑相對於 CHM 根目錄，例如 html/functions/MsgBox.htm。", _
        "--extract-chm  <CHM>  <輸出資料夾>" & @LF & "輸出資料夾必須不存在或為空。", _
        "--build-chm  <來源資料夾>  <輸出 CHM>" & @LF & "輸出檔已存在時不覆寫。", _
        "--compiler  hhc.exe 的路徑（HTML Help Workshop）" & @LF & "--home  首頁，相對於來源資料夾" & @LF & "--project  指定 .hhp 專案檔", _
        "--translate-chm  <來源資料夾或 .chm>  <輸出資料夾>" & @LF & "--profile  AI 設定檔編號（預設為目前使用中）" & @LF & "--lang  目標語言名稱" & @LF & _
        "--lcid  輸出 CHM 語系（1028＝繁體中文）" & @LF & "--comments 1/0  是否翻譯程式碼註解" & @LF & "--toc 1/0  目錄　--index 1/0  索引　--hhp 1/0  專案標題", _
        "--engine google  改用 Google 免費翻譯" & @LF & "--code  Google 語言代碼，例如 zh-TW、ja、en", _
        "--help  列出所有參數與用法。", _
        "0 成功　2 參數錯誤　3 CHM 無法開啟　4 讀取失敗　5 輸出資料夾不可用" & @LF & _
        "10 來源／專案錯誤　11 找不到 hhc.exe　12 工作區錯誤" & @LF & "13 編譯失敗　14 新 CHM 驗證失敗　15 無法輸出" & @LF & _
        "20 使用者停止（已完成的檔案與快取保留）" & @LF & "21 完成，但部分段落保留原文（見 errors.txt）" & @LF & _
        "紀錄檔：<輸出路徑>.<PID>.log" & @LF & "批次檔中用 start /wait 執行，結束後再檢查 %ERRORLEVEL%。"]
    $gCliHelpCount = 9
    For $i = 0 To 8
        $gCliHelpCmds[$i] = $cmds[$i]
        $gCliHelpDescs[$i] = $descs[$i]
        $gCliHelpNotes[$i] = $notes[$i]
        $gCliHelpTitles[$i] = $titles[$i]
    Next
    ; 不使用捲動區：左側選單切換頁面，每頁內容固定位置，矮螢幕也不必捲動。
    Local $sz = $gAppSize
    If $sz < 12 Then $sz = 12
    If $sz > 16 Then $sz = 16
    Local $lh = Int($sz * 1.7)
    Local $rx = 284, $rw = 660
    $gCliHelpCodeCols = Int(($rw - 28) / ($sz * 0.56))
    $gCliHelpNoteCols = Int($rw / ($sz * 0.52))
    Local $y = 52
    Local $yTitle = $y, $yDesc = $yTitle + $lh + 14
    Local $yCodeLabel = $yDesc + 2 * $lh + 10
    Local $yPanel = $yCodeLabel + $lh + 4
    Local $panelH = $HH_CLI_CODE_LINES * $lh + 16
    Local $yCopy = $yPanel + $panelH + 10
    Local $yNoteLabel = $yCopy + 50
    Local $yNotes = $yNoteLabel + $lh + 4
    Local $winH = $yNotes + $HH_CLI_NOTE_LINES * $lh + 24
    If $winH < 52 + 9 * 46 + 70 Then $winH = 52 + 9 * 46 + 70
    $gCliHelpWnd = _UI_WindowCreateEx("命令列說明 - " & $HH_APP_NAME, 0, 0, $rx + $rw + 24, $winH, BitOR($AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED, $AUI_WIN_NO_THEME_BTN))
    If $gCliHelpWnd = 0 Then Return
    _UI_ThemeSetMode($gCliHelpWnd, $gThemeMode)
    _UI_WindowCenter($gCliHelpWnd)
    For $i = 0 To 8
        $gCliHelpButtons[$i] = HH_Button($gCliHelpWnd, 0, $titles[$i], $AUI_VAR_DEFAULT, 16, 52 + $i * 46, 240, 40)
        _UI_OnClick($gCliHelpWnd, $gCliHelpButtons[$i], "HH_CliHelpNav")
    Next
    Local $close = HH_Button($gCliHelpWnd, 0, "關閉", $AUI_VAR_DEFAULT, 16, $winH - 60, 240, 40)
    _UI_OnClick($gCliHelpWnd, $close, "HH_CliHelpClose")
    _UI_Divider($gCliHelpWnd, 0, True, 268, 52, 1, $winH - 76)
    $gCliHelpTitle = HH_CliLabel($rx, $yTitle, $rw, $lh + 8, $gAppFont, $sz + 5)
    For $i = 0 To 1
        $gCliHelpDesc[$i] = HH_CliLabel($rx, $yDesc + $i * $lh, $rw, $lh, $gAppFont, $sz)
    Next
    HH_CliLabel($rx, $yCodeLabel, $rw, $lh, $gAppFont, $sz, "指令")
    Local $panel = _UI_Panel($gCliHelpWnd, 0, $rx, $yPanel, $rw, $panelH)
    If $panel > 0 Then _UI_PanelSetBordered($gCliHelpWnd, $panel, True)
    For $i = 0 To $HH_CLI_CODE_LINES - 1
        $gCliHelpCode[$i] = HH_CliLabel($rx + 14, $yPanel + 8 + $i * $lh, $rw - 28, $lh, "Consolas", $sz)
    Next
    $gCliHelpCopyBtn = HH_Button($gCliHelpWnd, 0, "複製指令", $AUI_VAR_PRIMARY, $rx, $yCopy, 160, 40)
    _UI_OnClick($gCliHelpWnd, $gCliHelpCopyBtn, "HH_CliHelpCopy")
    HH_CliLabel($rx + 176, $yCopy, $rw - 176, 40, $gAppFont, $sz, "複製後貼到命令提示字元或批次檔，再改成自己的路徑。")
    HH_CliLabel($rx, $yNoteLabel, $rw, $lh, $gAppFont, $sz, "說明")
    For $i = 0 To $HH_CLI_NOTE_LINES - 1
        $gCliHelpNote[$i] = HH_CliLabel($rx, $yNotes + $i * $lh, $rw, $lh, $gAppFont, $sz)
    Next
    _UI_OnClose($gCliHelpWnd, "HH_CliHelpClosed")
    HH_ApplyChildFonts()
    HH_CliHelpShow(0)
    _UI_WindowShowModal($gCliHelpWnd, $gWnd)
EndFunc

; 在說明視窗建立指定字型的文字列。
Func HH_CliLabel($x, $y, $w, $h, $font, $size, $text = " ")
    Local $id = _UI_Text($gCliHelpWnd, 0, $text, $x, $y, $w, $h)
    If $id > 0 Then _UI_SetFont($gCliHelpWnd, $id, $font, $size)
    Return $id
EndFunc

; 左側選單按鈕回呼：切換頁面。
Func HH_CliHelpNav($id)
    For $i = 0 To $gCliHelpCount - 1
        If $gCliHelpButtons[$i] = $id Then
            HH_CliHelpShow($i)
            Return
        EndIf
    Next
EndFunc

; 切換頁面：只更新固定位置文字的內容與選單按鈕的樣式。
Func HH_CliHelpShow($page)
    If $gCliHelpWnd = 0 Or $page < 0 Or $page >= $gCliHelpCount Then Return
    $gCliHelpPage = $page
    For $i = 0 To $gCliHelpCount - 1
        _UI_ButtonSetVariant($gCliHelpWnd, $gCliHelpButtons[$i], ($i = $page ? $AUI_VAR_PRIMARY : $AUI_VAR_DEFAULT))
    Next
    _UI_SetText($gCliHelpWnd, $gCliHelpTitle, ($page + 1) & ". " & $gCliHelpTitles[$page])
    HH_CliFill($gCliHelpDesc, 2, $gCliHelpDescs[$page], $gCliHelpNoteCols)
    HH_CliFill($gCliHelpCode, $HH_CLI_CODE_LINES, $gCliHelpCmds[$page], $gCliHelpCodeCols)
    HH_CliFill($gCliHelpNote, $HH_CLI_NOTE_LINES, $gCliHelpNotes[$page], $gCliHelpNoteCols)
EndFunc

; 把文字斷行後填入固定數量的文字列；超出的行併到最後一列並以「…」結尾（複製仍是完整內容）。
Func HH_CliFill(ByRef $ids, $count, $text, $cols)
    Local $all[1] = [" "], $n = 0
    Local $src = StringSplit($text, @LF, 2)
    For $k = 0 To UBound($src) - 1
        Local $parts = HH_CliWrap($src[$k], $cols)
        For $c = 0 To UBound($parts) - 1
            If $n >= UBound($all) Then ReDim $all[$n + 8]
            $all[$n] = $parts[$c]
            $n += 1
        Next
    Next
    For $i = 0 To $count - 1
        Local $line = " "
        If $i < $n Then $line = $all[$i]
        If $i = $count - 1 And $n > $count Then $line = StringLeft($line, StringLen($line) - 1) & "…"
        _UI_SetText($gCliHelpWnd, $ids[$i], $line)
    Next
EndFunc

; 依顯示寬度斷行（中日韓字元算 2 欄），優先在空白處斷開；回傳至少一行的陣列。
Func HH_CliWrap($text, $cols)
    Local $out[1] = [" "], $n = 0
    If $text = "" Then Return $out
    Local $len = StringLen($text), $start = 1
    While $start <= $len
        Local $w = 0, $pos = $start, $lastSpace = 0
        While $pos <= $len
            Local $code = AscW(StringMid($text, $pos, 1))
            Local $cw = (($code >= 0x1100 And $code <= 0x115F) Or ($code >= 0x2E80 And $code <= 0xA4CF) Or ($code >= 0xAC00 And $code <= 0xD7A3) Or ($code >= 0xF900 And $code <= 0xFAFF) Or ($code >= 0xFE30 And $code <= 0xFE4F) Or ($code >= 0xFF00 And $code <= 0xFF60) Or ($code >= 0xFFE0 And $code <= 0xFFE6)) ? 2 : 1
            If $w + $cw > $cols Then ExitLoop
            $w += $cw
            If $code = 32 Then $lastSpace = $pos
            $pos += 1
        WEnd
        Local $stop = $pos
        If $pos <= $len And $lastSpace > $start Then $stop = $lastSpace + 1
        If $stop <= $start Then $stop = $start + 1
        If $n >= UBound($out) Then ReDim $out[$n + 4]
        $out[$n] = StringStripWS(StringMid($text, $start, $stop - $start), 2)
        If $out[$n] = "" Then $out[$n] = " "
        $n += 1
        $start = $stop
    WEnd
    ReDim $out[$n]
    Return $out
EndFunc

; 「複製指令」按鈕：複製目前頁面的完整指令。
Func HH_CliHelpCopy($id)
    #forceref $id
    If $gCliHelpWnd = 0 Or $gCliHelpPage < 0 Or $gCliHelpPage >= $gCliHelpCount Then Return
    ClipPut($gCliHelpCmds[$gCliHelpPage])
    _UI_Notify($gCliHelpWnd, "已複製", $gCliHelpTitles[$gCliHelpPage] & " 的指令已複製到剪貼簿。", $AUI_NOTIFY_SUCCESS, 2500)
EndFunc

; 「關閉」按鈕。
Func HH_CliHelpClose($id)
    #forceref $id
    Local $w = $gCliHelpWnd
    If $w = 0 Then Return
    HH_ClearChildFonts($w)
    $gCliHelpWnd = 0
    _UI_WindowClose($w)
EndFunc

; 說明視窗已關閉的回呼。
Func HH_CliHelpClosed($id)
    #forceref $id
    If $gCliHelpWnd = 0 Then Return
    HH_ClearChildFonts($gCliHelpWnd)
    $gCliHelpWnd = 0
EndFunc
