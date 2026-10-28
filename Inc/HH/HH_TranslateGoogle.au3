#include-once
; =============================================================================
; Html Helper － 網頁 Google 翻譯
;
; Google 免費翻譯（非官方端點，可能限流）：選取文字與整頁翻譯。
; 整頁以多個 q 參數批次送出，結果永久快取，並套用台灣用語。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ===== AI 第一階段結束 =====
; ===== 免費 Google 傳統翻譯（非官方網頁端點，可能變更／限流） =====
; 不使用 API Key。選取文字會傳送到 Google，原 CHM 不修改。
Func HH_AI_GoogleTranslateSelection()
    If $gWebLangCode = "" Then
        HH_TrMsg("Google 翻譯", "目前的翻譯目的語言沒有語言代碼，請在右鍵「翻譯目的語言…」填入代碼。")
        Return
    EndIf
    If $gAiPageMode Or IsObj($gAiHttp) Or $gAiBusyRetryDelay > 0 Then
        HH_TrMsg("Google 翻譯", "AI 翻譯進行中，請先完成或停止。")
        Return
    EndIf
    If IsObj($gGoogleHttp) Or $gGooglePageMode Then
        HH_TrMsg("Google 翻譯", "已有免費翻譯請求進行中。")
        Return
    EndIf
    Local $js = "(function(){var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
        "var w=d.defaultView||window;return String(w.getSelection?w.getSelection():'');})()"
    If HH_WebExec($js, "HH_AI_GoogleSelected") = 0 Then HH_TrMsg("Google 翻譯", "無法讀取目前頁面的選取文字，請點一下頁面後再試。")
EndFunc

; 讀到選取文字後送出 Google 翻譯請求。
Func HH_AI_GoogleSelected($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If StringLeft($raw, 1) <> '"' Then Return
    Local $selected = HH_AI_Unescape(StringMid($raw, 2, StringLen($raw) - 2))
    If StringStripWS($selected, 3) = "" Then
        HH_TrMsg("Google 翻譯", "請先反白選取要翻譯的文字。")
        Return
    EndIf
    If StringLen($selected) > 1800 Then
        HH_TrMsg("Google 翻譯", "免費翻譯一次最多 1,800 字元，請縮小選取範圍。")
        Return
    EndIf
    Local $http = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($http) Then Return
    $http.SetTimeouts(10000, 10000, 15000, 30000)
    Local $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" & $gWebLangCode & "&dt=t&q=" & HH_UrlEncodeUtf8($selected)
    $http.Open("GET", $url, True)
    $http.SetRequestHeader("User-Agent", "Mozilla/5.0")
    $http.Send()
    If @error Then
        HH_TrMsg("Google 翻譯", "請求無法送出。")
        Return
    EndIf
    $gGoogleHttp = $http
    $gGoogleClock = TimerInit()
EndFunc

; 主迴圈呼叫：檢查 Google 翻譯回應（整頁與選取共用，含重試）。
Func HH_AI_GooglePoll()
    If $gGooglePageMode And $gGooglePageRetryAt <> 0 And Not IsObj($gGoogleHttp) Then
        If TimerDiff($gGooglePageRetryAt) >= 2500 * $gGooglePageFailures Then
            $gGooglePageRetryAt = 0
            HH_GoogleSendPageText($gGooglePageRetryText)
        EndIf
        Return
    EndIf
    If Not IsObj($gGoogleHttp) Then Return
    Local $http = $gGoogleHttp
    Local $done = $http.WaitForResponse(0)
    If @error Then
        $gGoogleHttp = 0
        If $gGooglePageMode Then
            HH_GoogleApplyOriginalPending()
        Else
            HH_TrMsg("Google 翻譯", "連線失敗。")
        EndIf
        Return
    EndIf
    If Not $done Then
        If TimerDiff($gGoogleClock) > 45000 Then
            $http.Abort()
            $gGoogleHttp = 0
            If $gGooglePageMode Then
                HH_GoogleApplyOriginalPending()
            Else
                HH_TrMsg("Google 翻譯", "連線逾時。")
            EndIf
        EndIf
        Return
    EndIf
    $gGoogleHttp = 0
    If $http.Status <> 200 Then
        Local $status = $http.Status
        If $gGooglePageMode And ($status = 500 Or $status = 502 Or $status = 503 Or $status = 504) Then
            $gGooglePageFailures += 1
            If $gGooglePageFailures <= 2 Then
                $gGooglePageRetryText = $gGooglePageSource
                $gGooglePageRetryAt = TimerInit()
                Return
            EndIf
        EndIf
        If $gGooglePageMode And $status <> 429 And $status < 500 Then
            HH_GoogleApplyOriginalPending()
            Return
        EndIf
        $gGooglePageMode = False
        HH_TrNotifyClose()
        HH_TrMsg("Google 翻譯", "服務暫時無法使用（HTTP " & $status & "）。已完成 " & $gGooglePageDone & " 段，保留已翻譯內容。請稍後重試；可先還原原文。")
        Return
    EndIf
    $gGooglePageFailures = 0
    ; 僅讀取 JSON 最外層第一個陣列中的「翻譯片段第一欄」。
    ; 不可對整份 JSON 使用全域正則，否則會誤收語言偵測資訊、雜湊碼等欄位。
    Local $response = $http.ResponseText, $translated = ""
    If $gGooglePageMode Then
        $translated = HH_GoogleParseMulti($response)
    Else
        $translated = HH_GoogleExtractTranslatedText($response)
    EndIf
    If @error Then
        $gGooglePageMode = False
        HH_TrMsg("Google 翻譯", "Google 回應格式無法辨識，已取消複製以免混入其他資料。")
        Return
    EndIf
    If $translated = "" Then
        If $gGooglePageMode Then
            ; 空譯文不應讓整頁翻譯永久停在等待狀態。
            HH_GoogleApplyOriginalPending()
        Else
            HH_TrMsg("Google 翻譯", "翻譯服務傳回空白內容。")
        EndIf
        Return
    EndIf
    If $gGooglePageMode Then
        If $gGoogleBatchCount > 1 Then
            Local $pieces = StringSplit($translated, $gGoogleBatchSep, 1)
            If $pieces[0] <> $gGoogleBatchCount Then
                ; 翻譯端改寫了分隔符：退回單節點，絕不錯位套用。
                $gGoogleBatchCount = 1
                $gGoogleBatchFallback = True
                HH_GoogleNextPage()
                Return
            EndIf
            HH_GoogleCacheWrite($gGooglePageSource, $translated)
            HH_GoogleApplyBatch($pieces)
        Else
            HH_GoogleCacheWrite($gGooglePageSource, $translated)
            HH_GoogleApplyPage($translated)
        EndIf
        Return
    EndIf
    P135ClipboardDialog("Google 免費翻譯（" & $gWebLangName & "）", $translated)
EndFunc

; ===== 免費 Google 整頁翻譯：逐文字節點、非同步、可取消 =====
; 逐節點避免翻譯端破壞分隔符，保留 HTML 結構、程式碼和連結。
; ===== 永久快取：UTF-8 十六進位儲存，避免 INI 換行與特殊字元 =====
Func HH_GoogleCacheKey($source)
    Return StringTrimLeft(String(_Crypt_HashData(StringToBinary($gWebLangCode & "|" & $source, 4), $CALG_SHA_256)), 2)
EndFunc

; 永久快取：每筆一個小檔案（舊版單一 INI 越存越大，每批都要整檔重寫，翻譯會越來越慢）。
Func HH_GoogleCacheFile($source)
    Return @LocalAppDataDir & "\HtmlHelper\gcache\" & HH_GoogleCacheKey($source) & ".txt"
EndFunc

; 讀取翻譯快取（先查記憶體）。
Func HH_GoogleCacheRead($source)
    If $gGooglePageCache.Exists($source) Then Return $gGooglePageCache.Item($source)
    Local $file = HH_GoogleCacheFile($source)
    If Not FileExists($file) Then Return ""
    Local $h = FileOpen($file, 256)
    If $h = -1 Then Return ""
    Local $translated = FileRead($h)
    FileClose($h)
    If $translated <> "" Then $gGooglePageCache.Item($source) = $translated
    Return $translated
EndFunc

; 寫入翻譯快取。
Func HH_GoogleCacheWrite($source, $translated)
    If $source = "" Or $translated = "" Then Return
    $gGooglePageCache.Item($source) = $translated
    Local $h = FileOpen(HH_GoogleCacheFile($source), 2 + 8 + 256)
    If $h = -1 Then Return
    FileWrite($h, $translated)
    FileClose($h)
EndFunc

; 翻譯進度：顯示已套用文字節點、總數與快取命中批數。
Func HH_GoogleShowProgress($dialog = False)
    Local $percent = 0
    If $gGooglePageTotal > 0 Then $percent = Int($gGooglePageDone * 100 / $gGooglePageTotal)
    If $percent > 100 Then $percent = 100
    Local $state = "已停止或尚未開始"
    If $gGooglePageMode Then $state = "翻譯中"
    Local $msg = $state & "：" & $gGooglePageDone & " / " & $gGooglePageTotal & " 個文字節點（" & $percent & "%）" & @CRLF & "快取命中：" & $gGoogleCacheHits & " 批"
    If $dialog Then
        HH_TrNotify("Google 整頁翻譯進度", $msg, $AUI_NOTIFY_INFO, 6000)
    ElseIf $gGooglePageMode Then
        HH_TrProgress("Google 整頁翻譯", $msg)
    EndIf
EndFunc

; 清除全部永久快取；正在翻譯時不允許清除，以免破壞續傳。
Func HH_GoogleTranslatePage()
    If $gWebLangCode = "" Then
        HH_TrMsg("Google 整頁翻譯", "目前的翻譯目的語言沒有語言代碼，請在右鍵「翻譯目的語言…」填入代碼。")
        Return
    EndIf
    If $gAiPageMode Or IsObj($gAiHttp) Or $gAiPageRequest <> 0 Then
        HH_TrMsg("Google 整頁翻譯", "請先停止或完成 AI 整頁翻譯。")
        Return
    EndIf
    If $gGooglePageMode Or IsObj($gGoogleHttp) Or $gGooglePageRequest <> 0 Then
        HH_TrMsg("Google 整頁翻譯", "已有 Google 翻譯工作進行中。")
        Return
    EndIf
    $gGooglePageMode = True
    $gGooglePageDone = 0
    $gGoogleAppliedCount = 0
    $gGooglePageTotal = 0
    $gGoogleCacheHits = 0
    $gGooglePageFailures = 0
    $gGooglePageRetryAt = 0
    $gGoogleBatchCount = 40
    $gGoogleBatchFallback = False
    ; 同引擎未完成工作可續傳；跨引擎必須先還原。
    HH_GoogleNextPage(True)
EndFunc

; 停止 Google 整頁翻譯（已翻譯的內容保留）。
Func HH_GoogleStopPage()
    $gGooglePageMode = False
    If IsObj($gGoogleHttp) Then $gGoogleHttp.Abort()
    $gGoogleHttp = 0
    $gGooglePageRetryAt = 0
    $gGooglePageRetryText = ""
    $gGooglePageFailures = 0
    $gGooglePageSource = ""
    $gGooglePageRequest = 0 ; 讓停止前尚未完成的 WebView2 回呼失效
    HH_TrNotifyClose()
    ; 已完成的譯文留在頁面，可用 AI 還原原文恢復。
EndFunc

; 擷取下一批文字節點（最多 40 段、4500 字元）。
Func HH_GoogleNextPage($reset = False)
    If Not $gGooglePageMode Then Return
    Local $resetJs = "false"
    $gGoogleBatchCount = 40
    If $gGoogleBatchFallback Then $gGoogleBatchCount = 1
    $gGoogleBatchFallback = False
    If $reset Then $resetJs = "true"
    Local $js = "(function(){var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
        "if(!d.body)return '__EMPTY__';var x=d.__hhTranslation;" & _
        "if(" & $resetJs & "){if(x&&x.url===d.URL){if(x.engine!=='google'||x.lang!==" & JsString($gWebLangCode) & "||x.complete)return '__ALREADY__';" & _
        "x.pendingNodes=[];x.pendingOriginal=[];x.pendingMasks=[];}else{" & _
        "x={url:d.URL,engine:'google',lang:" & JsString($gWebLangCode) & ",original:[],nodes:[],index:0,complete:false};d.__hhTranslation=x;}}" & _
        "if(!x||x.url!==d.URL)return '__CHANGED__';" & _
        "if(!x.allNodes){var w=d.createTreeWalker(d.body,NodeFilter.SHOW_TEXT,null),n,all=[];" & _
        "while((n=w.nextNode())){var p=n.parentElement;if(!p)continue;" & _
        "if(p.closest('script,style,noscript,pre,code,kbd,samp,textarea,svg,nav,aside,[contenteditable],.codebox,.codeheader,.codeSnippetContainer,.autoit-code'))continue;" & _
        "if(n.nodeValue&&n.nodeValue.trim()&&!/^(?:\s*[_$]?[A-Za-z][_A-Za-z0-9]*(?:\(\))?\s*)$/.test(n.nodeValue))all.push(n);}x.allNodes=all;}" & _
        "if(x.index>=x.allNodes.length){x.complete=true;return '__DONE__';}" & _
        "if(!x.allNodes[x.index].isConnected)return '__CHANGED__';" & _
        "var a=[],o=[],total=0,lim=" & $gGoogleBatchCount & ";" & _
        "for(var i=x.index;i<x.allNodes.length&&a.length<lim;i++){var v=x.allNodes[i].nodeValue;" & _
        "if(total+v.length>4500&&a.length)break;if(v.length>1800&&a.length)break;" & _
        "a.push(x.allNodes[i]);o.push(v);total+=v.length;}" & _
        "var masks=[],safe=[];for(var j=0;j<o.length;j++){var m=[],k=0;" & _
        "var v=o[j].replace(/\$[A-Za-z_][A-Za-z0-9_]*|@[A-Za-z_][A-Za-z0-9_]*|\b_[A-Za-z][A-Za-z0-9_]*\b|\b[A-Za-z_][A-Za-z0-9_]*\s*\(\s*\)/g,function(t){" & _
        "var tag='⟦HH'+(k++)+'⟧';m.push([tag,t]);return tag;});masks.push(m);safe.push(v);}" & _
        "x.pendingNodes=a;x.pendingOriginal=o;x.pendingMasks=masks;return '__HH_PROGRESS__'+x.allNodes.length+'|'+safe.join('" & $gGoogleBatchSep & "');})()"
    $gGooglePageRequest = HH_WebExec($js, "HH_GooglePageResult")
    If $gGooglePageRequest = 0 Then
        $gGooglePageMode = False
        HH_TrMsg("Google 整頁翻譯", "無法擷取頁面文字。")
    EndIf
EndFunc

; 擷取結果回呼：先查快取，沒有才送出請求。
Func HH_GooglePageResult($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If $iRequestId <> $gGooglePageRequest Then Return
    $gGooglePageRequest = 0
    If Not $gGooglePageMode Then Return
    If StringLeft($raw, 1) <> '"' Then
        $gGooglePageMode = False
        HH_TrMsg("Google 整頁翻譯", "頁面讀取失敗。")
        Return
    EndIf
    Local $txt = HH_AI_Unescape(StringMid($raw, 2, StringLen($raw) - 2))
    If StringLeft($txt, 15) = "__HH_PROGRESS__" Then
        Local $sepPos = StringInStr($txt, "|")
        If $sepPos > 15 Then
            $gGooglePageTotal = Number(StringMid($txt, 16, $sepPos - 16))
            $txt = StringMid($txt, $sepPos + 1)
            ; 最後一批可能少於設定的 3 個節點，須依實際數量計算。
            $gGoogleBatchCount = 1
            Local $splitOffset = 1
            While 1
                $splitOffset = StringInStr($txt, $gGoogleBatchSep, 1, 1, $splitOffset)
                If $splitOffset = 0 Then ExitLoop
                $gGoogleBatchCount += 1
                $splitOffset += StringLen($gGoogleBatchSep)
            WEnd
            If $gGoogleProgressClock = 0 Or TimerDiff($gGoogleProgressClock) > 450 Then
                HH_GoogleShowProgress()
                $gGoogleProgressClock = TimerInit()
            EndIf
        EndIf
    EndIf
    Switch $txt
        Case "__DONE__"
            $gGooglePageMode = False
            HH_TrNotifyClose()
            HH_TrNotify("Google 整頁翻譯完成", "共 " & $gGooglePageDone & " 個文字節點；快取命中 " & $gGoogleCacheHits & " 批。", $AUI_NOTIFY_SUCCESS, 6000)
            Return
        Case "__ALREADY__", "__EMPTY__", "__CHANGED__"
            $gGooglePageMode = False
            HH_TrNotify("Google 整頁翻譯", "頁面已有翻譯內容、沒有可翻譯文字或已切換頁面；若需重新翻譯，請先使用「AI 還原原文」。", $AUI_NOTIFY_INFO, 6000)
            Return
    EndSwitch
    ; 優先查詢記憶體與永久快取，批次及單節點均可命中。
    Local $cached = HH_GoogleCacheRead($txt)
    If $cached <> "" Then
        If $gGoogleBatchCount > 1 Then
            Local $cachedParts = StringSplit($cached, $gGoogleBatchSep, 1)
            If $cachedParts[0] = $gGoogleBatchCount Then
                $gGoogleCacheHits += 1
                HH_GoogleApplyBatch($cachedParts)
                Return
            EndIf
        Else
            $gGoogleCacheHits += 1
            HH_GoogleApplyPage($cached)
            Return
        EndIf
    EndIf
    If StringLen($txt) > 1800 Then
        ; 超長文字節點不送出，保留原文，繼續下一個節點。
        HH_GoogleApplyPage($txt)
        Return
    EndIf
    $gGooglePageSource = $txt
    HH_GoogleSendPageText($txt)
EndFunc

; 集中送出 Google 整頁請求，供暫時性 HTTP 500 重試使用。
Func HH_GoogleSendPageText($txt)
    If Not $gGooglePageMode Then Return
    Local $http = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($http) Then
        $gGooglePageMode = False
        Return
    EndIf
    ; translate_a/t 一次接受多個 q，回傳同順序陣列；不再依賴分隔符，可放心加大批次。
    Local $parts = StringSplit($txt, $gGoogleBatchSep, 1), $body = ""
    For $i = 1 To $parts[0]
        $body &= ($i > 1 ? "&" : "") & "q=" & HH_UrlEncodeUtf8($parts[$i])
    Next
    $http.SetTimeouts(10000, 10000, 15000, 30000)
    $http.Open("POST", "https://translate.googleapis.com/translate_a/t?client=gtx&sl=auto&tl=" & $gWebLangCode & "&format=text", True)
    $http.SetRequestHeader("User-Agent", "Mozilla/5.0")
    $http.SetRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=utf-8")
    $http.Send(StringToBinary($body, 4))
    If @error Then
        $gGooglePageMode = False
        HH_TrMsg("Google 整頁翻譯", "無法送出翻譯請求；已完成的譯文保留。")
        Return
    EndIf
    $gGoogleHttp = $http
    $gGoogleClock = TimerInit()
EndFunc

; 解析 translate_a/t：[["譯文","en"],...] 或 ["譯文",...]；以分隔符串回，供既有批次套用流程使用。
Func HH_GoogleParseMulti($json)
    Local $depth = 0, $inString = False, $escaped = False, $part = "", $out = "", $count = 0, $taken = False
    For $i = 1 To StringLen($json)
        Local $ch = StringMid($json, $i, 1)
        If $inString Then
            If $escaped Then
                $part &= $ch
                $escaped = False
            ElseIf $ch = "\" Then
                $part &= $ch
                $escaped = True
            ElseIf $ch = '"' Then
                $inString = False
                ; 第 1 層的字串，或第 2 層陣列中的第一個字串，才是譯文。
                If ($depth = 1) Or ($depth = 2 And Not $taken) Then
                    $out &= ($count > 0 ? $gGoogleBatchSep : "") & HH_AI_Unescape($part)
                    $count += 1
                    If $depth = 2 Then $taken = True
                EndIf
            Else
                $part &= $ch
            EndIf
        ElseIf $ch = '"' Then
            $inString = True
            $part = ""
        ElseIf $ch = "[" Then
            $depth += 1
            If $depth = 2 Then $taken = False
        ElseIf $ch = "]" Then
            $depth -= 1
        EndIf
    Next
    If $count = 0 Then Return SetError(1, 0, "")
    Return SetExtended($count, $out)
EndFunc

; 批次譯文只有分隔符數量完全吻合時才會套用，否則退回單節點。
; 台灣 AutoIt 文件用語：僅處理已翻譯的中文詞彙，不修改英文函式與參數。
; 此步驟在快取讀取後套用，舊快取也可享有新版用語修正。
Func HH_GoogleTaiwanTerms($translated)
    If $gWebLangCode <> "zh-TW" Then Return $translated
    Local $out = $translated
    $out = StringReplace($out, "鼠標", "滑鼠", 0, 1)
    $out = StringReplace($out, "默認", "預設", 0, 1)
    $out = StringReplace($out, "窗口", "視窗", 0, 1)
    $out = StringReplace($out, "文件夾", "資料夾", 0, 1)
    $out = StringReplace($out, "剪貼板", "剪貼簿", 0, 1)
    $out = StringReplace($out, "字符串", "字串", 0, 1)
    $out = StringReplace($out, "數組", "陣列", 0, 1)
    $out = StringReplace($out, "變量", "變數", 0, 1)
    $out = StringReplace($out, "函數", "函式", 0, 1)
    $out = StringReplace($out, "程序", "程式", 0, 1)
    $out = StringReplace($out, "菜單", "選單", 0, 1)
    $out = StringReplace($out, "打印", "列印", 0, 1)
    Return $out
EndFunc

; 失敗批次原文回填：不寫入快取，不破壞文字節點順序。
; 透過原本的 ApplyResult 推進索引，避免網路失敗時卡死。
Func HH_GoogleApplyOriginalPending()
    If Not $gGooglePageMode Then Return
    Local $js = "(function(){var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
        "var x=d.__hhTranslation;if(!x||x.url!==d.URL||!x.pendingNodes)return false;" & _
        "for(var i=0;i<x.pendingNodes.length;i++){if(!x.pendingNodes[i].isConnected||x.pendingNodes[i].nodeValue!==x.pendingOriginal[i])return false;}" & _
        "var n=x.pendingNodes.length;x.index+=n;x.pendingNodes=[];return n;})()"
    $gGooglePageRequest = HH_WebExec($js, "HH_GoogleSkipResult")
    If $gGooglePageRequest = 0 Then HH_GoogleStopPage()
EndFunc

; 略過批次的回呼。
Func HH_GoogleSkipResult($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If $iRequestId <> $gGooglePageRequest Then Return
    $gGooglePageRequest = 0
    If Not $gGooglePageMode Then Return
    If $raw = "false" Or Not StringRegExp($raw, "^[0-9]+$") Then
        HH_GoogleStopPage()
        Return
    EndIf
    $gGooglePageDone += Number($raw)
    HH_GoogleShowProgress()
    HH_GoogleNextPage()
EndFunc

; 把多段譯文套回文字節點（保護標記遺失時保留原文）。
Func HH_GoogleApplyBatch(ByRef $parts)
    If Not $gGooglePageMode Then Return
    $gGoogleAppliedCount = $parts[0]
    Local $arr = "["
    For $i = 1 To $parts[0]
        If $i > 1 Then $arr &= ","
        $arr &= HH_AI_JsonQuote(HH_GoogleTaiwanTerms($parts[$i]))
    Next
    $arr &= "]"
    Local $js = "(function(){var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
        "var x=d.__hhTranslation,v=" & $arr & ";if(!x||x.engine!=='google'||x.url!==d.URL||!x.pendingNodes||x.pendingNodes.length!==v.length)return false;" & _
        "for(var i=0;i<v.length;i++){if(!x.pendingNodes[i].isConnected||x.pendingNodes[i].nodeValue!==x.pendingOriginal[i])return false;" & _
        "var mm=x.pendingMasks&&x.pendingMasks[i]||[];for(var k=0;k<mm.length;k++){" & _
        "var tag=mm[k][0],at=v[i].indexOf(tag);if(at<0){v[i]=x.pendingOriginal[i];break;}" & _
        "v[i]=v[i].split(tag).join(mm[k][1]);}}" & _
        "for(var j=0;j<v.length;j++){var n=x.pendingNodes[j],po=x.pendingOriginal[j],lead=po.match(/^\s*/)[0],tail=po.match(/\s*$/)[0];x.nodes.push(n);x.original.push(po);n.nodeValue=lead+v[j].trim()+tail;}" & _
        "x.index+=v.length;x.pendingNodes=[];return true;})()"
    $gGooglePageRequest = HH_WebExec($js, "HH_GoogleApplyResult")
EndFunc

; 把單段譯文套回文字節點。
Func HH_GoogleApplyPage($translated)
    If Not $gGooglePageMode Then Return
    $gGoogleAppliedCount = 1
    Local $js = "(function(){var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
        "var x=d.__hhTranslation;if(!x||x.engine!=='google'||x.url!==d.URL||!x.pendingNodes||x.pendingNodes.length!==1)return false;" & _
        "var n=x.pendingNodes[0];if(!n.isConnected||n.nodeValue!==x.pendingOriginal[0])return false;" & _
        "var v=" & HH_AI_JsonQuote(HH_GoogleTaiwanTerms($translated)) & ";" & _
        "var mm=x.pendingMasks&&x.pendingMasks[0]||[];for(var k=0;k<mm.length;k++){" & _
        "var tag=mm[k][0];if(v.indexOf(tag)<0){v=x.pendingOriginal[0];break;}v=v.split(tag).join(mm[k][1]);}" & _
        "x.nodes.push(n);x.original.push(x.pendingOriginal[0]);n.nodeValue=v;" & _
        "x.index++;x.pendingNodes=[];return true;})()"
    $gGooglePageRequest = HH_WebExec($js, "HH_GoogleApplyResult")
EndFunc

; 套用結果回呼：更新進度並繼續下一批。
Func HH_GoogleApplyResult($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If $iRequestId <> $gGooglePageRequest Then Return
    $gGooglePageRequest = 0
    If Not $gGooglePageMode Then Return
    If $raw <> "true" Then
        $gGooglePageMode = False
        HH_TrMsg("Google 整頁翻譯", "頁面已改變，已停止翻譯。")
        Return
    EndIf
    ; 以實際套用的節點數計算進度，避免最後一批不足 3 個時超計。
    $gGooglePageDone += $gGoogleAppliedCount
    HH_GoogleShowProgress()
    HH_GoogleNextPage()
EndFunc

; Google translate_a/single 回應：[[[譯文,原文,...],...], ...]
; 以括號深度與 JSON 引號狀態只擷取每個片段的第一個字串。
Func HH_GoogleExtractTranslatedText($json)
    Local $depth = 0, $inString = False, $escaped = False
    Local $capture = False, $gotFirst = False, $part = "", $out = "", $found = 0
    For $i = 1 To StringLen($json)
        Local $ch = StringMid($json, $i, 1)
        If $inString Then
            If $escaped Then
                If $capture Then $part &= $ch
                $escaped = False
            ElseIf $ch = "\" Then
                If $capture Then $part &= $ch
                $escaped = True
            ElseIf $ch = '"' Then
                $inString = False
                If $capture Then
                    $out &= HH_AI_Unescape($part)
                    $found += 1
                    $capture = False
                    $gotFirst = True
                EndIf
            Else
                If $capture Then $part &= $ch
            EndIf
            ContinueLoop
        EndIf
        Switch $ch
            Case '"'
                $inString = True
                If $depth = 3 And Not $gotFirst Then
                    $capture = True
                    $part = ""
                EndIf
            Case "["
                $depth += 1
                If $depth = 3 Then $gotFirst = False
            Case "]"
                If $depth = 2 Then ExitLoop ; 已離開第一個翻譯陣列
                $depth -= 1
        EndSwitch
    Next
    If $found = 0 Or $inString Then Return SetError(1, 0, "")
    Return $out
EndFunc
