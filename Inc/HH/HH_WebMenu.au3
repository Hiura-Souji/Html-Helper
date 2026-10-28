#include-once
; =============================================================================
; Html Helper － 網頁右鍵選單
;
; WebView 原生右鍵選單的選項處理（選單關閉後才在主迴圈執行，
; WebView 才拿得回焦點）。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; AUI 原生 ContextMenu 的選項事件。複製使用 WebView2 的頁面選取內容。
Func HH_WebContextSelected($iId, $iIndex)
    #forceref $iId
    ; 選單回呼內 WebView2 尚未取回焦點，ExecuteScriptAsync 可能直接失敗；
    ; 改為記錄選項，由主迴圈在選單關閉後執行。
    $gWebMenuPending = Number($iIndex)
    $gWebMenuClock = TimerInit()
EndFunc

; 主迴圈呼叫：選單關閉約 120 ms 後執行記下的選項。
Func HH_WebMenuTick()
    If $gWebMenuPending < 0 Or TimerDiff($gWebMenuClock) < 120 Then Return
    Local $index = $gWebMenuPending
    $gWebMenuPending = -1
    HH_WebContextRun($index)
EndFunc

; 執行右鍵選單選項（導覽、複製、QR、編碼、翻譯）。
Func HH_WebContextRun($iIndex)
    Switch Number($iIndex)
        Case 0
            GoBack(0)
        Case 1
            GoForward(0)
        Case 2
            ReloadPage(0)
        Case 3
            ; 原先直接 execCommand('copy') 會因右鍵選單奪走焦點而失敗。
            ; 從 CHM 內文 iframe 或一般網頁擷取選取文字，使用 Clipboard API，
            ; 若權限不允許則使用暫時 textarea 進行複製。
            Local $js = "(async function(){" & _
                "var d=document;try{var f=d.getElementById('docframe');if(f&&f.contentDocument)d=f.contentDocument;}catch(e){}" & _
                "var w=d.defaultView||window;var s=String(w.getSelection?w.getSelection():'');" & _
                "if(!s){var a=d.activeElement;if(a&&typeof a.selectionStart==='number')s=a.value.substring(a.selectionStart,a.selectionEnd);}" & _
                "if(!s&&d!==document)s=String(window.getSelection?window.getSelection():'');" & _
                "if(!s)return false;" & _
                "try{await navigator.clipboard.writeText(s);return true;}catch(e){}" & _
                "var t=document.createElement('textarea');t.value=s;t.style.cssText='position:fixed;left:-9999px;top:0;';" & _
                "document.body.appendChild(t);t.focus();t.select();var ok=document.execCommand('copy');t.remove();return ok;" & _
                "})()"
            HH_WebExec($js)
        Case 4
            HH_ShowUrlQRCode()
        Case 5
            HH_CycleChmCharset()
        Case 6
            HH_CycleSidebarCharset()
        Case 7
            HH_AI_TranslateSelection()
        Case 8
            HH_AI_TranslatePage()
        Case 9
            HH_AI_RestorePage()
        Case 10
            HH_AI_GoogleTranslateSelection()
        Case 11
            HH_GoogleTranslatePage()
        Case 12
            HH_GoogleStopPage()
            If $gAiPageMode Then
                HH_AI_PageStop()
                _UI_Notify($gWnd, "AI 整頁翻譯", "已停止；已翻譯的文字保留，可用「AI 還原原文」復原。", $AUI_NOTIFY_INFO, 4000)
            EndIf
        Case 13
            HH_WebLangOpen()
    EndSwitch
EndFunc
