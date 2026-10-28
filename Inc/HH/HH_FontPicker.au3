#include-once
; =============================================================================
; Html Helper － 字型選擇視窗
;
; 以 DirectWrite 列舉系統字型（AUI 以 DirectWrite 繪字，列出的都能用），
; 提供篩選、大小與即時範例。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ---------------------------------------------------------------------------
; 字型選擇視窗（參照 LineageAUI v60.8）
; AUI 以 DirectWrite 繪字，因此清單以 DirectWrite 系統字型集合列舉，列出的名稱都能套用；
; DirectWrite 失敗時才退回 GDI 列舉。
; ---------------------------------------------------------------------------
Func HH_FontTargetName($t)
    If $t = 2 Then Return "左側導航"
    If $t = 3 Then Return "文件內文"
    Return "軟體介面"
EndFunc

; 取得指定對象目前的字型與大小。
Func HH_FontTargetGet($t, ByRef $font, ByRef $size)
    If $t = 2 Then
        $font = $gSideFont
        $size = $gSideSize
    ElseIf $t = 3 Then
        $font = $gContentFont
        $size = $gContentSize
    Else
        $font = $gAppFont
        $size = $gAppSize
    EndIf
EndFunc

; 產生「字型，大小 px」的按鈕文字。
Func HH_FontTargetLabel($t)
    Local $f = "", $s = 14
    HH_FontTargetGet($t, $f, $s)
    Return $f & "，" & $s & " px"
EndFunc

; 讀取 COM 物件函式表中的第 $i 個方法位址。
Func HH_VT($p, $i)
    Local $vt = DllStructGetData(DllStructCreate("ptr", $p), 1)
    Return DllStructGetData(DllStructCreate("ptr", $vt + $i * (@AutoItX64 ? 8 : 4)), 1)
EndFunc

; 呼叫 COM 物件的 Release。
Func HH_ComRelease($p)
    If $p Then DllCallAddress("ulong", HH_VT($p, 2), "ptr", $p)
EndFunc

; 從 IDWriteLocalizedStrings 取名稱（優先繁中，其次英文）。
Func HH_DWLocalName($ls)
    ; IDWriteLocalizedStrings：優先繁中，其次英文，再其次第一個。
    Local $idx = -1
    Local $loc = StringSplit("zh-tw|zh-hk|en-us", "|", 2)
    For $l In $loc
        Local $f = DllCallAddress("long", HH_VT($ls, 4), "ptr", $ls, "wstr", $l, "uint*", 0, "bool*", 0)
        If Not @error And IsArray($f) And $f[0] = 0 And $f[4] Then
            $idx = $f[3]
            ExitLoop
        EndIf
    Next
    If $idx < 0 Then $idx = 0
    Local $len = DllCallAddress("long", HH_VT($ls, 7), "ptr", $ls, "uint", $idx, "uint*", 0)
    If @error Or Not IsArray($len) Or $len[0] <> 0 Then Return ""
    Local $n = $len[3] + 1
    Local $t = DllStructCreate("wchar[" & $n & "]")
    Local $g = DllCallAddress("long", HH_VT($ls, 8), "ptr", $ls, "uint", $idx, "struct*", $t, "uint", $n)
    If @error Or Not IsArray($g) Or $g[0] <> 0 Then Return ""
    Return DllStructGetData($t, 1)
EndFunc

; 以 DirectWrite 系統字型集合列舉字型家族。
Func HH_FontEnumDW(ByRef $names)
    Local $tIID = DllStructCreate("byte[16]")
    DllCall("ole32.dll", "long", "CLSIDFromString", "wstr", "{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}", "struct*", $tIID)
    ; dwrite.dll 必須保持載入，否則 COM 物件的函式表會失效。
    If $gDWDll = -1 Then $gDWDll = DllOpen("dwrite.dll")
    If $gDWDll = -1 Then Return 0
    Local $r = DllCall($gDWDll, "long", "DWriteCreateFactory", "int", 0, "struct*", $tIID, "ptr*", 0)
    If @error Or Not IsArray($r) Or $r[0] <> 0 Or Not $r[3] Then Return 0
    Local $fac = $r[3]
    Local $c = DllCallAddress("long", HH_VT($fac, 3), "ptr", $fac, "ptr*", 0, "bool", False)
    If @error Or Not IsArray($c) Or $c[0] <> 0 Or Not $c[2] Then
        HH_ComRelease($fac)
        Return 0
    EndIf
    Local $coll = $c[2]
    Local $cnt = DllCallAddress("uint", HH_VT($coll, 3), "ptr", $coll)
    Local $n = 0
    If Not @error And IsArray($cnt) Then $n = $cnt[0]
    ReDim $names[$n + 1]
    Local $m = 0
    For $i = 0 To $n - 1
        Local $fr = DllCallAddress("long", HH_VT($coll, 4), "ptr", $coll, "uint", $i, "ptr*", 0)
        If @error Or Not IsArray($fr) Or $fr[0] <> 0 Or Not $fr[3] Then ContinueLoop
        Local $fam = $fr[3]
        Local $nr = DllCallAddress("long", HH_VT($fam, 6), "ptr", $fam, "ptr*", 0)
        If Not @error And IsArray($nr) And $nr[0] = 0 And $nr[2] Then
            Local $name = StringStripWS(HH_DWLocalName($nr[2]), 3)
            HH_ComRelease($nr[2])
            If $name <> "" And StringLeft($name, 1) <> "@" Then
                $names[$m] = $name
                $m += 1
            EndIf
        EndIf
        HH_ComRelease($fam)
    Next
    HH_ComRelease($coll)
    HH_ComRelease($fac)
    Return $m
EndFunc

; 列舉並排序字型（DirectWrite 失敗時改用 GDI，再失敗用內建清單）。
Func HH_FontEnum()
    If $gFontListCount > 0 Then Return
    Local $names[1], $m = HH_FontEnumDW($names)
    If $m <= 0 Then
        Local $a = _WinAPI_EnumFontFamilies(0, "", $DEFAULT_CHARSET, BitOR($DEVICE_FONTTYPE, $TRUETYPE_FONTTYPE), "@*", 1)
        $m = 0
        If IsArray($a) And UBound($a, 0) = 2 Then
            ReDim $names[UBound($a) + 1]
            For $i = 1 To UBound($a) - 1
                Local $nm = StringStripWS($a[$i][0], 3)
                If $nm = "" Or StringLeft($nm, 1) = "@" Then ContinueLoop
                $names[$m] = $nm
                $m += 1
            Next
        EndIf
    EndIf
    If $m = 0 Then
        Local $fb = StringSplit("Microsoft JhengHei|Microsoft JhengHei UI|微軟正黑體|Segoe UI|新細明體|標楷體|Consolas", "|", 2)
        $m = UBound($fb)
        ReDim $names[$m]
        For $i = 0 To $m - 1
            $names[$i] = $fb[$i]
        Next
    Else
        ReDim $names[$m]
    EndIf
    _ArraySort($names)
    ReDim $gFontList[$m + 1]
    $gFontListCount = 0
    For $i = 0 To $m - 1
        If $gFontListCount > 0 And $names[$i] = $gFontList[$gFontListCount] Then ContinueLoop
        $gFontListCount += 1
        $gFontList[$gFontListCount] = $names[$i]
    Next
EndFunc

; 開啟字型選擇視窗。
Func HH_FontWinOpen($target)
    If $gFontWin <> 0 And _UI_IsAlive($gFontWin) Then Return
    HH_FontEnum()
    $gFontTarget = $target
    HH_FontTargetGet($target, $gFontPickFamily, $gFontPickSize)
    $gFontFilterText = ""
    $gFontPickBad = False
    Local $owner = $gSettingsWnd
    If $owner = 0 Or Not _UI_IsAlive($owner) Then $owner = $gWnd
    $gFontWin = _UI_WindowCreateEx("字型選擇｜" & HH_FontTargetName($target), 0, 0, 580, 470, BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $gFontWin = 0 Then Return
    _UI_ThemeSetMode($gFontWin, HelperEffectiveTheme())
    _UI_WindowCenter($gFontWin)
    HH_Text($gFontWin, 0, "字型", 24, 46, 260, 24)
    $gFontFilter = HH_Input($gFontWin, 0, "篩選字型名稱", "", 24, 74, 266, 34)
    ; 固定大小的 DataView 清單，超出時在框內捲動。
    $gFontTree = _UI_DataView($gFontWin, 0, "", "", False, 24, 116, 266, 278)
    If $gFontTree > 0 Then HH_RegisterChildFont($gFontWin, $gFontTree)
    HH_Text($gFontWin, 0, "字體大小", 312, 46, 244, 24)
    $gFontSizeCombo = HH_Combo($gFontWin, 0, $gFontSizeChoices, 0, 312, 74, 244, 36)
    SelectFontCombo($gFontWin, $gFontSizeCombo, String($gFontPickSize))
    HH_Text($gFontWin, 0, "範例", 312, 118, 244, 24)
    ; 範例文字不註冊為子視窗字型，才能保留選取中的預覽字型。
    $gFontSample = _UI_Panel($gFontWin, 0, 312, 146, 244, 210)
    _UI_PanelSetBordered($gFontWin, $gFontSample, True)
    Local $aSample = StringSplit("測試字型|abcABC|おはよう、ユエ", "|", 2)
    For $i = 1 To 3
        $gFontSampleLines[$i] = _UI_Text($gFontWin, $gFontSample, $aSample[$i - 1], 12, 14 + ($i - 1) * 46, 220, 42)
    Next
    $gFontPickInfo = HH_Text($gFontWin, 0, "", 312, 362, 244, 26)
    Local $bDef = HH_Button($gFontWin, 0, "預設", $AUI_VAR_DEFAULT, 24, 408, 110, 40)
    Local $bCancel = HH_Button($gFontWin, 0, "取消", $AUI_VAR_DEFAULT, 332, 408, 104, 40)
    Local $bOk = HH_Button($gFontWin, 0, "確定", $AUI_VAR_PRIMARY, 452, 408, 104, 40)
    HH_FontTreeFill()
    _UI_OnValue($gFontWin, $gFontTree, "HH_FontListSel")
    _UI_DataViewOnCellClick($gFontWin, $gFontTree, "HH_FontListClick")
    _UI_OnValue($gFontWin, $gFontSizeCombo, "HH_FontSizeSel")
    _UI_OnChange($gFontWin, $gFontSizeCombo, "HH_FontSizeSel")
    _UI_OnValue($gFontWin, $gFontFilter, "HH_FontFilterSel")
    _UI_OnClick($gFontWin, $bDef, "HH_FontWinDefault")
    _UI_OnClick($gFontWin, $bCancel, "HH_FontWinCancel")
    _UI_OnClick($gFontWin, $bOk, "HH_FontWinOk")
    _UI_OnClose($gFontWin, "HH_FontWinClosed")
    HH_FontPreview()
    _UI_WindowShowModal($gFontWin, $owner)
    ; 置中於設定視窗（以實際像素尺寸計算，與 DPI 無關）。
    Local $po = WinGetPos($owner), $pf = WinGetPos($gFontWin)
    If IsArray($po) And IsArray($pf) Then WinMove($gFontWin, "", $po[0] + Int(($po[2] - $pf[2]) / 2), $po[1] + Int(($po[3] - $pf[3]) / 2))
EndFunc

; 依篩選文字填入字型清單並選取目前字型。
Func HH_FontTreeFill()
    If $gFontWin = 0 Or $gFontTree < 1 Then Return
    ReDim $gFontNodeNames[$gFontListCount + 2]
    $gFontNodeCount = 0
    Local $rows = "", $selRow = -1, $filter = StringStripWS($gFontFilterText, 3)
    For $i = 1 To $gFontListCount
        If $filter <> "" And Not StringInStr($gFontList[$i], $filter) Then ContinueLoop
        $gFontNodeNames[$gFontNodeCount] = $gFontList[$i]
        If $gFontNodeCount > 0 Then $rows &= @CRLF
        $rows &= StringReplace($gFontList[$i], @TAB, " ")
        If $gFontList[$i] = $gFontPickFamily Then $selRow = $gFontNodeCount
        $gFontNodeCount += 1
    Next
    _UI_DataViewSetRows($gFontWin, $gFontTree, $rows)
    If $selRow >= 0 Then
        _UI_DataViewSetSelected($gFontWin, $gFontTree, $selRow)
        _UI_DataViewScrollToRow($gFontWin, $gFontTree, $selRow)
    EndIf
EndFunc

; 選取清單中的字型並排定預覽。
Func HH_FontListPick($row)
    If $gFontWin = 0 Or $gFontTree < 1 Then Return
    $row = Int($row)
    If $row < 0 Or $row >= $gFontNodeCount Then $row = Int(_UI_DataViewGetSelected($gFontWin, $gFontTree))
    If $row < 0 Or $row >= $gFontNodeCount Then Return
    If $gFontNodeNames[$row] = $gFontPickFamily Then Return
    $gFontPickFamily = $gFontNodeNames[$row]
    HH_FontPreviewLater()
EndFunc

; 以下為 AUI 回呼：只排入佇列。
Func HH_FontListSel($id, $value = 0)
    If $gFontWin = 0 Or $id <> $gFontTree Then Return
    HH_Q("HH_FontListPick", 1, $value)
EndFunc

; 字型清單點選回呼（排入佇列）。
Func HH_FontListClick($row, $col = 0)
    #forceref $col
    HH_Q("HH_FontListPick", 1, $row)
EndFunc

; 字體大小回呼（排入佇列）。
Func HH_FontSizeSel($id, $value = 0)
    #forceref $value
    If $gFontWin = 0 Or $id <> $gFontSizeCombo Then Return
    HH_Q("HH_FontSizeNow")
EndFunc

; 套用選取的字體大小並排定預覽。
Func HH_FontSizeNow()
    If $gFontWin = 0 Or $gFontSizeCombo < 1 Then Return
    Local $s = Number(ComboValue($gFontWin, $gFontSizeCombo, String($gFontPickSize)))
    If $s < 5 Or $s > 40 Or $s = $gFontPickSize Then Return
    $gFontPickSize = $s
    HH_FontPreviewLater()
EndFunc

; 篩選框輸入回呼（排入佇列）。
Func HH_FontFilterSel($id = 0, $value = "")
    #forceref $id, $value
    HH_Q("HH_FontFilterNow")
EndFunc

; 依篩選文字重新填入清單。
Func HH_FontFilterNow()
    If $gFontWin = 0 Or $gFontFilter < 1 Then Return
    Local $text = _UI_GetText($gFontWin, $gFontFilter)
    If $text = $gFontFilterText Then Return
    $gFontFilterText = $text
    HH_FontTreeFill()
EndFunc

; 連續選取時只預覽最後一個（停 80 ms 後才套用到範例）。
Func HH_FontPreviewLater()
    $gFontPreviewDue = True
    $gFontPreviewClock = TimerInit()
EndFunc

; 主迴圈呼叫：時間到就執行預覽。
Func HH_FontPreviewTick()
    If Not $gFontPreviewDue Then Return
    If TimerDiff($gFontPreviewClock) < 80 Then Return
    $gFontPreviewDue = False
    HH_FontPreview()
EndFunc

; 把選取的字型套用到範例文字；AUI 不接受時顯示提示。
Func HH_FontPreview()
    If $gFontWin = 0 Or $gFontSample < 1 Then Return
    Local $ok = True
    For $i = 1 To 3
        If $gFontSampleLines[$i] < 1 Then ContinueLoop
        If _UI_SetFont($gFontWin, $gFontSampleLines[$i], $gFontPickFamily, $gFontPickSize) = 0 Then $ok = False
    Next
    If Not $ok Then
        ; AUI 不接受此字型名稱：範例改回預設字型並提示。
        For $i = 1 To 3
            If $gFontSampleLines[$i] > 0 Then _UI_SetFont($gFontWin, $gFontSampleLines[$i], $HH_DEFAULT_FONT, $gFontPickSize)
        Next
    EndIf
    $gFontPickBad = Not $ok
    If $ok Then
        _UI_SetText($gFontWin, $gFontPickInfo, $gFontPickFamily & "，" & $gFontPickSize & " px")
    Else
        _UI_SetText($gFontWin, $gFontPickInfo, "此字型 AUI 無法使用，請改選其他字型")
    EndIf
EndFunc

; 「預設」按鈕回呼。
Func HH_FontWinDefault($id = 0)
    #forceref $id
    HH_Q("HH_FontWinDefaultNow")
EndFunc

; 恢復預設字型與大小。
Func HH_FontWinDefaultNow()
    If $gFontWin = 0 Then Return
    $gFontPickFamily = $HH_DEFAULT_FONT
    $gFontPickSize = 14
    SelectFontCombo($gFontWin, $gFontSizeCombo, "14")
    If $gFontFilterText <> "" Then
        $gFontFilterText = ""
        _UI_SetText($gFontWin, $gFontFilter, "")
    EndIf
    HH_FontTreeFill()
    HH_FontPreview()
EndFunc

; 「確定」按鈕回呼。
Func HH_FontWinOk($id = 0)
    #forceref $id
    HH_Q("HH_FontWinOkNow")
EndFunc

; 記下要套用的字型（由主迴圈套用）並關閉視窗。
Func HH_FontWinOkNow()
    If $gFontWin = 0 Then Return
    If $gFontPreviewDue Then
        $gFontPreviewDue = False
        HH_FontPreview()
    EndIf
    If $gFontPickBad Or $gFontPickFamily = "" Then
        _UI_SetText($gFontWin, $gFontPickInfo, "此字型 AUI 無法使用，請改選其他字型")
        Return
    EndIf
    ; 真正套用移到主迴圈執行，避免在 AUI 回呼內重設大量字型而卡住。
    $gFontApplyTarget = $gFontTarget
    $gFontApplyFamily = $gFontPickFamily
    $gFontApplySize = $gFontPickSize
    HH_FontWinCancelNow()
EndFunc

; 「取消」按鈕回呼。
Func HH_FontWinCancel($id = 0)
    #forceref $id
    HH_Q("HH_FontWinCancelNow")
EndFunc

; 關閉字型選擇視窗。
Func HH_FontWinCancelNow()
    Local $h = $gFontWin
    If $h <> 0 And _UI_IsAlive($h) Then _UI_WindowClose($h)
    If $gFontWin <> 0 Then HH_FontWinClosed(0)
EndFunc

; 字型選擇視窗已關閉：重設狀態。
Func HH_FontWinClosed($id = 0)
    #forceref $id
    $gFontPreviewDue = False
    HH_ClearChildFonts($gFontWin)
    $gFontWin = 0
    $gFontTree = 0
    $gFontFilter = 0
    $gFontSizeCombo = 0
    $gFontSample = 0
    $gFontPickInfo = 0
    For $i = 1 To 3
        $gFontSampleLines[$i] = 0
    Next
EndFunc

; 主迴圈呼叫：套用字型視窗按下「確定」的結果。
Func HH_FontApplyTick()
    If $gFontApplyTarget = 0 Then Return
    If $gFontWin <> 0 Then Return
    Local $t = $gFontApplyTarget, $f = $gFontApplyFamily, $s = $gFontApplySize
    $gFontApplyTarget = 0
    If $f = "" Or $s < 5 Or $s > 40 Then Return
    If $t = 1 Then
        If $f <> $gAppFont Or $s <> $gAppSize Then
            $gAppFont = $f
            $gAppSize = $s
            _IniWrite($gIni, "Display", "AppFont", $gAppFont)
            _IniWrite($gIni, "Display", "AppSize", $gAppSize)
            ApplyAppFont()
            HH_ApplyChildFonts()
        EndIf
    ElseIf $t = 2 Then
        If $f <> $gSideFont Or $s <> $gSideSize Then
            $gSideFont = $f
            $gSideSize = $s
            _IniWrite($gIni, "Display", "SideFont", $gSideFont)
            _IniWrite($gIni, "Display", "SideSize", $gSideSize)
            HH_WebFire("if(window.setSideFont)setSideFont(" & JsString($gSideFont) & "," & $gSideSize & ");")
            HH_StyleBump()
        EndIf
    Else
        If $f <> $gContentFont Or $s <> $gContentSize Then
            $gContentFont = $f
            $gContentSize = $s
            _IniWrite($gIni, "Display", "ContentFont", $gContentFont)
            _IniWrite($gIni, "Display", "ContentSize", $gContentSize)
            HH_WebFire("if(window.setContentFont)setContentFont(" & JsString($gContentFont) & "," & $gContentSize & ");")
            HH_StyleBump()
        EndIf
    EndIf
    If $gSettingsWnd <> 0 And _UI_IsAlive($gSettingsWnd) Then
        If $gSettingFontBtn[$t] > 0 Then _UI_SetText($gSettingsWnd, $gSettingFontBtn[$t], HH_FontTargetLabel($t))
        _UI_Notify($gSettingsWnd, "已套用字型", HH_FontTargetName($t) & "：" & $f & "，" & $s & " px", $AUI_NOTIFY_SUCCESS, 2200)
    EndIf
EndFunc
