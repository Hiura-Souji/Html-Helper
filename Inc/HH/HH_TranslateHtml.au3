#include-once
; =============================================================================
; Html Helper － HTML／目錄／專案的翻譯切分
;
; 把 HTML 切成「可翻譯段落」：只翻可見說明文字，
; script／style／pre／code 原樣保留，行內標籤換成 <tN> 標記；
; 程式碼區塊內只翻註解。也處理 HHC／HHK 名稱與 HHP 標題，並以原編碼寫回。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ---------- HTML 分段：只翻譯說明文字，程式碼原樣保留 ----------
Func P136Esc($s)
    $s = StringReplace($s, "&", "&amp;")
    $s = StringReplace($s, "<", "&lt;")
    $s = StringReplace($s, ">", "&gt;")
    Return StringReplace($s, ChrW(160), "&nbsp;")
EndFunc

; 這段文字是否值得翻譯（排除識別字、網址、純符號）。
Func P136Worth($plain)
    Local $p = StringStripWS(StringReplace($plain, ChrW(160), " "), 3)
    If StringLen($p) < 2 Then Return False
    If Not StringRegExp($p, "\p{L}") Then Return False
    If StringRegExp($p, "</?t[0-9]+/?>") Then Return False
    If Not StringRegExp($p, "\s") Then
        If StringRegExp($p, "^[a-z][A-Za-z0-9_]*$") Then Return False
        If StringRegExp($p, "^[A-Za-z_][A-Za-z0-9_]*[A-Z0-9_][A-Za-z0-9_]*$") Then Return False
        If StringRegExp($p, "[\$@#_\\/.()\[\]{}<>=:]") Then Return False
    EndIf
    If StringRegExp($p, "^(?i)(https?|ftp|mailto|file|ms-its|mk):") Then Return False
    Return True
EndFunc

; 加入一個段落片段（文字、開標籤、關標籤、獨立標籤）。
Func P136SegAdd($kind, $raw, $name)
    If $p136SegN >= UBound($p136SegRaw) Then
        ReDim $p136SegRaw[$p136SegN * 2 + 16]
        ReDim $p136SegKind[$p136SegN * 2 + 16]
        ReDim $p136SegName[$p136SegN * 2 + 16]
    EndIf
    $p136SegRaw[$p136SegN] = $raw
    $p136SegKind[$p136SegN] = $kind
    $p136SegName[$p136SegN] = $name
    $p136SegN += 1
EndFunc

; 拆出前後空白與核心文字。
Func P136Split($marked, ByRef $lead, ByRef $core, ByRef $trail)
    Local $m = StringRegExp($marked, "(?s)^([\s\x{A0}]*)(.*?)([\s\x{A0}]*)$", 1)
    If @error Then
        $lead = ""
        $core = $marked
        $trail = ""
        Return
    EndIf
    $lead = $m[0]
    $core = $m[1]
    $trail = $m[2]
EndFunc

; 查詢譯文（收集模式登記待翻，重建模式回傳譯文）。
Func P136Unit($core)
    ; 收集模式登記需要翻譯的單位；重建模式回傳譯文或 SetError。
    If $p136Cache.Exists($core) Then
        If $p136Mode = 1 Then $p136Hits += 1
        Return $p136Cache.Item($core)
    EndIf
    If $p136Mode = 0 And Not $p136Bad.Exists($core) Then $p136Need.Item($core) = 1
    Return SetError(1, 0, "")
EndFunc

; 格式標記驗證失敗時，改為逐段純文字翻譯並保留原標籤。
Func P136Runs($n, ByRef $raws, ByRef $kinds)
    ; 標記驗證失敗時，改為逐段純文字翻譯，保留所有原始標籤。
    Local $out = "", $i = 0
    While $i < $n
        If $kinds[$i] <> "t" Then
            $out &= $raws[$i]
            $i += 1
            ContinueLoop
        EndIf
        Local $raw = ""
        While $i < $n
            If $kinds[$i] <> "t" Then ExitLoop
            $raw &= $raws[$i]
            $i += 1
        WEnd
        Local $lead, $core, $trail
        P136Split(HH_ExportDecodeEntities($raw), $lead, $core, $trail)
        If Not P136Worth($core) Then
            $out &= $raw
            ContinueLoop
        EndIf
        Local $tr = P136Unit($core)
        If @error Then
            $out &= $raw
        Else
            $out &= P136Esc($lead) & P136Esc($tr) & P136Esc($trail)
        EndIf
    WEnd
    Return $out
EndFunc

; 處理累積的段落：組成含 <tN> 標記的文字，查詢譯文並還原標籤。
Func P136Flush()
    If $p136SegN = 0 Then Return
    Local $n = $p136SegN
    $p136SegN = 0
    Local $raws[$n], $kinds[$n], $labels[$n], $raw = ""
    For $i = 0 To $n - 1
        $raws[$i] = $p136SegRaw[$i]
        $kinds[$i] = $p136SegKind[$i]
        $raw &= $raws[$i]
    Next
    Local $hasText = False
    For $i = 0 To $n - 1
        If $kinds[$i] = "t" Then
            $hasText = True
            ExitLoop
        EndIf
    Next
    If Not $hasText Then
        If $p136Mode = 1 Then $p136Out &= $raw
        Return
    EndIf
    Local $marked = "", $stackName[$n], $stackId[$n], $stackAt[$n], $sp = 0, $k = 0
    For $i = 0 To $n - 1
        Switch $kinds[$i]
            Case "t"
                $marked &= HH_ExportDecodeEntities($raws[$i])
            Case "o"
                $k += 1
                $labels[$i] = $k
                $stackName[$sp] = $p136SegName[$i]
                $stackId[$sp] = $k
                $stackAt[$sp] = $i
                $sp += 1
                $marked &= "<t" & $k & ">"
            Case "c"
                Local $found = -1
                For $j = $sp - 1 To 0 Step -1
                    If $stackName[$j] = $p136SegName[$i] Then
                        $found = $j
                        ExitLoop
                    EndIf
                Next
                If $found >= 0 Then
                    For $j = $sp - 1 To $found + 1 Step -1
                        $kinds[$stackAt[$j]] = "v"
                        $marked = StringReplace($marked, "<t" & $stackId[$j] & ">", "<t" & $stackId[$j] & "/>", 0, 1)
                    Next
                    $labels[$i] = $stackId[$found]
                    $sp = $found
                    $marked &= "</t" & $labels[$i] & ">"
                Else
                    $k += 1
                    $labels[$i] = $k
                    $kinds[$i] = "v"
                    $marked &= "<t" & $k & "/>"
                EndIf
            Case Else
                $k += 1
                $labels[$i] = $k
                $kinds[$i] = "v"
                $marked &= "<t" & $k & "/>"
        EndSwitch
    Next
    For $j = $sp - 1 To 0 Step -1
        $kinds[$stackAt[$j]] = "v"
        $marked = StringReplace($marked, "<t" & $stackId[$j] & ">", "<t" & $stackId[$j] & "/>", 0, 1)
    Next
    Local $lead, $core, $trail
    P136Split($marked, $lead, $core, $trail)
    Local $plain = StringRegExpReplace($core, "</?t[0-9]+/?>", " ")
    Local $decodedText = ""
    For $i = 0 To $n - 1
        If $kinds[$i] = "t" Then $decodedText &= HH_ExportDecodeEntities($raws[$i])
    Next
    If StringRegExp($decodedText, "</?t[0-9]+/?>") Or Not P136Worth($plain) Then
        If $p136Mode = 1 Then $p136Out &= $raw
        Return
    EndIf
    If $p136Bad.Exists($core) Then
        Local $piece = P136Runs($n, $raws, $kinds)
        If $p136Mode = 1 Then $p136Out &= $piece
        Return
    EndIf
    Local $tr = P136Unit($core)
    If @error Then
        If $p136Mode = 1 Then $p136Out &= $raw
        Return
    EndIf
    If $p136Mode = 0 Then Return
    Local $map = ObjCreate("Scripting.Dictionary")
    For $i = 0 To $n - 1
        Switch $kinds[$i]
            Case "o"
                $map.Item("<t" & $labels[$i] & ">") = $raws[$i]
            Case "c"
                $map.Item("</t" & $labels[$i] & ">") = $raws[$i]
            Case "v"
                $map.Item("<t" & $labels[$i] & "/>") = $raws[$i]
        EndSwitch
    Next
    Local $pieces = StringRegExp($tr, "</?t[0-9]+/?>|[^<]+|<", 3), $result = ""
    If Not @error Then
        For $i = 0 To UBound($pieces) - 1
            If $map.Exists($pieces[$i]) Then
                $result &= $map.Item($pieces[$i])
            Else
                $result &= P136Esc($pieces[$i])
            EndIf
        Next
    EndIf
    $p136Out &= P136Esc($lead) & $result & P136Esc($trail)
EndFunc

; 是否為行內標籤（會併入同一段落）。
Func P136Inline($name)
    Return StringInStr("|a|abbr|acronym|b|big|bdi|bdo|br|cite|dfn|em|font|i|img|ins|del|label|mark|nobr|q|s|small|span|strike|strong|sub|sup|u|wbr|", "|" & $name & "|", 1) > 0
EndFunc

; 是否為沒有結束標籤的元素。
Func P136Void($name)
    Return StringInStr("|area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr|", "|" & $name & "|", 1) > 0
EndFunc

; 是否為程式碼區塊的開始（pre 或 class 含 code／syntax 等）。
Func P136CodeStart($name, $tag)
    If $name = "pre" Or $name = "listing" Or $name = "plaintext" Then Return True
    Return StringRegExp($tag, "(?i)\bclass\s*=\s*[""']?[^""'>]*?\b(code[a-z0-9_-]*|syntax[a-z0-9_-]*|sourcecode|highlight|prettyprint)\b") = 1
EndFunc

; 重設程式碼區塊的掃描狀態。
Func P136CodeReset()
    $p136cQuote = ""
    $p136cStarted = False
    $p136cComment = False
    $p136cBlockNext = False
    $p136cLast = ""
EndFunc

; 程式碼換行：結束目前的註解段落。
Func P136CodeLineEnd()
    If $p136cComment Then P136Flush()
    $p136cComment = False
    $p136cQuote = ""
    $p136cStarted = False
    $p136cLast = ""
    If $p136cBlockNext Then $p136cBlock = True
    $p136cBlockNext = False
EndFunc

; 輸出程式碼文字（註解中則加入翻譯段落）。
Func P136Emit($s)
    If $p136cComment Then
        P136SegAdd("t", $s, "")
    ElseIf $p136Mode = 1 Then
        $p136Out &= $s
    EndIf
EndFunc

; 掃描程式碼文字，找出 ; // #cs…#ce 註解（字串內的不算）。
Func P136CodeText($t)
    If Not $p136Comments Then
        If $p136Mode = 1 Then $p136Out &= $t
        Return
    EndIf
    If StringLeft($t, 1) = "&" And StringLen($t) > 1 Then
        If Not $p136cComment Then
            Local $d = HH_ExportDecodeEntities($t)
            If $d = '"' Or $d = "'" Then
                If $p136cQuote = "" Then
                    $p136cQuote = $d
                ElseIf $p136cQuote = $d Then
                    $p136cQuote = ""
                EndIf
            EndIf
            If StringStripWS($d, 8) <> "" Then $p136cStarted = True
            $p136cLast = StringRight($d, 1)
        EndIf
        P136Emit($t)
        Return
    EndIf
    Local $n = StringLen($t), $start = 1, $k = 1
    While $k <= $n
        Local $ch = StringMid($t, $k, 1)
        If $ch = @LF Or $ch = @CR Then
            If $k > $start Then P136Emit(StringMid($t, $start, $k - $start))
            P136CodeLineEnd()
            If $p136Mode = 1 Then $p136Out &= $ch
            $k += 1
            $start = $k
            ContinueLoop
        EndIf
        If $p136cComment Then
            $k += 1
            ContinueLoop
        EndIf
        If Not $p136cStarted And $ch <> " " And $ch <> @TAB Then
            $p136cStarted = True
            Local $rest = StringMid($t, $k, 20)
            If $p136cBlock Then
                If StringRegExp($rest, "(?i)^#(ce|comments-end)\b") Then
                    $p136cBlock = False
                Else
                    If $k > $start And $p136Mode = 1 Then $p136Out &= StringMid($t, $start, $k - $start)
                    $start = $k
                    $p136cComment = True
                    $k += 1
                    ContinueLoop
                EndIf
            ElseIf StringRegExp($rest, "(?i)^#(cs|comments-start)\b") Then
                $p136cBlockNext = True
            EndIf
        EndIf
        If $p136cQuote <> "" Then
            If $ch = $p136cQuote Then $p136cQuote = ""
            $k += 1
            ContinueLoop
        EndIf
        If $ch = '"' Or $ch = "'" Then
            $p136cQuote = $ch
            $k += 1
            ContinueLoop
        EndIf
        Local $marker = 0
        If $ch = ";" Then $marker = 1
        If $ch = "/" And StringMid($t, $k + 1, 1) = "/" And StringMid($t, $k - 1, 1) <> ":" Then $marker = 2
        If $marker Then
            ; 只有在行首或空白之後的 ; 或 // 才視為註解，避免 C 語法 a;b 被誤判。
            Local $prev = $p136cLast
            If $k > 1 Then $prev = StringMid($t, $k - 1, 1)
            If $prev = "" Or $prev = " " Or $prev = @TAB Or $prev = @LF Or $prev = @CR Then
                Local $after = $k + $marker
                While $after <= $n And (StringMid($t, $after, 1) = " " Or StringMid($t, $after, 1) = @TAB Or StringMid($t, $after, 1) = ";")
                    $after += 1
                WEnd
                If $p136Mode = 1 Then $p136Out &= StringMid($t, $start, $after - $start)
                $start = $after
                $k = $after
                $p136cComment = True
                ContinueLoop
            EndIf
        EndIf
        $k += 1
    WEnd
    If Not $p136cComment And $n > 0 Then $p136cLast = StringRight($t, 1)
    If $start <= $n Then P136Emit(StringMid($t, $start))
EndFunc

; 走訪 HTML：收集模式（0）登記待翻段落，重建模式（1）輸出譯文。
Func P136Pass($html, $mode)
    $p136Mode = $mode
    $p136Out = ""
    $p136SegN = 0
    P136CodeReset()
    $p136cBlock = False
    Local $tokens = StringRegExp($html, "(?s)(<!--.*?-->|<!\[CDATA\[.*?\]\]>|<[^>]*>|&(?:\#[0-9]+|\#x[0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]+);|[^<&]+|<|&)", 3)
    If @error Then Return SetError(1, 0, "")
    Local $skip = "", $skipDepth = 0, $code = "", $codeDepth = 0, $atom = "", $atomDepth = 0, $atomBuf = ""
    For $i = 0 To UBound($tokens) - 1
        Local $t = $tokens[$i], $isTag = False, $name = "", $closing = False, $self = False
        If StringLeft($t, 1) = "<" And StringLen($t) > 2 Then
            If StringRegExp($t, "^<[!?]") Then
                $name = "!"
                $isTag = True
            Else
                Local $m = StringRegExp($t, "^<(/?)([A-Za-z][A-Za-z0-9:_-]*)", 1)
                If Not @error Then
                    $isTag = True
                    $closing = ($m[0] = "/")
                    $name = StringLower($m[1])
                    $self = StringRegExp($t, "/\s*>$") Or P136Void($name)
                EndIf
            EndIf
        EndIf
        If $skip <> "" Then
            If $mode = 1 Then $p136Out &= $t
            If $isTag And $name = $skip Then
                If $closing Then
                    $skipDepth -= 1
                    If $skipDepth <= 0 Then $skip = ""
                ElseIf Not $self Then
                    $skipDepth += 1
                EndIf
            EndIf
            ContinueLoop
        EndIf
        If $atom <> "" Then
            If $isTag And $name = $atom Then
                If $closing Then
                    $atomDepth -= 1
                    If $atomDepth <= 0 Then
                        P136SegAdd("v", $atomBuf & $t, $atom)
                        $atom = ""
                        $atomBuf = ""
                        ContinueLoop
                    EndIf
                ElseIf Not $self Then
                    $atomDepth += 1
                EndIf
                $atomBuf &= $t
                ContinueLoop
            EndIf
            If $isTag And $name <> "!" And Not P136Inline($name) Then
                P136SegAdd("v", $atomBuf, $atom)
                $atom = ""
                $atomBuf = ""
            Else
                $atomBuf &= $t
                ContinueLoop
            EndIf
        EndIf
        If $code <> "" Then
            Local $leave = False
            If $isTag And $name = $code Then
                If $closing Then
                    $codeDepth -= 1
                    If $codeDepth <= 0 Then $leave = True
                ElseIf Not $self Then
                    $codeDepth += 1
                EndIf
            ElseIf $isTag And $code = "p" And Not $closing And StringRegExp($name, "^(p|div|h[1-6]|table|ul|ol|dl|pre|blockquote|hr)$") Then
                P136CodeLineEnd()
                $code = ""
            EndIf
            If $code <> "" Then
                If $leave Then
                    P136CodeLineEnd()
                    If $mode = 1 Then $p136Out &= $t
                    $code = ""
                    $p136cBlock = False
                    ContinueLoop
                EndIf
                If $isTag Then
                    If $name = "br" Then
                        P136CodeLineEnd()
                        If $mode = 1 Then $p136Out &= $t
                    ElseIf $p136cComment And $name <> "!" And P136Inline($name) Then
                        P136SegAdd(($closing ? "c" : ($self ? "v" : "o")), $t, $name)
                    Else
                        If $p136cComment Then
                            P136Flush()
                            $p136cComment = False
                        EndIf
                        If $mode = 1 Then $p136Out &= $t
                    EndIf
                Else
                    P136CodeText($t)
                EndIf
                ContinueLoop
            EndIf
        EndIf
        If Not $isTag Then
            P136SegAdd("t", $t, "")
            ContinueLoop
        EndIf
        If $name = "!" Then
            P136Flush()
            If $mode = 1 Then $p136Out &= $t
            ContinueLoop
        EndIf
        If Not $closing And StringRegExp($name, "^(script|style|textarea|template|svg|math|noscript|xmp|object|applet|iframe|head-script)$") Then
            P136Flush()
            If $mode = 1 Then $p136Out &= $t
            If Not $self Then
                $skip = $name
                $skipDepth = 1
            EndIf
            ContinueLoop
        EndIf
        If Not $closing And P136CodeStart($name, $t) Then
            P136Flush()
            If $mode = 1 Then $p136Out &= $t
            If Not $self Then
                $code = $name
                $codeDepth = 1
                P136CodeReset()
                $p136cBlock = False
            EndIf
            ContinueLoop
        EndIf
        If Not $closing And Not $self And StringRegExp($name, "^(code|kbd|samp|tt|var)$") Then
            $atom = $name
            $atomDepth = 1
            $atomBuf = $t
            ContinueLoop
        EndIf
        If P136Inline($name) Then
            P136SegAdd(($closing ? "c" : ($self ? "v" : "o")), $t, $name)
            ContinueLoop
        EndIf
        P136Flush()
        If $mode = 1 Then $p136Out &= $t
    Next
    If $atom <> "" Then P136SegAdd("v", $atomBuf, $atom)
    If $code <> "" Then P136CodeLineEnd()
    P136Flush()
    If $mode = 1 Then Return $p136Out
    Return ""
EndFunc

; 翻譯整份 HTML（收集→翻譯→第二輪補翻→重建）。
Func P136Translate($html, ByRef $why)
    ; 第一輪收集與翻譯；標記驗證失敗的段落於第二輪改為純文字逐段翻譯。
    For $round = 1 To 2
        P136Pass($html, 0)
        If @error Then
            $why = "HTML 解析失敗"
            Return SetError(1, 0, "")
        EndIf
        If $p136Need.Count = 0 Then ExitLoop
        If Not P136TranslateNeed() Then
            $why = ($p136Fatal ? $p136Error : "使用者停止")
            Return SetError(1, 0, "")
        EndIf
    Next
    Local $result = P136Pass($html, 1)
    If @error Then
        $why = "HTML 解析失敗"
        Return SetError(1, 0, "")
    EndIf
    Return $result
EndFunc

; ---------- 檔案讀寫：保留原編碼；必要時改存 UTF-8 並同步宣告 ----------
Func P136ReadHtml($source, ByRef $charset, ByRef $enc, ByRef $bom, ByRef $why)
    Local $fh = FileOpen($source, 16)
    If $fh = -1 Then
        $why = "無法讀取"
        Return SetError(1, 0, "")
    EndIf
    Local $raw = FileRead($fh)
    FileClose($fh)
    $enc = 4
    $charset = ""
    $bom = Binary("0x")
    Local $body = $raw
    If BinaryLen($raw) = 0 Then Return ""
    If BinaryMid($raw, 1, 3) = Binary("0xEFBBBF") Then
        $bom = Binary("0xEFBBBF")
        $body = BinaryMid($raw, 4)
    ElseIf BinaryMid($raw, 1, 2) = Binary("0xFFFE") Then
        $enc = 2
        $bom = Binary("0xFFFE")
        $body = BinaryMid($raw, 3)
    ElseIf BinaryMid($raw, 1, 2) = Binary("0xFEFF") Then
        $enc = 3
        $bom = Binary("0xFEFF")
        $body = BinaryMid($raw, 3)
    EndIf
    Local $head = BinaryToString(BinaryMid($raw, 1, 4096), 1)
    Local $declared = StringRegExp($head, '(?i)(?:charset\s*=\s*["'']?\s*|encoding\s*=\s*["'']\s*)([a-z0-9_-]+)', 1)
    If $bom = Binary("0x") And IsArray($declared) Then
        Switch StringLower($declared[0])
            Case "big5", "cp950", "windows-950", "x-big5"
                $charset = "big5"
            Case "gb2312", "gbk", "cp936", "windows-936"
                $charset = "gbk"
            Case "gb18030"
                $charset = "gb18030"
            Case "shift_jis", "shift-jis", "sjis", "cp932", "windows-31j"
                $charset = "shift_jis"
            Case "euc-kr", "cp949", "ks_c_5601-1987"
                $charset = "ks_c_5601-1987"
            Case "windows-1252", "iso-8859-1", "us-ascii", "windows-1250", "windows-1251", "koi8-r", "iso-8859-2"
                $charset = StringLower($declared[0])
        EndSwitch
    EndIf
    Local $html = ""
    If $charset <> "" Then
        $html = HH_SourceCharsetDecode($body, $charset)
        If @error Then
            $why = "原始編碼解碼失敗：" & $charset
            Return SetError(1, 0, "")
        EndIf
        Local $check = HH_SourceCharsetEncode($html, $charset)
        If @error Or $check <> $body Then
            $why = "原始編碼無法無損往返：" & $charset
            Return SetError(1, 0, "")
        EndIf
        Return $html
    EndIf
    $html = BinaryToString($body, $enc)
    If $enc <> 4 Or StringToBinary($html, 4) = $body Then Return $html
    If HH_SourceHasUtf8Multibyte($body) Then
        $why = "檔案混用 UTF-8 與其他編碼"
        Return SetError(1, 0, "")
    EndIf
    ; 無宣告的舊碼頁：先試系統 ANSI，再試常見中日韓碼頁。
    Local $acp = _DecodeCodepage($body, 0)
    If BinaryToString(StringToBinary($acp, 1), 1) = $acp And StringToBinary($acp, 1) = $body Then
        $charset = "ansi"
        Return $acp
    EndIf
    Local $try[4] = ["big5", "gbk", "shift_jis", "windows-1252"]
    For $i = 0 To 3
        Local $candidate = HH_SourceCharsetDecode($body, $try[$i])
        If @error Then ContinueLoop
        Local $round = HH_SourceCharsetEncode($candidate, $try[$i])
        If @error Or $round <> $body Then ContinueLoop
        $charset = $try[$i]
        Return $candidate
    Next
    $why = "無法安全辨識原始編碼"
    Return SetError(1, 0, "")
EndFunc

; 以原編碼寫回；無法表示時改存 UTF-8 並同步 charset 宣告。
Func P136WriteHtml($target, $result, $charset, $enc, $bom, ByRef $why)
    Local $encoded, $ok = False
    If $charset = "ansi" Then
        $encoded = StringToBinary($result, 1)
        $ok = (BinaryToString($encoded, 1) = $result)
    ElseIf $charset <> "" Then
        $encoded = HH_SourceCharsetEncode($result, $charset)
        If Not @error Then
            Local $verify = HH_SourceCharsetDecode($encoded, $charset)
            $ok = (Not @error And $verify = $result)
        EndIf
    Else
        $encoded = StringToBinary($result, $enc)
        $ok = (BinaryToString($encoded, $enc) = $result)
    EndIf
    If Not $ok Then
        ; 譯文含原碼頁無法表示的字元：改存 UTF-8，並同步 HTML／XML 宣告。
        $result = StringRegExpReplace($result, '(?i)(charset\s*=\s*["'']?\s*)([a-z0-9_-]+)', '${1}utf-8')
        $result = StringRegExpReplace($result, '(?i)(<\?xml[^>]*encoding\s*=\s*["''])([a-z0-9_-]+)', '${1}utf-8')
        If Not StringRegExp($result, "(?i)<meta[^>]+charset") Then $result = StringRegExpReplace($result, "(?i)(<head[^>]*>)", '${1}<meta http-equiv="Content-Type" content="text/html; charset=utf-8">', 1)
        $encoded = StringToBinary($result, 4)
        $bom = Binary("0x")
    EndIf
    Local $f = FileOpen($target & ".hh_tmp", 2 + 8 + 16)
    If $f = -1 Then
        $why = "無法寫入"
        Return False
    EndIf
    FileWrite($f, $bom & $encoded)
    FileClose($f)
    If Not FileMove($target & ".hh_tmp", $target, 1 + 8) Then
        $why = "無法儲存"
        Return False
    EndIf
    Return True
EndFunc

; 翻譯單一 HTML 檔案。
Func P136HtmlFile($from, $dstPath, ByRef $why)
    Local $charset, $enc, $bom
    Local $html = P136ReadHtml($from, $charset, $enc, $bom, $why)
    If @error Then Return False
    If $html = "" Then Return (FileCopy($from, $dstPath, 1 + 8) <> 0)
    Local $result = P136Translate($html, $why)
    If @error Then Return False
    Return P136WriteHtml($dstPath, $result, $charset, $enc, $bom, $why)
EndFunc

; 目標語言對應的 ANSI 字碼頁（目錄、索引與 HHP 使用）。
Func P136TargetCp()
    If $p136Hhp And $p136Lcid > 0 Then
        Local $cp = P135Codepage($p136Lcid)
        If $cp > 0 Then Return $cp
    EndIf
    Return 0
EndFunc

; 以指定字碼頁編碼，並回報是否有無法表示的字元。
Func P136CpBytes($s, $cp, ByRef $lossy)
    $lossy = False
    If $s = "" Then Return Binary("0x")
    Local $r = DllCall("kernel32.dll", "int", "WideCharToMultiByte", "uint", $cp, "dword", 0, "wstr", $s, "int", -1, "ptr", 0, "int", 0, "ptr", 0, "ptr", 0)
    If @error Or Not IsArray($r) Or $r[0] < 1 Then
        $lossy = True
        Return Binary("0x")
    EndIf
    Local $size = $r[0], $buf = DllStructCreate("byte[" & $size & "]"), $used = DllStructCreate("int")
    $r = DllCall("kernel32.dll", "int", "WideCharToMultiByte", "uint", $cp, "dword", 0, "wstr", $s, "int", -1, "struct*", $buf, "int", $size, "ptr", 0, "struct*", $used)
    If @error Or Not IsArray($r) Or $r[0] < 1 Then
        $lossy = True
        Return Binary("0x")
    EndIf
    If DllStructGetData($used, 1) Then $lossy = True
    Return BinaryMid(DllStructGetData($buf, 1), 1, $r[0] - 1)
EndFunc

; 無法以字碼頁表示的字元改成 &#數字; 參照。
Func P136CpText($s, $cp)
    ; 目錄／索引／HHP 為 ANSI；無法表示的字元改為數值字元參照。
    Local $lossy
    P136CpBytes($s, $cp, $lossy)
    If Not $lossy Then Return $s
    Local $out = ""
    For $i = 1 To StringLen($s)
        Local $ch = StringMid($s, $i, 1)
        P136CpBytes($ch, $cp, $lossy)
        If $lossy Then
            $out &= "&#" & AscW($ch) & ";"
        Else
            $out &= $ch
        EndIf
    Next
    Return $out
EndFunc

; 以指定字碼頁寫入檔案。
Func P136WriteCp($target, $text, $cp, ByRef $why)
    Local $lossy, $bytes = P136CpBytes($text, $cp, $lossy)
    If $lossy Or ($text <> "" And BinaryLen($bytes) = 0) Then
        $why = "無法以碼頁 " & $cp & " 儲存"
        Return False
    EndIf
    Local $f = FileOpen($target & ".hh_tmp", 2 + 8 + 16)
    If $f = -1 Then
        $why = "無法寫入"
        Return False
    EndIf
    FileWrite($f, $bytes)
    FileClose($f)
    If Not FileMove($target & ".hh_tmp", $target, 1 + 8) Then
        $why = "無法儲存"
        Return False
    EndIf
    Return True
EndFunc

; 讀取標籤的 value 屬性值與引號種類。
Func P136AttrValue($tag, ByRef $q)
    Local $m = StringRegExp($tag, "(?i)\bvalue\s*=\s*(""([^""]*)""|'([^']*)'|([^\s>]+))", 1)
    If @error Then Return SetError(1, 0, "")
    $q = StringLeft($m[0], 1)
    If $q = '"' Or $q = "'" Then Return StringTrimLeft(StringTrimRight($m[0], 1), 1)
    $q = ""
    Return $m[0]
EndFunc

; 走訪 sitemap，翻譯 Name 參數（Local 連結不變）。
Func P136Sitemap($text, $mode, $cp)
    Local $tokens = StringRegExp($text, "(?s)(<!--.*?-->|<[^>]*>|[^<]+|<)", 3)
    If @error Then Return SetError(1, 0, "")
    Local $out = ""
    For $i = 0 To UBound($tokens) - 1
        Local $t = $tokens[$i]
        If StringRegExp($t, "(?i)^<param\b") And StringRegExp($t, "(?i)\bname\s*=\s*[""']?name[""']?[\s/>]") Then
            Local $q, $value = P136AttrValue($t, $q)
            If Not @error Then
                Local $lead, $core, $trail
                P136Split(HH_ExportDecodeEntities($value), $lead, $core, $trail)
                If P136Worth($core) Then
                    $p136Mode = $mode
                    Local $tr = P136Unit($core)
                    If Not @error And $mode = 1 Then
                        Local $v = StringReplace(StringReplace(StringReplace(StringReplace($lead & $tr & $trail, "&", "&amp;"), '"', "&quot;"), "<", "&lt;"), ">", "&gt;")
                        $v = P136CpText($v, $cp)
                        $v = StringReplace(StringReplace($v, "\", "\\"), "$", "\$")
                        $t = StringRegExpReplace($t, "(?i)(\bvalue\s*=\s*)(""[^""]*""|'[^']*'|[^\s>]+)", '${1}"' & $v & '"', 1)
                    EndIf
                EndIf
            EndIf
        EndIf
        $out &= $t
    Next
    Return $out
EndFunc

; 翻譯 HHC／HHK 檔案。
Func P136SitemapFile($from, $dstPath, ByRef $why)
    Local $text = P133ReadText($from)
    If @error Then
        $why = "無法讀取"
        Return False
    EndIf
    Local $cp = P136TargetCp()
    P136Sitemap($text, 0, $cp)
    If Not P136TranslateNeed() Then
        $why = ($p136Fatal ? $p136Error : "使用者停止")
        Return False
    EndIf
    Local $result = P136Sitemap($text, 1, $cp)
    If @error Then
        $why = "目錄／索引解析失敗"
        Return False
    EndIf
    If $cp = 0 Then $result = P136CpText($result, 0)
    Return P136WriteCp($dstPath, $result, $cp, $why)
EndFunc

; 翻譯 HHP 的 Title 與視窗標題，並更新 Language。
Func P136Project($text, $mode, $cp)
    Local $lines = StringSplit(StringReplace($text, @CRLF, @LF), @LF, 2), $section = "", $out = "", $hasLanguage = False
    #forceref $hasLanguage
    For $i = 0 To UBound($lines) - 1
        Local $line = $lines[$i], $m
        If StringRegExp($line, "^\s*\[[^\]]+\]\s*$") Then $section = StringUpper(StringStripWS($line, 8))
        If $section = "[OPTIONS]" Then
            If StringRegExp($line, "(?i)^\s*Language\s*=") Then
                $hasLanguage = True
                If $p136Lcid > 0 Then $line = "Language=0x" & Hex($p136Lcid, 4)
            ElseIf StringRegExp($line, "(?i)^\s*Title\s*=") Then
                $m = StringRegExp($line, "(?i)^(\s*Title\s*=)(.*)$", 1)
                If Not @error And P136Worth($m[1]) Then
                    $p136Mode = $mode
                    Local $tr = P136Unit(StringStripWS($m[1], 3))
                    If Not @error Then $line = $m[0] & P136CpText($tr, $cp)
                EndIf
            EndIf
        ElseIf $section = "[WINDOWS]" Then
            $m = StringRegExp($line, '^([^=;\[]+=\s*)"([^"]*)"(.*)$', 1)
            If Not @error And P136Worth($m[1]) Then
                $p136Mode = $mode
                Local $cap = P136Unit(StringStripWS($m[1], 3))
                If Not @error Then $line = $m[0] & '"' & P136CpText(StringReplace($cap, '"', "'"), $cp) & '"' & $m[2]
            EndIf
        EndIf
        $out &= $line & ($i < UBound($lines) - 1 ? @CRLF : "")
        If StringUpper(StringStripWS($line, 8)) = "[OPTIONS]" And $p136Lcid > 0 And Not StringRegExp($text, "(?im)^\s*Language\s*=") Then $out &= "Language=0x" & Hex($p136Lcid, 4) & @CRLF
    Next
    Return $out
EndFunc

; 翻譯 HHP 檔案（碼頁與 Windows 不同時提醒）。
Func P136ProjectFile($from, $dstPath, ByRef $why)
    Local $text = P133ReadText($from)
    If @error Then
        $why = "無法讀取"
        Return False
    EndIf
    Local $cp = P136TargetCp()
    P136Project($text, 0, $cp)
    If Not P136TranslateNeed() Then
        $why = ($p136Fatal ? $p136Error : "使用者停止")
        Return False
    EndIf
    Local $result = P136Project($text, 1, $cp)
    If $cp = 0 Then $result = P136CpText($result, 0)
    If Not P136WriteCp($dstPath, $result, $cp, $why) Then Return False
    Local $acp = DllCall("kernel32.dll", "uint", "GetACP")
    If Not @error And IsArray($acp) And $cp > 0 And $cp <> $acp[0] Then P136Note("[注意] HHP Language 碼頁 " & $cp & " 與目前 Windows ANSI 碼頁 " & $acp[0] & " 不同；hhc.exe 打包目錄／索引時建議在相同語系的 Windows 執行。")
    Return True
EndFunc
