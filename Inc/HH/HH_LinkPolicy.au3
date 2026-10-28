#include-once
; =============================================================================
; Html Helper － 中鍵開新分頁
;
; 網頁內以滑鼠中鍵點連結時在背景開新分頁：
; 網頁端記錄＋原生游標命中測試兩種方式互補；分頁列上中鍵關閉分頁。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 注入腳本的完成回呼：釋放結果。
Func HH91_InstallDone($iWebId, $iRequestId, $iStatus)
    #forceref $iStatus
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
EndFunc

; 定期在頁面與同源框架注入中鍵記錄腳本。
Func HH_InstallLinkPolicy()
    If $gDrawerOpen Then Return
    ; 在最上層與同源框架（CHM iframe）的 window 捕獲階段記錄中鍵按下的連結，
    ; 放開時再讀取，補足座標判斷失準或主迴圈漏抓快速點擊的情況。
    _UI_WebViewExecuteScriptAsync($gWnd, $gWeb, HH91_RecorderScript(), "HH91_InstallDone")
EndFunc

; 產生中鍵記錄腳本（記下按下時的連結）。
Func HH91_RecorderScript()
    Return '(function(){var T=window;function rec(w){try{if(!w||w.__hhMidRec)return;w.__hhMidRec=1;var h=function(e){if(e.button!==1)return;var a=null;try{var n=e.target;if(n&&n.closest)a=n.closest("a[href],area[href]");if(!a&&e.composedPath){var p=e.composedPath();for(var i=0;i<p.length;i++){var q=p[i];if(q&&q.tagName&&/^(A|AREA)$/i.test(q.tagName)&&q.href){a=q;break;}}}}catch(x){}T.__hhMid={u:a?String(a.href||""):"",at:Date.now(),used:0,tag:(e.target&&e.target.tagName)||"",d:w.__hhDepth||0,x:Math.round(e.clientX),y:Math.round(e.clientY)};};w.addEventListener("pointerdown",h,true);w.addEventListener("mousedown",h,true);}catch(e){}}' & _
        'var nw=0,fr=0,xo=0;function scan(w,d){try{w.__hhDepth=d;}catch(e){}if(!w.__hhMidRec)nw++;rec(w);if(d>6)return;try{for(var i=0;i<w.frames.length;i++){var f=w.frames[i];fr++;try{if(f.document)scan(f,d+1);}catch(e){xo++;}}}catch(e){}}scan(T,0);' & _
        'if(!T.__hh133Pointer){T.__hh133Pointer=1;T.hh90Move={x:-1,y:-1,at:0};document.addEventListener("pointermove",function(e){T.hh90Move={x:e.clientX,y:e.clientY,at:Date.now()};},{capture:true,passive:true});}return "已安裝 框架="+fr+" 不同源框架="+xo+" 視窗="+innerWidth+"x"+innerHeight+" dpr="+devicePixelRatio+" "+location.host;})()'
EndFunc

; 中鍵放開後讀取頁面記錄的連結（備援路徑）。
Func HH91_RequestRecorded()
    $gHH91Due = False
    If $gWnd = 0 Or $gWeb = 0 Or $gDrawerOpen Then Return
    $gHH91Tab = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    Local $js = '(function(){var m=window.__hhMid;if(!m||m.used||!m.u||Date.now()-m.at>2500)return "HH91|";m.used=1;return "HH91|"+encodeURIComponent(m.u);})()'
    $gHH91Req = HH_WebExec($js, "HH91_RecResult")
EndFunc

; 讀取記錄結果：是網站連結就排入開新分頁佇列。
Func HH91_RecResult($iWebId, $iRequestId, $iStatus)
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    Local $err = @error
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If $iRequestId <> $gHH91Req Then Return
    $gHH91Req = 0
    If $iStatus <> 1 Or $err <> 0 Then
        Return
    EndIf
    If StringLeft($raw, 1) = '"' And StringRight($raw, 1) = '"' Then $raw = StringMid($raw, 2, StringLen($raw) - 2)
    If StringLeft($raw, 5) <> "HH91|" Then
        Return
    EndIf
    Local $info = StringSplit(StringMid($raw, 6), "|", 2)
    Local $url = UrlDecode($info[0])
    If $url = "" Then
        Return
    EndIf
    If Not StringRegExp($url, "(?i)^https?://") Then
        Return
    EndIf
    If _UI_WebViewGetCurrentTab($gWnd, $gWeb) <> $gHH91Tab Then
        Return
    EndIf
    HH_LinkQueuePush($url)
EndFunc

; 以原生游標換算出的 CSS 座標做命中測試；遇到同源 iframe／frame 時往內層找，CHM 內文也能取得連結。
Func HH90_HitScript($x, $y, $bw = 0, $bh = 0)
    Return '(function(){try{' & _
        'var m=window.__hhMid;if(m&&!m.used&&m.u&&/^https?:/i.test(m.u)&&Date.now()-m.at<1500){m.used=1;return "HH90|"+encodeURIComponent(m.u)+"|0|0|0|REC";}' & _
        'var bw=' & $bw & ',bh=' & $bh & ',sx=bw>0?innerWidth/bw:1,sy=bh>0?innerHeight/bh:1;var x=' & $x & '*sx,y=' & $y & '*sy,d=document,n=null,depth=0;var x0=x,y0=y;' & _
        'while(d&&depth<8){n=d.elementFromPoint(x,y);if(!n)break;var tg=(n.tagName||"").toUpperCase();' & _
        'if(tg==="IFRAME"||tg==="FRAME"){var cd=null;try{cd=n.contentDocument;}catch(e){}if(!cd)break;var r=n.getBoundingClientRect();' & _
        'x-=r.left+(n.clientLeft||0);y-=r.top+(n.clientTop||0);d=cd;depth++;continue;}break;}' & _
        'var a=null;if(n&&n.closest)a=n.closest("a[href],area[href]");' & _
        'if(!a&&n&&n.getRootNode){var rn=n.getRootNode();if(rn&&rn.host&&rn.host.closest)a=rn.host.closest("a[href],area[href]");}' & _
        'var u=a?String(a.href||""):"";if(m&&m.u&&m.u===u)m.used=1;' & _
        'return "HH90|"+encodeURIComponent(u)+"|"+Math.round(x)+"|"+Math.round(y)+"|0|"+(n?n.tagName:"null")+"|"+innerWidth+"x"+innerHeight+" 比例="+sx.toFixed(3)+","+sy.toFixed(3)+" 修正後="+Math.round(x0)+","+Math.round(y0);' & _
        '}catch(ex){return "HH90_ERROR|"+String(ex).slice(0,120);}})()'
EndFunc

; 螢幕游標 → WebView 內座標。
; AUI 回報的 WebView 大小與網頁實際 CSS 寬高不同（DPI 125% 時差 1.25 倍），右半邊全部落空。
; 改為優先以游標下方的 WebView2 原生視窗（螢幕像素）為準，再由網頁 innerWidth／innerHeight 換算成 CSS 座標。
Func HH90_CursorCss(ByRef $cx, ByRef $cy, ByRef $bw, ByRef $bh)
    Local $p = MouseGetPos()
    Local $tp = DllStructCreate("long x;long y")
    DllStructSetData($tp, 1, $p[0])
    DllStructSetData($tp, 2, $p[1])
    Local $t64 = DllStructCreate("int64", DllStructGetPtr($tp))
    Local $wf = DllCall("user32.dll", "hwnd", "WindowFromPoint", "int64", DllStructGetData($t64, 1))
    If Not @error And IsArray($wf) And $wf[0] Then
        Local $cls = DllCall("user32.dll", "int", "GetClassNameW", "hwnd", $wf[0], "wstr", "", "int", 256)
        Local $cn = ""
        If Not @error And IsArray($cls) Then $cn = $cls[2]
        If StringInStr($cn, "Chrome_RenderWidgetHostHWND") Or StringInStr($cn, "Chrome_WidgetWin") Then
            Local $tr = DllStructCreate("long l;long t;long r;long b")
            DllCall("user32.dll", "bool", "GetWindowRect", "hwnd", $wf[0], "struct*", $tr)
            Local $rw = DllStructGetData($tr, 3) - DllStructGetData($tr, 1), $rh = DllStructGetData($tr, 4) - DllStructGetData($tr, 2)
            If $rw > 50 And $rh > 50 Then
                $cx = $p[0] - DllStructGetData($tr, 1)
                $cy = $p[1] - DllStructGetData($tr, 2)
                $bw = $rw
                $bh = $rh
                Return $cx >= 0 And $cy >= 0 And $cx <= $bw And $cy <= $bh
            EndIf
        EndIf
    EndIf
    Local $lp = P133Point($p[0], $p[1]), $b = _UI_GetBounds($gWnd, $gWeb)
    If Not IsArray($lp) Or Not IsArray($b) Then Return False
    $cx = Round($lp[0] - $b[0], 1)
    $cy = Round($lp[1] - $b[1], 1)
    $bw = $b[2]
    $bh = $b[3]
    Return $cx >= 0 And $cy >= 0 And $cx <= $bw And $cy <= $bh
EndFunc

; 中鍵開分頁佇列：iframe 監聽、原生命中測試與其他路徑可能同時送出同一網址，1.5 秒內相同網址只開一次。
Func HH_LinkQueuePush($url)
    If Not StringRegExp($url, "(?i)^https?://") Or StringLen($url) > 4096 Then Return False
    If $url = $gHHLinkLastUrl And TimerDiff($gHHLinkLastClock) < 1500 Then Return False
    Local $n = UBound($gHHLinkTabQueue)
    If $n >= 24 Then Return False
    ReDim $gHHLinkTabQueue[$n + 1]
    $gHHLinkTabQueue[$n] = $url
    $gHHLinkLastUrl = $url
    $gHHLinkLastClock = TimerInit()
    Return True
EndFunc

; 中鍵按下時發出命中測試。
Func HH90_RequestHit()
    If $gWnd = 0 Or $gWeb = 0 Or $gDrawerOpen Then Return
    If WinGetProcess("[ACTIVE]") <> @AutoItPID Then
        Return
    EndIf
    If $gHH90HitPending Then
        If TimerDiff($gHH90HitClock) < 1500 Then
            Return
        EndIf
        $gHH90HitPending = False
        $gHH90HitReq = 0
    EndIf
    Local $cx = 0, $cy = 0, $bw = 0, $bh = 0
    If Not HH90_CursorCss($cx, $cy, $bw, $bh) Then
        Return
    EndIf
    $gHH90HitTab = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    Local $req = HH_WebExec(HH90_HitScript($cx, $cy, $bw, $bh), "HH90_HitResult")
    If $req > 0 Then
        $gHH90HitReq = $req
        $gHH90HitPending = True
        $gHH90HitClock = TimerInit()
    EndIf
EndFunc

; 命中測試結果：確認仍是同一分頁後排入佇列。
Func HH90_HitResult($iWebId, $iRequestId, $iStatus)
    Local $raw = _UI_WebViewResultGet($gWnd, $iWebId, $iRequestId)
    Local $err = @error
    _UI_WebViewResultRelease($gWnd, $iWebId, $iRequestId)
    If $iRequestId <> $gHH90HitReq Then
        Return
    EndIf
    $gHH90HitPending = False
    $gHH90HitReq = 0
    If $iStatus <> 1 Or $err <> 0 Then
        Return
    EndIf
    If StringLeft($raw, 1) = '"' And StringRight($raw, 1) = '"' Then $raw = StringMid($raw, 2, StringLen($raw) - 2)
    Local $parts = StringSplit($raw, "|", 2)
    If UBound($parts) < 5 Or $parts[0] <> "HH90" Then
        Return
    EndIf
    If $parts[1] = "NO_POINTER" Then
        Return
    EndIf
    ; 忽略延遲過久的命中測試結果，避免游標移動後誤開其他連結。
    If TimerDiff($gHH90HitClock) > 3000 Then
        Return
    EndIf
    If UBound($parts) >= 4 And Number($parts[4]) > 2000 Then
        Return
    EndIf
    Local $url = UrlDecode($parts[1])
    If Not StringRegExp($url, "(?i)^https?://") Or StringLen($url) > 4096 Then
        Return
    EndIf
    ; 非同步命中測試期間若已切換分頁，丟棄結果。
    If _UI_WebViewGetCurrentTab($gWnd, $gWeb) <> $gHH90HitTab Then
        Return
    EndIf
    If Not HH_LinkQueuePush($url) Then
        Return
    EndIf
EndFunc

; 主迴圈輪詢中鍵：分頁列上關閉分頁，網頁內開新分頁。
Func HH89_PollNativeMiddle()
    ; GetAsyncKeyState 低位元可補抓兩次輪詢之間完成的快速中鍵點擊。
    Local $ks = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", 0x04)
    Local $state = 0
    If Not @error And IsArray($ks) Then $state = $ks[0]
    Local $pressed = (BitAND($state, 0x8000) <> 0)
    Local $tapped = (Not $pressed) And (Not $gHH89MiddleHeld) And (BitAND($state, 1) <> 0)
    If ($pressed Or $tapped) And Not $gHH89MiddleHeld Then
        $g133TabDown = 0
        $gHH90PressContent = False
        Local $p = MouseGetPos()
        If HH99_IsHeaderPoint($p[0], $p[1]) Then
            Local $slot = P133Slot($p[0], $p[1])
            If $slot >= 0 Then $g133TabDown = $g133TabIds[$slot]
            $gHH95DownX = $p[0]
            $gHH95DownY = $p[1]
        ElseIf WinActive($gWnd) And Not $gDrawerOpen Then
            Local $lp = P133Point($p[0], $p[1])
            If IsArray($lp) Then
                If $lp[1] >= 156 Then
                    $gHH90PressContent = True
                    HH90_RequestHit()
                EndIf
            EndIf
        EndIf
    EndIf
    If Not $pressed And ($gHH89MiddleHeld Or $tapped) Then
        If $g133TabDown > 0 And WinActive($gWnd) And Not $gDrawerOpen Then
            Local $p2 = MouseGetPos(), $slot2 = P133Slot($p2[0], $p2[1])
            If $slot2 >= 0 Then
                Local $scale = _UI_GetDpiScale($gWnd)
                If @error Or $scale <= 0 Then $scale = 1
                If $g133TabIds[$slot2] = $g133TabDown And Abs($p2[0] - $gHH95DownX) <= 24 * $scale And Abs($p2[1] - $gHH95DownY) <= 24 * $scale Then
                    Local $idx = P133Index($g133TabDown)
                    If $idx >= 0 Then HH93_CloseTabAt($idx)
                EndIf
            EndIf
        EndIf
        $g133TabDown = 0
        ; 放開後稍等，讓網頁的 pointerdown 記錄完成，再讀取一次作為備援。
        If $gHH90PressContent Then
            $gHH91Due = True
            $gHH91Clock = TimerInit()
        EndIf
        $gHH90PressContent = False
    EndIf
    $gHH89MiddleHeld = $pressed
    If $gHH91Due And TimerDiff($gHH91Clock) >= 90 Then HH91_RequestRecorded()
EndFunc

; 主迴圈呼叫：在背景開新分頁，完成後切回原分頁。
Func HH_PumpLinkTabQueue()
    ; 背景新分頁建立完成後，切回原本的分頁。
    If $gHH88RestoreTab > 0 And TimerDiff($gHH88RestoreClock) > 180 Then
        Local $restore = $gHH88RestoreTab
        If _UI_WebViewSwitchTab($gWnd, $gWeb, $restore) Then
            HH_RefreshChmHistory()
            $gHH88RestoreTab = 0
        ElseIf TimerDiff($gHH88RestoreClock) > 4000 Then
            $gHH88RestoreTab = 0
        EndIf
    EndIf
    ; 上一個背景分頁尚未切回原分頁前，不建立下一個，避免切回錯誤分頁或遺失連結。
    If $gHH88RestoreTab > 0 Then Return
    If UBound($gHHLinkTabQueue) = 0 Then Return
    Local $url = $gHHLinkTabQueue[0]
    _ArrayDelete($gHHLinkTabQueue, 0)
    If Not StringRegExp($url, "(?i)^https?://") Then Return
    ; 使用 AUI 原生新增分頁，不覆蓋目前分頁的瀏覽歷史。
    Local $original = _UI_WebViewGetCurrentTab($gWnd, $gWeb)
    Local $created = _UI_WebViewNewTab($gWnd, $gWeb, $url)
    If $created > 0 And $original > 0 Then
        $gHH88RestoreTab = $original
        $gHH88RestoreClock = TimerInit()
    EndIf
EndFunc
