#include-once
; =============================================================================
; Html Helper － 網頁 AI 翻譯
;
; AI 翻譯選取文字與整頁翻譯。
; 整頁翻譯以多個槽位同時送出請求（0 閒置／1 擷取／2 等待回應／3 延遲重送／4 套用中）
; ，失敗批次自動補翻一次，可還原原文。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ===== 翻譯進度與安全狀態 =====
Func HH_AI_ShowProgress($dialog = False)
    Local $state = "尚未開始或已結束"
    If $gAiPageMode Then $state = "翻譯中"
    If $gAiPaused Then $state = "已暫停"
    Local $msg = "AI（同時 " & $gAiPar & " 個請求）：" & $state & @CRLF & _
        "成功批次：" & $gAiPageBatchCount & @CRLF & _
        "失敗／略過事件：" & $gAiPageSkipped & @CRLF & _
        "累計已套用節點：" & $gAiPageNodeCount & @CRLF & _
        "已掃描位置：" & $gAiPagePosition & " / " & $gAiPageTotal & _
        ($gAiPageTotal > 0 ? "（" & Int(100 * $gAiPagePosition / $gAiPageTotal) & "%）" : "")
    If $dialog Then
        HH_TrNotify("AI 翻譯進度", $msg, $AUI_NOTIFY_INFO, 6000)
    ElseIf $gAiPageMode Then
        HH_TrProgress("AI 整頁翻譯", $msg)
    EndIf
EndFunc

; ===== 控制結束 =====
; ===== 整頁文字節點翻譯（不修改原始 CHM 或 HTML 檔案） =====
; 僅翻譯目前頁面的文字節點。程式碼、連結目標、屬性與 DOM 結構均保留。
Func HH_AI_TranslatePage()
    If $gGooglePageMode Or IsObj($gGoogleHttp) Or $gGooglePageRequest <> 0 Then
        HH_TrMsg("AI 整頁翻譯", "請先停止 Google 整頁翻譯。")
        Return
    EndIf
    If $gAiKey = "" Then
        HH_AI_Settings()
        If $gAiKey = "" Then Return
    EndIf
    If $gAiPageMode Or $gAiRequest <> 0 Or IsObj($gAiHttp) Or $gAiBusyRetryDelay > 0 Then
        HH_TrMsg("AI 整頁翻譯", "已有翻譯工作進行中。")
        Return
    EndIf
    ; 設定只在開始時讀取一次（含 DPAPI 解密），之後每批直接沿用。
    $gAiPageCfg = P136ApplyActive()
    $gAiPar = Number($gAiPageCfg.Item("parallel"))
    If $gAiPar < 1 Then $gAiPar = 1
    If $gAiPar > $HH_AI_MAXPAR Then $gAiPar = $HH_AI_MAXPAR
    $gAiPageItems = Number($gAiPageCfg.Item("items"))
    If $gAiPageItems < 1 Then $gAiPageItems = 20
    $gAiPageChars = Number($gAiPageCfg.Item("chars"))
    If $gAiPageChars < 500 Then $gAiPageChars = 500
    If $gAiPageChars > 12000 Then $gAiPageChars = 12000
    $gAiPageDelay = Number($gAiPageCfg.Item("delay"))
    If $gAiPageDelay < 0 Then $gAiPageDelay = 0
    $gAiPageTimeout = Number($gAiPageCfg.Item("timeout")) * 1000
    If $gAiPageTimeout < 30000 Then $gAiPageTimeout = 30000
    $gAiPaused = False
    $gAiPageMode = True
    $gAiPageBatchCount = 0
    $gAiPageNodeCount = 0
    $gAiPageSkipped = 0
    $gAiPageTotal = 0
    $gAiPagePosition = 0
    $gAiBusyRetryCount = 0
    $gAiTaking = 0
    $gAiTakeSlot = -1
    $gAiTakeReset = True
    $gAiExhausted = False
    $gAiRetryPass = False
    $gAiLastTake = 0
    For $i = 0 To $HH_AI_MAXPAR - 1
        HH_AI_SlotClear($i)
    Next
    HH_AI_ShowProgress()
EndFunc

; 清空單一請求槽位。
Func HH_AI_SlotClear($i)
    If IsObj($gAiSlotHttp[$i]) Then $gAiSlotHttp[$i].Abort()
    $gAiSlotHttp[$i] = 0
    $gAiSlotState[$i] = 0
    $gAiSlotId[$i] = 0
    $gAiSlotText[$i] = ""
    $gAiSlotRetry[$i] = 0
    $gAiSlotDelay[$i] = 0
    $gAiSlotReq[$i] = 0
    $gAiSlotModelTry[$i] = False
EndFunc

; 停止 AI 整頁翻譯：中止所有同時進行的請求；已套用的譯文保留，可用「AI 還原原文」復原。
Func HH_AI_PageStop()
    $gAiPageMode = False
    $gAiTaking = 0
    $gAiTakeSlot = -1
    For $i = 0 To $HH_AI_MAXPAR - 1
        HH_AI_SlotClear($i)
    Next
    HH_TrNotifyClose()
EndFunc

; 主迴圈呼叫：同時維持多個 AI 請求（數量依設定檔「同時請求數」）。
; 頁面文字依序分批保留，譯文回來後依批次編號各自套用，不會錯位。
Func HH_AI_PageTick()
    If Not $gAiPageMode Then Return
    Local $active = 0
    For $i = 0 To $HH_AI_MAXPAR - 1
        Switch $gAiSlotState[$i]
            Case 2
                HH_AI_SlotPoll($i)
            Case 3
                If TimerDiff($gAiSlotClock[$i]) >= $gAiSlotDelay[$i] Then HH_AI_SlotSend($i)
        EndSwitch
        If Not $gAiPageMode Then Return
        If $gAiSlotState[$i] <> 0 Then $active += 1
    Next
    If $gAiTaking <> 0 Then Return
    If Not $gAiExhausted Then
        If $active >= $gAiPar Then Return
        If $gAiLastTake <> 0 And TimerDiff($gAiLastTake) < $gAiPageDelay Then Return
        For $i = 0 To $gAiPar - 1
            If $gAiSlotState[$i] = 0 Then
                HH_AI_Take($i)
                Return
            EndIf
        Next
        Return
    EndIf
    If $active > 0 Then Return
    If Not $gAiRetryPass Then
        ; 第一輪結束：失敗的批次自動再翻一次。
        $gAiRetryPass = True
        $gAiExhausted = False
        Return
    EndIf
    HH_AI_PageFinish()
EndFunc

; 產生取得翻譯目標文件的 JS（CHM 為 docframe 內文，否則為頁面本身）。
Func HH_AI_DocJs()
    Return "var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}"
EndFunc

; 從頁面擷取下一批文字節點（保護變數、網址等標記），放入指定槽位。
Func HH_AI_Take($slot)
    Local $resetJs = ($gAiTakeReset ? "true" : "false"), $retryJs = ($gAiRetryPass ? "true" : "false")
    Local $js = "(function(){" & HH_AI_DocJs() & _
        "if(!d.body)return '__EMPTY__';var x=d.__hhTranslation;" & _
        "if(" & $resetJs & "){if(x&&x.url===d.URL){if(x.engine!=='gemini'||x.lang!==" & JsString($gWebLangCode) & "||x.complete)return '__ALREADY__';" & _
        "x.requeue=x.requeue||[];if(x.batches){for(var bk in x.batches){x.requeue.push({start:x.batches[bk].start,end:x.batches[bk].end});}}x.batches={};}else{" & _
        "x={url:d.URL,engine:'gemini',lang:" & JsString($gWebLangCode) & ",original:[],nodes:[],index:0,complete:false,batches:{},seq:0,failedBatches:[],failedAgain:[],requeue:[]};d.__hhTranslation=x;}}" & _
        "if(!x||x.url!==d.URL)return '__CHANGED__';" & _
        "x.batches=x.batches||{};x.seq=x.seq||0;x.failedBatches=x.failedBatches||[];x.failedAgain=x.failedAgain||[];x.requeue=x.requeue||[];" & _
        "if(!x.allNodes){var w=d.createTreeWalker(d.body,NodeFilter.SHOW_TEXT,null),n,all=[];" & _
        "while((n=w.nextNode())){var p=n.parentElement;if(!p)continue;" & _
        "if(p.closest('script,style,noscript,pre,code,kbd,samp,textarea,svg,nav,aside,[contenteditable],.codebox,.codeheader,.codeSnippetContainer,.autoit-code'))continue;" & _
        "if(n.nodeValue&&n.nodeValue.trim()&&!/^(?:\s*[_$]?[A-Za-z][_A-Za-z0-9]*(?:\(\))?\s*)$/.test(n.nodeValue))all.push(n);}" & _
        "x.allNodes=all;}" & _
        "var nodes=[],a=[],s=0,e=0,retry=false,cnt=0,i,q;" & _
        "function grab(from,to){for(var k=from;k<to;k++){q=x.allNodes[k];if(!q||!q.isConnected||q.__hhDone)continue;nodes.push(q);a.push(q.nodeValue);}}" & _
        "if(x.requeue.length){var r0=x.requeue.shift();s=r0.start;e=r0.end;grab(s,e);}" & _
        "else if(x.index<x.allNodes.length){s=x.index;for(i=x.index;i<x.allNodes.length;i++){q=x.allNodes[i];if(!q.isConnected||q.__hhDone)continue;var t=q.nodeValue;" & _
        "if(a.length>=" & $gAiPageItems & "||(a.length>0&&cnt+t.length>" & $gAiPageChars & "))break;nodes.push(q);a.push(t);cnt+=t.length;}e=i;x.index=i;}" & _
        "else if(" & $retryJs & "){var r=x.failedBatches.shift();if(!r)return '__NOMORE__';s=r.start;e=r.end;retry=true;grab(s,e);}" & _
        "else return '__NOMORE__';" & _
        "if(!a.length)return '__RETRY_NEXT__';" & _
        "var id=++x.seq,masks=[],serial=0,re=/(\x60[^\x60\r\n]+\x60|\$[A-Za-z_][\w]*|@[A-Za-z_][\w]*|\b_[A-Za-z][\w]*(?=\s*\()|#[A-Za-z_][\w]*|https?:\/\/[^\s<>]+)/g;" & _
        "var safe=a.map(function(v){var m=[];var out=v.replace(re,function(token){var key='HHKEEP'+String(++serial).padStart(5,'0')+'HH';m.push([key,token]);return key;});masks.push(m);return out;});" & _
        "x.batches[id]={nodes:nodes,orig:a,masks:masks,start:s,end:e,retry:retry};" & _
        "return '__HH_AI_PROGRESS__'+x.allNodes.length+'|'+x.index+'|'+id+'|'+JSON.stringify(safe);})()"
    Local $req = HH_WebExec($js, "HH_AI_TakeResult")
    If $req = 0 Then
        HH_AI_PageStop()
        HH_TrMsg("AI 整頁翻譯", "無法讀取目前頁面。")
        Return
    EndIf
    $gAiTakeReset = False
    $gAiSlotState[$slot] = 1
    $gAiTaking = $req
    $gAiTakeSlot = $slot
    $gAiLastTake = TimerInit()
EndFunc

; 擷取結果回呼：解析進度與批次內容後送出請求。
Func HH_AI_TakeResult($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    Local $err = @error
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If $iRequestId <> $gAiTaking Then Return
    Local $slot = $gAiTakeSlot
    $gAiTaking = 0
    $gAiTakeSlot = -1
    If $slot >= 0 Then $gAiSlotState[$slot] = 0
    If Not $gAiPageMode Or $slot < 0 Then Return
    If $err Or StringLeft($raw, 1) <> '"' Then
        HH_AI_PageStop()
        HH_TrMsg("AI 整頁翻譯", "無法讀取頁面文字。")
        Return
    EndIf
    Local $payload = HH_AI_Unescape(StringMid($raw, 2, StringLen($raw) - 2))
    Switch $payload
        Case "__NOMORE__"
            $gAiExhausted = True
            Return
        Case "__RETRY_NEXT__"
            Return
        Case "__ALREADY__"
            HH_AI_PageStop()
            HH_TrNotify("AI 整頁翻譯", "此頁已完成翻譯，或由另一個引擎／其他目的語言建立翻譯紀錄。請先使用「AI 還原原文」，再重新翻譯。", $AUI_NOTIFY_INFO, 6000)
            Return
        Case "__EMPTY__", "__CHANGED__"
            HH_AI_PageStop()
            HH_TrNotify("AI 整頁翻譯", "此頁沒有可翻譯文字，或頁面已變更。", $AUI_NOTIFY_INFO, 5000)
            Return
    EndSwitch
    Local $m = StringRegExp($payload, "^__HH_AI_PROGRESS__([0-9]+)\|([0-9]+)\|([0-9]+)\|", 1)
    If Not IsArray($m) Then
        HH_AI_PageStop()
        HH_TrMsg("AI 整頁翻譯", "文字擷取格式不正確。")
        Return
    EndIf
    $gAiPageTotal = Number($m[0])
    $gAiPagePosition = Number($m[1])
    $gAiSlotId[$slot] = Number($m[2])
    $gAiSlotText[$slot] = StringRegExpReplace($payload, "^__HH_AI_PROGRESS__[0-9]+\|[0-9]+\|[0-9]+\|", "")
    $gAiSlotRetry[$slot] = 0
    $gAiSlotModelTry[$slot] = False
    HH_AI_SlotSend($slot)
EndFunc

; 建立 AI 請求（選取文字與整頁共用）；非同步送出，不在主執行緒等待回應。
Func HH_AI_MakeRequest($text, $page, $cfg, ByRef $gemini)
    Local $prompt = "請將下列 AutoIt 技術文件文字翻譯為" & HH_WebLangPrompt() & "。" & _
        "保持函式名稱、變數、參數、程式碼、網址及專有識別字不變。" & _
        "只輸出翻譯，不添加解說。"
    If $page Then
        $prompt = "將以下 JSON 字串陣列逐項翻譯成" & HH_WebLangPrompt() & "，輸出同長度的 JSON 字串陣列，不要 Markdown、解釋或額外項目。" & _
            "保留各字串前後空白、AutoIt 函式名稱、參數、變數、識別字、網址、程式碼與符號。HHKEEP加五位數字加HH 是不可更動的保護標記，必須原樣保留且不可重複。只翻譯自然語言。"
    EndIf
    Local $url = "", $body = "", $headers = ""
    $gemini = ($cfg.Item("protocol") = 1)
    Local $sendSystem = $prompt, $sendText = $text
    $p136GoogleJson = False
    If $cfg.Item("protocol") = 4 And $page Then
        $sendSystem = Chr(1)
        $sendText = P136GoogleFormJson($text)
        $p136GoogleJson = True
    EndIf
    P136Build($cfg, $sendSystem, $sendText, $url, $body, $headers)
    Local $http = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($http) Then Return 0
    Local $timeout = Number($cfg.Item("timeout")) * 1000
    If $timeout < 30000 Then $timeout = 60000
    $http.SetTimeouts(10000, 10000, 30000, $timeout)
    $http.Open("POST", $url, True)
    P136SetHeaders($http, $headers)
    $http.Send(StringToBinary($body, 4))
    If @error Then Return 0
    Return $http
EndFunc

; 送出槽位中的批次。
Func HH_AI_SlotSend($i)
    Local $gemini = False
    Local $http = HH_AI_MakeRequest($gAiSlotText[$i], True, $gAiPageCfg, $gemini)
    If Not IsObj($http) Then
        HH_AI_SlotFail($i)
        Return
    EndIf
    $gAiSlotHttp[$i] = $http
    $gAiSlotGemini[$i] = $gemini
    $gAiSlotState[$i] = 2
    $gAiSlotClock[$i] = TimerInit()
EndFunc

; 槽位延遲重送（限流或伺服器忙碌時）。
Func HH_AI_SlotWait($i, $ms)
    $gAiSlotHttp[$i] = 0
    $gAiSlotDelay[$i] = $ms
    $gAiSlotClock[$i] = TimerInit()
    $gAiSlotState[$i] = 3
EndFunc

; 檢查槽位請求：處理成功、限流重試、模型不存在、權限錯誤與逾時。
Func HH_AI_SlotPoll($i)
    Local $http = $gAiSlotHttp[$i]
    If Not IsObj($http) Then
        HH_AI_SlotFail($i)
        Return
    EndIf
    Local $done = $http.WaitForResponse(0)
    If @error Then
        HH_AI_SlotFail($i)
        Return
    EndIf
    If Not $done Then
        If TimerDiff($gAiSlotClock[$i]) > $gAiPageTimeout + 5000 Then
            $http.Abort()
            HH_AI_SlotFail($i)
        EndIf
        Return
    EndIf
    $gAiSlotHttp[$i] = 0
    Local $status = $http.Status, $resp = $http.ResponseText
    If $status = 404 And $gAiSlotGemini[$i] And Not $gAiSlotModelTry[$i] Then
        $gAiSlotModelTry[$i] = True
        Local $newModel = "", $suggested = StringRegExp($resp, '(?i)use models/([a-z0-9._-]+)', 1)
        If IsArray($suggested) Then $newModel = $suggested[0]
        If $newModel = "" Or $newModel = $gAiPageCfg.Item("model") Then $newModel = HH_AI_FindGeminiModel($gAiPageCfg.Item("endpoint"), $gAiPageCfg.Item("key"))
        If $newModel <> "" And $newModel <> $gAiPageCfg.Item("model") Then
            $gAiPageCfg.Item("model") = $newModel
            $gAiModel = $newModel
            _IniWrite($p136Ini, P136Section(P136Active()), "Model", $newModel)
            HH_AI_SlotSend($i)
            Return
        EndIf
    EndIf
    If $status = 429 Or $status = 500 Or $status = 502 Or $status = 503 Or $status = 504 Then
        ; 每日額度用完才停止；每分鐘限流則降低同時請求數並等待後重送。
        If $status = 429 And StringRegExp($resp, "(?i)per ?day|PerDay|daily") Then
            HH_AI_PageStop()
            HH_TrMsg("AI 免費額度", "此模型今日的 API 請求額度已用完，已停止翻譯。" & @CRLF & "已翻譯的文字保留，可用「AI 還原原文」復原。")
            Return
        EndIf
        If $gAiSlotRetry[$i] < 5 Then
            $gAiSlotRetry[$i] += 1
            Local $wait = 2000 * $gAiSlotRetry[$i]
            Local $hint = StringRegExp($resp, '(?i)"retryDelay"\s*:\s*"([0-9.]+)s"', 1)
            If IsArray($hint) Then $wait = Number($hint[0]) * 1000 + 500
            If $wait > 60000 Then $wait = 60000
            If $status = 429 And $gAiPar > 1 Then $gAiPar -= 1
            HH_AI_SlotWait($i, $wait)
            Return
        EndIf
        HH_AI_SlotFail($i)
        Return
    EndIf
    If $status = 401 Or $status = 403 Then
        HH_AI_PageStop()
        HH_TrMsg("AI 翻譯", "API 回應 HTTP " & $status & "，請檢查 API Key 與權限。" & @CRLF & StringLeft($resp, 600))
        Return
    EndIf
    If $status <> 200 Then
        HH_AI_SlotFail($i)
        Return
    EndIf
    Local $translated = P136Reply($p136Protocol, P136ResponseText($http))
    If @error Then
        HH_AI_SlotFail($i)
        Return
    EndIf
    Local $js = "(function(){" & HH_AI_DocJs() & _
        "var x=d.__hhTranslation;if(!x||x.engine!=='gemini'||x.url!==d.URL)return 'page changed';" & _
        "var b=x.batches&&x.batches[" & $gAiSlotId[$i] & "];if(!b)return 'gone';" & _
        "var t=" & HH_AI_JsonQuote($translated) & ";t=t.trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'');" & _
        "var a;try{a=JSON.parse(t);}catch(e){return 'invalid json';}" & _
        "if(!Array.isArray(a)||a.length!==b.nodes.length||!a.every(function(v){return typeof v==='string';}))return 'count mismatch';" & _
        "for(var k=0;k<a.length;k++){var masks=b.masks[k]||[];for(var m=0;m<masks.length;m++){" & _
        "var key=masks[m][0],first=a[k].indexOf(key);if(first<0||a[k].indexOf(key,first+key.length)>=0)return 'protected token missing';" & _
        "var keep=masks[m][1];a[k]=a[k].replace(key,function(){return keep;});}}" & _
        "var n=0;for(var j=0;j<a.length;j++){var q=b.nodes[j];if(!q.isConnected||q.nodeValue!==b.orig[j])continue;" & _
        "x.nodes.push(q);x.original.push(b.orig[j]);q.nodeValue=a[j];q.__hhDone=1;n++;}" & _
        "delete x.batches[" & $gAiSlotId[$i] & "];return 'ok:'+n;})()"
    Local $req = HH_WebExec($js, "HH_AI_SlotApplyResult")
    If $req = 0 Then
        HH_AI_SlotFail($i)
        Return
    EndIf
    $gAiSlotReq[$i] = $req
    $gAiSlotState[$i] = 4
EndFunc

; 依腳本請求 ID 找出槽位。
Func HH_AI_SlotByReq($req)
    If $req = 0 Then Return -1
    For $i = 0 To $HH_AI_MAXPAR - 1
        If $gAiSlotState[$i] = 4 And $gAiSlotReq[$i] = $req Then Return $i
    Next
    Return -1
EndFunc

; 套用譯文的回呼：統計成功數量或判定失敗。
Func HH_AI_SlotApplyResult($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If Not $gAiPageMode Then Return
    Local $i = HH_AI_SlotByReq($iRequestId)
    If $i < 0 Then Return
    $gAiSlotReq[$i] = 0
    If StringRegExp($raw, '^"ok:[0-9]+"$') Then
        $gAiPageBatchCount += 1
        $gAiPageNodeCount += Number(StringTrimRight(StringTrimLeft($raw, 4), 1))
        $gAiSlotState[$i] = 0
        Return
    EndIf
    If $raw = '"gone"' Then
        $gAiSlotState[$i] = 0
        Return
    EndIf
    If $raw = '"invalid json"' Or $raw = '"count mismatch"' Or $raw = '"protected token missing"' Then
        HH_AI_SlotFail($i)
        Return
    EndIf
    HH_AI_PageStop()
    HH_TrMsg("AI 整頁翻譯", "譯文未套用（頁面已變更）。" & @CRLF & StringLeft($raw, 180))
EndFunc

; 單一批次失敗：保留原文，記錄範圍，第一輪結束後自動補翻一次。
Func HH_AI_SlotFail($i)
    $gAiSlotHttp[$i] = 0
    If $gAiSlotId[$i] <= 0 Then
        $gAiSlotState[$i] = 0
        Return
    EndIf
    Local $js = "(function(){" & HH_AI_DocJs() & _
        "var x=d.__hhTranslation;if(!x||x.engine!=='gemini'||x.url!==d.URL)return 'changed';" & _
        "var b=x.batches&&x.batches[" & $gAiSlotId[$i] & "];if(!b)return 'ok';delete x.batches[" & $gAiSlotId[$i] & "];" & _
        "(b.retry?(x.failedAgain||(x.failedAgain=[])):(x.failedBatches||(x.failedBatches=[]))).push({start:b.start,end:b.end});return 'ok';})()"
    Local $req = HH_WebExec($js, "HH_AI_SlotFailResult")
    If $req = 0 Then
        HH_AI_PageStop()
        HH_TrMsg("AI 整頁翻譯", "無法略過失敗批次。")
        Return
    EndIf
    $gAiSlotReq[$i] = $req
    $gAiSlotState[$i] = 4
EndFunc

; 失敗記錄的回呼。
Func HH_AI_SlotFailResult($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If Not $gAiPageMode Then Return
    Local $i = HH_AI_SlotByReq($iRequestId)
    If $i < 0 Then Return
    $gAiSlotReq[$i] = 0
    $gAiSlotState[$i] = 0
    If $raw <> '"ok"' Then
        HH_AI_PageStop()
        HH_TrMsg("AI 整頁翻譯", "頁面已變更，為避免錯位已停止翻譯。")
        Return
    EndIf
    $gAiPageSkipped += 1
EndFunc

; 整頁翻譯完成：顯示統計。
Func HH_AI_PageFinish()
    $gAiPagePosition = $gAiPageTotal
    HH_AI_PageStop()
    HH_WebFire("(function(){" & HH_AI_DocJs() & "var x=d.__hhTranslation;if(x&&x.engine==='gemini')x.complete=!(x.failedAgain&&x.failedAgain.length);})()")
    HH_TrNotify("AI 整頁翻譯完成", "成功 " & $gAiPageBatchCount & " 批，共 " & $gAiPageNodeCount & " 段；失敗事件 " & $gAiPageSkipped & " 次（失敗批次已自動補翻一次）。", ($gAiPageSkipped > 0 ? $AUI_NOTIFY_WARNING : $AUI_NOTIFY_SUCCESS), 6000)
EndFunc

; 還原原文：停止所有翻譯並把文字節點改回原本內容。
Func HH_AI_RestorePage()
    $gAiPaused = False
    If $gGooglePageMode Then HH_GoogleStopPage()
    ; 中止後續批次；保留已翻譯節點的原始文字以供還原。
    HH_AI_PageStop()
    $gAiPageRequest = 0
    $gAiBusyRetryDelay = 0
    $gAiBusyRetryText = ""
    $gAiBusyRetryCount = 0
    $gAiRequest = 0
    If IsObj($gAiHttp) Then $gAiHttp.Abort()
    $gAiHttp = 0
    Local $js = "(function(){var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
        "var x=d.__hhTranslation;if(!x||x.url!==d.URL)return false;" & _
        "for(var i=0;i<x.nodes.length;i++){if(x.nodes[i].isConnected){x.nodes[i].nodeValue=x.original[i];try{delete x.nodes[i].__hhDone;}catch(e){}}}" & _
        "delete d.__hhTranslation;return true;})()"
    HH_WebExec($js)
EndFunc

; ===== 整頁翻譯結束 =====
; ===== AI 選取文字翻譯（第一階段） =====
; API Key 僅保留於執行階段記憶體，不寫入 INI、網頁或日誌。
Func HH_AI_Settings()
    ; 改用 AUI「AI API 設定」視窗（多設定檔、各家通道、DPAPI 加密 Key），不再使用 InputBox。
    P136ApplyActive()
    P136OpenSettings($gWnd)
EndFunc

; 從 Google 官方 models.list 取得目前 API Key 可使用 generateContent 的模型。
; 不將 API Key 寫入網址、設定檔或診斷訊息。
Func HH_AI_FindGeminiModel($baseUrl, $key)
    Local $base = "https://generativelanguage.googleapis.com/v1beta/models"
    If StringInStr($baseUrl, "/v1/models") Then $base = "https://generativelanguage.googleapis.com/v1/models"
    Local $http = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($http) Then Return ""
    $http.SetTimeouts(10000, 10000, 20000, 30000)
    $http.Open("GET", $base & "?pageSize=1000", False)
    $http.SetRequestHeader("x-goog-api-key", $key)
    $http.Send()
    If @error Then
        HH_TrMsg("Gemini 模型", "無法取得模型清單，請檢查網路。")
        Return ""
    EndIf
    If $http.Status <> 200 Then
        HH_TrMsg("Gemini 模型", "查詢模型清單失敗：HTTP " & $http.Status)
        Return ""
    EndIf
    Local $json = $http.ResponseText
    ; 以每個 model 物件為單位，確認支援 generateContent。
    Local $blocks = StringRegExp($json, '(?s)\{\s*"name"\s*:\s*"models/[^"\r\n]+".*?(?=\{\s*"name"\s*:|\]\s*\}|$)', 3)
    Local $first = "", $preferred = "", $name
    If IsArray($blocks) Then
        For $i = 0 To UBound($blocks) - 1
            If Not StringInStr($blocks[$i], '"generateContent"') Then ContinueLoop
            Local $m = StringRegExp($blocks[$i], '"name"\s*:\s*"models/([^"\r\n]+)"', 1)
            If Not IsArray($m) Then ContinueLoop
            $name = $m[0]
            If StringInStr($name, "gemini-2.5-flash") Then ContinueLoop ; 新帳號已不可用
            If $first = "" Then $first = $name
            If StringInStr($name, "gemini-3.8-flash") Then Return $name
            If StringInStr($name, "flash") And Not StringInStr($name, "preview") And Not StringInStr($name, "exp") Then
                $preferred = $name
            EndIf
        Next
    EndIf
    If $preferred <> "" Then Return $preferred
    If $first <> "" Then Return $first
    HH_TrMsg("Gemini 模型", "模型清單沒有找到支援 generateContent 的模型。請在 Google AI Studio 確認 API Key 權限。")
    Return ""
EndFunc

; AI 翻譯選取文字：先讀取頁面選取內容。
Func HH_AI_TranslateSelection()
    If $gGooglePageMode Or IsObj($gGoogleHttp) Then
        HH_TrMsg("AI 翻譯", "請先完成或停止 Google 翻譯。")
        Return
    EndIf
    If $gAiPageMode Or $gAiPageRequest <> 0 Or IsObj($gAiHttp) Or $gAiBusyRetryDelay > 0 Or $gGooglePageMode Or IsObj($gGoogleHttp) Then
        HH_TrMsg("AI 翻譯", "整頁翻譯進行中，請先完成或停止。")
        Return
    EndIf
    $gAiBusyRetryCount = 0
    $gAiBusyRetryDelay = 0
    If $gAiKey = "" Then
        HH_AI_Settings()
        If $gAiKey = "" Then Return
    EndIf
    If $gAiRequest <> 0 Or IsObj($gAiHttp) Then
        HH_TrMsg("AI 翻譯", "翻譯請求正在處理中，請稍候。")
        Return
    EndIf
    ; 選取範圍優先使用 CHM 的 docframe，其次使用一般網頁。
    Local $js = "(function(){var d=document;try{var f=d.getElementById('docframe');" & _
        "if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
        "var w=d.defaultView||window,s=String(w.getSelection?w.getSelection():'');" & _
        "if(!s&&d!==document)s=String(window.getSelection?window.getSelection():'');" & _
        "return s.substring(0,12000);})()"
    $gAiRequest = HH_WebExec($js, "HH_AI_SelectedResult")
    If $gAiRequest = 0 Then HH_TrMsg("AI 翻譯", "無法讀取目前頁面的選取文字。")
EndFunc

; 讀到選取文字後送出翻譯。
Func HH_AI_SelectedResult($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    Local $err = @error
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    $gAiRequest = 0
    If $err Or StringLeft($raw, 1) <> '"' Then
        HH_TrMsg("AI 翻譯", "讀取選取文字失敗。")
        Return
    EndIf
    Local $text = HH_AI_Unescape(StringMid($raw, 2, StringLen($raw) - 2))
    If StringStripWS($text, 3) = "" Then
        HH_TrMsg("AI 翻譯", "請先在文件中反白選取要翻譯的文字。")
        Return
    EndIf
    HH_AI_Send($text)
EndFunc

; 送出選取文字的翻譯請求。
Func HH_AI_Send($text, $retry = False)
    Local $cfg = P136ApplyActive(), $gemini = False
    If $gAiModel <> "" Then $cfg.Item("model") = $gAiModel
    Local $http = HH_AI_MakeRequest($text, False, $cfg, $gemini)
    If Not IsObj($http) Then
        HH_TrMsg("AI 翻譯", "無法送出翻譯請求，請檢查網路與 API 設定。")
        Return
    EndIf
    $gAiHttp = $http
    $gAiPendingText = $text
    $gAiPendingRetry = $retry
    $gAiPendingGemini = $gemini
    $gAiRequestClock = TimerInit()
EndFunc

; 由主事件迴圈定期檢查 WinHTTP，避免同步 Send 阻塞 WebView2。
Func HH_AI_PollHttp()
    ; HTTP 503/429：由主事件迴圈延遲重試，不凍結 AUI 視窗。
    If $gAiBusyRetryDelay > 0 Then
        If TimerDiff($gAiBusyRetryClock) < $gAiBusyRetryDelay Then Return
        Local $retryText = $gAiBusyRetryText
        $gAiBusyRetryDelay = 0
        $gAiBusyRetryText = ""
        HH_AI_Send($retryText, True)
        Return
    EndIf
    If Not IsObj($gAiHttp) Then Return
    Local $http = $gAiHttp
    ; 0 秒超時：只查詢是否完成，不等待伺服器。
    Local $done = $http.WaitForResponse(0)
    If @error Then
        $gAiHttp = 0
        HH_TrMsg("AI 翻譯", "API 請求失敗，請檢查網路連線。")
        Return
    EndIf
    If Not $done Then
        If TimerDiff($gAiRequestClock) > 90000 Then
            $http.Abort()
            $gAiHttp = 0
            HH_TrMsg("AI 翻譯", "翻譯逾時（90 秒），請稍後再試。")
        EndIf
        Return
    EndIf
    $gAiHttp = 0
    Local $text = $gAiPendingText, $retry = $gAiPendingRetry, $gemini = $gAiPendingGemini
    $gAiPendingText = ""
    If $http.Status = 404 And $gemini And Not $retry Then
        ; 優先使用 Google 404 錯誤訊息明確指定的替代模型。
        Local $newModel = ""
        Local $suggested = StringRegExp($http.ResponseText, '(?i)use models/([a-z0-9._-]+)', 1)
        If IsArray($suggested) Then $newModel = $suggested[0]
        If $newModel = "" Or $newModel = $gAiModel Then $newModel = HH_AI_FindGeminiModel($gAiEndpoint, $gAiKey)
        If $newModel <> "" And $newModel <> $gAiModel Then
            $gAiModel = $newModel
            _IniWrite($gIni, "AI", "Model", $newModel)
            HH_AI_Send($text, True)
            Return
        EndIf
    EndIf
    ; 免費額度耗盡不可短時間重試，避免浪費請求與無限等待。
    If $http.Status = 429 And (StringInStr($http.ResponseText, "free_tier_requests") Or StringInStr($http.ResponseText, "RESOURCE_EXHAUSTED")) Then
        $gAiBusyRetryDelay = 0
        $gAiBusyRetryCount = 0
        HH_TrMsg("Gemini 免費額度", "此模型的 API 免費請求額度已用完，已停止翻譯及自動重試。" & @CRLF & "已翻譯的頁面文字仍可使用「AI 還原原文」復原。" & @CRLF & "可改用右鍵「免費 Google 翻譯選取文字」繼續翻譯少量文字。")
        Return
    EndIf
    If ($http.Status = 503 Or $http.Status = 429 Or $http.Status = 502 Or $http.Status = 504) And $gAiBusyRetryCount < 3 Then
        $gAiBusyRetryCount += 1
        Switch $gAiBusyRetryCount
            Case 1
                $gAiBusyRetryDelay = 2000
            Case 2
                $gAiBusyRetryDelay = 5000
            Case Else
                $gAiBusyRetryDelay = 10000
        EndSwitch
        $gAiBusyRetryText = $text
        $gAiBusyRetryClock = TimerInit()
        Return
    EndIf
    If $http.Status <> 200 Then
        $gAiBusyRetryCount = 0
        Local $errText = StringLeft($http.ResponseText, 800)
        ; 不顯示 API Key 或完整請求資訊。
        HH_TrMsg("AI 翻譯", "API 回應 HTTP " & $http.Status & "。" & @CRLF & $errText)
        Return
    EndIf
    Local $response = P136ResponseText($http)
    Local $translated = P136Reply($p136Protocol, $response)
    If @error Then
        HH_TrMsg("AI 翻譯", "API 已回應，但無法解析譯文。請確認模型有輸出文字。")
        Return
    EndIf
    $gAiBusyRetryCount = 0
    P135ClipboardDialog("AI 翻譯結果（" & $gWebLangName & "）", $translated)
EndFunc
