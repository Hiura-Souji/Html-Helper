#include-once
; =============================================================================
; Html Helper － 虛擬 CHM（不解包直接閱讀）
;
; 以 ITSS 直接讀取 CHM 內部檔案，透過 /__vchm__/文件ID/ 路徑提供給 WebView。
; 含目錄解析、索引延遲載入、磁碟快取與 ITSS 控制代碼重複使用。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ===== 免費 Google 傳統翻譯結束 =====
Func HH_CycleChmCharset()
    Local $tab = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tab <= 0 Then Return
    Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tab)
    If Not StringInStr($url, "/__vchm__/") Then
        _ChmMessage("文字編碼", "此選項僅適用於 CHM 內文。一般網站由 WebView2 自動判斷編碼。")
        Return
    EndIf
    $gChmCharsetMode = Mod($gChmCharsetMode + 1, 4)
    Local $names[4] = ["自動偵測", "UTF-8", "繁體中文 Big5", "簡體中文 GB18030"]
    _ChmMessage("CHM 文字編碼", "已切換為：" & $names[$gChmCharsetMode] & @CRLF & "將重新載入目前 CHM 內文。")
    ; 只重新載入 docframe，不重建目錄及整個閱讀器。
    HH_WebFire("(function(){var f=document.getElementById('docframe');if(f&&f.contentWindow){f.contentWindow.location.reload();}})();")
EndFunc

; 只更新 CHM 左側目錄與索引，保留目前 iframe 內文及瀏覽位置。
Func HH_CycleSidebarCharset()
    Local $tab = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    If $tab <= 0 Then Return
    Local $url = _UI_WebViewGetTabUrl($gWnd, $gWeb, $tab)
    Local $m = StringRegExp($url, "(?i)/__vchm__/([0-9]+)/", 1)
    If Not IsArray($m) Then
        _ChmMessage("左側欄編碼", "此選項僅適用於 CHM。")
        Return
    EndIf
    Local $id = Number($m[0])
    If $id < 1 Or $id >= UBound($gVChmPaths) Then Return
    $gChmSidebarModes[$id] = Mod($gChmSidebarModes[$id] + 1, 4)
    If $id < UBound($gVChmKeyHtml) Then $gVChmKeyHtml[$id] = ""
    Local $oldMode = $gChmSidebarDecodeMode
    $gChmSidebarDecodeMode = $gChmSidebarModes[$id]
    Local $toc = $gVChmTocFiles[$id], $key = $gVChmKeyFiles[$id]
    Local $prefix = "/__vchm__/" & $id & "/", $tocHtml = "", $keyHtml = ""
    If $toc <> "" Then
        Local $raw = VChmRead($gVChmExe, $gVChmPaths[$id], $toc)
        If Not @error Then $tocHtml = VChmSitemapNative($raw, $prefix, True)
    EndIf
    If $key <> "" Then
        $raw = VChmRead($gVChmExe, $gVChmPaths[$id], $key)
        If Not @error Then $keyHtml = VChmSitemapNative($raw, $prefix, False)
    EndIf
    $gChmSidebarDecodeMode = $oldMode
    If $tocHtml = "" And $keyHtml = "" Then
        _ChmMessage("左側欄編碼", "找不到可重新解碼的 .hhc 或 .hhk 目錄。")
        Return
    EndIf
    $tocHtml = StringReplace($tocHtml, 'target="doc"', 'target="docframe"')
    $keyHtml = StringReplace($keyHtml, 'target="doc"', 'target="docframe"')
    Local $js = "(function(){var p=document.querySelectorAll('#sidelists .panel');" & _
        "if(p.length<2)return;" & _
        "p[0].innerHTML=" & JsString($tocHtml) & ";p[1].innerHTML=" & JsString($keyHtml) & ";" & _
        "if(typeof filterNav==='function')filterNav();})()"
    HH_WebFire($js)
    Local $names[4] = ["自動偵測", "UTF-8", "Big5（系統 ANSI）", "GB18030（系統 ANSI 暫代）"]
    _ChmMessage("CHM 左側欄編碼", "目前 CHM 左側欄：" & $names[$gChmSidebarModes[$id]] & @CRLF & "右側內文不受影響。")
EndFunc

; 虛擬開啟 CHM，與 hh.exe 相同只讀必要資料：
;   1. 記憶體快取（同一份 CHM 已開過）→ 直接沿用。
;   2. 磁碟快取（路徑、大小、修改時間相同）→ 載入已解析的目錄與首頁。
;   3. 從 #SYSTEM 取得目錄／索引檔名，直接讀目錄，不列舉內部檔案（約省 0.7 秒）。
;   4. #SYSTEM 不可用時才列舉全部內部檔案（ITSS，最後才用 7-Zip）。
; 內部檔案清單改為需要時才列舉（「所有頁面」分頁、找不到首頁時）。
Func VChmOpen($path)
    Local $exe = ""
    If Not StartHttp() Then Return False
    Local $stamp = FileGetSize($path) & "|" & FileGetTime($path, 0, 1)
    For $jj = UBound($gVChmPaths) - 1 To 1 Step -1
        If $gVChmPaths[$jj] = "" Or $gVChmIndexes[$jj] = "" Then ContinueLoop
        If StringLower($gVChmPaths[$jj]) = StringLower($path) And $gVChmStamps[$jj] = $stamp Then
            $gPendingUrl = "http://127.0.0.1:" & $gPort & "/__vchm__/" & $jj & "/__index__"
            _UI_SetText($gWnd, $gStatus, $path)
            Return True
        EndIf
    Next
    VChmDocClose(StringLower($path))
    Local $aEntries = 0, $first = "", $toc = "", $keyword = "", $sysHome = "", $cachedToc = "", $fromDisk = False, $entry
    If HH_ChmCacheLoad($path, $stamp, $aEntries, $first, $toc, $keyword, $cachedToc) Then
        $fromDisk = True
    ElseIf VChmQuickInfo($path, $toc, $keyword, $sysHome) Then
        ; 根目錄的常見首頁優先（與舊版規則相同）。
        Local $roots[8] = ["index.htm", "index.html", "default.htm", "default.html", "welcome.htm", "welcome.html", "start.htm", "start.html"]
        For $r = 0 To UBound($roots) - 1
            If VChmExists($path, $roots[$r]) Then
                $first = $roots[$r]
                ExitLoop
            EndIf
        Next
    Else
        $aEntries = VChmEnum($path)
        If Not IsArray($aEntries) Then $aEntries = ITSS_List($path)
        If Not IsArray($aEntries) Or UBound($aEntries) = 0 Then
            $exe = _HtmlHelperFind7Zip()
            If $exe = "" Then Return False
            $aEntries = VChmList($exe, $path)
            If Not IsArray($aEntries) Then Return False
        EndIf
        For $i = 0 To UBound($aEntries) - 1
            $entry = $aEntries[$i]
            If $toc = "" And StringRegExp($entry, "(?i)\.hhc$") Then $toc = $entry
            If $keyword = "" And StringRegExp($entry, "(?i)\.hhk$") Then $keyword = $entry
            If Not StringRegExp($entry, "(?i)\.(htm|html|xhtml)$") Then ContinueLoop
            If $first = "" Then $first = $entry
            ; 僅根目錄的首頁檔案具有優先權；避免誤選 html/keywords/Default.htm。
            If StringRegExp($entry, "(?i)^(index|default|welcome|start)\.(htm|html)$") Then $first = $entry
        Next
        If $first = "" Then Return False
    EndIf
    $gVChmSeq += 1
    Local $id = $gVChmSeq
    ReDim $gVChmPaths[$id + 1]
    ReDim $gVChmEntries[$id + 1]
    ReDim $gVChmIndexes[$id + 1]
    ReDim $gVChmHomes[$id + 1]
    ReDim $gChmSidebarModes[$id + 1]
    ReDim $gVChmStamps[$id + 1]
    ReDim $gVChmKeyFiles[$id + 1]
    ReDim $gVChmTocFiles[$id + 1]
    ReDim $gVChmKeyHtml[$id + 1]
    ReDim $gVChmFileHtml[$id + 1]
    $gVChmStamps[$id] = $stamp
    $gVChmPaths[$id] = $path
    $gVChmEntries[$id] = ""
    If IsArray($aEntries) Then $gVChmEntries[$id] = _ArrayToString($aEntries, "|")
    $gVChmExe = $exe
    $gVChmTocFiles[$id] = $toc
    Local $prefix = "/__vchm__/" & $id & "/"
    Local $tocLinks = "", $keywordLinks = ""
    If $fromDisk Then
        $tocLinks = StringReplace($cachedToc, "/__vchm__/__HHID__/", $prefix, 0, 1)
    ElseIf $toc <> "" Then
        Local $rawToc = VChmRead($exe, $path, $toc)
        If Not @error Then $tocLinks = VChmSitemapNative($rawToc, $prefix, True)
        ; 無根目錄首頁時，以目錄中第一個實際存在的頁面作為首頁（不使用任意子資料夾的 Default.htm）。
        If Not StringRegExp($first, "(?i)^(index|default|welcome|start)\.(htm|html)$") Then
            Local $homeCandidates = StringRegExp($tocLinks, '(?i)href="' & $prefix & '([^"#?]+)', 3)
            If IsArray($homeCandidates) Then
                For $h = 0 To UBound($homeCandidates) - 1
                    Local $candidate = UrlDecode($homeCandidates[$h])
                    If VChmHasEntry($id, $candidate) Then
                        $first = $candidate
                        ExitLoop
                    EndIf
                Next
            EndIf
        EndIf
    EndIf
    ; 目錄找不到首頁時，依序改用 #SYSTEM 預設主題、列舉後的第一個 HTML。
    If $first = "" And $sysHome <> "" Then $first = $sysHome
    If $first = "" And VChmEnsureEntries($id) Then
        Local $all = StringSplit($gVChmEntries[$id], "|", 2)
        For $i = 0 To UBound($all) - 1
            If StringRegExp($all[$i], "(?i)\.(htm|html|xhtml)$") Then
                $first = $all[$i]
                ExitLoop
            EndIf
        Next
    EndIf
    If $first = "" Then
        $gVChmPaths[$id] = ""
        Return False
    EndIf
    $gVChmHomes[$id] = $first
    If Not $fromDisk And $exe = "" Then
        HH_ChmCacheSave($path, $stamp, $first, $toc, $keyword, StringReplace($tocLinks, $prefix, "/__vchm__/__HHID__/", 0, 1))
        If IsArray($aEntries) Then HH_ChmFilesCacheSave($path, $stamp, $aEntries)
    EndIf
    ; 索引（.hhk）通常比目錄大很多，改為切到「索引」分頁時才讀取解析（與 hh.exe 相同的延遲載入）。
    $gVChmKeyFiles[$id] = $keyword
    $gVChmKeyHtml[$id] = ""
    $gVChmFileHtml[$id] = ""
    $keywordLinks = '<div class="lazy" data-src="__keywords__">正在載入索引…</div>'
    If $tocLinks = "" Then $tocLinks = '<p>無法解析原始 CHM 目錄（.hhc），請查看「所有頁面」或檢查編碼。</p>'
    ; 以 BuildIndex 產生閱讀器；暫存並恢復全域資料，避免污染其他檔案的目錄。
    ; 延遲模式下 BuildIndex 不需要頁面清單（「所有頁面」另外載入），因此給空清單。
    Local $savedToc = $gTocHtml, $savedKey = $gKeywordHtml
    Local $savedDefault = $gDefaultTopic, $savedRequested = $gRequestedPage
    Local $savedFiles = $gPageFiles, $savedNames = $gPageNames
    Local $noPages[0]
    $gPageFiles = $noPages
    $gPageNames = $noPages
    $gTocHtml = StringReplace($tocLinks, 'target="doc"', 'target="docframe"')
    $gKeywordHtml = StringReplace($keywordLinks, 'target="doc"', 'target="docframe"')
    $gDefaultTopic = $first
    $gRequestedPage = ""
    $gIndexLazy = True
    $gVChmIndexes[$id] = BuildIndex($prefix)
    $gIndexLazy = False
    $gTocHtml = $savedToc
    $gKeywordHtml = $savedKey
    $gDefaultTopic = $savedDefault
    $gRequestedPage = $savedRequested
    $gPageFiles = $savedFiles
    $gPageNames = $savedNames
    $gPendingUrl = "http://127.0.0.1:" & $gPort & $prefix & "__index__"
    _UI_SetText($gWnd, $gStatus, $path)
    Return True
EndFunc

; 從 #SYSTEM 讀出目錄、索引與預設主題的檔名（檔案必須實際存在），不必列舉整份 CHM。
Func VChmQuickInfo($path, ByRef $toc, ByRef $keyword, ByRef $home)
    Local $doc = VChmDoc($path)
    If Not $doc Then Return False
    Local $detail = "", $sys = P133ReadAny($doc, "#SYSTEM", $detail, 16777216)
    Local $readErr = @error, $fields, $parse = ""
    If Not $readErr And BinaryLen($sys) > 0 And P133System($sys, $fields, $parse) Then
        $toc = VChmNormName(P133SystemText($fields, 0))
        $keyword = VChmNormName(P133SystemText($fields, 1))
        $home = VChmNormName(P133SystemText($fields, 2))
        If $toc <> "" And Not VChmExists($path, $toc) Then $toc = ""
        If $keyword <> "" And Not VChmExists($path, $keyword) Then $keyword = ""
        If $home <> "" And Not VChmExists($path, StringRegExpReplace($home, "[#?].*$", "")) Then $home = ""
    EndIf
    ; 很多 CHM 的 #SYSTEM 沒有記錄目錄檔名：只列舉根目錄找 .hhc／.hhk（不列舉整份 CHM）。
    If $toc = "" Then
        Local $rows = _ITSS_Enum($doc, False, 0)
        If Not @error And IsArray($rows) And UBound($rows, 0) = 2 Then
            For $i = 0 To UBound($rows) - 1
                If $rows[$i][1] <> 2 Then ContinueLoop
                Local $name = VChmNormName($rows[$i][0])
                If StringInStr($name, "/") Then ContinueLoop
                If $toc = "" And StringRegExp($name, "(?i)\.hhc$") Then $toc = $name
                If $keyword = "" And StringRegExp($name, "(?i)\.hhk$") Then $keyword = $name
            Next
        EndIf
    EndIf
    Return $toc <> ""
EndFunc

; 把 #SYSTEM 中的路徑轉成內部檔案名稱（斜線方向、去掉開頭的 / 與 mk:@MSITStore 前綴）。
Func VChmNormName($name)
    $name = StringReplace(StringStripWS($name, 3), "\", "/")
    $name = StringRegExpReplace($name, "(?i)^(?:mk:@msitstore:|ms-its:|its:)[^:]*::", "")
    While StringLeft($name, 1) = "/"
        $name = StringTrimLeft($name, 1)
    WEnd
    Return $name
EndFunc

; CHM 內是否有指定的內部檔案（只開啟串流，不讀內容）。
Func VChmExists($path, $name)
    If $name = "" Then Return False
    Local $doc = VChmDoc($path)
    If Not $doc Then Return False
    Local $st = _ITSS_StreamOpen($doc, $name)
    If @error Or Not $st Then Return False
    _ITSS_StreamClose($st)
    Return True
EndFunc

; 指定文件是否有這個內部檔案：已列舉時查清單，否則直接向 CHM 查詢。
Func VChmHasEntry($id, $name)
    If $gVChmEntries[$id] <> "" Then Return StringInStr("|" & $gVChmEntries[$id] & "|", "|" & $name & "|", 2) > 0
    Return VChmExists($gVChmPaths[$id], $name)
EndFunc

; 需要完整內部檔案清單時才列舉（「所有頁面」分頁等），結果另存磁碟快取。
Func VChmEnsureEntries($id)
    If $gVChmEntries[$id] <> "" Then Return True
    Local $path = $gVChmPaths[$id]
    Local $a = HH_ChmFilesCacheLoad($path, $gVChmStamps[$id])
    If Not IsArray($a) Then
        $a = VChmEnum($path)
        If Not IsArray($a) Then $a = ITSS_List($path)
        If (Not IsArray($a) Or UBound($a) = 0) And $gVChmExe <> "" Then $a = VChmList($gVChmExe, $path)
        If Not IsArray($a) Or UBound($a) = 0 Then Return False
        If $gVChmExe = "" Then HH_ChmFilesCacheSave($path, $gVChmStamps[$id], $a)
    EndIf
    $gVChmEntries[$id] = _ArrayToString($a, "|")
    Return True
EndFunc

; 以已開啟（並會留著重複使用）的 ITSS 控制代碼列舉 CHM 內部檔案。
Func VChmEnum($path)
    Local $doc = VChmDoc($path)
    If Not $doc Then Return SetError(1, 0, 0)
    Local $rows = _ITSS_Enum($doc, True, 0)
    If @error Or Not IsArray($rows) Or UBound($rows, 0) <> 2 Then Return SetError(2, 0, 0)
    Local $out[UBound($rows)], $n = 0, $name
    For $i = 0 To UBound($rows) - 1
        If $rows[$i][1] <> 2 Then ContinueLoop
        $name = StringReplace($rows[$i][0], "\", "/")
        While StringLeft($name, 1) = "/"
            $name = StringTrimLeft($name, 1)
        WEnd
        If $name = "" Or StringRegExp($name, "^(#|\$|::)") Or StringInStr($name, "|") Then ContinueLoop
        $out[$n] = $name
        $n += 1
    Next
    If $n = 0 Then Return SetError(3, 0, 0)
    ReDim $out[$n]
    Return $out
EndFunc

; ---------- CHM 目錄磁碟快取（%LOCALAPPDATA%\HtmlHelper\chmcache）----------
Func HH_ChmCacheFile($path)
    Local $key = StringTrimLeft(String(_Crypt_HashData(StringToBinary(StringLower($path), 4), $CALG_SHA_256)), 2)
    Return @LocalAppDataDir & "\HtmlHelper\chmcache\" & StringLeft($key, 32) & ".txt"
EndFunc

; 讀取磁碟快取；路徑、大小、修改時間任一不同即視為無效。
Func HH_ChmCacheLoad($path, $stamp, ByRef $entries, ByRef $first, ByRef $toc, ByRef $keyword, ByRef $tocHtml)
    Local $file = HH_ChmCacheFile($path)
    If Not FileExists($file) Then Return False
    Local $h = FileOpen($file, 256)
    If $h = -1 Then Return False
    Local $txt = FileRead($h)
    FileClose($h)
    Local $parts[7], $pos = 1, $nl
    For $i = 0 To 6
        $nl = StringInStr($txt, @LF, 1, 1, $pos)
        If $nl = 0 Then Return False
        $parts[$i] = StringMid($txt, $pos, $nl - $pos)
        $pos = $nl + 1
    Next
    If $parts[0] <> "HHCACHE2" Or $parts[1] <> StringLower($path) Or $parts[2] <> $stamp Or $parts[3] = "" Then Return False
    $first = $parts[3]
    $toc = $parts[4]
    $keyword = $parts[5]
    ; 第 7 欄保留給相容用途；內部檔案清單另存 .files，需要時才載入。
    $entries = 0
    $tocHtml = StringMid($txt, $pos)
    FileSetTime($file, "")
    Return True
EndFunc

; 寫入磁碟快取（先寫暫存檔再取代）。
Func HH_ChmCacheSave($path, $stamp, $first, $toc, $keyword, $tocHtml)
    Local $file = HH_ChmCacheFile($path)
    Local $h = FileOpen($file & ".tmp", 2 + 8 + 256)
    If $h = -1 Then Return False
    FileWrite($h, "HHCACHE2" & @LF & StringLower($path) & @LF & $stamp & @LF & $first & @LF & $toc & @LF & $keyword & @LF & @LF & $tocHtml)
    FileClose($h)
    If Not FileMove($file & ".tmp", $file, 1) Then Return False
    FileDelete($file & ".hhk")
    FileDelete($file & ".files")
    HH_ChmCachePrune()
    Return True
EndFunc

; 索引（.hhk）解析結果另存一份，第二次開啟時點「索引」也不必重新解析。
Func HH_ChmKeyCacheLoad($path, $stamp, $prefix)
    Local $h = FileOpen(HH_ChmCacheFile($path) & ".hhk", 256)
    If $h = -1 Then Return ""
    Local $txt = FileRead($h)
    FileClose($h)
    Local $nl = StringInStr($txt, @LF)
    If $nl = 0 Or StringLeft($txt, $nl - 1) <> $stamp Then Return ""
    Return StringReplace(StringMid($txt, $nl + 1), "/__vchm__/__HHID__/", $prefix, 0, 1)
EndFunc

; 寫入索引（.hhk）解析結果的磁碟快取。
Func HH_ChmKeyCacheSave($path, $stamp, $prefix, $html)
    Local $file = HH_ChmCacheFile($path)
    If Not FileExists($file) Then Return
    Local $h = FileOpen($file & ".hhk", 2 + 8 + 256)
    If $h = -1 Then Return
    FileWrite($h, $stamp & @LF & StringReplace($html, $prefix, "/__vchm__/__HHID__/", 0, 1))
    FileClose($h)
EndFunc

; 讀取內部檔案清單的磁碟快取（第一行為大小｜修改時間）。
Func HH_ChmFilesCacheLoad($path, $stamp)
    Local $h = FileOpen(HH_ChmCacheFile($path) & ".files", 256)
    If $h = -1 Then Return 0
    Local $txt = FileRead($h)
    FileClose($h)
    Local $nl = StringInStr($txt, @LF)
    If $nl = 0 Or StringLeft($txt, $nl - 1) <> $stamp Or StringMid($txt, $nl + 1) = "" Then Return 0
    Return StringSplit(StringMid($txt, $nl + 1), "|", 2)
EndFunc

; 寫入內部檔案清單的磁碟快取。
Func HH_ChmFilesCacheSave($path, $stamp, ByRef $entries)
    Local $h = FileOpen(HH_ChmCacheFile($path) & ".files", 2 + 8 + 256)
    If $h = -1 Then Return
    FileWrite($h, $stamp & @LF & _ArrayToString($entries, "|"))
    FileClose($h)
EndFunc

; 只保留最近使用的 40 份 CHM 快取。
Func HH_ChmCachePrune()
    Local $dir = @LocalAppDataDir & "\HtmlHelper\chmcache"
    Local $list = _FileListToArray($dir, "*.txt", $FLTA_FILES)
    If Not IsArray($list) Or $list[0] <= 40 Then Return
    Local $rows[$list[0]][2]
    For $i = 1 To $list[0]
        $rows[$i - 1][0] = FileGetTime($dir & "\" & $list[$i], 0, 1)
        $rows[$i - 1][1] = $list[$i]
    Next
    _ArraySort($rows, 1)
    For $i = 40 To UBound($rows) - 1
        FileDelete($dir & "\" & $rows[$i][1])
        FileDelete($dir & "\" & $rows[$i][1] & ".hhk")
        FileDelete($dir & "\" & $rows[$i][1] & ".files")
    Next
EndFunc

; 以 7-Zip 列出 CHM 內部檔案（ITSS 不可用時的退回方案）。
Func VChmList($exe, $archive)
    Local $cmd = '"' & $exe & '" l -slt -sccUTF-8 "' & $archive & '"'
    Local $pid = Run($cmd, @ScriptDir, @SW_HIDE, $STDOUT_CHILD + $STDERR_CHILD)
    If $pid = 0 Then Return SetError(1, 0, 0)
    Local $buffer = Binary(""), $clock = TimerInit()
    While ProcessExists($pid)
        Local $part = StdoutRead($pid, False, True)
        If Not @error And BinaryLen($part) Then $buffer &= $part
        If Not ProcessExists($pid) Then ExitLoop
        If TimerDiff($clock) > 30000 Or BinaryLen($buffer) > 8000000 Then
            ProcessClose($pid)
            Return SetError(2, 0, 0)
        EndIf
        Sleep(15)
    WEnd
    Local $tail = StdoutRead($pid, False, True)
    If Not @error And BinaryLen($tail) Then $buffer &= $tail
    Local $listing = BinaryToString($buffer, 4)
    Local $lines = StringSplit(StringReplace($listing, @CR, ""), @LF, 2)
    Local $entries[0], $candidate = "", $folder = "", $started = False
    For $i = 0 To UBound($lines) - 1
        Local $line = $lines[$i]
        If StringLeft($line, 7) = "Path = " Then
            If $started And $candidate <> "" And $folder = "-" Then VChmAddEntry($entries, $candidate)
            $candidate = StringTrimLeft($line, 7)
            $folder = ""
            $started = True
        ElseIf StringLeft($line, 9) = "Folder = " Then
            $folder = StringTrimLeft($line, 9)
        EndIf
    Next
    If $candidate <> "" And $folder = "-" Then VChmAddEntry($entries, $candidate)
    If UBound($entries) = 0 Then Return SetError(3, 0, 0)
    Return $entries
EndFunc

; 加入一筆內部檔案名稱（拒絕絕對路徑與路徑穿越）。
Func VChmAddEntry(ByRef $entries, $entry)
    $entry = StringReplace($entry, "\", "/")
    If StringLeft($entry, 1) = "/" Or StringInStr($entry, "..") Or StringInStr($entry, ":") Or StringInStr($entry, "|") Then Return
    ReDim $entries[UBound($entries) + 1]
    $entries[UBound($entries) - 1] = $entry
EndFunc

; 把 CHM 內的 HHC／HHK 位元組轉成側欄 HTML，連結指向 /__vchm__/文件ID/。
Func VChmSitemapNative($bytes, $prefix, $bTree)
    ; 保留 HHC 的 UL 階層，並為含子節點的項目建立展開/收合按鈕。
    Local $sRaw = BinaryToString($bytes, 1)
    Switch $gChmSidebarDecodeMode
        Case 1
            $sRaw = BinaryToString($bytes, 4)
        Case 2
            $sRaw = BinaryToString($bytes, 1) ; 系統 ANSI；繁體 Windows 通常為 Big5
        Case 3
            $sRaw = BinaryToString($bytes, 1) ; 後續可加入 Windows API GB18030 轉換
        Case Else
            If BinaryLen($bytes) >= 3 And BinaryMid($bytes, 1, 3) = Binary("0xEFBBBF") Then $sRaw = BinaryToString($bytes, 4)
    EndSwitch
    Local $aTokens = StringRegExp($sRaw, "(?is)<ul\b[^>]*>|</ul\s*>|<object\b[^>]*>.*?</object>", 3)
    If Not IsArray($aTokens) Then Return ""
    Local $aNames[UBound($aTokens)], $aLocals[UBound($aTokens)], $aDepths[UBound($aTokens)], $iDepth = 0, $iItems = 0
    For $i = 0 To UBound($aTokens) - 1
        Local $sToken = $aTokens[$i]
        If StringRegExp($sToken, "(?i)^<ul\b") Then
            $iDepth += 1
            ContinueLoop
        EndIf
        If StringRegExp($sToken, "(?i)^</ul") Then
            $iDepth -= 1
            If $iDepth < 0 Then $iDepth = 0
            ContinueLoop
        EndIf
        Local $sName = _SitemapParam($sToken, "Name")
        If $sName = "" Then ContinueLoop
        Local $sLocal = _SitemapParam($sToken, "Local")
        $sLocal = StringReplace($sLocal, "\", "/")
        $sLocal = StringRegExpReplace($sLocal, "(?i)^mk:@msitstore:[^:]*::/", "")
        $sLocal = StringRegExpReplace($sLocal, "^\./", "")
        ; HHK 的 Local 常是 URL 編碼，例如 Windows%20Message。
        ; 過去以未解碼字串 FileExists 檢查，導致 WM_SIZE 等索引被錯誤取消連結。
        ; 一律保留原始索引連結；不存在的目標交由 HTTP 服務回傳 404。
        If StringInStr($sLocal, "%") Then $sLocal = UrlDecode($sLocal)
        ; 某些 CHM 索引以 $tag 名稱代表關鍵字，並非可直接開啟的實體檔案。
        If StringRegExp(StringStripWS($sLocal, 3), "(?i)^\$tag(?:\b|\s)") Then $sLocal = ""
        $sLocal = StringRegExpReplace($sLocal, "(?i)^ms-its:[^:]*::/", "")
        Local $n = $iItems
        $iItems += 1
        $aNames[$n] = $sName
        $aLocals[$n] = $sLocal
        $aDepths[$n] = $iDepth
    Next
    Local $sOut = "", $iOpen = 0
    For $i = 0 To $iItems - 1
        Local $iCurrent = 0
        If $bTree Then $iCurrent = $aDepths[$i] - 1
        If $iCurrent < 0 Then $iCurrent = 0
        ; 關閉前面已結束的節點；下一個較深的項目才是上一個的子節點。
        If $i > 0 Then
            Local $iPrevious = 0
            If $bTree Then $iPrevious = $aDepths[$i - 1] - 1
            If $iPrevious < 0 Then $iPrevious = 0
            If $iCurrent > $iPrevious Then
                $sOut &= '<div class="children">'
                $iOpen += 1
            Else
                $sOut &= '</div>'
                While $iOpen > 0 And $iCurrent < $iPrevious
                    $sOut &= '</div></div>'
                    $iOpen -= 1
                    $iPrevious -= 1
                WEnd
            EndIf
        EndIf
        Local $bParent = False
        If $bTree And $i + 1 < $iItems Then $bParent = $aDepths[$i + 1] > $aDepths[$i]
        $sOut &= '<div class="node"><div class="entry">'
        If $bParent Then
            $sOut &= '<button type="button" class="twisty" onclick="toggleNode(this);return false;" title="展開或收合">▸</button>'
        Else
            $sOut &= '<span class="twisty-placeholder"></span>'
        EndIf
        If $aLocals[$i] <> "" Then
            $sOut &= '<a href="' & $prefix & HtmlEscape(EncodeUrlPath($aLocals[$i])) & '" target="docframe" ondblclick="toggleTitle(this);return false;" title="按兩下展開或收合">' & HtmlEscape($aNames[$i]) & '</a>'
        Else
            $sOut &= '<span class="group-title" ondblclick="toggleTitle(this)" title="按兩下展開或收合">' & HtmlEscape($aNames[$i]) & '</span>'
        EndIf
        $sOut &= '</div>'
    Next
    If $iItems Then $sOut &= '</div>'
    While $iOpen > 0
        $sOut &= '</div></div>'
        $iOpen -= 1
    WEnd
    Return $sOut
EndFunc

; 處理 /__vchm__/ 請求：閱讀器頁面、延遲載入的側欄，以及 CHM 內部檔案。
Func VChmHttp($client, $url)
    Local $m = StringRegExp($url, "^/__vchm__/([0-9]+)/(.+)$", 1)
    If Not IsArray($m) Then
        SendResponse($client, 404, "text/plain", Binary(""))
        Return
    EndIf
    Local $id = Number($m[0]), $inner = UrlDecode($m[1])
    If $id < 1 Or $id >= UBound($gVChmPaths) Then
        SendResponse($client, 404, "text/plain", Binary(""))
        Return
    EndIf
    If $inner = "__index__" Then
        SendResponse($client, 200, "text/html; charset=utf-8", StringToBinary($gVChmIndexes[$id], 4))
        Return
    EndIf
    If $inner = "__keywords__" Or $inner = "__files__" Then
        SendResponse($client, 200, "text/html; charset=utf-8", StringToBinary(VChmLazyPanel($id, $inner), 4))
        Return
    EndIf
    ; 不允許 CHM 內部路徑逃逸或任意要求主機檔案。
    If StringLeft($inner, 1) = "/" Or StringInStr($inner, "..") Or StringInStr($inner, ":") Or StringInStr($inner, Chr(0)) Then
        SendResponse($client, 403, "text/plain", Binary(""))
        Return
    EndIf
    ; 已列舉時先查清單；尚未列舉時直接讀取，讀不到就回 404。
    If $gVChmEntries[$id] <> "" And StringInStr("|" & $gVChmEntries[$id] & "|", "|" & $inner & "|", 2) = 0 Then
        SendResponse($client, 404, "text/plain", Binary(""))
        Return
    EndIf
    Local $bytes = VChmRead($gVChmExe, $gVChmPaths[$id], $inner)
    If @error Then
        SendResponse($client, 404, "text/plain", Binary(""))
        Return
    EndIf
    Local $mime = MimeType($inner)
    If $gChmCharsetMode > 0 And StringRegExp($inner, "(?i)\.(htm|html|xhtml)$") Then
        Local $charset = "utf-8"
        Switch $gChmCharsetMode
            Case 2
                $charset = "big5"
            Case 3
                $charset = "gb18030"
        EndSwitch
        ; 將宣告放在 HTML 最前面，以覆蓋 CHM 舊頁面中不正確的 charset meta。
        ; ASCII 前綴不更動原始文字位元組；自動模式保持原封不動。
        $bytes = StringToBinary('<meta charset="' & $charset & '">', 1) & $bytes
        $mime = "text/html; charset=" & $charset
    EndIf
    SendResponse($client, 200, $mime, $bytes)
EndFunc

; 延遲載入的側欄分頁：索引（.hhk）與所有頁面清單，第一次要求時才產生並快取。
Func VChmLazyPanel($id, $what)
    Local $prefix = "/__vchm__/" & $id & "/"
    If $what = "__files__" Then
        If $gVChmFileHtml[$id] <> "" Then Return $gVChmFileHtml[$id]
        If Not VChmEnsureEntries($id) Then Return "<p>無法列出 CHM 內部檔案。</p>"
        Local $all = StringSplit($gVChmEntries[$id], "|", 2), $out = ""
        For $i = 0 To UBound($all) - 1
            If Not StringRegExp($all[$i], "(?i)\.(htm|html|xhtml)$") Then ContinueLoop
            $out &= '<div class="entry"><a target="docframe" href="' & $prefix & HtmlEscape(EncodeUrlPath($all[$i])) & '">' & HtmlEscape($all[$i]) & '</a></div>'
        Next
        If $out = "" Then $out = "<p>沒有 HTML 頁面。</p>"
        $gVChmFileHtml[$id] = $out
        Return $out
    EndIf
    If $gVChmKeyHtml[$id] <> "" Then Return $gVChmKeyHtml[$id]
    Local $html = ""
    If $gChmSidebarModes[$id] = 0 And $gVChmExe = "" Then
        $html = HH_ChmKeyCacheLoad($gVChmPaths[$id], $gVChmStamps[$id], $prefix)
        If $html <> "" Then
            $gVChmKeyHtml[$id] = $html
            Return $html
        EndIf
    EndIf
    If $gVChmKeyFiles[$id] <> "" Then
        Local $raw = VChmRead($gVChmExe, $gVChmPaths[$id], $gVChmKeyFiles[$id])
        If Not @error Then
            Local $oldMode = $gChmSidebarDecodeMode
            $gChmSidebarDecodeMode = $gChmSidebarModes[$id]
            $html = StringReplace(VChmSitemapNative($raw, $prefix, False), 'target="doc"', 'target="docframe"')
            $gChmSidebarDecodeMode = $oldMode
        EndIf
        If $html <> "" And $gChmSidebarModes[$id] = 0 And $gVChmExe = "" Then HH_ChmKeyCacheSave($gVChmPaths[$id], $gVChmStamps[$id], $prefix, $html)
    EndIf
    If $html = "" Then $html = "<p>這份 CHM 未提供可解析的索引（.hhk）。</p>"
    $gVChmKeyHtml[$id] = $html
    Return $html
EndFunc


; 取得（必要時開啟）CHM 的 ITSS 文件控制代碼並記錄使用時間。
Func VChmDoc($archive)
    Local $k = StringLower($archive)
    If $gVChmDocs.Exists($k) Then
        $gVChmDocUse.Item($k) = TimerInit()
        Return $gVChmDocs.Item($k)
    EndIf
    Local $doc = _ITSS_Open($archive)
    If @error Or Not $doc Then Return 0
    $gVChmDocs.Item($k) = $doc
    $gVChmDocUse.Item($k) = TimerInit()
    Return $doc
EndFunc

; 關閉並移除指定 CHM 的 ITSS 控制代碼。
Func VChmDocClose($k)
    If Not $gVChmDocs.Exists($k) Then Return
    Local $doc = $gVChmDocs.Item($k)
    _ITSS_Close($doc)
    $gVChmDocs.Remove($k)
    If $gVChmDocUse.Exists($k) Then $gVChmDocUse.Remove($k)
EndFunc

; 主迴圈呼叫：閒置超過 60 秒的 CHM 釋放檔案控制代碼，讓使用者可以覆寫或刪除該 CHM。
Func HH_VChmIdleTick()
    If TimerDiff($gVChmIdleClock) < 5000 Then Return
    $gVChmIdleClock = TimerInit()
    If $gVChmDocs.Count = 0 Then Return
    Local $keys = $gVChmDocs.Keys()
    For $k In $keys
        If TimerDiff($gVChmDocUse.Item($k)) > 60000 Then VChmDocClose($k)
    Next
EndFunc

; 讀取 CHM 內部檔案：先用已開啟的控制代碼，失敗才逐次開檔，最後才用 7-Zip。
Func VChmRead($exe, $archive, $inner)
    ; 先用已開啟的 ITSS 控制代碼讀取；失敗才走原本逐次開檔／7-Zip 的路徑。
    Local $doc = VChmDoc($archive)
    If $doc Then
        Local $detail = "", $fast = P133ReadAny($doc, $inner, $detail, 33554432)
        If Not @error And BinaryLen($fast) > 0 Then Return $fast
    EndIf
    Local $native = ITSS_Read($archive, $inner, 33554432)
    If Not @error Then Return $native
    If $exe = "" Then $exe = _HtmlHelperFind7Zip()
    If $exe = "" Then Return SetError(3, 0, Binary(""))
    ; 使用 7-Zip stdout 二進位管線，檔案內容不落地；大資源設 32MB 上限。
    Local $cmd = '"' & $exe & '" e -so -y "' & $archive & '" "' & $inner & '"'
    Local $pid = Run($cmd, @ScriptDir, @SW_HIDE, $STDOUT_CHILD)
    If $pid = 0 Then Return SetError(1, 0, Binary(""))
    Local $bytes = Binary(""), $clock = TimerInit()
    While ProcessExists($pid)
        Local $part = StdoutRead($pid, False, True)
        If Not @error And BinaryLen($part) Then $bytes &= $part
        If TimerDiff($clock) > 12000 Or BinaryLen($bytes) > 33554432 Then
            ProcessClose($pid)
            Return SetError(2, 0, Binary(""))
        EndIf
        Sleep(10)
    WEnd
    Local $last = StdoutRead($pid, False, True)
    If Not @error And BinaryLen($last) Then $bytes &= $last
    Return $bytes
EndFunc
