#include-once
; =============================================================================
; Html Helper － CHM 解包與打包核心
;
; 命令列模式（--extract-chm、--build-chm）：
; ITSS 完整匯出 CHM（保留原始檔名對照），以 hhc.exe 重新編譯並逐檔驗證內容、
; 目錄與索引。進度透過共享記憶體回報給 GUI。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 路徑正規化（完整路徑、去掉結尾反斜線）。
Func P133Path($p)
    $p = _PathFull($p)
    While StringLen($p) > 3 And StringRight($p, 1) = "\"
        $p = StringTrimRight($p, 1)
    WEnd
    Return $p
EndFunc

; 輸出訊息到主控台與工作紀錄，並回傳結束代碼。
Func P133Report($code, $text, $work = "")
    If $work <> "" Then $text &= @CRLF & "工作目錄：" & $work
    ConsoleWrite($text & @CRLF)
    If $g133Log <> -1 Then FileWriteLine($g133Log, "[" & $code & "] " & $text)
    Return $code
EndFunc

; 在指定位置旁建立唯一的工作資料夾。
Func P133Work($base)
    For $i = 1 To 100
        Local $p = $base & "_work_" & @AutoItPID & "_" & $i
        If Not FileExists($p) Then
            If DirCreate($p) Then Return $p
        EndIf
    Next
    Return ""
EndFunc

; 資料夾是否不存在或為空。
Func P133Empty($p)
    If Not FileExists($p) Then Return True
    If Not StringInStr(FileGetAttrib($p), "D") Then Return False
    Local $h = FileFindFirstFile($p & "\*")
    If $h = -1 Then Return True
    FileClose($h)
    Return False
EndFunc

; 依 BOM 與 UTF-8 有效性把位元組轉成文字（否則用系統 ANSI）。
Func P133BytesText($b)
    If BinaryMid($b, 1, 3) = Binary("0xEFBBBF") Then Return BinaryToString(BinaryMid($b, 4), 4)
    If BinaryMid($b, 1, 2) = Binary("0xFFFE") Then Return BinaryToString(BinaryMid($b, 3), 2)
    If BinaryMid($b, 1, 2) = Binary("0xFEFF") Then Return BinaryToString(BinaryMid($b, 3), 3)
    If BinaryLen($b) >= 4 Then
        If BinaryMid($b, 2, 1) = Binary("0x00") And BinaryMid($b, 4, 1) = Binary("0x00") Then Return BinaryToString($b, 2)
        If BinaryMid($b, 1, 1) = Binary("0x00") And BinaryMid($b, 3, 1) = Binary("0x00") Then Return BinaryToString($b, 3)
    EndIf
    Local $u = BinaryToString($b, 4)
    If StringToBinary($u, 4) = $b Then Return $u
    Return _DecodeCodepage($b, 0)
EndFunc

; 讀取文字檔（自動判斷編碼）。
Func P133ReadText($file)
    Local $h = FileOpen($file, 16)
    If $h = -1 Then Return SetError(1, 0, "")
    Local $b = FileRead($h), $e = @error
    FileClose($h)
    If $e And $e <> -1 Then Return SetError(1, 0, "")
    Return P133BytesText($b)
EndFunc

; 寫入文字檔（ANSI 或 UTF-8）；ANSI 無法表示時回傳 False。
Func P133WriteText($file, $text, $ansi = False)
    If $ansi And BinaryToString(StringToBinary($text, 1), 1) <> $text Then Return False
    Local $h = FileOpen($file, 10 + ($ansi ? 512 : 256))
    If $h = -1 Then Return False
    Local $ok = FileWrite($h, $text)
    FileClose($h)
    Return $ok <> 0
EndFunc

; 建立或開啟共享記憶體（命令列子程序回報進度用）。
Func P133Map($pid, $create, ByRef $handle)
    Local $r, $name = "Local\HtmlHelperCHMProgress." & $pid
    If $create Then
        $r = DllCall("kernel32.dll", "handle", "CreateFileMappingW", "handle", Ptr(-1), "ptr", 0, "dword", 4, "dword", 0, "dword", 8192, "wstr", $name)
    Else
        $r = DllCall("kernel32.dll", "handle", "OpenFileMappingW", "dword", 6, "bool", False, "wstr", $name)
    EndIf
    If @error Or Not IsArray($r) Then Return 0
    If Not $r[0] Then Return 0
    $handle = $r[0]
    $r = DllCall("kernel32.dll", "ptr", "MapViewOfFile", "handle", $handle, "dword", 6, "dword", 0, "dword", 0, "ulong_ptr", 8192)
    Local $view = 0
    If Not @error And IsArray($r) Then $view = $r[0]
    If Not $view Then
        DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $handle)
        $handle = 0
    EndIf
    Return $view
EndFunc

; 釋放共享記憶體。
Func P133Unmap(ByRef $view, ByRef $handle)
    If $view Then DllCall("kernel32.dll", "bool", "UnmapViewOfFile", "ptr", $view)
    If $handle Then DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $handle)
    $view = 0
    $handle = 0
EndFunc

; 寫入進度到共享記憶體（以序號確保 GUI 讀到完整資料，最多每 80 ms 一次）。
Func P133Progress($phase, $done = 0, $total = 0, $item = "", $force = False)
    If Not $g133WorkerPtr Then Return
    If Not $force And TimerDiff($g133WriteClock) < 80 Then Return
    $g133WriteClock = TimerInit()
    Local $st = DllStructCreate($g133Tag, $g133WorkerPtr), $seq = DllStructGetData($st, "seq"), $pct = -1
    If Mod($seq, 2) Then $seq += 1
    If $total > 0 Then $pct = Int(100 * $done / $total)
    If $pct > 100 Then $pct = 100
    DllStructSetData($st, "seq", $seq + 1)
    DllStructSetData($st, "percent", $pct)
    DllStructSetData($st, "done", $done)
    DllStructSetData($st, "total", $total)
    DllStructSetData($st, "phase", $phase)
    DllStructSetData($st, "item", $item)
    DllStructSetData($st, "seq", $seq + 2)
EndFunc

; 列舉資料夾內所有檔案的相對路徑（遇到 junction／符號連結視為錯誤）。
Func P133Files($root)
    Local $q[1] = [""], $head = 0, $out[0]
    Local $d = DllStructCreate("dword attr;dword times[6];dword sizeHi;dword sizeLo;dword reserved[2];wchar name[260];wchar shortName[14]")
    While $head < UBound($q)
        Local $dir = $q[$head]
        $head += 1
        Local $r = DllCall("kernel32.dll", "handle", "FindFirstFileW", "wstr", $root & "\" & $dir & "*", "ptr", DllStructGetPtr($d))
        If @error Or Not IsArray($r) Then Return SetError(1, 0, 0)
        Local $handle = $r[0]
        If $handle = Ptr(-1) Then
            Local $le = DllCall("kernel32.dll", "dword", "GetLastError")
            If @error Or Not IsArray($le) Then Return SetError(1, 0, 0)
            If $le[0] = 2 Or $le[0] = 18 Then ContinueLoop
            Return SetError(1, $le[0], 0)
        EndIf
        While True
            Local $name = DllStructGetData($d, "name"), $attr = DllStructGetData($d, "attr")
            If $name <> "." And $name <> ".." Then
                If BitAND($attr, 0x400) Then
                    DllCall("kernel32.dll", "bool", "FindClose", "handle", $handle)
                    Return SetError(1, 0, 0)
                EndIf
                Local $n, $rel = $dir & $name
                If BitAND($attr, 0x10) Then
                    $n = UBound($q)
                    ReDim $q[$n + 1]
                    $q[$n] = $rel & "\"
                Else
                    $n = UBound($out)
                    ReDim $out[$n + 1]
                    $out[$n] = $rel
                EndIf
            EndIf
            $r = DllCall("kernel32.dll", "bool", "FindNextFileW", "handle", $handle, "ptr", DllStructGetPtr($d))
            If @error Or Not IsArray($r) Then
                DllCall("kernel32.dll", "bool", "FindClose", "handle", $handle)
                Return SetError(1, 0, 0)
            EndIf
            If Not $r[0] Then
                $le = DllCall("kernel32.dll", "dword", "GetLastError")
                Local $err = @error, $endCode = -1
                If Not $err And IsArray($le) Then $endCode = $le[0]
                DllCall("kernel32.dll", "bool", "FindClose", "handle", $handle)
                If $endCode <> 18 Then Return SetError(1, $endCode, 0)
                ExitLoop
            EndIf
        WEnd
    WEnd
    Return $out
EndFunc

; 相對路徑是否可安全還原（無保留名稱、非法字元與路徑穿越）。
Func P133ValidRel($p)
    $p = StringReplace($p, "/", "\")
    If $p = "" Or StringLeft($p, 1) = "\" Or StringRegExp($p, '[\x00-\x1F<>:"|?*]') Then Return False
    Local $parts = StringSplit($p, "\", 2)
    For $v In $parts
        If $v = "" Or $v = "." Or $v = ".." Or StringLen($v) > 240 Then Return False
        If StringRight($v, 1) = "." Or StringRight($v, 1) = " " Then Return False
        If StringRegExp($v, "(?i)^(con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])(?:\.|$)") Then Return False
    Next
    Return True
EndFunc

; 是否為要編譯進 CHM 的資源（排除 #、$、:: 特殊項目與專案檔）。
Func P133Resource($rel)
    Local $first = StringRegExpReplace(StringReplace($rel, "/", "\"), "\\.*$", "")
    If StringRegExp($first, "^[#$]") Or StringLeft($first, 2) = "::" Or StringRegExp($first, "(?i)^%003A%003A") Then Return False
    If StringLower($rel) = "__htmlhelper_manifest.tsv" Then Return False
    Return Not StringRegExp($rel, "(?i)\.(hhp|chm)$")
EndFunc

; 還原對照表中跳脫的 Tab、換行與 %。
Func P133TsvDecode($v)
    $v = StringReplace($v, "%0009", @TAB)
    $v = StringReplace($v, "%000D", @CR)
    $v = StringReplace($v, "%000A", @LF)
    Return StringReplace($v, "%0025", "%")
EndFunc

; 讀取匯出對照表（輸出檔名 → 原始檔名）。
Func P133Manifest($root)
    Local $map = ObjCreate("Scripting.Dictionary")
    $map.CompareMode = 1
    If Not FileExists($root & "\__htmlhelper_manifest.tsv") Then Return $map
    Local $text = P133ReadText($root & "\__htmlhelper_manifest.tsv")
    If @error Then Return SetError(1, 0, 0)
    Local $lines = StringSplit(StringReplace($text, @CR, ""), @LF, 2)
    For $i = 1 To UBound($lines) - 1
        If $lines[$i] = "" Then ContinueLoop
        Local $c = StringSplit($lines[$i], @TAB, 2)
        If UBound($c) < 3 Then Return SetError(1, 0, 0)
        Local $src = StringReplace(P133TsvDecode($c[1]), "/", "\"), $dst = StringReplace(P133TsvDecode($c[2]), "/", "\")
        If $map.Exists($dst) Then Return SetError(1, 0, 0)
        $map.Add($dst, $src)
    Next
    Return $map
EndFunc

; 解析 #SYSTEM 中繼資料的各欄位。
Func P133System($b, ByRef $fields, ByRef $detail)
    $fields = ObjCreate("Scripting.Dictionary")
    Local $size = BinaryLen($b)
    If $size < 4 Then
        $detail = "#SYSTEM bytes=" & $size
        Return False
    EndIf
    Local $buf = DllStructCreate("byte[" & $size & "]")
    DllStructSetData($buf, 1, $b)
    Local $hdr = DllStructCreate("dword", DllStructGetPtr($buf)), $ver = DllStructGetData($hdr, 1), $pos = 4
    $detail = "#SYSTEM bytes=" & $size & " version=" & $ver
    If $ver <> 2 And $ver <> 3 Then Return False
    While $pos < $size
        If $pos + 4 > $size Then Return False
        Local $r = DllStructCreate("ushort code;ushort length", DllStructGetPtr($buf) + $pos), $tag = DllStructGetData($r, 1), $len = DllStructGetData($r, 2)
        $pos += 4
        If $len > $size - $pos Then Return False
        If Not $fields.Exists(String($tag)) Then $fields.Add(String($tag), BinaryMid($b, $pos + 1, $len))
        $detail &= " " & $tag & ":" & $len
        $pos += $len
    WEnd
    Return True
EndFunc

; 讀取 #SYSTEM 指定欄位的文字。
Func P133SystemText($fields, $tag)
    If Not IsObj($fields) Then Return ""
    If Not $fields.Exists(String($tag)) Then Return ""
    Return StringStripWS(_DecodeCodepage($fields.Item(String($tag)), 0), 3)
EndFunc

; 以 ITSS 串流讀取 CHM 內部檔案（有大小上限）。
Func P133ReadAny($doc, $name, ByRef $detail, $maxSize = 67108864)
    Local $stream = _ITSS_StreamOpen($doc, $name)
    If @error Or Not $stream Then
        $detail = _ITSS_LastErrorText()
        Return SetError(1, 0, Binary(""))
    EndIf
    Local $size = _ITSS_StreamSize($stream), $se = @error, $hex = "", $total = 0, $bad = False
    While True
        Local $b = _ITSS_StreamRead($stream, 65536), $e = @error, $n = BinaryLen($b)
        If $e Then
            $detail = _ITSS_LastErrorText()
            $bad = True
            ExitLoop
        EndIf
        If Not $n Then ExitLoop
        $total += $n
        If $total > $maxSize Then
            $detail = "串流超過安全上限：" & $name
            $bad = True
            ExitLoop
        EndIf
        $hex &= StringTrimLeft(String($b), 2)
    WEnd
    _ITSS_StreamClose($stream)
    If $bad Then Return SetError(1, 0, Binary(""))
    $detail = "Stat=" & $size & " StatError=" & $se & " Read=" & $total
    If Not $total Then Return SetError(0, 0, Binary(""))
    Return SetError(0, 0, Binary("0x" & $hex))
EndFunc

; 加入路徑別名（同一別名對到不同檔案時回傳 False）。
Func P133Alias($map, $key, $value)
    $key = StringReplace($key, "/", "\")
    If $map.Exists($key) Then Return StringLower($map.Item($key)) = StringLower($value)
    $map.Add($key, $value)
    Return True
EndFunc

; 開頭單一斜線代表 CHM 容器根目錄，不是 Windows 磁碟根目錄。
Func P133Resolve($ref, $sitemap, $root, $names, $aliases)
    $ref = StringStripWS(_HtmlUnescape($ref), 3)
    If StringRegExp($ref, "(?i)^(https?|mailto|ftp):") Then Return SetError(0, 1, $ref)
    Local $suffix = "", $cut = StringRegExp($ref, "[#?].*$", 1)
    If IsArray($cut) Then $suffix = $cut[0]
    Local $plain = StringRegExpReplace($ref, "[#?].*$", ""), $forms[2] = [$plain, UrlDecode($plain)]
    Local $prefix = StringRegExpReplace($root, "[\\/]+$", "") & "\"
    Local $base = StringRegExpReplace(StringReplace($sitemap, "/", "\"), "[^\\]+$", "")
    For $form In $forms
        Local $candidate = StringReplace($form, "/", "\")
        If StringLeft($candidate, 2) = "\\" Or StringInStr($candidate, ":") Then ContinueLoop
        Local $rootRelative = (StringLeft($candidate, 1) = "\")
        If $rootRelative Then $candidate = StringTrimLeft($candidate, 1)
        If $candidate = "" Then ContinueLoop
        Local $tries[2] = [$candidate, $base & $candidate]
        For $j = 0 To ($rootRelative ? 0 : 1)
            Local $full = P133Path($prefix & $tries[$j])
            If StringLeft(StringLower($full), StringLen($prefix)) <> StringLower($prefix) Then ContinueLoop
            Local $relative = StringTrimLeft($full, StringLen($prefix))
            If $names.Exists($relative) Then Return SetError(0, 0, $names.Item($relative) & $suffix)
            If $aliases.Exists($relative) Then
                Local $target = $aliases.Item($relative)
                If $names.Exists($target) Then Return SetError(0, 0, $names.Item($target) & $suffix)
            EndIf
        Next
    Next
    Return SetError(1, 0, "")
EndFunc

; 把緩衝內容寫入檔案並清空緩衝。
Func P133Flush($h, ByRef $buffer)
    If $buffer = "" Then Return True
    Local $ok = FileWrite($h, StringToBinary($buffer, 1))
    $buffer = ""
    Return $ok <> 0
EndFunc

; 改寫 sitemap 失敗時的清理（關檔、刪暫存檔、記錄原因）。
Func P133RewriteFail($h, $tmp, ByRef $why, $message)
    FileClose($h)
    FileDelete($tmp)
    $why = $message
    Return False
EndFunc

; 把 sitemap 的 Local 參照改成還原後的實際檔名（ANSI 寫回）。
Func P133FixSitemap($file, $rel, $root, $names, $aliases, ByRef $why)
    P133Progress("讀取目錄／索引", 0, 0, $rel, True)
    Local $text = P133ReadText($file)
    If @error Then
        $why = "讀取 sitemap 失敗：" & $rel
        Return False
    EndIf
    If BinaryToString(StringToBinary($text, 1), 1) <> $text Then
        $why = "sitemap 不能以目前 ANSI 字碼頁表示：" & $rel
        Return False
    EndIf
    Local $tokens = StringRegExp($text, '(?is)<param\b(?=[^>]*\bname\s*=\s*(?:"Local"|''Local''|Local(?=\s|/?>)))[^>]*>', 3), $total = 0
    If IsArray($tokens) Then $total = UBound($tokens)
    If Not $total Then
        If Not P133WriteText($file, $text, True) Then
            $why = "寫入 sitemap 失敗：" & $rel
            Return False
        EndIf
        P133Progress("核對 Local 完成（0 筆）", 0, 0, $rel, True)
        P133Report(0, "正規化 " & $rel & "，Local=0，修正=0")
        Return True
    EndIf
    Local $tmp = $root & "\__hh_rewrite_" & @AutoItPID & ".tmp"
    If FileExists($tmp) Then
        $why = "工作暫存檔已存在：" & $tmp
        Return False
    EndIf
    Local $h = FileOpen($tmp, 18)
    If $h = -1 Then
        $why = "不能建立 sitemap 暫存檔。"
        Return False
    EndIf
    Local $cursor = 1, $buffer = "", $changed = 0, $cache = ObjCreate("Scripting.Dictionary")
    P133Progress("核對 Local 參照", 0, $total, $rel, True)
    For $i = 0 To $total - 1
        Local $token = $tokens[$i], $pos = StringInStr($text, $token, 1, 1, $cursor)
        If Not $pos Then Return P133RewriteFail($h, $tmp, $why, "sitemap 掃描位置不符：" & $rel)
        Local $v = StringRegExp($token, '(?is)\bvalue\s*=\s*(["''])(.*?)\1', 1), $attr = StringRegExp($token, '(?is)\bvalue\s*=\s*(?:"[^"]*"|''[^'']*'')', 1)
        If Not IsArray($v) Or Not IsArray($attr) Then Return P133RewriteFail($h, $tmp, $why, "Local 格式不完整：" & $rel)
        Local $target = "", $ext = 0, $key = $v[1]
        If $cache.Exists($key) Then
            Local $cached = $cache.Item($key)
            $ext = Number(StringLeft($cached, 1))
            $target = StringTrimLeft($cached, 1)
        Else
            $target = P133Resolve($key, $rel, $root, $names, $aliases)
            Local $e = @error
            $ext = @extended
            If $e Then Return P133RewriteFail($h, $tmp, $why, "找不到 sitemap 參照：" & $rel & " -> " & $key)
            $cache.Add($key, $ext & $target)
        EndIf
        Local $new = $token
        If Not $ext Then $new = StringReplace($token, $attr[0], 'value="' & HtmlEscape(StringReplace($target, "\", "/")) & '"', 1)
        If BinaryToString(StringToBinary($new, 1), 1) <> $new Then Return P133RewriteFail($h, $tmp, $why, "Local 不能以 ANSI 表示：" & $target)
        If $new <> $token Then $changed += 1
        $buffer &= StringMid($text, $cursor, $pos - $cursor) & $new
        $cursor = $pos + StringLen($token)
        If StringLen($buffer) >= 65536 Then
            If Not P133Flush($h, $buffer) Then Return P133RewriteFail($h, $tmp, $why, "sitemap 分段寫入失敗：" & $rel)
        EndIf
        P133Progress("核對 Local 參照", $i + 1, $total, $rel)
    Next
    P133Progress("寫入目錄／索引", 0, 0, $rel, True)
    While $cursor <= StringLen($text)
        $buffer &= StringMid($text, $cursor, 65536)
        $cursor += 65536
        If Not P133Flush($h, $buffer) Then Return P133RewriteFail($h, $tmp, $why, "sitemap 尾端寫入失敗：" & $rel)
    WEnd
    If Not P133Flush($h, $buffer) Then Return P133RewriteFail($h, $tmp, $why, "sitemap 最後寫入失敗：" & $rel)
    FileClose($h)
    If Not FileMove($tmp, $file, 1) Then
        $why = "不能完成 sitemap 工作副本：" & $rel
        Return False
    EndIf
    P133Progress("核對 Local 完成", $total, $total, $rel, True)
    P133Report(0, "正規化 " & $rel & "，Local=" & $total & "，修正=" & $changed)
    Return True
EndFunc

; 取得 sitemap 的語意特徵（名稱＋目標）供驗證比對。
Func P133Signature($text, $rel, $root, $names, $aliases, $phase, ByRef $why)
    Local $set = ObjCreate("Scripting.Dictionary"), $objects = StringRegExp($text, "(?is)<object\b[^>]*>.*?</object\s*>", 3)
    If Not IsArray($objects) Then
        $why = "sitemap 不是可解析的 OBJECT 格式：" & $rel
        Return SetError(1, 0, 0)
    EndIf
    For $i = 0 To UBound($objects) - 1
        Local $params = StringRegExp($objects[$i], "(?is)<param\b[^>]*>", 3), $title = "", $locals[0], $seeAlso[0]
        If IsArray($params) Then
            For $param In $params
                Local $pn = StringRegExp($param, '(?is)\bname\s*=\s*(["''])(.*?)\1', 1), $pv = StringRegExp($param, '(?is)\bvalue\s*=\s*(["''])(.*?)\1', 1)
                If Not IsArray($pn) Or Not IsArray($pv) Then ContinueLoop
                Local $value = _HtmlUnescape($pv[1])
                Switch StringLower($pn[1])
                    Case "name"
                        $title = StringStripWS(StringRegExpReplace($value, "[\r\n\t]+", " "), 3)
                    Case "local"
                        Local $n = UBound($locals)
                        ReDim $locals[$n + 1]
                        $locals[$n] = $value
                    Case "see also"
                        $n = UBound($seeAlso)
                        ReDim $seeAlso[$n + 1]
                        $seeAlso[$n] = $value
                EndSwitch
            Next
        EndIf
        If $title <> "" Then
            If UBound($locals) = 0 And UBound($seeAlso) = 0 Then
                Local $key = $title & Chr(31) & "N"
                If Not $set.Exists($key) Then $set.Add($key, True)
            EndIf
            For $local In $locals
                Local $target = P133Resolve($local, $rel, $root, $names, $aliases), $e = @error, $ext = @extended
                If $e Then
                    $why = "語意驗證找不到 Local：" & $rel & " -> " & $local
                    Return SetError(1, 0, 0)
                EndIf
                If Not $ext Then
                    Local $suffix = "", $m = StringRegExp($target, "[#?].*$", 1)
                    If IsArray($m) Then $suffix = $m[0]
                    $target = StringLower(StringReplace(StringRegExpReplace($target, "[#?].*$", ""), "\", "/")) & $suffix
                EndIf
                $key = $title & Chr(31) & "L" & Chr(31) & $target
                If Not $set.Exists($key) Then $set.Add($key, True)
            Next
            For $see In $seeAlso
                $key = $title & Chr(31) & "S" & Chr(31) & StringStripWS($see, 3)
                If Not $set.Exists($key) Then $set.Add($key, True)
            Next
        EndIf
        P133Progress($phase, $i + 1, UBound($objects), $rel)
    Next
    If $set.Count = 0 Then
        $why = "sitemap 沒有可驗證的名稱／參照：" & $rel
        Return SetError(1, 0, 0)
    EndIf
    Return $set
EndFunc

; 驗證新 CHM 中的目錄／索引與來源語意一致。
Func P133VerifySitemap($doc, $rel, $work, $names, $aliases, ByRef $why)
    P133Progress("讀取 CHM 目錄／索引", 0, 0, $rel, True)
    Local $detail = "", $b = P133ReadAny($doc, StringReplace($rel, "\", "/"), $detail), $e = @error
    P133Report(0, "sitemap " & $rel & " expectedBytes=" & FileGetSize($work & "\" & $rel) & " " & $detail)
    If $e Or BinaryLen($b) = 0 Then
        $why = "CHM sitemap 不能完整讀取：" & $rel & " " & $detail
        Return False
    EndIf
    Local $source = P133ReadText($work & "\" & $rel)
    If @error Then
        $why = "來源 sitemap 不能讀取：" & $rel
        Return False
    EndIf
    Local $expected = P133Signature($source, $rel, $work, $names, $aliases, "解析來源目錄／索引語意", $why)
    If @error Or Not IsObj($expected) Then Return False
    Local $actual = P133Signature(P133BytesText($b), $rel, $work, $names, $aliases, "解析 CHM 目錄／索引語意", $why)
    If @error Or Not IsObj($actual) Then Return False
    Local $keys = $expected.Keys()
    For $key In $keys
        If Not $actual.Exists($key) Then
            $why = "CHM 缺少 sitemap 名稱／參照：" & $rel & " -> " & StringReplace($key, Chr(31), " | ")
            Return False
        EndIf
    Next
    P133Report(0, "sitemap 語意驗證通過：" & $rel & "，來源=" & $expected.Count & "，CHM=" & $actual.Count & "；允許額外 CHM 關聯。")
    Return True
EndFunc

; 以 SHA-256 雜湊檔案（分段讀取並回報進度）。
Func P133HashFile($file, $phase, $item, ByRef $why)
    Local $h = FileOpen($file, 16)
    If $h = -1 Then
        $why = "不能讀取雜湊來源：" & $file
        Return SetError(1, 0, Binary(""))
    EndIf
    Local $size = FileGetSize($file), $done = 0, $hash = 0
    While $done < $size
        Local $want = $size - $done
        If $want > 262144 Then $want = 262144
        Local $b = FileRead($h, $want), $n = BinaryLen($b)
        If Not $n Then
            FileClose($h)
            If $hash Then _Crypt_HashData(Binary(""), $CALG_SHA_256, True, $hash)
            $why = "雜湊讀取提早結束：" & $file
            Return SetError(1, 0, Binary(""))
        EndIf
        $hash = _Crypt_HashData($b, $CALG_SHA_256, False, $hash)
        If @error Then
            FileClose($h)
            $why = "SHA-256 更新失敗：" & $file
            Return SetError(1, 0, Binary(""))
        EndIf
        $done += $n
        P133Progress($phase, $g133BytesBase + $done, $g133BytesTotal, $item)
    WEnd
    FileClose($h)
    Local $digest = _Crypt_HashData(Binary(""), $CALG_SHA_256, True, $hash), $e = @error
    If $e Then $why = "SHA-256 結尾失敗：" & $file
    Return SetError($e, 0, $digest)
EndFunc

; 把 CHM 內部檔案串流複製到磁碟並核對長度。
Func P133StreamCopy($doc, $name, $target, $expected, ByRef $why)
    Local $st = _ITSS_StreamOpen($doc, $name)
    If @error Or Not $st Then
        $why = _ITSS_LastErrorText()
        Return False
    EndIf
    Local $size = _ITSS_StreamSize($st), $se = @error
    If $se Or ($size <> $expected And $size <> 0) Then
        $why = "串流 Stat 不符：" & $name & " expected=" & $expected & " stat=" & $size & " error=" & $se
        _ITSS_StreamClose($st)
        Return False
    EndIf
    Local $h = FileOpen($target, 26), $done = 0, $ok = True
    If $h = -1 Then
        _ITSS_StreamClose($st)
        $why = "不能寫入：" & $target
        Return False
    EndIf
    While True
        Local $b = _ITSS_StreamRead($st, 262144), $e = @error, $n = BinaryLen($b)
        If $e Or $done + $n > $expected Then
            $why = "串流讀取失敗／超過預期：" & $name
            $ok = False
            ExitLoop
        EndIf
        If Not $n Then ExitLoop
        If Not FileWrite($h, $b) Then
            $why = "串流寫入失敗：" & $target
            $ok = False
            ExitLoop
        EndIf
        $done += $n
        P133Progress($g133BytePhase, $g133BytesBase + $done, $g133BytesTotal, $name)
    WEnd
    FileClose($h)
    _ITSS_StreamClose($st)
    If $ok And ($done <> $expected Or FileGetSize($target) <> $expected) Then
        $why = "串流／輸出長度不符：" & $name & " expected=" & $expected & " read=" & $done
        $ok = False
    EndIf
    Return $ok
EndFunc

; 尋找 hhc.exe（指定路徑、程式旁、HTML Help Workshop、PATH）。
Func P133Compiler($explicit)
    If $explicit <> "" Then
        If FileExists($explicit) Then Return P133Path($explicit)
        Return ""
    EndIf
    Local $paths[3] = [@ScriptDir & "\hhc.exe", EnvGet("ProgramFiles(x86)") & "\HTML Help Workshop\hhc.exe", @ProgramFilesDir & "\HTML Help Workshop\hhc.exe"]
    For $p In $paths
        If FileExists($p) Then Return $p
    Next
    Local $dirs = StringSplit(EnvGet("PATH"), ";", 2)
    For $d In $dirs
        $d = StringReplace($d, '"', "")
        If $d <> "" And FileExists($d & "\hhc.exe") Then Return $d & "\hhc.exe"
    Next
    Return ""
EndFunc

; --build-chm：準備工作區、還原檔名、修正 sitemap、產生專案、編譯並逐檔驗證。
Func P133Build($input, $output, $compilerArg, $homeArg, $projectArg = "")
    Local $selectedRoot = P133Path($input), $root = $selectedRoot, $dest = P133Path($output), $projectName = "", $projectWhy = ""
    If Not FileExists($root) Or Not StringInStr(FileGetAttrib($root), "D") Then Return P133Report(10, "來源資料夾不存在。")
    If FileExists($dest) Then Return P133Report(10, "輸出 CHM 已存在，不覆寫。")
    P133Progress("定位 HHP 專案", 0, 0, $selectedRoot, True)
    If Not P134Locate($selectedRoot, $projectArg, $root, $projectName, $projectWhy) Then Return P133Report(10, $projectWhy)
    If $homeArg <> "" And StringLower(P134Prefix($selectedRoot)) <> StringLower(P134Prefix($root)) Then
        Local $selectedHome = P133Path(P134Prefix($selectedRoot) & StringReplace($homeArg, "/", "\")), $projectPrefix = P134Prefix($root)
        If FileExists($selectedHome) And StringLeft(StringLower($selectedHome), StringLen($projectPrefix)) = StringLower($projectPrefix) Then $homeArg = StringTrimLeft($selectedHome, StringLen($projectPrefix))
    EndIf
    Local $originalProject = ""
    If $projectName <> "" Then
        $originalProject = P133ReadText(P134Prefix($root) & $projectName)
        If @error Then Return P133Report(10, "HHP 讀取失敗：" & $projectName)
    EndIf
    Local $oldArchive = P134Unquote(P134Option($originalProject, "Compiled file"))
    If $oldArchive = "" And $projectName <> "" Then $oldArchive = StringTrimRight($projectName, 4) & ".chm"
    Local $support = P134Includes($root, $originalProject, $projectWhy)
    If @error Or Not IsObj($support) Then Return P133Report(10, $projectWhy)
    P133Report(0, "專案根目錄=" & $root & @CRLF & "HHP=" & $projectName)
    If StringRegExp($root, "(?i)^[a-z]:\\$") Then $root = StringTrimRight($root, 1)
    Local $activeLog = StringLower(P133Path($dest & "." & @AutoItPID & ".log")), $compiler = P133Compiler($compilerArg)
    If $compiler = "" Then Return P133Report(11, "找不到 hhc.exe，請使用 --compiler 指定。")
    P133Progress("列舉來源", 0, 0, $root, True)
    Local $files = P133Files($root)
    If @error Or Not IsArray($files) Then Return P133Report(10, "來源列舉失敗或含有 junction／符號連結。")
    Local $manifest = P133Manifest($root)
    If @error Or Not IsObj($manifest) Then Return P133Report(10, "匯出對照表格式錯誤。")
    Local $plan[UBound($files)][2], $count = 0, $names = ObjCreate("Scripting.Dictionary"), $aliases = ObjCreate("Scripting.Dictionary")
    $names.CompareMode = 1
    $aliases.CompareMode = 1
    Local $toc = "", $index = "", $home = "", $reason = ""
    For $rel In $files
        Local $full = StringLower(P133Path($root & "\" & $rel))
        If $full = $activeLog Or $full = StringLower($dest) Then ContinueLoop
        If StringRegExp($rel, "(?i)\.chm\.[0-9]+\.log$") Then ContinueLoop
        If $support.Exists($rel) Then ContinueLoop
        If StringRegExp($rel, "(?i)^__htmlhelper_project_report(?:_[0-9]+)?\.txt$") And Not $manifest.Exists($rel) Then ContinueLoop
        Local $original = $rel
        If $manifest.Exists($rel) Then $original = $manifest.Item($rel)
        If Not P133Resource($original) Then ContinueLoop
        If Not P133ValidRel($original) Then Return P133Report(10, "不能安全還原原始檔名：" & $original)
        If StringRegExp($original, "(?i)^__hh_(build|verify|rewrite)") Then Return P133Report(10, "保留工作檔名衝突：" & $original)
        If $names.Exists($original) Then Return P133Report(10, "還原後檔名衝突：" & $original)
        $names.Add($original, $original)
        If Not P133Alias($aliases, $rel, $original) Or Not P133Alias($aliases, $original, $original) Then Return P133Report(10, "路徑別名有歧義：" & $rel)
        $plan[$count][0] = $rel
        $plan[$count][1] = $original
        $count += 1
        If $toc = "" And StringRegExp($original, "(?i)\.hhc$") Then $toc = $original
        If $index = "" And StringRegExp($original, "(?i)\.hhk$") Then $index = $original
    Next
    If Not $count Then Return P133Report(10, "沒有可編譯資源。")
    ReDim $plan[$count][2]
    Local $work = P133Work(@TempDir & "\HHBuild")
    If $work = "" Then Return P133Report(12, "無法建立編譯工作區。")
    For $i = 0 To $count - 1
        Local $target = $plan[$i][1]
        If StringLen($work & "\" & $target) > 245 Then Return P133Report(12, "工作路徑過長：" & $target, $work)
        If Not FileCopy($root & "\" & $plan[$i][0], $work & "\" & $target, 8) Then Return P133Report(12, "複製／還原失敗：" & $target, $work)
        P133Progress("準備編譯資源（檔案）", $i + 1, $count, $target)
    Next
    If FileExists($root & "\#SYSTEM") Then
        Local $f = FileOpen($root & "\#SYSTEM", 16), $b = Binary("")
        If $f <> -1 Then
            $b = FileRead($f)
            FileClose($f)
        EndIf
        Local $fields, $detail = ""
        If P133System($b, $fields, $detail) Then
            $home = P133Resolve(P133SystemText($fields, 2), "", $work, $names, $aliases)
            If @error Then $home = ""
            If $home <> "" Then $reason = "原 #SYSTEM"
            Local $t = StringReplace(P133SystemText($fields, 0), "/", "\"), $k = StringReplace(P133SystemText($fields, 1), "/", "\")
            If $aliases.Exists($t) Then $toc = $aliases.Item($t)
            If $aliases.Exists($k) Then $index = $aliases.Item($k)
        EndIf
        P133Report(0, "原始 " & $detail)
    EndIf
    If $originalProject <> "" Then
        Local $projectDefault = P134WindowDefault($originalProject)
        If $projectDefault <> "" Then
            $home = P133Resolve($projectDefault, "", $work, $names, $aliases)
            Local $defaultError = @error, $defaultExternal = @extended
            If $defaultError Or $defaultExternal Then Return P133Report(10, "HHP／預設 WINDOWS 首頁不存在：" & $projectDefault, $work)
            $reason = "原 HHP／預設 WINDOWS"
        EndIf
        Local $projectToc = P134Unquote(P134Option($originalProject, "Contents file")), $projectIndex = P134Unquote(P134Option($originalProject, "Index file"))
        $toc = ""
        $index = ""
        If $projectToc <> "" Then
            $toc = P133Resolve($projectToc, "", $work, $names, $aliases)
            Local $pathError = @error, $pathExternal = @extended
            If $pathError Or $pathExternal Then Return P133Report(10, "HHP 目錄檔不存在：" & $projectToc, $work)
        EndIf
        If $projectIndex <> "" Then
            $index = P133Resolve($projectIndex, "", $work, $names, $aliases)
            $pathError = @error
            $pathExternal = @extended
            If $pathError Or $pathExternal Then Return P133Report(10, "HHP 索引檔不存在：" & $projectIndex, $work)
        EndIf
    EndIf
    If $homeArg <> "" Then
        $home = P133Resolve($homeArg, "", $work, $names, $aliases)
        If @error Then Return P133Report(10, "指定首頁不能對應來源 HTML：" & $homeArg, $work)
        $reason = "UI／--home 明確指定"
    EndIf
    Local $why = ""
    For $i = 0 To $count - 1
        $rel = $plan[$i][1]
        If StringRegExp($rel, "(?i)\.hh[ck]$") Then
            If Not P133FixSitemap($work & "\" & $rel, $rel, $work, $names, $aliases, $why) Then Return P133Report(10, $why, $work)
        EndIf
    Next
    If $home = "" And $toc <> "" Then
        Local $tokens = StringRegExp(P133ReadText($work & "\" & $toc), "(?is)<param\b[^>]*>", 3)
        If IsArray($tokens) Then
            For $token In $tokens
                Local $name = StringRegExp($token, '(?is)\bname\s*=\s*(["''])(.*?)\1', 1), $value = StringRegExp($token, '(?is)\bvalue\s*=\s*(["''])(.*?)\1', 1)
                If Not IsArray($name) Or Not IsArray($value) Then ContinueLoop
                If StringLower($name[1]) <> "local" Then ContinueLoop
                Local $candidate = P133Resolve($value[1], $toc, $work, $names, $aliases), $e = @error, $external = @extended
                If $e Or $external Then ContinueLoop
                If StringRegExp($candidate, "(?i)\.html?(?:[#?].*)?$") And Not StringRegExp($candidate, "(?i)(credits|copyright|license|changelog)") Then
                    $home = $candidate
                    $reason = "目錄第一個有效主題"
                    ExitLoop
                EndIf
            Next
        EndIf
    EndIf
    If $home = "" Then
        For $i = 0 To $count - 1
            If StringRegExp($plan[$i][1], "(?i)(^|[\\/])(index|default|home|intro|introduction|welcome|start)\.html?$") Then
                $home = $plan[$i][1]
                $reason = "常見首頁檔名"
                ExitLoop
            EndIf
        Next
    EndIf
    If $home = "" Or Not StringRegExp($home, "(?i)\.html?(?:[#?].*)?$") Or StringRegExp($home, "(?i)^[a-z]+:") Then Return P133Report(10, "不能選出本機 HTML 首頁，請手動指定。", $work)
    If Not P134CopyIncludes($root, $work, $support, $oldArchive, $names, $aliases, $why) Then Return P133Report(10, $why, $work)
    Local $project = P134ProjectText($originalProject, $home, $toc, $index, $plan, $count, $oldArchive, $work, $names, $aliases, $why)
    If @error Then Return P133Report(10, $why, $work)
    If Not P133WriteText($work & "\__hh_build_project.hhp", $project, True) Then Return P133Report(12, "HHP 不能以目前 ANSI 字碼頁寫入。", $work)
    P133Report(0, "實際首頁=" & $home & "（" & $reason & "）" & @CRLF & "啟動頁=" & $home & @CRLF & "目錄=" & $toc & @CRLF & "索引=" & $index, $work)
    P133Progress("編譯 CHM", 0, 0, "等待 hhc.exe", True)
    Local $pid = Run('"' & $compiler & '" "__hh_build_project.hhp"', $work, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    If @error Or Not $pid Then Return P133Report(13, "不能啟動 hhc.exe。", $work)
    Local $log = FileOpen($work & "\__hh_build_process.log", 18), $clock = TimerInit()
    While ProcessExists($pid)
        Local $out = StdoutRead($pid, False, True), $err = StderrRead($pid, False, True)
        If $log <> -1 Then
            If BinaryLen($out) Then FileWrite($log, $out)
            If BinaryLen($err) Then FileWrite($log, $err)
        EndIf
        P133Progress("編譯 CHM（不定進度）", 0, 0, "經過 " & Int(TimerDiff($clock) / 1000) & " 秒")
        If TimerDiff($clock) > 1800000 Then
            ProcessClose($pid)
            If $log <> -1 Then FileClose($log)
            Return P133Report(13, "編譯超過 30 分鐘。", $work)
        EndIf
        Sleep(25)
    WEnd
    $out = StdoutRead($pid, False, True)
    $err = StderrRead($pid, False, True)
    If $log <> -1 Then
        If BinaryLen($out) Then FileWrite($log, $out)
        If BinaryLen($err) Then FileWrite($log, $err)
        FileClose($log)
    EndIf
    Local $logFile = $work & "\__hh_build_compiler.log"
    If Not FileExists($logFile) Then Return P133Report(13, "沒有編譯紀錄，不能判定成功。", $work)
    Local $compileText = P133ReadText($logFile)
    $e = @error
    Local $processText = P133ReadText($work & "\__hh_build_process.log")
    If $e Then Return P133Report(13, "編譯紀錄讀取失敗。", $work)
    Local $errors = StringRegExp($compileText & @CRLF & $processText, "(?im)^.*HHC[0-9]+\s*:\s*(?:Error|錯誤|错误)\s*:.*$", 3)
    If IsArray($errors) Then
        For $line In $errors
            P133Report(13, $line)
        Next
        Return P133Report(13, "編譯器回報錯誤，不使用半成品 CHM。", $work)
    EndIf
    Local $built = $work & "\__hh_build_output.chm", $doc = _ITSS_Open($built)
    If @error Or Not $doc Then Return P133Report(14, "新 CHM 無法掛載：" & _ITSS_LastErrorText(), $work)
    Local $metadataDetail = "", $system = P133ReadAny($doc, "#SYSTEM", $metadataDetail, 16777216), $readError = @error
    $fields = ""
    Local $parseDetail = "", $pass = True
    $why = ""
    P133Report(0, "新 CHM " & $metadataDetail)
    If $readError Then
        $pass = False
        $why = "#SYSTEM 讀取失敗：" & $metadataDetail
    ElseIf Not P133System($system, $fields, $parseDetail) Then
        $pass = False
        $why = "#SYSTEM 解析失敗：" & $parseDetail
    Else
        Local $actual = P133SystemText($fields, 2)
        P133Report(0, $parseDetail & @CRLF & "啟動頁=" & $actual)
        Local $canonical = P133Resolve($actual, "", $work, $names, $aliases), $ce = @error, $cx = @extended
        If $ce Or $cx Or StringLower(StringReplace($canonical, "/", "\")) <> StringLower(StringReplace($home, "/", "\")) Then
            $pass = False
            $why = "#SYSTEM 啟動頁不符：actual=" & $actual & " expected=" & $home
        EndIf
    EndIf
    If $pass And $originalProject <> "" Then
        Local $expectedTitle = P134Unquote(P134Option($originalProject, "Title")), $actualTitle = P133SystemText($fields, 3)
        Local $expectedWindow = P134Unquote(P134Option($originalProject, "Default Window")), $actualWindow = P133SystemText($fields, 5)
        P133Report(0, "CHM Title=" & $actualTitle & @CRLF & "CHM Default Window=" & $actualWindow)
        If $expectedTitle <> "" And StringStripWS($actualTitle, 3) <> StringStripWS($expectedTitle, 3) Then
            $pass = False
            $why = "CHM 標題與原 HHP 不符。"
        EndIf
        If $pass And $expectedWindow <> "" Then
            If StringLower($actualWindow) <> StringLower($expectedWindow) Then
                $pass = False
                $why = "CHM Default Window 與原 HHP 不符。"
            Else
                Local $windowDetail = "", $windowData = P133ReadAny($doc, "#WINDOWS", $windowDetail, 16777216), $windowError = @error
                If $windowError Or BinaryLen($windowData) < 8 Then
                    $pass = False
                    $why = "新 CHM 缺少有效 #WINDOWS：" & $windowDetail
                EndIf
            EndIf
        EndIf
    EndIf
    $g133BytesTotal = 0
    $g133BytesBase = 0
    For $i = 0 To $count - 1
        If Not StringRegExp($plan[$i][1], "(?i)\.hh[ck]$") Then $g133BytesTotal += 3 * FileGetSize($work & "\" & $plan[$i][1])
    Next
    Local $verify = $work & "\__hh_verify.bin"
    For $i = 0 To $count - 1
        If Not $pass Then ExitLoop
        $rel = $plan[$i][1]
        Local $src = $work & "\" & $rel, $size = FileGetSize($src)
        If StringRegExp($rel, "(?i)\.hh[ck]$") Then
            If Not P133VerifySitemap($doc, $rel, $work, $names, $aliases, $why) Then $pass = False
            ContinueLoop
        EndIf
        $g133BytePhase = "驗證：讀取 CHM 資源（位元組）"
        If Not P133StreamCopy($doc, StringReplace($rel, "\", "/"), $verify, $size, $why) Then
            $pass = False
            ExitLoop
        EndIf
        $g133BytesBase += $size
        Local $ha = P133HashFile($src, "驗證：來源 SHA-256（位元組）", $rel, $why), $ea = @error
        $g133BytesBase += $size
        Local $hb = P133HashFile($verify, "驗證：CHM SHA-256（位元組）", $rel, $why), $eb = @error
        $g133BytesBase += $size
        If $ea Or $eb Or $ha <> $hb Then
            $pass = False
            If $why = "" Then $why = "資源內容不符：" & $rel
            ExitLoop
        EndIf
    Next
    _ITSS_Close($doc)
    FileDelete($verify)
    $g133BytesTotal = 0
    If Not $pass Then Return P133Report(14, "新 CHM 驗證失敗：" & $why, $work)
    If Not FileMove($built, $dest, 8) Then Return P133Report(15, "不能完成最終輸出，或目的檔已存在。", $work)
    P133Report(0, "打包完成；首頁直接指向實際 HTML；內容與 sitemap 名稱／參照已驗證。" & @CRLF & $dest)
    DirRemove($work, 1)
    Return 0
EndFunc

; 把無法當成 Windows 檔名的字元以 %XXXX 表示。
Func P133Encode($v)
    Local $out = ""
    For $i = 1 To StringLen($v)
        Local $c = StringMid($v, $i, 1), $n = AscW($c)
        If $n < 0 Then $n += 65536
        If $n < 32 Or StringInStr('<>:"/\|?*', $c) Or ($i = StringLen($v) And ($c = "." Or $c = " ")) Then
            $out &= "%" & Hex($n, 4)
        Else
            $out &= $c
        EndIf
    Next
    If StringRegExp($v, "(?i)^(con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])(?:\.|$)") Then $out = "%" & Hex(AscW(StringLeft($v, 1)), 4) & StringTrimLeft($out, 1)
    Return $out
EndFunc

; 產生匯出時的安全輸出檔名（大小寫衝突時加 ~n）。
Func P133ExtractName($name, $directory, $map, $used, $types)
    Local $parts = StringSplit(StringReplace($name, "\", "/"), "/", 2), $key = "", $out = ""
    For $i = 0 To UBound($parts) - 1
        If $parts[$i] = "" Then Return SetError(1, 0, "")
        If $key <> "" Then $key &= "/"
        $key &= $parts[$i]
        Local $kind = ($directory Or $i < UBound($parts) - 1)
        If $map.Exists($key) Then
            If $types.Item($key) <> $kind Then Return SetError(1, 0, "")
            $out = $map.Item($key)
        Else
            Local $base = P133Encode($parts[$i]), $candidate = $base, $prefix = $out, $n = 0
            If $base = "" Or StringLen($base) > 230 Then Return SetError(1, 0, "")
            If $prefix <> "" Then $prefix &= "\"
            While $used.Exists($prefix & $candidate)
                $n += 1
                $candidate = $base & "~" & $n
            WEnd
            $out = $prefix & $candidate
            $map.Add($key, $out)
            $types.Add($key, $kind)
            $used.Add($out, True)
        EndIf
    Next
    Return $out
EndFunc

; 跳脫對照表中的 Tab、換行與 %。
Func P133Tsv($v)
    $v = StringReplace($v, "%", "%0025")
    $v = StringReplace($v, @TAB, "%0009")
    $v = StringReplace($v, @CR, "%000D")
    Return StringReplace($v, @LF, "%000A")
EndFunc

; --extract-chm：以 ITSS 完整匯出 CHM 並寫出對照表與重建的 HHP。
Func P133Extract($input, $output)
    Local $dest = P133Path($output)
    If Not P133Empty($dest) Then Return P133Report(5, "輸出資料夾須不存在或為空。")
    P133Progress("掛載與列舉 CHM", 0, 0, $input, True)
    Local $doc = _ITSS_Open(P133Path($input))
    If @error Or Not $doc Then Return P133Report(3, _ITSS_LastErrorText())
    Local $rows = _ITSS_Enum($doc, True, 0), $e = @error
    If $e Or Not IsArray($rows) Then
        Local $why = _ITSS_LastErrorText()
        _ITSS_Close($doc)
        Return P133Report(4, $why)
    EndIf
    Local $work = P133Work($dest)
    If $work = "" Then
        _ITSS_Close($doc)
        Return P133Report(5, "無法建立工作區。")
    EndIf
    $g133BytesBase = 0
    $g133BytesTotal = 0
    $g133BytePhase = "匯出 CHM 資源（位元組）"
    For $i = 0 To UBound($rows) - 1
        If $rows[$i][1] = 2 Then $g133BytesTotal += $rows[$i][2]
    Next
    Local $map = ObjCreate("Scripting.Dictionary"), $used = ObjCreate("Scripting.Dictionary"), $types = ObjCreate("Scripting.Dictionary"), $seen = ObjCreate("Scripting.Dictionary")
    $used.CompareMode = 1
    $used.Add("__htmlhelper_manifest.tsv", True)
    Local $f = FileOpen($work & "\__htmlhelper_manifest.tsv", 130), $code = 0
    $why = ""
    Local $count = 0
    If $f = -1 Then
        _ITSS_Close($doc)
        Return P133Report(5, "不能建立對照表。", $work)
    EndIf
    If Not FileWriteLine($f, "type" & @TAB & "original_escaped" & @TAB & "output_escaped" & @TAB & "bytes") Then $code = 5
    For $i = 0 To UBound($rows) - 1
        If $code Then ExitLoop
        Local $name = $rows[$i][0], $type = $rows[$i][1]
        If ($type <> 1 And $type <> 2) Or $seen.Exists($name) Then
            $code = 4
            $why = "重複或不支援項目：" & $name
            ExitLoop
        EndIf
        $seen.Add($name, True)
        Local $rel = P133ExtractName($name, $type = 1, $map, $used, $types)
        $e = @error
        If $e Or StringLen($work & "\" & $rel) > 245 Then
            $code = 5
            $why = "路徑無法安全表示或太長：" & $name
            ExitLoop
        EndIf
        If $type = 1 Then
            If Not DirCreate($work & "\" & $rel) Then
                $code = 5
                $why = "不能建立：" & $rel
                ExitLoop
            EndIf
        Else
            If Not P133StreamCopy($doc, $name, $work & "\" & $rel, $rows[$i][2], $why) Then
                $code = 6
                ExitLoop
            EndIf
            $g133BytesBase += $rows[$i][2]
            $count += 1
        EndIf
        If Not FileWriteLine($f, $type & @TAB & P133Tsv($name) & @TAB & P133Tsv($rel) & @TAB & $rows[$i][2]) Then
            $code = 5
            $why = "對照表寫入失敗。"
            ExitLoop
        EndIf
    Next
    FileClose($f)
    $g133BytesTotal = 0
    If $code = 0 Then
        If Not P135GenerateProject($doc, $input, $work, $rows, $map, $why) Then $code = 7
    EndIf
    _ITSS_Close($doc)
    If $code Then Return P133Report($code, $why, $work)
    If FileExists($dest) Then
        If Not P133Empty($dest) Then Return P133Report(5, "目的資料夾已非空。", $work)
        If Not DirRemove($dest, 0) Then Return P133Report(5, "不能移除空目的資料夾。", $work)
    EndIf
    If Not DirMove($work, $dest, 0) Then Return P133Report(5, "不能完成匯出目的地。", $work)
    Return P133Report(0, "匯出完成，檔案數=" & $count & @CRLF & $dest)
EndFunc

; 命令列模式入口：解析參數並執行解包或打包。
Func P133Main()
    Local $mode = StringLower($CmdLine[1])
    If $mode = "--help" Then Return P133Report(0, '--extract-chm "input.chm" "folder"' & @CRLF & '--build-chm "folder" "output.chm" [--compiler "hhc.exe"] [--home "html\index.htm"] [--project "AutoIt.hhp"]' & @CRLF & P136Usage())
    If $CmdLine[0] < 3 Or Mod($CmdLine[0] - 3, 2) Then Return P133Report(2, "命令列參數錯誤。")
    Local $compiler = "", $home = "", $project = ""
    For $i = 4 To $CmdLine[0] Step 2
        Switch StringLower($CmdLine[$i])
            Case "--compiler"
                $compiler = $CmdLine[$i + 1]
            Case "--home"
                $home = $CmdLine[$i + 1]
            Case "--project"
                $project = $CmdLine[$i + 1]
            Case Else
                Return P133Report(2, "不支援參數：" & $CmdLine[$i])
        EndSwitch
    Next
    $g133Log = FileOpen(P133Path($CmdLine[3]) & "." & @AutoItPID & ".log", 138)
    $g133WorkerPtr = P133Map(@AutoItPID, True, $g133WorkerHandle)
    _Crypt_Startup()
    Local $code = 2
    If $mode = "--extract-chm" And $CmdLine[0] = 3 Then
        $code = P133Extract($CmdLine[2], $CmdLine[3])
    ElseIf $mode = "--build-chm" Then
        $code = P133Build($CmdLine[2], $CmdLine[3], $compiler, $home, $project)
    Else
        P133Report(2, "不支援的命令列。")
    EndIf
    _Crypt_Shutdown()
    P133Progress(($code = 0 ? "完成" : "失敗"), ($code = 0 ? 1 : 0), 1, "ExitCode=" & $code, True)
    If $g133Log <> -1 Then
        FileWriteLine($g133Log, "ExitCode=" & $code)
        FileClose($g133Log)
        $g133Log = -1
    EndIf
    P133Unmap($g133WorkerPtr, $g133WorkerHandle)
    Return $code
EndFunc
