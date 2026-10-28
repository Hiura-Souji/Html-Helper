#include-once
; =============================================================================
; Html Helper － HHP 專案處理與重建
;
; 打包時讀取與改寫原 HHP（OPTIONS／WINDOWS／MAP／ALIAS、#include）；
; 解包時從 #SYSTEM、#WINDOWS、#STRINGS、#IVB 重建 HHP、
; MAP 與 ALIAS（缺少的資料只回報、不臆造）。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 保留原專案的打包輔助函式；所有寫入都只針對暫存建置工作區。
Func P134Prefix($path)
    Return StringRegExpReplace(P133Path($path), "[\\/]+$", "") & "\"
EndFunc

; 去掉前後成對的引號。
Func P134Unquote($s)
    $s = StringStripWS($s, 3)
    If StringLen($s) >= 2 Then
        If (StringLeft($s, 1) = '"' And StringRight($s, 1) = '"') Or (StringLeft($s, 1) = "'" And StringRight($s, 1) = "'") Then $s = StringMid($s, 2, StringLen($s) - 2)
    EndIf
    Return $s
EndFunc

; 若為 [區段] 行則回傳大寫區段名稱。
Func P134Section($line)
    Local $m = StringRegExp(StringStripWS($line, 3), "^\[([^]]+)\]$", 1)
    If IsArray($m) Then Return StringUpper(StringStripWS($m[0], 3))
    Return ""
EndFunc

; 讀取 HHP [OPTIONS] 中指定鍵的值。
Func P134Option($text, $key, $fallback = "")
    Local $lines = StringSplit(StringReplace($text, @CR, ""), @LF, 2), $section = ""
    For $line In $lines
        Local $new = P134Section($line)
        If $new <> "" Then $section = $new
        If $section <> "OPTIONS" Then ContinueLoop
        Local $eq = StringInStr($line, "=")
        If $eq And StringLower(StringStripWS(StringLeft($line, $eq - 1), 3)) = StringLower($key) Then Return StringStripWS(StringMid($line, $eq + 1), 3)
    Next
    Return $fallback
EndFunc

; 拆開 WINDOWS 定義的逗號欄位（處理引號與方括號）。
Func P134WindowFields($text)
    Local $out[0], $start = 1, $quote = False, $brackets = 0, $i = 1
    While $i <= StringLen($text)
        Local $ch = StringMid($text, $i, 1)
        If $ch = '"' Then
            If $quote And StringMid($text, $i + 1, 1) = '"' Then
                $i += 2
                ContinueLoop
            EndIf
            $quote = Not $quote
        ElseIf Not $quote Then
            If $ch = "[" Then $brackets += 1
            If $ch = "]" Then $brackets -= 1
            If $brackets < 0 Then Return SetError(1, 0, 0)
            If $ch = "," And $brackets = 0 Then
                Local $n = UBound($out)
                ReDim $out[$n + 1]
                $out[$n] = StringMid($text, $start, $i - $start)
                $start = $i + 1
            EndIf
        EndIf
        $i += 1
    WEnd
    If $quote Or $brackets Then Return SetError(1, 0, 0)
    $n = UBound($out)
    ReDim $out[$n + 1]
    $out[$n] = StringMid($text, $start)
    Return $out
EndFunc

; 取得預設視窗的首頁（沒有時用 Default topic）。
Func P134WindowDefault($text)
    Local $window = P134Unquote(P134Option($text, "Default Window")), $section = ""
    Local $lines = StringSplit(StringReplace($text, @CR, ""), @LF, 2)
    If $window <> "" Then
        For $line In $lines
            Local $new = P134Section($line)
            If $new <> "" Then $section = $new
            If $section <> "WINDOWS" Then ContinueLoop
            Local $eq = StringInStr($line, "=")
            If Not $eq Then ContinueLoop
            If StringLower(StringStripWS(StringLeft($line, $eq - 1), 3)) <> StringLower($window) Then ContinueLoop
            Local $f = P134WindowFields(StringMid($line, $eq + 1))
            If Not @error And IsArray($f) Then
                If UBound($f) >= 4 And P134Unquote($f[3]) <> "" Then Return P134Unquote($f[3])
            EndIf
        Next
    EndIf
    Return P134Unquote(P134Option($text, "Default topic"))
EndFunc

; 搜尋來源中的 HHP（優先根目錄）。
Func P134Candidates($root)
    Local $all = P133Files($root)
    If @error Or Not IsArray($all) Then Return SetError(1, 0, 0)
    Local $top[0], $nested[0]
    For $rel In $all
        If Not StringRegExp($rel, "(?i)\.hhp$") Then ContinueLoop
        If StringRegExp($rel, "(?i)(^|[\\/])__hh_build") Then ContinueLoop
        If StringInStr($rel, "\") Then
            Local $n = UBound($nested)
            ReDim $nested[$n + 1]
            $nested[$n] = $rel
        Else
            $n = UBound($top)
            ReDim $top[$n + 1]
            $top[$n] = $rel
        EndIf
    Next
    If UBound($top) Then Return $top
    Return $nested
EndFunc

; 決定專案根目錄與 HHP 檔名（必須位於來源資料夾內）。
Func P134Locate($input, $projectArg, ByRef $root, ByRef $hhp, ByRef $why)
    $root = P133Path($input)
    $hhp = ""
    Local $full = "", $prefix = P134Prefix($root)
    If $projectArg <> "" Then
        If StringRegExp($projectArg, "(?i)^[a-z]:|^\\\\") Then
            $full = P133Path($projectArg)
        Else
            $full = P133Path($prefix & $projectArg)
        EndIf
        If StringLeft(StringLower($full), StringLen($prefix)) <> StringLower($prefix) Then
            $why = "HHP 必須位於所選來源資料夾內。"
            Return False
        EndIf
        If Not FileExists($full) Or Not StringRegExp($full, "(?i)\.hhp$") Then
            $why = "指定 HHP 不存在：" & $full
            Return False
        EndIf
    Else
        Local $projects = P134Candidates($root)
        If @error Or Not IsArray($projects) Then
            $why = "不能完整搜尋 HHP 專案。"
            Return False
        EndIf
        If UBound($projects) > 1 Then
            $why = "找到多個 HHP，請用 GUI 選擇，或以 --project 指定。"
            Return False
        EndIf
        If UBound($projects) = 0 Then Return True
        $full = P133Path($prefix & $projects[0])
    EndIf
    $hhp = StringRegExpReplace($full, "^.*[\\/]", "")
    $root = StringTrimRight($full, StringLen($hhp))
    While StringLen($root) > 3 And StringRight($root, 1) = "\"
        $root = StringTrimRight($root, 1)
    WEnd
    Return True
EndFunc

; 讀取 #include 行的檔名。
Func P134IncludeName($line)
    Local $m = StringRegExp($line, '(?i)^\s*#include\s+(?:"([^"]+)"|<([^>]+)>|([^;\r\n]+))', 1)
    If Not IsArray($m) Then Return ""
    For $v In $m
        If StringStripWS($v, 3) <> "" Then Return StringStripWS($v, 3)
    Next
    Return ""
EndFunc

; 把 #include 解析成專案內的相對路徑（不允許超出專案根目錄）。
Func P134IncludeRel($root, $baseFile, $name, ByRef $why)
    If $name = "" Or StringRegExp($name, "^[\\/]|:") Then
        $why = "不支援絕對路徑 include：" & $name
        Return SetError(1, 0, "")
    EndIf
    Local $base = StringRegExpReplace($baseFile, "[^\\]+$", ""), $prefix = P134Prefix($root)
    Local $full = P133Path($prefix & $base & StringReplace($name, "/", "\"))
    If StringLeft(StringLower($full), StringLen($prefix)) <> StringLower($prefix) Then
        $why = "include 超出 HHP 根目錄：" & $name
        Return SetError(1, 0, "")
    EndIf
    If Not FileExists($full) Or StringInStr(FileGetAttrib($full), "D") Then
        $why = "找不到專案 include：" & $full
        Return SetError(1, 0, "")
    EndIf
    Return StringTrimLeft($full, StringLen($prefix))
EndFunc

; 遞迴收集 MAP／ALIAS 引用的 include 檔案。
Func P134Includes($root, $project, ByRef $why)
    Local $result = ObjCreate("Scripting.Dictionary"), $queue[0][2], $head = 0, $section = ""
    $result.CompareMode = 1
    Local $lines = StringSplit(StringReplace($project, @CR, ""), @LF, 2)
    For $line In $lines
        Local $new = P134Section($line)
        If $new <> "" Then $section = $new
        If $section <> "MAP" And $section <> "ALIAS" Then ContinueLoop
        Local $name = P134IncludeName($line)
        If $name = "" Then ContinueLoop
        Local $rel = P134IncludeRel($root, "", $name, $why)
        If @error Then Return SetError(1, 0, 0)
        Local $n = UBound($queue)
        ReDim $queue[$n + 1][2]
        $queue[$n][0] = $rel
        $queue[$n][1] = $section
    Next
    While $head < UBound($queue)
        If $head > 1024 Then
            $why = "專案 include 數量超過安全上限。"
            Return SetError(1, 0, 0)
        EndIf
        $rel = $queue[$head][0]
        Local $kind = $queue[$head][1]
        $head += 1
        If $result.Exists($rel) Then
            If $result.Item($rel) = "ALIAS" Or $kind <> "ALIAS" Then ContinueLoop
            $result.Item($rel) = "ALIAS"
        Else
            $result.Add($rel, $kind)
        EndIf
        Local $text = P133ReadText(P134Prefix($root) & $rel)
        If @error Then
            $why = "不能讀取專案 include：" & $rel
            Return SetError(1, 0, 0)
        EndIf
        Local $childLines = StringSplit(StringReplace($text, @CR, ""), @LF, 2)
        For $childLine In $childLines
            $name = P134IncludeName($childLine)
            If $name = "" Then ContinueLoop
            Local $child = P134IncludeRel($root, $rel, $name, $why)
            If @error Then Return SetError(1, 0, 0)
            $n = UBound($queue)
            ReDim $queue[$n + 1][2]
            $queue[$n][0] = $child
            $queue[$n][1] = $kind
        Next
    WEnd
    Return $result
EndFunc

; 把 ALIAS 行的主題路徑改成實際檔名（外部 CHM 參照保留原樣）。
Func P134AliasLine($line, $baseFile, $oldArchive, $work, $names, $aliases, ByRef $why)
    Local $trim = StringStripWS($line, 3)
    If $trim = "" Or StringLeft($trim, 1) = ";" Or StringLeft($trim, 1) = "#" Or StringLeft($trim, 2) = "//" Then Return $line
    Local $eq = StringInStr($line, "=")
    If Not $eq Then Return $line
    Local $symbol = StringStripWS(StringLeft($line, $eq - 1), 3)
    If Not StringRegExp($symbol, "^(?:[A-Za-z_][A-Za-z_0-9]*|[0-9]+)$") Then Return $line
    Local $rhs = P134Unquote(StringMid($line, $eq + 1))
    If StringRegExp($rhs, "(?i)^(https?|ftp):") Then Return $line
    Local $clean = StringRegExpReplace($rhs, "(?i)^(?:mk:@MSITStore:|ms-its:|its:)", "")
    Local $sep = StringInStr($clean, "::")
    If $sep Then
        Local $archive = StringRegExpReplace(StringLeft($clean, $sep - 1), "^.*[\\/]", "")
        Local $self = StringRegExpReplace($oldArchive, "^.*[\\/]", "")
        If $self = "" Or StringLower($archive) <> StringLower($self) Then Return $line
        $rhs = StringMid($clean, $sep + 2)
    ElseIf StringRegExp($rhs, "(?i)^[a-z][a-z0-9+.-]*:") Then
        Return $line
    EndIf
    Local $target = P133Resolve($rhs, $baseFile, $work, $names, $aliases), $e = @error, $external = @extended
    If $e Or $external Then
        $why = "ALIAS 找不到內部主題：" & $symbol & " -> " & $rhs
        Return SetError(1, 0, "")
    EndIf
    Return StringLeft($line, $eq) & $target
EndFunc

; 改寫整份 ALIAS 檔。
Func P134AliasText($text, $baseFile, $oldArchive, $work, $names, $aliases, ByRef $why)
    Local $lines = StringSplit(StringReplace($text, @CR, ""), @LF, 2), $out = ""
    For $line In $lines
        Local $new = P134AliasLine($line, $baseFile, $oldArchive, $work, $names, $aliases, $why)
        If @error Then Return SetError(1, 0, "")
        $out &= $new & @CRLF
    Next
    Return $out
EndFunc

; 把 include 檔複製到建置工作區（ALIAS 會改寫路徑）。
Func P134CopyIncludes($root, $work, $support, $oldArchive, $names, $aliases, ByRef $why)
    Local $keys = $support.Keys()
    For $rel In $keys
        If StringLen(P134Prefix($work) & $rel) > 245 Then
            $why = "include 工作路徑過長：" & $rel
            Return False
        EndIf
        Local $text = P133ReadText(P134Prefix($root) & $rel)
        If @error Then
            $why = "include 讀取失敗：" & $rel
            Return False
        EndIf
        If $support.Item($rel) = "ALIAS" Then
            $text = P134AliasText($text, $rel, $oldArchive, $work, $names, $aliases, $why)
            If @error Then Return False
        EndIf
        If Not P133WriteText(P134Prefix($work) & $rel, $text, True) Then
            $why = "include 不能以系統 ANSI 字碼頁寫入：" & $rel
            Return False
        EndIf
        P133Report(0, "保留 " & $support.Item($rel) & " include：" & $rel)
    Next
    Return True
EndFunc

; 以雙引號包住字串（內部引號加倍）。
Func P134Quote($s)
    Return '"' & StringReplace($s, '"', '""') & '"'
EndFunc

; 產生建置用 HHP：保留原設定，只更新輸出、首頁、目錄、索引與 [FILES]。
Func P134ProjectText($original, $home, $toc, $index, ByRef $plan, $count, $oldArchive, $work, $names, $aliases, ByRef $why)
    Local $text = $original
    If $text = "" Then
        $text = "[OPTIONS]" & @CRLF & "Compatibility=1.1 or later" & @CRLF & "Title=Html Helper" & @CRLF & "Language=0x404" & @CRLF & "Full-text search=Yes" & @CRLF
        P133Report(0, "警告：來源沒有 HHP，此次為簡化重建，無法宣稱恢復原 WINDOWS／MAP／ALIAS。")
    EndIf
    Local $defaultWindow = P134Unquote(P134Option($text, "Default Window")), $foundWindow = False, $foundOptions = False
    Local $lines = StringSplit(StringReplace($text, @CR, ""), @LF, 2), $section = "", $out = ""
    For $line In $lines
        Local $newSection = P134Section($line)
        If $newSection <> "" Then $section = $newSection
        If $section = "FILES" Then ContinueLoop
        If $section = "OPTIONS" Then
            If $newSection = "OPTIONS" Then
                $foundOptions = True
                $out &= $line & @CRLF & "Compiled file=__hh_build_output.chm" & @CRLF & "Error log file=__hh_build_compiler.log" & @CRLF & "Display compile progress=No" & @CRLF & "Default topic=" & $home & @CRLF
                If $toc <> "" Then $out &= "Contents file=" & $toc & @CRLF
                If $index <> "" Then $out &= "Index file=" & $index & @CRLF
                ContinueLoop
            EndIf
            If StringRegExp(StringStripWS($line, 3), "(?i)^(Compiled file|Error log file|Display compile progress|Default topic|Contents file|Index file)\s*=") Then ContinueLoop
        ElseIf $section = "WINDOWS" And $newSection = "" Then
            Local $eq = StringInStr($line, "=")
            If $eq And StringLower(StringStripWS(StringLeft($line, $eq - 1), 3)) = StringLower($defaultWindow) And $defaultWindow <> "" Then
                Local $f = P134WindowFields(StringMid($line, $eq + 1))
                If @error Or Not IsArray($f) Then
                    $why = "預設 WINDOWS 定義格式錯誤：" & $defaultWindow
                    Return SetError(1, 0, "")
                EndIf
                If UBound($f) < 4 Then
                    $why = "預設 WINDOWS 欄位不足：" & $defaultWindow
                    Return SetError(1, 0, "")
                EndIf
                Local $oldDefault = P134Unquote($f[3])
                For $j = 1 To 2
                    Local $oldPath = P134Unquote($f[$j])
                    If $oldPath <> "" Then
                        Local $resolved = P133Resolve($oldPath, "", $work, $names, $aliases), $e = @error, $external = @extended
                        If $e Or $external Then
                            $why = "WINDOWS 找不到目錄／索引：" & $oldPath
                            Return SetError(1, 0, "")
                        EndIf
                        $f[$j] = P134Quote($resolved)
                    EndIf
                Next
                $f[3] = P134Quote($home)
                ; 「首頁」按鈕若原本指向不同網址，不可被啟動頁覆蓋。
                If UBound($f) > 4 Then
                    Local $oldHome = P134Unquote($f[4])
                    If $oldHome <> "" And StringLower(StringReplace($oldHome, "/", "\")) = StringLower(StringReplace($oldDefault, "/", "\")) Then $f[4] = P134Quote($home)
                EndIf
                $line = StringLeft($line, $eq) & _ArrayToString($f, ",")
                $foundWindow = True
            EndIf
        ElseIf $section = "ALIAS" And $newSection = "" Then
            $line = P134AliasLine($line, "", $oldArchive, $work, $names, $aliases, $why)
            If @error Then Return SetError(1, 0, "")
        EndIf
        $out &= $line & @CRLF
    Next
    If Not $foundOptions Then
        $why = "HHP 缺少 [OPTIONS]。"
        Return SetError(1, 0, "")
    EndIf
    If $defaultWindow <> "" And Not $foundWindow Then
        $why = "Default Window 指定的視窗不存在：" & $defaultWindow
        Return SetError(1, 0, "")
    EndIf
    $out &= @CRLF & "[FILES]" & @CRLF
    For $i = 0 To $count - 1
        $out &= $plan[$i][1] & @CRLF
    Next
    P133Report(0, "專案標題=" & P134Option($text, "Title") & @CRLF & "Default Window=" & $defaultWindow & @CRLF & "保留原 OPTIONS／WINDOWS／MAP／ALIAS；只更新輸出與必要資源路徑。")
    Return $out
EndFunc

; 依 CHM 中繼資料格式重建專案（讀取量有上限）。
Func P135U32(ByRef $b, $offset)
    If $offset < 0 Or $offset + 4 > BinaryLen($b) Then Return SetError(1, 0, 0)
    Local $raw = DllStructCreate("byte[4]")
    DllStructSetData($raw, 1, BinaryMid($b, $offset + 1, 4))
    Local $num = DllStructCreate("dword", DllStructGetPtr($raw))
    Return SetError(0, 0, DllStructGetData($num, 1))
EndFunc

; 讀取位元組中的有號 32 位元整數。
Func P135I32(ByRef $b, $offset)
    Local $v = P135U32($b, $offset), $e = @error
    If $v >= 2147483648 Then $v -= 4294967296
    Return SetError($e, 0, $v)
EndFunc

; LCID 對應的 ANSI 字碼頁。
Func P135Codepage($lcid)
    Local $r = DllCall("kernel32.dll", "int", "GetLocaleInfoW", "dword", $lcid, "dword", 0x1004, "wstr", "", "int", 16)
    If @error Or Not IsArray($r) Then Return 0
    If $r[0] < 1 Then Return 0
    Return Number($r[3])
EndFunc

; 解碼以 NUL 結尾的字串（UTF-8 有效時用 UTF-8，否則用指定字碼頁）。
Func P135DecodeNT($b, $cp)
    Local $n = BinaryLen($b)
    For $i = 1 To $n
        If BinaryMid($b, $i, 1) = Binary("0x00") Then
            $b = BinaryMid($b, 1, $i - 1)
            ExitLoop
        EndIf
    Next
    Local $u = BinaryToString($b, 4)
    If StringToBinary($u, 4) = $b Then Return $u
    Return _DecodeCodepage($b, $cp)
EndFunc

; 讀取 #SYSTEM 指定欄位的文字。
Func P135SysText($fields, $tag, $cp)
    If Not $fields.Exists(String($tag)) Then Return ""
    Return P135DecodeNT($fields.Item(String($tag)), $cp)
EndFunc

; 讀取 #STRINGS 指定偏移的字串。
Func P135String(ByRef $buffer, $size, $offset, $cp, ByRef $why)
    If $offset = 0 Or $offset = 4294967295 Then Return ""
    If $offset < 0 Or $offset >= $size Then
        $why = "#STRINGS 偏移越界：" & $offset
        Return SetError(1, 0, "")
    EndIf
    Local $limit = $size - $offset
    If $limit > 1048576 Then $limit = 1048576
    Local $start = DllStructGetPtr($buffer) + $offset
    Local $r = DllCall("msvcrt.dll", "ptr:cdecl", "memchr", "ptr", $start, "int", 0, "ulong_ptr", $limit)
    If @error Or Not IsArray($r) Then
        $why = "不能搜尋 #STRINGS 結尾。"
        Return SetError(1, 0, "")
    EndIf
    If Not $r[0] Then
        $why = "#STRINGS 字串缺少 NUL 結尾。"
        Return SetError(1, 0, "")
    EndIf
    Local $length = Number($r[0]) - Number($start)
    If $length <= 0 Then Return ""
    Local $v = DllStructCreate("byte[" & $length & "]", $start)
    Return P135DecodeNT(DllStructGetData($v, 1), $cp)
EndFunc

; 把換行改成空白，讓值可放進 HHP 單行。
Func P135IniValue($s)
    Return StringReplace(StringReplace($s, @CR, " "), @LF, " ")
EndFunc

; 取得不與現有檔案衝突的檔名（加 _n）。
Func P135Available($root, $preferred)
    If Not FileExists($root & "\" & $preferred) Then Return $preferred
    Local $dot = StringInStr($preferred, ".", 0, -1), $stem = $preferred, $ext = ""
    If $dot Then
        $stem = StringLeft($preferred, $dot - 1)
        $ext = StringMid($preferred, $dot)
    EndIf
    For $i = 1 To 1000
        Local $name = $stem & "_" & $i & $ext
        If Not FileExists($root & "\" & $name) Then Return $name
    Next
    Return SetError(1, 0, "")
EndFunc

; 把中繼資料中的路徑對應到匯出後的實際檔名。
Func P135MetaPath($path, $lookup, ByRef $why, $selfNames = "")
    $path = P135IniValue(StringStripWS($path, 3))
    If $path = "" Then Return ""
    If StringRegExp($path, "(?i)^(https?|mailto|ftp):") Then Return $path
    Local $compound = StringRegExpReplace($path, "(?i)^(?:mk:@MSITStore:|ms-its:|its:)", "")
    Local $sep = StringInStr($compound, "::")
    If $sep Then
        Local $archive = StringLower(StringRegExpReplace(StringLeft($compound, $sep - 1), "^.*[\\/]", ""))
        If Not StringInStr($selfNames, "|" & $archive & "|", 1) Then Return $path
        $path = StringMid($compound, $sep + 2)
    EndIf
    Local $suffix = "", $m = StringRegExp($path, "[#?].*$", 1)
    If IsArray($m) Then $suffix = $m[0]
    Local $plain = StringRegExpReplace($path, "[#?].*$", ""), $forms[2] = [$plain, UrlDecode($plain)]
    For $form In $forms
        $form = StringReplace($form, "\", "/")
        While StringLeft($form, 1) = "/"
            $form = StringTrimLeft($form, 1)
        WEnd
        If $lookup.Exists($form) Then
            If $lookup.Item($form) = "" Then
                $why = "中繼資料路徑有大小寫歧義：" & $path
                Return SetError(1, 0, "")
            EndIf
            Return StringReplace($lookup.Item($form), "/", "\") & $suffix
        EndIf
    Next
    ; 對應不到的原始參照原樣保留，不臆造檔案或 ID。
    $why = "未能對應中繼資料路徑：" & $path
    Return SetError(1, 0, $path)
EndFunc

; 從 #WINDOWS 與 #STRINGS 重建 [WINDOWS] 定義。
Func P135Windows($b, ByRef $stringBuffer, $stringSize, $cp, $lookup, $selfNames, ByRef $defined, ByRef $why)
    $defined = ObjCreate("Scripting.Dictionary")
    $defined.CompareMode = 1
    If BinaryLen($b) < 8 Then
        $why = "#WINDOWS 標頭不足。"
        Return SetError(1, 0, "")
    EndIf
    Local $count = P135U32($b, 0), $stride = P135U32($b, 4)
    If $count > 128 Or $stride < 188 Or $stride > 4096 Or $count * $stride > BinaryLen($b) - 8 Then
        $why = "#WINDOWS 項目數／大小不受支援或越界。"
        Return SetError(1, 0, "")
    EndIf
    Local $out = "", $offsets[9] = [0x14, 0x60, 0x64, 0x68, 0x6C, 0xA4, 0x9C, 0xA8, 0xA0]
    For $i = 0 To $count - 1
        Local $base = 8 + $i * $stride, $entrySize = P135U32($b, $base), $unicode = P135U32($b, $base + 4)
        If $entrySize < 188 Or $entrySize > $stride Or $unicode <> 0 Then
            $why = "#WINDOWS 第 " & $i & " 筆版本／Unicode 配置不受支援。"
            Return SetError(1, 0, "")
        EndIf
        Local $name = P135String($stringBuffer, $stringSize, P135U32($b, $base + 8), $cp, $why)
        If @error Or $name = "" Or StringRegExp($name, '[=\[\]\r\n,;"]') Then
            $why = "#WINDOWS 視窗名稱無效：" & $name
            Return SetError(1, 0, "")
        EndIf
        If $defined.Exists($name) Then
            $why = "#WINDOWS 視窗名稱重複：" & $name
            Return SetError(1, 0, "")
        EndIf
        $defined.Add($name, True)
        Local $f[20]
        For $j = 0 To 19
            $f[$j] = ""
        Next
        For $j = 0 To 8
            Local $value = P135String($stringBuffer, $stringSize, P135U32($b, $base + $offsets[$j]), $cp, $why)
            If @error Then Return SetError(1, 0, "")
            If $j = 1 Or $j = 2 Or $j = 3 Or $j = 4 Or $j = 5 Or $j = 7 Then
                If $value <> "" Then
                    $value = P135MetaPath($value, $lookup, $why, $selfNames)
                    If @error Then Return SetError(1, 0, "")
                EndIf
            EndIf
            If $value <> "" Then $f[$j] = P134Quote(P135IniValue($value))
        Next
        Local $valid = P135U32($b, $base + 0x0C)
        If BitAND($valid, 0x2) Then $f[9] = "0x" & Hex(P135U32($b, $base + 0x10))
        If BitAND($valid, 0x20) Then $f[10] = P135U32($b, $base + 0x4C)
        If BitAND($valid, 0x100) Then $f[11] = "0x" & Hex(P135U32($b, $base + 0x70))
        If BitAND($valid, 0x10) Then $f[12] = "[" & P135I32($b, $base + 0x20) & "," & P135I32($b, $base + 0x24) & "," & P135I32($b, $base + 0x28) & "," & P135I32($b, $base + 0x2C) & "]"
        If BitAND($valid, 0x4) Then $f[13] = "0x" & Hex(P135U32($b, $base + 0x18))
        If BitAND($valid, 0x8) Then $f[14] = "0x" & Hex(P135U32($b, $base + 0x1C))
        If BitAND($valid, 0x40) Then $f[15] = P135U32($b, $base + 0x30)
        If BitAND($valid, 0x200) Then $f[16] = P135U32($b, $base + 0x74)
        If BitAND($valid, 0x2000) Then $f[17] = P135U32($b, $base + 0x78)
        If BitAND($valid, 0x400) Then $f[18] = P135U32($b, $base + 0x7C)
        $f[19] = P135U32($b, $base + 0x80)
        Local $line = $name & "=" & _ArrayToString($f, ",")
        If StringLen($line) > 1023 Then
            $why = "WINDOWS 定義超過 HHP 單行安全長度：" & $name
            Return SetError(1, 0, "")
        EndIf
        $out &= $line & @CRLF
    Next
    Return $out
EndFunc

; 從 #IVB 重建說明 ID（MAP 與 ALIAS）。
Func P135Context($b, ByRef $stringBuffer, $stringSize, $cp, $lookup, $selfNames, ByRef $aliasText, ByRef $mapText, ByRef $why)
    $aliasText = ""
    $mapText = ""
    If BinaryLen($b) < 4 Then
        $why = "#IVB 標頭不足。"
        Return SetError(1, 0, 0)
    EndIf
    Local $bytes = P135U32($b, 0)
    If Mod($bytes, 8) <> 0 Or $bytes <> BinaryLen($b) - 4 Or $bytes / 8 > 100000 Then
        $why = "#IVB 記錄長度不符。"
        Return SetError(1, 0, 0)
    EndIf
    Local $seen = ObjCreate("Scripting.Dictionary"), $count = 0
    For $offset = 4 To $bytes Step 8
        Local $id = P135U32($b, $offset), $nameOffset = P135U32($b, $offset + 4)
        Local $topic = P135String($stringBuffer, $stringSize, $nameOffset, $cp, $why)
        If @error Or $topic = "" Then
            $why = "#IVB 主題字串無效，ID=" & $id
            Return SetError(1, 0, 0)
        EndIf
        $topic = P135MetaPath($topic, $lookup, $why, $selfNames)
        If @error Then Return SetError(1, 0, 0)
        Local $key = String($id)
        If $seen.Exists($key) Then
            If $seen.Item($key) <> $topic Then
                $why = "#IVB 同一 ID 指向不同頁面：" & $id
                Return SetError(1, 0, 0)
            EndIf
            ContinueLoop
        EndIf
        $seen.Add($key, $topic)
        $mapText &= "#define IDH_" & $key & " " & $key & @CRLF
        $aliasText &= "IDH_" & $key & "=" & $topic & @CRLF
        $count += 1
        P133Progress("重建說明 ID", $offset + 8 - 4, $bytes, $topic)
    Next
    Return $count
EndFunc

; 寫入重建的檔案（優先 ANSI，無法表示時改 UTF-8 並記錄警告）。
Func P135WriteRecovered($path, $text, ByRef $notes)
    If P133WriteText($path, $text, True) Then Return True
    If P133WriteText($path, $text, False) Then
        $notes &= "警告：" & $path & " 無法以本機 ANSI 寫入，改用 UTF-8 中介格式；打包時仍需相容字碼頁。" & @CRLF
        Return True
    EndIf
    Return False
EndFunc

; 解包時重建 HHP、MAP、ALIAS 與還原報告（已有 HHP 時不覆寫）。
Func P135GenerateProject($doc, $input, $root, ByRef $rows, $mapping, ByRef $why)
    P133Progress("重建 HHP 專案", 0, 0, $input, True)
    Local $files = P133Files($root)
    If @error Or Not IsArray($files) Then
        $why = "無法列舉匯出檔案來生成 HHP。"
        Return False
    EndIf
    For $rel In $files
        If Not StringInStr($rel, "\") And StringRegExp($rel, "(?i)\.hhp$") Then
            P133Report(0, "CHM 已帶有 HHP，保留原檔，不覆寫：" & $rel)
            Return True
        EndIf
    Next
    Local $notes = "Html Helper HHP 重建報告" & @CRLF & "來源：" & $input & @CRLF
    Local $detail = "", $system = P133ReadAny($doc, "#SYSTEM", $detail, 16777216), $readError = @error
    Local $fields = ObjCreate("Scripting.Dictionary"), $parseDetail = ""
    If $readError Or Not P133System($system, $fields, $parseDetail) Then
        $notes &= "警告：#SYSTEM 不能完整還原，生成基本專案。" & @CRLF & $detail & " " & $parseDetail & @CRLF
        $fields = ObjCreate("Scripting.Dictionary")
    Else
        $notes &= $detail & @CRLF & $parseDetail & @CRLF
    EndIf
    Local $lcid = 0, $cp = 0, $fullText = True
    If $fields.Exists("4") Then
        Local $v4 = $fields.Item("4")
        If BinaryLen($v4) >= 4 Then $lcid = P135U32($v4, 0)
        If BinaryLen($v4) >= 12 Then $fullText = (P135U32($v4, 8) <> 0)
    EndIf
    If $lcid Then $cp = P135Codepage($lcid)
    Local $lookup = ObjCreate("Scripting.Dictionary"), $keys = $mapping.Keys()
    $lookup.CompareMode = 1
    For $key In $keys
        If $lookup.Exists($key) Then
            If $lookup.Item($key) <> $mapping.Item($key) Then $lookup.Item($key) = ""
        Else
            $lookup.Add($key, $mapping.Item($key))
        EndIf
    Next
    Local $title = P135IniValue(P135SysText($fields, 3, $cp)), $toc = P135SysText($fields, 0, $cp), $index = P135SysText($fields, 1, $cp), $home = P135SysText($fields, 2, $cp)
    Local $defaultWindow = P135IniValue(P135SysText($fields, 5, $cp)), $font = P135IniValue(P135SysText($fields, 16, $cp))
    Local $stem = StringRegExpReplace($input, "^.*[\\/]", "")
    $stem = StringRegExpReplace($stem, "(?i)\.chm$", "")
    If $stem = "" Then $stem = "Help"
    If $title = "" Then $title = $stem
    Local $archiveBase = StringLower(StringRegExpReplace($input, "^.*[\\/]", ""))
    Local $compiledStem = StringLower(P135SysText($fields, 6, $cp))
    If $compiledStem <> "" And Not StringRegExp($compiledStem, "(?i)\.chm$") Then $compiledStem &= ".chm"
    Local $selfNames = "|" & $archiveBase & "|" & $compiledStem & "|"
    Local $projectFile = P135Available($root, P133Encode($stem) & ".hhp")
    If @error Or $projectFile = "" Then
        $why = "無法選擇 HHP 檔名。"
        Return False
    EndIf
    Local $refs[3] = [$toc, $index, $home]
    For $j = 0 To 2
        If $refs[$j] = "" Then ContinueLoop
        Local $resolved = P135MetaPath($refs[$j], $lookup, $why, $selfNames)
        If @error Then $notes &= "警告：" & $why & @CRLF
        $refs[$j] = $resolved
    Next
    $toc = $refs[0]
    $index = $refs[1]
    $home = $refs[2]
    If $home = "" Or $toc = "" Or $index = "" Then
        For $i = 0 To UBound($rows) - 1
            If $rows[$i][1] <> 2 Then ContinueLoop
            Local $name = $rows[$i][0], $out = $mapping.Item($name)
            If $toc = "" And StringRegExp($name, "(?i)\.hhc$") Then $toc = $out
            If $index = "" And StringRegExp($name, "(?i)\.hhk$") Then $index = $out
            If $home = "" And StringRegExp($name, "(?i)(^|/)(index|default|home|introduction|intro|welcome)\.html?$") Then $home = $out
        Next
    EndIf
    Local $strDetail = "", $strings = P133ReadAny($doc, "#STRINGS", $strDetail), $strError = @error, $stringSize = BinaryLen($strings)
    Local $stringBuffer = DllStructCreate("byte[" & ($stringSize > 0 ? $stringSize : 1) & "]")
    If $stringSize Then DllStructSetData($stringBuffer, 1, $strings)
    Local $windows = "", $defined = ObjCreate("Scripting.Dictionary"), $wd = "", $winDetail = ""
    Local $wb = P133ReadAny($doc, "#WINDOWS", $winDetail), $winError = @error
    If Not $winError And BinaryLen($wb) > 0 And Not $strError And $stringSize > 0 Then
        $windows = P135Windows($wb, $stringBuffer, $stringSize, $cp, $lookup, $selfNames, $defined, $wd)
        If @error Then
            $windows = ""
            $notes &= "警告：視窗定義未完整還原：" & $wd & @CRLF
        Else
            $notes &= "還原 WINDOWS=" & $defined.Count & @CRLF
        EndIf
    Else
        $notes &= "警告：無可用 #WINDOWS／#STRINGS，未猜造原視窗定義。" & @CRLF
    EndIf
    If $windows <> "" Then
        If $defaultWindow = "" Or Not $defined.Exists($defaultWindow) Then
            Local $windowNames = $defined.Keys()
            If UBound($windowNames) Then $defaultWindow = $windowNames[0]
            $notes &= "Default Window 由已還原視窗選定：" & $defaultWindow & @CRLF
        EndIf
    Else
        $defaultWindow = ""
    EndIf
    Local $aliasText = "", $mapText = "", $contextDetail = "", $contextWhy = "", $contexts = 0
    Local $ivb = P133ReadAny($doc, "#IVB", $contextDetail), $ivbError = @error
    If Not $ivbError And BinaryLen($ivb) > 0 And Not $strError And $stringSize > 0 Then
        $contexts = P135Context($ivb, $stringBuffer, $stringSize, $cp, $lookup, $selfNames, $aliasText, $mapText, $contextWhy)
        If @error Then
            $contexts = 0
            $aliasText = ""
            $mapText = ""
            $notes &= "警告：MAP／ALIAS 未能完整還原：" & $contextWhy & @CRLF
        Else
            $notes &= "還原 context ID=" & $contexts & "；符號名稱生成為 IDH_數值，原符號拼字未存於 CHM。" & @CRLF
        EndIf
    Else
        $notes &= "未取得可還原的 #IVB context ID，MAP／ALIAS 只產生空白模板，未捏造 ID。" & @CRLF
    EndIf
    If $aliasText = "" Then $aliasText = "; No recoverable context records. See project report." & @CRLF
    If $mapText = "" Then $mapText = "// No recoverable context records. See project report." & @CRLF
    Local $aliasFile = P135Available($root, "alias.ali")
    If @error Then Return False
    Local $mapFile = P135Available($root, "map.h")
    If @error Then Return False
    Local $project = "; Reconstructed by Html Helper; existing archive files were not overwritten." & @CRLF & "[OPTIONS]" & @CRLF & "Compatibility=1.1 or later" & @CRLF & "Compiled file=" & P133Encode($stem) & ".chm" & @CRLF & "Title=" & $title & @CRLF
    If $font <> "" Then $project &= "Default Font=" & $font & @CRLF
    If $lcid Then $project &= "Language=0x" & Hex($lcid) & @CRLF
    $project &= "Full-text search=" & ($fullText ? "Yes" : "No") & @CRLF
    $project &= "Binary Index=" & ($fields.Exists("7") ? "Yes" : "No") & @CRLF
    $project &= "Binary TOC=" & ($fields.Exists("11") ? "Yes" : "No") & @CRLF
    If $defaultWindow <> "" Then $project &= "Default Window=" & $defaultWindow & @CRLF
    If $home <> "" Then $project &= "Default topic=" & $home & @CRLF
    If $toc <> "" Then $project &= "Contents file=" & $toc & @CRLF
    If $index <> "" Then $project &= "Index file=" & $index & @CRLF
    If $windows <> "" Then $project &= @CRLF & "[WINDOWS]" & @CRLF & $windows
    $project &= @CRLF & "[FILES]" & @CRLF
    For $i = 0 To UBound($rows) - 1
        If $rows[$i][1] <> 2 Then ContinueLoop
        If Not P133Resource($rows[$i][0]) Then ContinueLoop
        $project &= $mapping.Item($rows[$i][0]) & @CRLF
        P133Progress("生成 HHP 檔案清單", $i + 1, UBound($rows), $rows[$i][0])
    Next
    $project &= @CRLF & "[INFOTYPES]" & @CRLF & @CRLF & "[MAP]" & @CRLF & "#include " & $mapFile & @CRLF & @CRLF & "[ALIAS]" & @CRLF & "#include " & $aliasFile & @CRLF
    If Not P135WriteRecovered($root & "\" & $aliasFile, $aliasText, $notes) Or Not P135WriteRecovered($root & "\" & $mapFile, $mapText, $notes) Or Not P135WriteRecovered($root & "\" & $projectFile, $project, $notes) Then
        $why = "重建 HHP／MAP／ALIAS 寫入失敗。"
        Return False
    EndIf
    $notes &= "HHP=" & $projectFile & @CRLF & "MAP=" & $mapFile & @CRLF & "ALIAS=" & $aliasFile & @CRLF
    $notes &= "原始 HHP 註解、完整未知選項、外部合併 CHM 及無中繼資料的特殊功能不在等價還原保證內。" & @CRLF
    $notes &= "安全轉碼檔名仍由匯出對照表追蹤；打包時需保留該對照表。" & @CRLF
    Local $reportFile = P135Available($root, "__htmlhelper_project_report.txt")
    If $reportFile = "" Or Not P133WriteText($root & "\" & $reportFile, $notes, False) Then
        $why = "不能寫入專案還原報告。"
        Return False
    EndIf
    P133Report(0, "已生成 HHP：" & $projectFile & @CRLF & "WINDOWS=" & ($windows <> "" ? $defined.Count : 0) & "，Context ID=" & $contexts & @CRLF & "請參閱：" & $reportFile)
    Return True
EndFunc
