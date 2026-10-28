#include-once
; =============================================================================
; Html Helper － 整份翻譯引擎（命令列）
;
; --translate-chm 的主流程：必要時先解包 CHM、逐檔翻譯或複製、快取與續譯、
; 批次請求（自動重試、縮小批次、驗證格式標記）。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 位元組中是否含有效的 UTF-8 多位元組字元。
Func HH_SourceHasUtf8Multibyte($bytes)
    Local $n = BinaryLen($bytes)
    For $i = 1 To $n
        Local $a = Dec(Hex(BinaryMid($bytes, $i, 1)))
        Local $count = 0
        If $a >= 194 And $a <= 223 Then
            $count = 1
        ElseIf $a >= 224 And $a <= 239 Then
            $count = 2
        ElseIf $a >= 240 And $a <= 244 Then
            $count = 3
        EndIf
        If $count = 0 Or $i + $count > $n Then ContinueLoop
        Local $valid = True
        For $j = 1 To $count
            Local $b = Dec(Hex(BinaryMid($bytes, $i + $j, 1)))
            If $b < 128 Or $b > 191 Then
                $valid = False
                ExitLoop
            EndIf
        Next
        If $valid Then Return True
    Next
    Return False
EndFunc

; 以 ADODB.Stream 依指定字元集解碼。
Func HH_SourceCharsetDecode($bytes, $charset)
    Local $st = ObjCreate("ADODB.Stream")
    If Not IsObj($st) Then Return SetError(1, 0, "")
    $st.Type = 1
    $st.Open()
    $st.Write($bytes)
    $st.Position = 0
    $st.Type = 2
    $st.Charset = $charset
    Local $value = $st.ReadText(-1)
    $st.Close()
    Return $value
EndFunc

; 以 ADODB.Stream 依指定字元集編碼。
Func HH_SourceCharsetEncode($value, $charset)
    Local $st = ObjCreate("ADODB.Stream")
    If Not IsObj($st) Then Return SetError(1, 0, Binary("0x"))
    $st.Type = 2
    $st.Charset = $charset
    $st.Open()
    $st.WriteText($value)
    $st.Position = 0
    $st.Type = 1
    Local $bytes = $st.Read()
    $st.Close()
    Return $bytes
EndFunc

; ---------- 命令模式：--translate-chm ----------
Func P136Usage()
    Return '--translate-chm "來源資料夾或.chm" "輸出資料夾" [--profile 1] [--lang "繁體中文（臺灣）"] [--lcid 1028] [--comments 1] [--toc 1] [--index 0] [--hhp 1] [--engine ai|google] [--code zh-TW]' & @CRLF & '  --engine google：Google 翻譯免費機器翻譯，免 API Key；--code 為 Google 語言代碼（未指定時依 --lang 推算）。'
EndFunc

; --translate-chm 入口：解析參數並執行翻譯。
Func P136Main()
    If $CmdLine[0] < 3 Or Mod($CmdLine[0] - 3, 2) Then
        ConsoleWrite("命令列參數錯誤。" & @CRLF & P136Usage() & @CRLF)
        Return 2
    EndIf
    Local $src = $CmdLine[2], $dest = P133Path($CmdLine[3]), $profile = 0
    $p136Language = "繁體中文（臺灣）"
    $p136Lcid = 0x404
    For $i = 4 To $CmdLine[0] Step 2
        Local $v = $CmdLine[$i + 1]
        Switch StringLower($CmdLine[$i])
            Case "--profile"
                $profile = Number($v)
            Case "--lang"
                $p136Language = StringStripWS($v, 3)
            Case "--lcid"
                $p136Lcid = Number($v)
            Case "--comments"
                $p136Comments = (Number($v) <> 0)
            Case "--toc"
                $p136Toc = (Number($v) <> 0)
            Case "--index"
                $p136Index = (Number($v) <> 0)
            Case "--hhp"
                $p136Hhp = (Number($v) <> 0)
            Case "--engine"
                $p136Engine = StringLower(StringStripWS($v, 3))
                If $p136Engine <> "google" And $p136Engine <> "ai" Then
                    ConsoleWrite("--engine 只接受 ai 或 google。" & @CRLF)
                    Return 2
                EndIf
            Case "--code"
                $p136LangCode = StringStripWS($v, 3)
            Case Else
                ConsoleWrite("不支援參數：" & $CmdLine[$i] & @CRLF & P136Usage() & @CRLF)
                Return 2
        EndSwitch
    Next
    $g133Log = FileOpen($dest & "." & @AutoItPID & ".log", 138)
    $g133WorkerPtr = P133Map(@AutoItPID, True, $g133WorkerHandle)
    _Crypt_Startup()
    Local $code = P136Run($src, $dest, $profile)
    _Crypt_Shutdown()
    P133Progress(($code = 0 ? "完成" : "結束"), (($code = 0 Or $code = 21) ? 1 : 0), 1, "ExitCode=" & $code, True)
    If $p136ErrHandle <> -1 Then FileClose($p136ErrHandle)
    If $p136CacheHandle <> -1 Then FileClose($p136CacheHandle)
    $p136ErrHandle = -1
    $p136CacheHandle = -1
    If $g133Log <> -1 Then
        FileWriteLine($g133Log, "ExitCode=" & $code)
        FileClose($g133Log)
        $g133Log = -1
    EndIf
    P133Unmap($g133WorkerPtr, $g133WorkerHandle)
    Return $code
EndFunc

; 使用者是否要求停止（GUI 寫出的取消檔）。
Func P136Cancelled()
    If $p136CancelRequested Then Return True
    If $p136Cancel <> "" And FileExists($p136Cancel) Then $p136CancelRequested = True
    Return $p136CancelRequested
EndFunc

; 可被取消的等待。
Func P136Sleep($ms)
    Local $t = TimerInit()
    While TimerDiff($t) < $ms
        If P136Cancelled() Then Return False
        Sleep(100)
    WEnd
    Return True
EndFunc

; 寫入 errors.txt。
Func P136Note($text)
    If $p136ErrHandle <> -1 Then FileWriteLine($p136ErrHandle, $text)
EndFunc

; 進度顯示用的統計文字。
Func P136Stats()
    Return $p136Item & @CRLF & "檔案 " & $p136FileNo & " / " & $p136FileTotal & "｜API " & $p136ApiCalls & " 次｜快取 " & $p136Hits & " 段｜保留原文 " & $p136Failed & " 段"
EndFunc

; 翻譯主流程：解包、建立狀態與快取、逐檔處理（已完成且未變更的檔案略過）。
Func P136Run($src, $dest, $profile)
    If $p136Engine = "google" Then
        $p136Config = P136GoogleConfig()
    Else
        If $profile < 1 Then $profile = P136Active()
        If $profile > P136Count() Then Return P133Report(2, "AI 設定檔不存在：" & $profile)
        $p136Config = P136Load($profile)
    EndIf
    Local $envKey = EnvGet("HH136_KEY")
    EnvSet("HH136_KEY")
    If $envKey <> "" Then $p136Config.Item("key") = $envKey
    If Not P136ValidEndpoint($p136Config.Item("endpoint")) Then Return P133Report(2, "AI Endpoint 不正確，請在 GUI 的 AI API 設定修正。")
    If $p136Config.Item("key") = "" And P136NeedsKey($p136Config) Then Return P133Report(2, "沒有可用的 API Key（未保存、無法解密或只保存在 GUI 本次執行）。")
    If $p136Language = "" Then Return P133Report(2, "缺少目標語言。")
    If $p136Config.Item("protocol") = 4 Then
        If $p136LangCode = "" Or $p136LangCode = "custom" Then $p136LangCode = P136CodeFor($p136Language)
        If $p136LangCode = "" Then Return P133Report(2, "Google 翻譯需要語言代碼（--code，例如 zh-TW、fr、yue）。")
    EndIf
    $p136Cancel = $dest & ".cancel"
    $src = P133Path($src)
    If Not FileExists($src) Then Return P133Report(2, "來源不存在：" & $src)
    If Not StringInStr(FileGetAttrib($src), "D") Then
        If Not StringRegExp($src, "(?i)\.chm$") Then Return P133Report(2, "檔案來源只接受 .chm。")
        Local $unpacked = $dest & "_原文解包"
        If P133Empty($unpacked) Then
            P133Progress("ITSS 解包 CHM", 0, 0, $src, True)
            Local $x = P133Extract($src, $unpacked)
            If $x <> 0 Then Return $x
        ElseIf Not FileExists($unpacked & "\__htmlhelper_manifest.tsv") Then
            Return P133Report(5, "解包資料夾已存在但不是本程式匯出：" & $unpacked)
        Else
            P133Report(0, "沿用既有解包資料夾：" & $unpacked)
        EndIf
        $src = $unpacked
    EndIf
    If P136Inside($dest, $src) Or P136Inside($src, $dest) Then Return P133Report(5, "輸出資料夾不可位於來源內，也不可包含來源。")
    Local $state = $dest & ".hhtrans", $signature = $src & @TAB & $p136Language & @TAB & ($p136Comments ? 1 : 0) & ($p136Toc ? 1 : 0) & ($p136Index ? 1 : 0) & ($p136Hhp ? 1 : 0) & @TAB & $p136Lcid
    If Not P133Empty($dest) Then
        Local $saved = FileRead($state & "\job.txt")
        If StringStripWS($saved, 3) <> $signature Then Return P133Report(5, "輸出資料夾已有內容，且不是相同來源、語言與選項的續譯工作。")
        P133Report(0, "續譯既有輸出資料夾。")
    EndIf
    If Not DirCreate($dest) Or Not DirCreate($state) Then Return P133Report(5, "無法建立輸出或狀態資料夾。")
    Local $hJob = FileOpen($state & "\job.txt", 2 + 256)
    If $hJob = -1 Then Return P133Report(5, "無法寫入工作狀態。")
    FileWrite($hJob, $signature)
    FileClose($hJob)
    P133Progress("讀取翻譯快取", 0, 0, $state, True)
    $p136Cache = ObjCreate("Scripting.Dictionary")
    $p136Need = ObjCreate("Scripting.Dictionary")
    $p136Bad = ObjCreate("Scripting.Dictionary")
    Local $done = ObjCreate("Scripting.Dictionary")
    P136LoadTsv($state & "\cache.tsv", $p136Cache)
    P136LoadTsv($state & "\done.tsv", $done)
    $p136CacheHandle = FileOpen($state & "\cache.tsv", 1 + 256)
    $p136ErrHandle = FileOpen($state & "\errors.txt", 2 + 256)
    Local $hDone = FileOpen($state & "\done.tsv", 1 + 256)
    If $p136CacheHandle = -1 Or $p136ErrHandle = -1 Or $hDone = -1 Then Return P133Report(5, "無法寫入快取或狀態檔。")
    P136Note("來源：" & $src & @CRLF & "輸出：" & $dest & @CRLF & "目標語言：" & $p136Language & @CRLF & "AI：" & $p136Config.Item("name") & "／" & $p136Config.Item("model"))
    P133Progress("列舉來源檔案", 0, 0, $src, True)
    Local $files = P133Files($src)
    If @error Or Not IsArray($files) Then
        FileClose($hDone)
        Return P133Report(4, "來源無法完整列舉（或含重新解析點）。")
    EndIf
    Local $dirs = _FileListToArrayRec($src, "*", $FLTAR_FOLDERS, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_RELPATH)
    If IsArray($dirs) Then
        For $i = 1 To $dirs[0]
            DirCreate($dest & "\" & $dirs[$i])
        Next
    EndIf
    $p136FileTotal = UBound($files)
    Local $partial = 0, $code = 0
    For $i = 0 To $p136FileTotal - 1
        If P136Cancelled() Then
            $code = 20
            ExitLoop
        EndIf
        Local $rel = $files[$i], $from = $src & "\" & $rel, $to = $dest & "\" & $rel
        $p136FileNo = $i + 1
        $p136Item = $rel
        P133Progress("翻譯與複製", $i, $p136FileTotal, P136Stats(), True)
        Local $identity = FileGetSize($from) & "|" & FileGetTime($from, 0, 1)
        If $done.Exists($rel) And FileExists($to) Then
            If $done.Item($rel) = $identity Then ContinueLoop
        EndIf
        Local $kind = P136Kind($rel), $why = "", $ok = True, $before = $p136Failed
        Switch $kind
            Case "html"
                $ok = P136HtmlFile($from, $to, $why)
            Case "hhc", "hhk"
                $ok = P136SitemapFile($from, $to, $why)
            Case "hhp"
                $ok = P136ProjectFile($from, $to, $why)
            Case Else
                $ok = (FileCopy($from, $to, 1 + 8) <> 0)
                If Not $ok Then $why = "複製失敗"
        EndSwitch
        If $p136Fatal Then
            $code = 30
            ExitLoop
        EndIf
        If P136Cancelled() Then
            $code = 20
            ExitLoop
        EndIf
        If Not $ok Then
            $partial += 1
            P136Note("[檔案] " & $rel & "：" & $why & "（已複製原檔）")
            P133Report(0, "保留原檔：" & $rel & "：" & $why)
            FileCopy($from, $to, 1 + 8)
            ContinueLoop
        EndIf
        If $p136Failed > $before Then
            $partial += 1
            ContinueLoop
        EndIf
        FileWriteLine($hDone, P133Tsv($rel) & @TAB & P133Tsv($identity))
        $done.Item($rel) = $identity
    Next
    FileClose($hDone)
    If $code = 30 Then Return P133Report(30, "AI API 停止：" & $p136Error)
    If $code = 20 Then Return P133Report(20, "使用者停止。已完成的檔案與快取已保留。")
    P136Note("API 請求 " & $p136ApiCalls & " 次，快取 " & $p136Hits & " 段，保留原文 " & $p136Failed & " 段。")
    If $partial > 0 Then Return P133Report(21, "完成，但 " & $partial & " 個檔案有段落保留原文；清單：" & $state & "\errors.txt" & @CRLF & $dest)
    Return P133Report(0, "翻譯完成：" & $dest)
EndFunc

; 讀取 TSV（快取或完成清單）到字典。
Func P136LoadTsv($file, $dict)
    If Not FileExists($file) Then Return
    Local $h = FileOpen($file, 256)
    If $h = -1 Then Return
    Local $text = FileRead($h)
    FileClose($h)
    Local $lines = StringSplit(StringReplace($text, @CR, ""), @LF, 2)
    For $i = 0 To UBound($lines) - 1
        Local $p = StringInStr($lines[$i], @TAB)
        If $p < 2 Then ContinueLoop
        $dict.Item(P133TsvDecode(StringLeft($lines[$i], $p - 1))) = P133TsvDecode(StringMid($lines[$i], $p + 1))
    Next
EndFunc

; 依副檔名決定處理方式（html／hhc／hhk／hhp／直接複製）。
Func P136Kind($rel)
    Local $l = StringLower($rel)
    If StringRegExp($l, "\.(htm|html|xhtml|xht)$") Then Return "html"
    If StringRegExp($l, "\.hhc$") And $p136Toc Then Return "hhc"
    If StringRegExp($l, "\.hhk$") And $p136Index Then Return "hhk"
    If StringRegExp($l, "\.hhp$") And $p136Hhp Then Return "hhp"
    Return "copy"
EndFunc

; ---------- AI 批次翻譯 ----------
Func P136Prompt()
    Local $s = "You translate software help documentation (CHM / HTML Help) into " & $p136Language & "." & @LF & _
        "The input contains numbered items. Every item starts with its own marker line such as [[HH_0001]]." & @LF & _
        "Rules:" & @LF & _
        "1. Output every marker exactly once, in the same order, each on its own line, followed by the translation of that item. Output nothing else: no explanations, no Markdown, no code fences." & @LF & _
        "2. <t1>, </t1>, <t2/> and similar tags are formatting placeholders. Keep every placeholder exactly as written and the same number of times. You may move them to fit the target word order, but <tN> must stay before </tN>." & @LF & _
        "3. Never translate or change program code, function names, keywords, variables ($name), macros (@Name), constants, file names, paths, URLs, command-line switches, key names or numbers." & @LF & _
        "4. Keep single-line items on one line. If an item is already in the target language or must not be translated, output it unchanged." & @LF & _
        "5. Use natural, standard technical terminology of the target language."
    If StringInStr($p136Language, "繁體") Or StringInStr($p136Language, "臺灣") Or StringInStr($p136Language, "台灣") Then $s &= @LF & "6. Use Traditional Chinese characters and Taiwan software terminology."
    Return $s
EndFunc

; 送出翻譯請求並等待回應（可取消、有逾時）。
Func P136Post($system, $user, ByRef $status, ByRef $resp, ByRef $retryAfter)
    Local $url, $body, $headers
    P136Build($p136Config, $system, $user, $url, $body, $headers)
    $status = 0
    $resp = ""
    $retryAfter = 0
    Local $http = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($http) Then Return
    Local $timeout = $p136Config.Item("timeout")
    $p136Com = ""
    $http.SetTimeouts(15000, 15000, 30000, $timeout * 1000)
    $http.Open("POST", $url, True)
    If @error Then Return
    P136SetHeaders($http, $headers)
    $http.Send(StringToBinary($body, 4))
    If @error Then Return
    Local $clock = TimerInit()
    While 1
        Local $finished = $http.WaitForResponse(1)
        If @error Then Return
        If $finished Then ExitLoop
        If P136Cancelled() Then
            $http.Abort()
            $status = -2
            Return
        EndIf
        If TimerDiff($clock) > ($timeout + 10) * 1000 Then
            $http.Abort()
            $status = -1
            Return
        EndIf
        P133Progress("等待翻譯回應（" & Int(TimerDiff($clock) / 1000) & " 秒）", $p136FileNo - 1, $p136FileTotal, P136Stats())
    WEnd
    $status = $http.Status
    $resp = P136ResponseText($http)
    Local $ra = $http.GetResponseHeader("Retry-After")
    If Not @error And StringIsDigit($ra) Then $retryAfter = Number($ra)
EndFunc

; 驗證譯文保留了所有格式標記與 $變數／@巨集。
Func P136MarkersOk($core, $tr)
    Local $a = StringRegExp($core, "</?t[0-9]+/?>", 3), $na = 0
    If Not @error Then $na = UBound($a)
    Local $b = StringRegExp($tr, "</?t[0-9]+/?>", 3), $nb = 0
    If Not @error Then $nb = UBound($b)
    If $na <> $nb Then Return False
    If $na > 0 Then
        Local $count = ObjCreate("Scripting.Dictionary")
        For $i = 0 To $na - 1
            $count.Item($a[$i]) = $count.Item($a[$i]) + 1
        Next
        For $i = 0 To $nb - 1
            If Not $count.Exists($b[$i]) Then Return False
            $count.Item($b[$i]) = $count.Item($b[$i]) - 1
            If $count.Item($b[$i]) < 0 Then Return False
        Next
        For $i = 0 To $nb - 1
            If StringLeft($b[$i], 2) = "</" Then
                Local $open = "<" & StringTrimLeft($b[$i], 2)
                Local $po = StringInStr($tr, $open, 1), $pc = StringInStr($tr, $b[$i], 1)
                If $po = 0 Or $po > $pc Then Return False
            EndIf
        Next
    EndIf
    Local $ids = StringRegExp($core, "[\$@][A-Za-z_][A-Za-z0-9_]*", 3)
    If Not @error Then
        For $i = 0 To UBound($ids) - 1
            If Not StringInStr($tr, $ids[$i], 1) Then Return False
        Next
    EndIf
    Return True
EndFunc

; 翻譯所有待翻段落（批次逐輪縮小，最後仍失敗的保留原文）。
Func P136TranslateNeed()
    If $p136Need.Count = 0 Then Return True
    Local $queue = $p136Need.Keys()
    $p136Need.RemoveAll()
    Local $round = 1, $limit = $p136Config.Item("items"), $chars = $p136Config.Item("chars")
    If $p136Config.Item("protocol") = 4 Then
        If $limit > 50 Then $limit = 50
        If $chars > 4000 Then $chars = 4000
    EndIf
    While UBound($queue) > 0 And $round <= 3
        Local $failed[0], $from = 0, $n = UBound($queue)
        If $round = 2 Then $limit = ($limit > 4 ? Int($limit / 4) : 1)
        If $round = 3 Then $limit = 1
        While $from < $n
            Local $to = $from, $size = StringLen($queue[$from])
            While $to + 1 < $n And $to - $from + 1 < $limit And $size + StringLen($queue[$to + 1]) <= $chars
                $to += 1
                $size += StringLen($queue[$to])
            WEnd
            If Not P136Batch($queue, $from, $to, $failed) Then Return False
            $from = $to + 1
        WEnd
        $queue = $failed
        $round += 1
    WEnd
    For $i = 0 To UBound($queue) - 1
        $p136Failed += 1
        P136Note("[段落] " & $p136Item & "：" & StringLeft(StringReplace(StringReplace($queue[$i], @CR, " "), @LF, " "), 200))
    Next
    Return True
EndFunc

; 把批次中的段落加入失敗清單。
Func P136AddFailed(ByRef $failed, ByRef $queue, $from, $to)
    For $i = $from To $to
        Local $n = UBound($failed)
        ReDim $failed[$n + 1]
        $failed[$n] = $queue[$i]
    Next
EndFunc

; 送出一個批次：處理限流重試、過大時拆半、解析編號結果並寫入快取。
Func P136Batch(ByRef $queue, $from, $to, ByRef $failed)
    Local $user = "", $system, $mt = ($p136Config.Item("protocol") = 4)
    If $mt Then
        ; Google 翻譯：每段一個 q 參數，依回應順序對應，不使用編號標記。
        $system = Chr(1)
        For $i = $from To $to
            $user &= ($i > $from ? "&" : "") & "q=" & P136UrlEncode($queue[$i])
        Next
    Else
        For $i = $from To $to
            $user &= "[[HH_" & StringFormat("%04d", $i - $from + 1) & "]]" & @LF & $queue[$i] & @LF
        Next
        $system = P136Prompt()
    EndIf
    Local $status, $resp, $retryAfter, $attempt = 0
    Local $delays[6] = [2000, 5000, 10000, 20000, 40000, 60000]
    While 1
        If P136Cancelled() Then Return False
        If $p136Config.Item("delay") > 0 And TimerDiff($p136LastRequest) < $p136Config.Item("delay") Then
            If Not P136Sleep($p136Config.Item("delay") - TimerDiff($p136LastRequest)) Then Return False
        EndIf
        P133Progress("AI 翻譯", $p136FileNo - 1, $p136FileTotal, P136Stats())
        P136Post($system, $user, $status, $resp, $retryAfter)
        $p136LastRequest = TimerInit()
        $p136ApiCalls += 1
        If $status = -2 Then Return False
        If $status = 200 Then ExitLoop
        If $status = 401 Or $status = 403 Or $status = 404 Then
            $p136Error = P136ErrorText($status, $resp)
            $p136Fatal = True
            Return False
        EndIf
        If ($status = 400 Or $status = 413) And $to > $from Then
            Local $mid = Int(($from + $to) / 2)
            If Not P136Batch($queue, $from, $mid, $failed) Then Return False
            Return P136Batch($queue, $mid + 1, $to, $failed)
        EndIf
        Local $retryable = ($status <= 0 Or $status = 408 Or $status = 409 Or $status = 425 Or $status = 429 Or $status >= 500)
        If $retryable And $attempt < 6 Then
            Local $wait = $delays[$attempt]
            If $retryAfter > 0 Then $wait = $retryAfter * 1000
            If $wait > 120000 Then $wait = 120000
            $attempt += 1
            P133Report(0, "翻譯服務暫時錯誤 " & $status & "，" & Int($wait / 1000) & " 秒後重試（第 " & $attempt & " 次）。")
            P133Progress("翻譯服務暫時錯誤，等待重試", $p136FileNo - 1, $p136FileTotal, P136Stats(), True)
            If Not P136Sleep($wait) Then Return False
            ContinueLoop
        EndIf
        If $status = 429 Then
            $p136Error = P136ErrorText($status, $resp)
            $p136Fatal = True
            Return False
        EndIf
        P136Note("[API] " & StringReplace(P136ErrorText($status, $resp), @CRLF, " "))
        P136AddFailed($failed, $queue, $from, $to)
        Return True
    WEnd
    Local $got = ObjCreate("Scripting.Dictionary")
    If $mt Then
        Local $list = P136GoogleList($resp)
        If @error Or UBound($list) <> $to - $from + 1 Then
            If $to > $from Then
                Local $half = Int(($from + $to) / 2)
                If Not P136Batch($queue, $from, $half, $failed) Then Return False
                Return P136Batch($queue, $half + 1, $to, $failed)
            EndIf
            P136Note("[Google] 無法解析回應：" & StringLeft($resp, 200))
            P136AddFailed($failed, $queue, $from, $to)
            Return True
        EndIf
        For $i = 0 To UBound($list) - 1
            $got.Item(StringFormat("%04d", $i + 1)) = StringRegExpReplace($list[$i], "(?i)<\s*(/?)\s*t\s*([0-9]+)\s*(/?)\s*>", "<\1t\2\3>")
        Next
    Else
        Local $reply = P136Reply($p136Config.Item("protocol"), $resp)
        If @error Then
            P136Note("[API] 無法解析回應：" & StringLeft($resp, 200))
            P136AddFailed($failed, $queue, $from, $to)
            Return True
        EndIf
        $reply = StringRegExpReplace($reply, "(?m)^\s*```[A-Za-z]*\s*$", "")
        Local $parts = StringRegExp($reply, "(?s)\[\[HH_([0-9]{4})\]\][ \t]*\r?\n?(.*?)(?=\r?\n?[ \t]*\[\[HH_[0-9]{4}\]\]|\z)", 3)
        If IsArray($parts) Then
            For $i = 0 To UBound($parts) - 2 Step 2
                If Not $got.Exists($parts[$i]) Then $got.Item($parts[$i]) = $parts[$i + 1]
            Next
        EndIf
    EndIf
    For $i = $from To $to
        Local $key = StringFormat("%04d", $i - $from + 1), $core = $queue[$i]
        Local $tr = ""
        If $got.Exists($key) Then $tr = StringRegExpReplace($got.Item($key), "^[\s]+|[\s]+$", "")
        If Not StringInStr($core, @LF) Then $tr = StringReplace(StringReplace($tr, @CR, ""), @LF, " ")
        If $tr <> "" And P136MarkersOk($core, $tr) Then
            $p136Cache.Item($core) = $tr
            If $p136CacheHandle <> -1 Then FileWriteLine($p136CacheHandle, P133Tsv($core) & @TAB & P133Tsv($tr))
        ElseIf StringRegExp($core, "</?t[0-9]+/?>") Then
            $p136Bad.Item($core) = 1
        Else
            Local $n = UBound($failed)
            ReDim $failed[$n + 1]
            $failed[$n] = $core
        EndIf
    Next
    Return True
EndFunc
