#include-once
; =============================================================================
; Html Helper － 閱讀器頁面
;
; 從 HHP／HHC／HHK 建立左側目錄與索引，
; 並產生「側欄＋內文」的閱讀器 HTML（含主題、字型、歷史與分割線腳本）。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; 讀取已解包資料夾的 HHP，載入目錄（.hhc）、索引（.hhk）與預設首頁。
Func LoadChmNavigation()
    $gTocHtml = ""
    $gKeywordHtml = ""
    $gDefaultTopic = ""
    Local $sHhp = $gRoot & "\AutoIt.hhp"
    If Not FileExists($sHhp) Then
        Local $aHhp = _FileListToArrayRec($gRoot, "*.hhp", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_SORT, $FLTAR_FULLPATH)
        If IsArray($aHhp) And $aHhp[0] Then $sHhp = $aHhp[1]
    EndIf
    Local $sToc = "", $sKeywords = ""
    If FileExists($sHhp) Then
        Local $sOptions = _ReadHelpText($sHhp)
        $gDefaultTopic = StringStripWS(_HhpOption($sOptions, "Default topic"), 3)
        $sToc = _HhpOption($sOptions, "Contents file")
        $sKeywords = _HhpOption($sOptions, "Index file")
        ; CHM 專案的相對路徑以 .hhp 所在資料夾為基準。
        Local $sBase = StringRegExpReplace($sHhp, "\\[^\\]+$", "")
        If $sToc <> "" Then $sToc = $sBase & "\" & $sToc
        If $sKeywords <> "" Then $sKeywords = $sBase & "\" & $sKeywords
    EndIf
    If Not FileExists($sToc) Then $sToc = $gRoot & "\AutoIt3TOC.hhc"
    If Not FileExists($sKeywords) Then $sKeywords = $gRoot & "\AutoIt3Index.hhk"
    If FileExists($sToc) Then $gTocHtml = _SitemapHtml($sToc, True)
    If FileExists($sKeywords) Then $gKeywordHtml = _SitemapHtml($sKeywords, False)
    $gDefaultTopic = StringReplace($gDefaultTopic, "\", "/")
    If $gDefaultTopic <> "" And Not FileExists($gRoot & "\" & StringReplace($gDefaultTopic, "/", "\")) Then $gDefaultTopic = ""
EndFunc

; 讀取 HHP [OPTIONS] 中指定鍵的值。
Func _HhpOption($sData, $sKey)
    Local $a = StringRegExp($sData, "(?im)^\s*" & StringReplace($sKey, " ", "\s+") & "\s*=\s*([^\r\n]*)", 1)
    If IsArray($a) Then Return StringStripWS($a[0], 3)
    Return ""
EndFunc

; 把 HHC／HHK 轉成可展開收合的側欄 HTML（保留 UL 階層）。
Func _SitemapHtml($sFile, $bTree)
    ; 保留 HHC 的 UL 階層，並為含子節點的項目建立展開/收合按鈕。
    Local $sRaw = _ReadHelpText($sFile)
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
            $sOut &= '<a href="/' & HtmlEscape(EncodeUrlPath($aLocals[$i])) & '" target="docframe" ondblclick="toggleTitle(this);return false;" title="按兩下展開或收合">' & HtmlEscape($aNames[$i]) & '</a>'
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

; 讀取 sitemap OBJECT 內指定 PARAM 的值。
Func _SitemapParam($sObject, $sKey)
    Local $a = StringRegExp($sObject, '(?is)<param\b[^>]*\bname\s*=\s*"' & $sKey & '"[^>]*\bvalue\s*=\s*"([^"]*)"', 1)
    If Not IsArray($a) Then Return ""
    Return _HtmlUnescape($a[0])
EndFunc

; 產生閱讀器頁面：左側目錄／索引／所有頁面，右側 iframe 顯示內文。
Func BuildIndex($sVirtualPrefix = "/")
    Local $sFirst = $gDefaultTopic
    ; 未指定命令列頁面：優先尋找常見首頁（包含子資料夾）。
    If $gRequestedPage = "" And $sFirst = "" Then
        Local $aHome[7] = ["index.htm", "index.html", "default.htm", "default.html", "home.htm", "home.html", "start.htm"]
        For $h = 0 To UBound($aHome) - 1
            For $k = 0 To UBound($gPageFiles) - 1
                Local $sName = StringLower(StringRegExpReplace($gPageFiles[$k], "^.*/", ""))
                If $sName = $aHome[$h] Then
                    $sFirst = $gPageFiles[$k]
                    ExitLoop 2
                EndIf
            Next
        Next
    EndIf
    If $gRequestedPage <> "" Then
        For $k = 0 To UBound($gPageFiles) - 1
            If StringLower($gPageFiles[$k]) = StringLower($gRequestedPage) Or StringLower($gPageNames[$k]) = StringLower($gRequestedPage) Then
                $sFirst = $gPageFiles[$k]
                ExitLoop
            EndIf
        Next
    EndIf
    Local $sFiles = ""
    If $gIndexLazy Then
        ; 「所有頁面」清單改為點選分頁時才向本機服務取得。
        If $sFirst = "" And UBound($gPageFiles) > 0 Then $sFirst = $gPageFiles[0]
        $sFiles = '<div class="lazy" data-src="__files__">正在載入頁面清單…</div>'
    Else
        For $i = 0 To UBound($gPageFiles) - 1
            Local $sPath = $gPageFiles[$i]
            If $sFirst = "" Then $sFirst = $sPath
            $sFiles &= '<div class="entry"><a target="docframe" href="' & $sVirtualPrefix & HtmlEscape(EncodeUrlPath($sPath)) & '">' & HtmlEscape($sPath) & '</a></div>'
        Next
    EndIf
    ; 單一 HTML 文件不建立 CHM 導航欄。
    If UBound($gPageFiles) = 1 And StringRegExp($sFirst, "(?i)\.html?$|\.xhtml?$") Then
        Return '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;width:100%;height:100%}iframe{border:0;width:100%;height:100%}</style></head><body><iframe id="docframe" src="' & $sVirtualPrefix & HtmlEscape(EncodeUrlPath($sFirst)) & '"></iframe></body></html>'
    EndIf
    ; PDF 直接嵌入瀏覽器原生 PDF viewer，隱藏側欄。
    If StringLower(StringRight($sFirst, 4)) = ".pdf" And UBound($gPageFiles) = 1 Then
        Return '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;width:100%;height:100%;background:#555}iframe{border:0;width:100%;height:100%}</style></head><body><iframe id="docframe" src="' & $sVirtualPrefix & HtmlEscape(EncodeUrlPath($sFirst)) & '#zoom=' & $gZoom & '"></iframe><script>function setContentZoom(n){var f=document.getElementById("docframe");if(!f)return;var u=f.getAttribute("src").split("#")[0];f.setAttribute("src",u+"#zoom="+encodeURIComponent(n));}</script></body></html>'
    EndIf
    Local $sToc = $gTocHtml, $sKey = $gKeywordHtml
    If $sToc = "" Then $sToc = $sFiles
    If $sKey = "" Then $sKey = $sFiles
    Local $s = '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><title>CHM 檔案閱讀器</title>' & _
        '<style>*{box-sizing:border-box}body{margin:0;font:14px/1.5 "Microsoft JhengHei","微軟正黑體",sans-serif;color:#25364a}' & _
        '#side{position:absolute;left:0;top:0;bottom:0;width:var(--side);overflow:hidden;background:#f4f7fb;border-right:1px solid #ccd9e6;padding:0;display:flex;flex-direction:column}#sidehead{flex:none;padding:12px 12px 7px;background:#f4f7fb;z-index:2}#sidelists{flex:1;min-height:0;overflow:auto;padding:0 12px 12px}' & _
        'h2{font-size:16px;margin:0 0 10px;color:#155e96}.tabs{display:flex;gap:3px;margin-bottom:9px}' & _
        '.tabs button{flex:1;border:1px solid #a7c4dd;background:#fff;padding:7px 2px;cursor:pointer;color:#235b86}' & _
        '.tabs button.active{background:#216eaa;color:white}.entry{padding:2px 0}.entry a{display:block;padding:3px 5px;color:#225e92;text-decoration:none;overflow-wrap:anywhere;word-break:normal;line-height:1.45}' & _
        '.entry a:hover{background:#e2eef9}.group-title{font-weight:bold;color:#334e68;cursor:pointer}.node{margin:0}.children{display:none;margin-left:17px;border-left:1px solid #dce5ee}.node.expanded>.children{display:block}.entry{display:flex;align-items:flex-start}.twisty{flex:none;border:0;background:transparent;color:#3a668b;width:19px;cursor:pointer;padding:2px 0}.twisty-placeholder{display:inline-block;flex:none;width:19px}.entry a{flex:1}#q{width:100%;padding:8px;border:1px solid #b8cadb;margin-bottom:7px}' & _
        '.panel{display:none}.panel.active{display:block}#docframe{position:absolute;left:var(--side);top:0;width:calc(100% - var(--side));height:100%;border:0}#splitter{position:absolute;left:calc(var(--side) - 4px);top:0;bottom:0;width:8px;cursor:col-resize;z-index:999;background:#d8e5ef;touch-action:none}#splitter:hover{background:#8db9db}' & _
        'body{font-family:' & HtmlEscape($gAppFont) & ',sans-serif;font-size:' & $gAppSize & 'px}' & _
        '</style><script>function toggleTitle(t){var n=t.closest(".node");if(!n)return;var b=n.querySelector(".entry>.twisty");if(b)toggleNode(b);}' & _
        'function toggleNode(b){if(!b)return;var n=b.parentNode.parentNode;if(n.className.indexOf("expanded")>=0){n.className="node";b.innerHTML="▸";}else{n.className="node expanded";b.innerHTML="▾";}}function tab(n){var p=document.getElementsByClassName("panel"),b=document.getElementsByClassName("tabbtn");' & _
        'for(var i=0;i<p.length;i++){p[i].className="panel"+(i===n?" active":"");b[i].className="tabbtn"+(i===n?" active":"");}hhLazy(p[n]);filterNav();}' & _
         'function hhLazy(p){var z=p&&p.querySelector(".lazy");if(!z||z.getAttribute("data-busy"))return;z.setAttribute("data-busy","1");fetch(z.getAttribute("data-src")).then(function(r){if(!r.ok)throw 0;return r.text();}).then(function(h){p.innerHTML=h;filterNav();}).catch(function(){z.textContent="載入失敗，請重新整理。";z.removeAttribute("data-busy");});}' & _
         'var ft=0,filterGeneration=0;function scheduleFilter(){clearTimeout(ft);ft=setTimeout(filterNav,180);}' & _
         'function filterNav(){var q=document.getElementById("q").value.toLowerCase(),p=document.getElementsByClassName("panel"),gen=++filterGeneration;' & _
         'for(var i=0;i<p.length;i++){if(p[i].className.indexOf("active")<0)continue;(function(panel){var e=panel.getElementsByClassName("entry"),j=0;' & _
         'function batch(){if(gen!==filterGeneration)return;var end=Math.min(j+160,e.length);for(;j<end;j++){var hit=!q||e[j].textContent.toLowerCase().indexOf(q)>=0;' & _
         'e[j].style.display=hit?"flex":"none";if(hit&&q){var n=e[j].parentNode;while(n&&n!==panel){if(n.className==="node")n.className="node expanded";n=n.parentNode;}}}' & _
         'if(j<e.length)setTimeout(batch,0);}batch();})(p[i]);}}' & _
         'var helperZoom=' & $gZoom & ',helperTheme=' & $gThemeMode & ',helperContentTheme=' & $gContentTheme & ';function htmlHelperSetContentTheme(n){var old=helperContentTheme;helperContentTheme=n;if(n===0&&old!==0){var f=document.getElementById("docframe");try{f.contentWindow.location.reload();}catch(e){styleDocument();}}else{styleDocument();}}var hhContentFont=' & JsString($gContentFont) & ',hhContentSize=' & $gContentSize & ';function setContentFont(f,n){hhContentFont=f;hhContentSize=n;clearTimeout(window.__hhFontTimer);window.__hhFontTimer=setTimeout(styleDocument,60);}function setContentZoom(n){helperZoom=n;styleDocument();}function htmlHelperSetTheme(n){helperTheme=n;document.body.style.background=n===2?"#20242c":"#fff";document.body.style.color=n===2?"#e7edf5":"#25364a";var side=document.getElementById("side");if(side){side.style.background=n===2?"#292e37":"#f4f7fb";side.style.color=n===2?"#e7edf5":"#25364a";}var head=document.getElementById("sidehead");if(head)head.style.background=n===2?"#292e37":"#f4f7fb";var css=document.getElementById("helper-nav-theme");if(!css){css=document.createElement("style");css.id="helper-nav-theme";document.head.appendChild(css);}css.textContent=n===2?"#side .entry a,#side h2,#side .group-title{color:#c5ddff!important}#side .entry a:hover{background:#394453!important}#side .tabs button{background:#363d48;color:#e6eef9;border-color:#566274}#side .tabs button.active{background:#245c91;color:white}#side #q{background:#303743;color:#e7edf5;border-color:#566274}#splitter{background:#424b56}":"";styleDocument();}function styleDocument(){hhStyleDocument();}' & _
         'var hhStyled=new Map();' & _
         'function hhEsc(s){return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}' & _
         'function hhLang(el){var v=((el.className||"")+" "+(el.parentElement?el.parentElement.className:"")+" "+(el.getAttribute("data-language")||"")).toLowerCase();var m=v.match(/(?:language-|lang-|brush:\s*)(autoit|au3|javascript|js|typescript|ts|python|py|html|xml|css|json|java|csharp|cs|cpp|c\+\+|c|sql|bash|shell|powershell|ps1|php|lua|ruby|go|rust)/);if(m)return m[1];var t=(el.textContent||"").slice(0,500);if(/(?:\$[A-Za-z_]\w*|#include\s*[<"]|\b(?:Func|EndFunc|Local|Global|GUICtrlCreate)\b)/i.test(t))return "au3";if(/\b(?:def |import |print\(|elif |None\b)/.test(t))return "python";if(/\b(?:const |let |function |console\.)/.test(t))return "js";return "generic";}' & _
         'function hhReset(){hhStyled.forEach(function(v,el){if(el&&el.isConnected)el.innerHTML=v;});hhStyled.clear();}' & _
         'function hhStyleDocument(){try{var f=document.getElementById("docframe"),d=f.contentDocument;if(!d||!d.documentElement)return;var st=d.getElementById("html-helper-style");if(!st){st=d.createElement("style");st.id="html-helper-style";(d.head||d.documentElement).appendChild(st);}if(window.hhCurrentDoc!==d){hhStyled.clear();window.hhCurrentDoc=d;}var base="html{zoom:"+helperZoom+"%}body,body p,body li,body td,body th{font-family:"+JSON.stringify(hhContentFont)+",sans-serif!important;font-size:"+hhContentSize+"px!important}body h1,body h2,body h3,body h4,body h5,body h6{font-family:"+JSON.stringify(hhContentFont)+",sans-serif!important;line-height:1.3!important;font-weight:700!important}body h1{font-size:2em!important}body h2{font-size:1.65em!important}body h3{font-size:1.4em!important}body h4{font-size:1.2em!important}body h5{font-size:1.08em!important}body h6{font-size:1em!important}body h1 *,body h2 *,body h3 *,body h4 *,body h5 *,body h6 *{font-size:inherit!important;' & _
         'line-height:inherit!important}body h1.small,body .small{font-size:.8125em!important;font-weight:400!important;line-height:1.5!important}body .funcdesc{font-size:1em!important;line-height:1.65!important}body .specialnote,body .experimental{font-size:1em!important;line-height:1.65!important}body .codeSnippetContainerTabs,body .codeSnippetToolBarText{font-size:.875em!important}body .codeSnippetContainerCode pre,body .codebox,body .codeheader{font-size:.875em!important;line-height:1.6!important}body .codeSnippetContainerCode pre{white-space:pre!important;overflow-x:auto!important}body .codeSnippetContainerCodeContainer{min-width:0!important}body .codeSnippetContainerCode{min-width:0!important}body table.noborder,body table.noborder td,body table.noborder th{border:0!important}body .copyCodeButton{cursor:pointer!important}pre,code,pre *,code *{font-family:Consolas,monospace!important}";base+="body h1,body h2,body h3,body h4,body h5,body h6{letter-spacing:normal!important;word-spacing:normal!important}body .codeSnippetToolBar{box-sizing:border-box!important;height:auto!important;min-height' & _
         ':42px!important;overflow:visible!important;padding:7px 10px!important}body .codeSnippetToolBarText{float:none!important;position:static!important;top:auto!important;height:auto!impo";base+="rtant;min-height:0!important;padding:0!important;margin:0!important;text-align:left!important}body .codeSnippetContainerCodeContainer{top:0!important;overflow:hidden!important}body .codeSnippetContainerCode{margin-top:0!important;padding:14px 12px!important}body .copyCodeButton,body button.copy-code,body .codeSnippetToolBarText a.copyCodeButton{display:inline-block!important;po";base+="sition:static!important;padding:7px 15px!important;margin:0!important;border-radius:4px!important;font-size:14px!important;font-weight:600!important;text-decoration:none!important;cursor:pointer!important}";if(helperContentTheme===0){st.textContent=base;return;' & _
         '}var dark=helperContentTheme===1,bg=dark?"#20252e":"#ffffff",panel=dark?"#2c3440":"#f2f5f9",fg=dark?"#e5eaf1":"#202936",border=dark?"#566579":"#c6d0dd",link=dark?"#91c7ff":"#075aa5",sub=dark?"#28303b":"#f7f9fc";st.textContent=base+"html,body{background:"+bg+"!important;color:"+fg+"!important;color-scheme:"+(dark?"dark":"light")+"!important}body,main,article,section,header,footer,nav,aside,div,form,table,tbody,thead,tr,td,th,pre,code,blockquote{color:"+fg+"!important}h1,h2,h3,h4,h5,h6,p,li,dt,dd,label,summary,font{color:"+fg+"!important}a,a:link{color:"+link+"!important}a:visited{color:"+(dark?"#d6adff":"#7546a4")+"!important}a:hover{text-decoration:underline!important}table,th,td{border-color:"+border+"!important}th,thead{background:"+panel+"!important}tr:nth-child(even),tr:nth-child(even) td{background:"+sub+"!important}td,th{background:"+bg+"!important}thead th,th{background:"+panel+"!important}p' & _
         're,code,kbd,samp,.code,.highlight,.syntaxhighlighter,.codebox,.codeheader,.code-toolbar,.code-toolbar *,[class*=codehead],[class*=codeHead],[class*=codebar],[class*=codeBar]{background:"+panel+"!important;color:"+fg+"!important;border-color:"+border+"!important}pre{padding:10px!important;overflow:auto!important;white-space:pre!important}blockquote{background:"+panel+"!important;border-left:3px solid "+link+"!important}input,select,textarea,button{background:"+panel+"!important;color:"+fg+"!important;' & _
         'border-color:"+border+"!important}hr{border-color:"+border+"!important}::selection{background:"+(dark?"#3b6595":"#b9dafb")+"!important}pre *,code *,.highlight *,.syntaxhighlighter *{background:transparent!important} .tok-comment,.tok-comment *,.hh-comment,.hh-comment *{color:"+(dark?"#91b89b":"#46724b")+"!important}.tok-string,.tok-string *,.hh-string,.hh-string *{color:"+(dark?"#f0b985":"#a34b16")+"!important}.tok-keyword,.tok-preprocessor,.hh-keyword,.hh-directive,.hh-keyword *,.hh-directive *{color:"+(dark?"#b9a5ff":"#7149b1")+"!important}.tok-variable,.tok-macro,.hh-variable,.hh-variable *{color:"+(dark?"#87d4e7":"#126b82")+"!important}.tok-function,.hh-func,.hh-func *{color:"+(dark?"#89baff":"#175da0")+"!important}.tok-number,.tok-constant,.hh-num,.hh-num *{color:"+(dark?"#e8c27a":"#8c6419")+"!important}"+(dark?".S1,.S2{color:#8bc99c!important;' & _
         'font-style:italic!important}.S3{color:#a6c8ff!important}.S4{color:#7fd4ff!important}.S5{color:#c7a8ff!important}.S6,.S11{color:#dfc57c!important}.S7{color:#f4ae9b!important}.S8{color:#f0bd82!important}.S9{color:#ffd08a!important}.S10{color:#a9b8cc!important}.S12{color:#ff9eb4!important}.S13{color:#ffc1aa!important;background:#3c3140!important}.S14{color:#dca6ef!important}.S15{color:#86d3ed!important}.S0{color:#dce6f4!important}":"");st.textContent+=".codeSnippetToolBar,.codeSnippetToolBarText{background:"+panel+"!important;color:"+fg+"!important;border-color:"+border+"!important}.codeSnippetContainerCodeContainer,.codeSnippetContainerCode{background:"+sub+"!important;color:"+fg+"!important;border-color:"+border+"!important}.copyCodeButton,.codeSnippetToolBarText a.copyCodeButton,button.copy-code{background:"+(dark?"#405b78":"#e8eff8")+"!important;color:"+(dark?"#e7f2ff":"#23588b")+"!important;border:1px solid "+(dark?"#6c8eae":"#9cb4d1")+"!important}.copyCodeButton:hover,.codeSnippetToolBarText a.copyCodeButton:hover,button.copy-code:hover{background:"+(dark?"#527397":"#d8e7f7")+"!important}.copyCodeButton.copied,.codeSnippetToolBarText a.copyCodeButton.copied{background:"+(dark?"#285a48":"#e3f4e8")+"!important;color:"+(dark?"#bdf5d5":"#24633a")+"!important}";st.textContent+="body .codeSnippetToolBar,body .codeSnippetToolBarText,body div.codeSnippetToolBarText{background:"+panel+"!important;color:"+fg+"!important;border-color:"+border+"!important}";st.textContent+="body .codeSnippetToolBarText a.copyCodeButton,body .codeSnippetToolBarText a.copyCodeButton:link,body .codeSnippetToolBarText a.copyCodeButton:visited,body .codeSnippetToolBarText button.copyCodeButton,body .copyCodeButton,body button.copy-code{background:"+(dark?"#405b78":"#e8eff8")+"!important;background-color:"+(dark?"#405b78":"#e8eff8")+"!important;color:"+(dark?"#e7f2ff":"#23588b")+"!important;border:1px solid "+(dark?"#6c8eae":"#9cb4d1")+"!important;box-shadow:none!important}";st.textContent+="body .codeSnippetToolBarText a.copyCodeButton:hover,body .codeSnippetToolBarText button.copyCodeButton:hover,body button.copy-code:hover{background:"+(dark?"#527397":"#d8e7f7")+"!important}";/* 原始碼語法上色功能已停用，保留文件原有格式 */}catch(e){try{console.warn("Html Helper style",e)}catch(x){}}}' & _
         'var helperPages=[],helperPos=-1,helperNavigating=false;function htmlHelperHistory(dir){var i=helperPos+dir;if(i<0||i>=helperPages.length)return;helperPos=i;helperNavigating=true;document.getElementById("docframe").src=helperPages[i];helperHistoryUpdate();}function helperHistoryUpdate(){if(document.visibilityState==="hidden")return;fetch("/__helper_history__?b="+(helperPos>0?1:0)+"&f="+(helperPos<helperPages.length-1?1:0)).catch(function(){});}window.helperHistoryUpdate=helperHistoryUpdate;document.addEventListener("visibilitychange",function(){if(document.visibilityState==="visible")helperHistoryUpdate();});function helperPageLoaded(){var f=document.getElementById("docframe"),u="";try{u=f.contentWindow.location.href;}catch(e){}if(!helperNavigating&&u){if(helperPos<0||helperPages[helperPos]!==u){helperPages=helperPages.slice(0,helperPos+1);helperPages.push(u);helperPos=helperPages.length-1;}}helperNavigating=false;helperHistoryUpdate();if(u){try{fetch("/__helper_location__?p="+encodeURIComponent(new URL(u).pathname+new URL(u).search+new URL(u).hash)).catch(function(){});}catch(e){}}styleDocument();try{var fw=document.getElementById("docframe").contentWindow;if(fw&&fw.document&&fw.document!==document){fw.document.addEventListener("click",function(e){var a=e.target.closest&&e.target.closest("a[href]");if(!a||e.button!==0||e.ctrlKey||e.metaKey||e.shiftKey||e.altKey||a.hasAttribute("download"))return;if(a.target==="_blank"){e.preventDefault();fw.location.assign(a.href);}},true);fw.document.addEventListener("pointerdown",function(e){if(e.button!==1)return;var a=e.target.closest&&e.target.closest("a[href]");if(!a||!/^https?:/i.test(a.href))return;e.preventDefault();e.stopImmediatePropagation();var im=new Image();(window.__hhChmRequests||(window.__hhChmRequests=[])).push(im);im.onload=im.onerror=function(){var k=window.__hhChmRequests.indexOf(im);if(k>=0)window.__hhChmRequests.splice(k,1);};im.src="/__helper_newtab__?u="+encodeURIComponent(a.href)+"&t="+Date.now();},true);}}catch(ex){} }function setSideFont(f,n){var el=document.getElementById("side");if(el){el.style.fontFamily=f+",sans-serif";el.style.fontSize=n+"px";}}var splitting=false;function startSplit(e){e.preventDefault();splitting=true;document.body.classList.add("dragging");document.getElementById("docframe").style.pointerEvents="none";try{e.currentTarget.setPointerCapture(e.pointerId);}catch(ex){}document.addEventListener("pointermove",moveSplit);document.addEventListener("pointerup",stopSplit);}' & _
         'function moveSplit(e){if(!splitting)return;var w=Math.max(160,Math.min(window.innerWidth-160,e.clientX));document.body.style.setProperty("--side",w+"px");try{sessionStorage.setItem("htmlHelperSide",String(w));}catch(ex){}}' & _
         'function stopSplit(){if(!splitting)return;splitting=false;document.body.classList.remove("dragging");document.getElementById("docframe").style.pointerEvents="auto";document.removeEventListener("pointermove",moveSplit);document.removeEventListener("pointerup",stopSplit);var w=Math.round(document.getElementById("side").getBoundingClientRect().width);try{sessionStorage.setItem("htmlHelperSide",String(w));}catch(ex){}fetch("/__helper_side__?w="+w).catch(function(){});}' & _
        '</script></head><body style="--side:' & $gSideWidth & 'px">' & _
        '<aside id="side"><div id="sidehead"><h2>AutoIt 說明檔案</h2><div class="tabs">' & _
        '<button class="tabbtn active" onclick="tab(0)">目錄</button><button class="tabbtn" onclick="tab(1)">索引</button>' & _
        '<button class="tabbtn" onclick="tab(2)">所有頁面</button></div>' & _
        '<input id="q" placeholder="篩選目前清單" oninput="scheduleFilter()"></div><div id="sidelists">' & _
        '<div class="panel active">' & $sToc & '</div><div class="panel">' & $sKey & '</div><div class="panel">' & $sFiles & '</div></div>' & _
        '</aside><div id="splitter" onpointerdown="startSplit(event)"></div><iframe id="docframe" name="docframe" onload="helperPageLoaded()" src="' & $sVirtualPrefix & HtmlEscape(EncodeUrlPath($sFirst)) & '"></iframe><script>try{var sw=parseInt(sessionStorage.getItem("htmlHelperSide"),10);if(sw>=160&&sw<window.innerWidth-160)document.body.style.setProperty("--side",sw+"px");}catch(ex){}htmlHelperSetTheme(' & HelperEffectiveTheme() & ');hhLazy(document.querySelector(".panel.active"));setSideFont(' & JsString($gSideFont) & ',' & $gSideSize & ');</script></body></html>'
    Return $s
EndFunc
