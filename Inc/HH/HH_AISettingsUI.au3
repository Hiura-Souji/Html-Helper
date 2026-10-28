#include-once
; =============================================================================
; Html Helper － AI 設定相關視窗
;
; AI API 設定視窗（多設定檔、測試連線、選擇模型）、網頁翻譯目的語言視窗、
; 開啟網址視窗。測試連線與模型清單皆為非同步。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ---------- AUI：AI API 設定 ----------
Func P136OpenSettings($parent = 0)
    If $p136SetWnd <> 0 And _UI_IsAlive($p136SetWnd) Then
        _UI_WindowShow($p136SetWnd)
        Return
    EndIf
    If $parent = 0 Then $parent = $gWnd
    Local $count = P136Count()
    If $p136Profile < 1 Or $p136Profile > $count Then $p136Profile = P136Active()
    Local $list = ""
    For $i = 1 To $count
        $list &= ($i > 1 ? "|" : "") & $i & ". " & _IniRead($p136Ini, P136Section($i), "Name", "AI " & $i)
    Next
    $p136SetWnd = _UI_WindowCreateEx("Html Helper｜AI API 設定", 0, 0, 780, 760, BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $p136SetWnd = 0 Then Return
    Local $w = $p136SetWnd
    _UI_ThemeSetMode($w, HelperEffectiveTheme())
    _UI_WindowCenter($w)
    HH_Text($w, 0, "設定檔（可建立多組 API，翻譯時使用「使用中」的設定）", 20, 44, 740, 24)
    $p136Fields[0] = HH_Combo($w, 0, $list, $p136Profile - 1, 20, 70, 470, 34)
    Local $add = HH_Button($w, 0, "新增", $AUI_VAR_DEFAULT, 500, 70, 125, 34)
    Local $del = HH_Button($w, 0, "刪除", $AUI_VAR_DEFAULT, 635, 70, 125, 34)
    HH_Text($w, 0, "名稱", 20, 116, 360, 24)
    $p136Fields[1] = HH_Input($w, 0, "設定檔名稱", "", 20, 142, 360, 34)
    HH_Text($w, 0, "供應商範本（選擇後自動填入 Endpoint／協定）", 400, 116, 360, 24)
    $p136Fields[2] = HH_Combo($w, 0, $p136Providers, 0, 400, 142, 360, 34)
    HH_Text($w, 0, "通道協定", 20, 188, 740, 24)
    $p136Fields[3] = HH_Combo($w, 0, $p136Protocols, 0, 20, 214, 740, 34)
    HH_Text($w, 0, "API Endpoint（HTTPS；本機 Ollama／LM Studio 可用 http://127.0.0.1）", 20, 260, 740, 24)
    $p136Fields[4] = HH_Input($w, 0, "https://...", "", 20, 286, 740, 34)
    HH_Text($w, 0, "模型（Azure 填部署名稱）", 20, 332, 560, 24)
    $p136Fields[5] = HH_Input($w, 0, "模型名稱", "", 20, 358, 560, 34)
    Local $pick = HH_Button($w, 0, "選擇模型…", $AUI_VAR_DEFAULT, 590, 358, 170, 34)
    HH_Text($w, 0, "API Key（留空 = 沿用已保存的 Key）", 20, 404, 470, 24)
    $p136Fields[6] = HH_Input($w, 0, "貼上自己的 API Key", "", 20, 430, 470, 34)
    $p136Fields[7] = HH_Combo($w, 0, "加密保存（Windows DPAPI，僅本機帳號可解）|只用於本次執行（不寫入設定檔）", 0, 500, 430, 260, 34)
    $p136Fields[8] = HH_Text($w, 0, "", 20, 470, 740, 24)
    HH_Text($w, 0, "溫度", 20, 504, 120, 24)
    $p136Fields[9] = HH_Combo($w, 0, "0|0.1|0.2|0.3|0.5|0.7|1", 2, 20, 530, 120, 34)
    HH_Text($w, 0, "每批段數", 150, 504, 130, 24)
    $p136Fields[10] = HH_Combo($w, 0, "5|10|20|30|40|60", 2, 150, 530, 130, 34)
    HH_Text($w, 0, "每批字元上限", 290, 504, 140, 24)
    $p136Fields[11] = HH_Combo($w, 0, "1500|3000|5000|8000|12000", 2, 290, 530, 140, 34)
    HH_Text($w, 0, "同時請求數", 440, 504, 125, 24)
    $p136Fields[15] = HH_Combo($w, 0, "1|2|3|4|6|8", 2, 440, 530, 125, 34)
    HH_Text($w, 0, "請求間隔 ms／逾時秒", 575, 504, 185, 24)
    $p136Fields[12] = HH_Combo($w, 0, "0|250|500|1000|2000|5000", 1, 575, 530, 90, 34)
    $p136Fields[13] = HH_Combo($w, 0, "30|60|120|180|300", 2, 670, 530, 90, 34)
    Local $test = HH_Button($w, 0, "測試連線", $AUI_VAR_DEFAULT, 20, 590, 170, 38)
    Local $clear = HH_Button($w, 0, "清除已存 Key", $AUI_VAR_DEFAULT, 200, 590, 170, 38)
    Local $save = HH_Button($w, 0, "儲存並設為使用中", $AUI_VAR_PRIMARY, 380, 590, 230, 38)
    Local $close = HH_Button($w, 0, "關閉", $AUI_VAR_DEFAULT, 620, 590, 140, 38)
    $p136Fields[14] = HH_Text($w, 0, "使用中：" & _IniRead($p136Ini, P136Section(P136Active()), "Name", ""), 20, 644, 740, 24)
    HH_Text($w, 0, "Key 不會寫入網址、命令列或工作紀錄。翻譯工作透過環境變數交給子程序後立即清除。", 20, 676, 740, 48)
    _UI_OnValue($w, $p136Fields[0], "P136ProfileChanged")
    _UI_OnValue($w, $p136Fields[2], "P136ProviderChanged")
    _UI_OnClick($w, $add, "P136AddProfile")
    _UI_OnClick($w, $del, "P136DeleteProfile")
    _UI_OnClick($w, $pick, "P136PickModels")
    _UI_OnClick($w, $test, "P136TestProfile")
    _UI_OnClick($w, $clear, "P136ClearKey")
    _UI_OnClick($w, $save, "P136SaveProfile")
    _UI_OnClick($w, $close, "P136CloseSettings")
    _UI_OnClose($w, "P136SettingsClosed")
    P136FillFields($p136Profile)
    HH_ApplyChildFonts()
    _UI_WindowShowModal($w, $parent)
EndFunc

; 在下拉選單中選取指定文字的項目。
Func P136SelectText($w, $combo, $value)
    Local $i = _UI_ComboFindItem($w, $combo, $value)
    If $i >= 0 Then _UI_ComboSetSelected($w, $combo, $i)
EndFunc

; 把設定檔內容填入視窗。
Func P136FillFields($n)
    Local $w = $p136SetWnd, $c = P136Load($n)
    $p136Loading = True
    _UI_SetText($w, $p136Fields[1], $c.Item("name"))
    _UI_ComboSetSelected($w, $p136Fields[2], $c.Item("provider"))
    _UI_ComboSetSelected($w, $p136Fields[3], $c.Item("protocol"))
    _UI_SetText($w, $p136Fields[4], $c.Item("endpoint"))
    _UI_SetText($w, $p136Fields[5], $c.Item("model"))
    _UI_SetText($w, $p136Fields[6], "")
    _UI_ComboSetSelected($w, $p136Fields[7], ($c.Item("keymode") = 1 ? 1 : 0))
    P136SelectText($w, $p136Fields[9], String($c.Item("temperature")))
    P136SelectText($w, $p136Fields[10], String($c.Item("items")))
    P136SelectText($w, $p136Fields[11], String($c.Item("chars")))
    P136SelectText($w, $p136Fields[12], String($c.Item("delay")))
    P136SelectText($w, $p136Fields[13], String($c.Item("timeout")))
    P136SelectText($w, $p136Fields[15], String($c.Item("parallel")))
    Local $state = "Key：" & P136Mask($c.Item("key"))
    If $c.Item("key") = "" And Not P136NeedsKey($c) Then $state = ($c.Item("protocol") = 4 ? "Key：免費服務不需要" : "Key：本機服務可不填")
    If $c.Item("key") = "" And $c.Item("stored") Then $state = "Key：已保存但無法解密（可能是其他 Windows 帳號建立），請重新輸入"
    _UI_SetText($w, $p136Fields[8], $state)
    $p136Loading = False
EndFunc

; 從視窗欄位讀出設定。
Func P136FieldsConfig()
    Local $w = $p136SetWnd, $c = P136Load($p136Profile)
    $c.Item("name") = StringStripWS(_UI_GetText($w, $p136Fields[1]), 3)
    $c.Item("provider") = _UI_ComboGetSelected($w, $p136Fields[2])
    $c.Item("protocol") = _UI_ComboGetSelected($w, $p136Fields[3])
    $c.Item("endpoint") = StringStripWS(_UI_GetText($w, $p136Fields[4]), 3)
    $c.Item("model") = StringStripWS(_UI_GetText($w, $p136Fields[5]), 3)
    $c.Item("keymode") = _UI_ComboGetSelected($w, $p136Fields[7])
    $c.Item("temperature") = ComboValue($w, $p136Fields[9], "0.2")
    $c.Item("items") = Number(ComboValue($w, $p136Fields[10], "20"))
    $c.Item("chars") = Number(ComboValue($w, $p136Fields[11], "5000"))
    $c.Item("delay") = Number(ComboValue($w, $p136Fields[12], "250"))
    $c.Item("timeout") = Number(ComboValue($w, $p136Fields[13], "120"))
    $c.Item("parallel") = Number(ComboValue($w, $p136Fields[15], "3"))
    If $c.Item("protocol") < 0 Then $c.Item("protocol") = 0
    If $c.Item("provider") < 0 Then $c.Item("provider") = 0
    Local $typed = StringStripWS(_UI_GetText($w, $p136Fields[6]), 3)
    If $typed <> "" Then $c.Item("key") = $typed
    $c.Item("typed") = $typed
    Return $c
EndFunc

; 切換設定檔。
Func P136ProfileChanged($id, $value)
    #forceref $id
    If $p136Loading Then Return
    Local $n = Number($value) + 1
    If $n < 1 Or $n > P136Count() Then Return
    $p136Profile = $n
    P136FillFields($n)
EndFunc

; 切換供應商範本：自動填入協定、Endpoint 與模型。
Func P136ProviderChanged($id, $value)
    #forceref $id
    If $p136Loading Then Return
    Local $protocol, $endpoint, $model, $w = $p136SetWnd
    P136Preset(Number($value), $protocol, $endpoint, $model)
    _UI_ComboSetSelected($w, $p136Fields[3], $protocol)
    _UI_SetText($w, $p136Fields[4], $endpoint)
    _UI_SetText($w, $p136Fields[5], $model)
    Local $name = StringStripWS(_UI_GetText($w, $p136Fields[1]), 3)
    If $name = "" Or StringInStr("|" & $p136Providers & "|", "|" & $name & "|") Then _UI_SetText($w, $p136Fields[1], P136ProviderName(Number($value)))
EndFunc

; 儲存設定並設為使用中（Key 依選擇加密保存或只用於本次執行）。
Func P136SaveProfile($id)
    #forceref $id
    Local $w = $p136SetWnd, $c = P136FieldsConfig(), $s = P136Section($p136Profile)
    If $c.Item("name") = "" Then $c.Item("name") = "AI " & $p136Profile
    If Not P136ValidEndpoint($c.Item("endpoint")) Then
        _UI_Notify($w, "Endpoint 不正確", "只接受 HTTPS，或 http://127.0.0.1／localhost 本機服務；Azure 請替換 <資源名稱>、<部署名稱>。", $AUI_NOTIFY_WARNING, 6000)
        Return False
    EndIf
    If $c.Item("model") = "" And $c.Item("protocol") <> 3 And $c.Item("protocol") <> 4 Then
        _UI_Notify($w, "缺少模型", "請輸入模型名稱，或按「選擇模型…」。", $AUI_NOTIFY_WARNING, 5000)
        Return False
    EndIf
    _IniWrite($p136Ini, $s, "Name", StringReplace($c.Item("name"), "|", "／"))
    _IniWrite($p136Ini, $s, "Provider", String($c.Item("provider")))
    _IniWrite($p136Ini, $s, "Protocol", String($c.Item("protocol")))
    _IniWrite($p136Ini, $s, "Endpoint", $c.Item("endpoint"))
    _IniWrite($p136Ini, $s, "Model", $c.Item("model"))
    _IniWrite($p136Ini, $s, "KeyMode", String($c.Item("keymode")))
    _IniWrite($p136Ini, $s, "Temperature", String($c.Item("temperature")))
    _IniWrite($p136Ini, $s, "BatchItems", String($c.Item("items")))
    _IniWrite($p136Ini, $s, "BatchChars", String($c.Item("chars")))
    _IniWrite($p136Ini, $s, "Delay", String($c.Item("delay")))
    _IniWrite($p136Ini, $s, "Timeout", String($c.Item("timeout")))
    _IniWrite($p136Ini, $s, "Parallel", String($c.Item("parallel")))
    Local $key = $c.Item("key")
    If $c.Item("keymode") = 1 Then
        _IniWrite($p136Ini, $s, "Key", "")
        If $key <> "" Then $p136Keys.Item(String($p136Profile)) = $key
    ElseIf $c.Item("typed") <> "" Then
        Local $blob = P136Protect($c.Item("typed"))
        If @error Or $blob = "" Then
            _UI_Notify($w, "Key 加密失敗", "Windows DPAPI 無法加密，已改為本次執行使用。", $AUI_NOTIFY_WARNING, 6000)
            $p136Keys.Item(String($p136Profile)) = $c.Item("typed")
        Else
            _IniWrite($p136Ini, $s, "Key", $blob)
            If $p136Keys.Exists(String($p136Profile)) Then $p136Keys.Remove(String($p136Profile))
        EndIf
    EndIf
    _IniWrite($p136Ini, "AIProfiles", "Active", String($p136Profile))
    P136ApplyActive()
    _UI_SetText($w, $p136Fields[6], "")
    _UI_SetText($w, $p136Fields[14], "使用中：" & $c.Item("name"))
    P136FillFields($p136Profile)
    P136RefreshTranslateProfile()
    _UI_Notify($w, "AI API 設定", "已儲存並設為使用中：" & $c.Item("name"), $AUI_NOTIFY_INFO, 3500)
    Return True
EndFunc

; 清除此設定檔已保存的 API Key。
Func P136ClearKey($id)
    #forceref $id
    _IniWrite($p136Ini, P136Section($p136Profile), "Key", "")
    If $p136Keys.Exists(String($p136Profile)) Then $p136Keys.Remove(String($p136Profile))
    If $p136Profile = P136Active() Then P136ApplyActive()
    P136FillFields($p136Profile)
    _UI_Notify($p136SetWnd, "AI API 設定", "已清除此設定檔的 API Key。", $AUI_NOTIFY_INFO, 3000)
EndFunc

; 新增設定檔（重新開啟視窗以更新清單）。
Func P136AddProfile($id)
    #forceref $id
    Local $n = P136Count() + 1
    P136WriteDefaults($n, 1)
    _IniWrite($p136Ini, "AIProfiles", "Count", String($n))
    $p136Profile = $n
    $p136State = "settings"
    _UI_WindowClose($p136SetWnd)
EndFunc

; 刪除設定檔（先確認）。
Func P136DeleteProfile($id)
    #forceref $id
    If P136Count() <= 1 Then
        _UI_Notify($p136SetWnd, "不能刪除", "至少需保留一組設定。", $AUI_NOTIFY_WARNING, 4000)
        Return
    EndIf
    $p136DeleteDialog = _UI_Dialog($p136SetWnd, "刪除 AI 設定檔", "確定刪除「" & _IniRead($p136Ini, P136Section($p136Profile), "Name", "") & "」？已保存的 Key 會一併刪除。", "刪除|取消")
    If $p136DeleteDialog Then
        _UI_DialogSetDefaultButton($p136SetWnd, $p136DeleteDialog, 1)
        _UI_DialogSetCancelButton($p136SetWnd, $p136DeleteDialog, 1)
        _UI_OnValue($p136SetWnd, $p136DeleteDialog, "P136DeleteReply")
    EndIf
EndFunc

; 刪除確認的回呼：搬移後續設定檔並調整使用中編號。
Func P136DeleteReply($id, $value)
    If $id <> $p136DeleteDialog Then Return
    $p136DeleteDialog = 0
    If Number($value) <> 0 Then Return
    Local $n = P136Count(), $keys[12] = ["Name", "Provider", "Protocol", "Endpoint", "Model", "Key", "KeyMode", "Temperature", "BatchItems", "BatchChars", "Delay", "Timeout"]
    For $i = $p136Profile To $n - 1
        For $k = 0 To UBound($keys) - 1
            _IniWrite($p136Ini, P136Section($i), $keys[$k], _IniRead($p136Ini, P136Section($i + 1), $keys[$k], ""))
        Next
    Next
    IniDelete($p136Ini, P136Section($n))
    Local $session = ObjCreate("Scripting.Dictionary")
    For $i = 1 To $n
        If Not $p136Keys.Exists(String($i)) Or $i = $p136Profile Then ContinueLoop
        $session.Item(String($i > $p136Profile ? $i - 1 : $i)) = $p136Keys.Item(String($i))
    Next
    $p136Keys = $session
    Local $active = P136Active()
    If $active = $p136Profile Then
        $active = 1
    ElseIf $active > $p136Profile Then
        $active -= 1
    EndIf
    _IniWrite($p136Ini, "AIProfiles", "Count", String($n - 1))
    _IniWrite($p136Ini, "AIProfiles", "Active", String($active))
    $p136Profile = $active
    P136ApplyActive()
    P136RefreshTranslateProfile()
    $p136State = "settings"
    _UI_WindowClose($p136SetWnd)
EndFunc

; 「關閉」按鈕。
Func P136CloseSettings($id)
    #forceref $id
    _UI_WindowClose($p136SetWnd)
EndFunc

; AI 設定視窗已關閉：中止進行中的測試請求。
Func P136SettingsClosed($id)
    #forceref $id
    If $p136ModelWnd <> 0 And _UI_IsAlive($p136ModelWnd) Then _UI_WindowClose($p136ModelWnd)
    HH_ClearChildFonts($p136SetWnd)
    $p136SetWnd = 0
    If $p136HttpMode = "test" Or $p136HttpMode = "models" Then P136AbortHttp()
EndFunc

; ---------- 非同步：測試連線與模型清單 ----------
Func P136AbortHttp()
    If IsObj($p136Http) Then $p136Http.Abort()
    $p136Http = 0
    $p136HttpMode = ""
EndFunc

; 非同步送出測試或模型清單請求。
Func P136StartHttp($mode, $method, $url, $headers, $body)
    P136AbortHttp()
    Local $http = ObjCreate("WinHttp.WinHttpRequest.5.1")
    If Not IsObj($http) Then Return False
    $p136Com = ""
    $http.SetTimeouts(10000, 10000, 30000, 60000)
    $http.Open($method, $url, True)
    If @error Then Return False
    P136SetHeaders($http, $headers)
    If $body = "" Then
        $http.Send()
    Else
        $http.Send(StringToBinary($body, 4))
    EndIf
    If @error Then Return False
    $p136Http = $http
    $p136HttpMode = $mode
    $p136HttpClock = TimerInit()
    Return True
EndFunc

; 「測試連線」按鈕。
Func P136TestProfile($id)
    #forceref $id
    Local $c = P136FieldsConfig()
    If Not P136ValidEndpoint($c.Item("endpoint")) Then
        _UI_Notify($p136SetWnd, "Endpoint 不正確", "請先填入正確的 API Endpoint。", $AUI_NOTIFY_WARNING, 5000)
        Return
    EndIf
    If $c.Item("key") = "" And P136NeedsKey($c) Then
        _UI_Notify($p136SetWnd, "缺少 API Key", "請輸入 API Key。", $AUI_NOTIFY_WARNING, 5000)
        Return
    EndIf
    Local $url, $body, $headers
    P136Build($c, "You are a connection test.", "Reply with OK only.", $url, $body, $headers)
    $p136HttpConfig = $c
    If Not P136StartHttp("test", "POST", $url, $headers, $body) Then
        _UI_Notify($p136SetWnd, "測試連線", "無法送出請求：" & $p136Com, $AUI_NOTIFY_WARNING, 6000)
        Return
    EndIf
    _UI_SetText($p136SetWnd, $p136Fields[8], "測試中…")
EndFunc

; 「選擇模型…」按鈕：取得模型清單。
Func P136PickModels($id)
    #forceref $id
    Local $c = P136FieldsConfig(), $headers
    Local $url = P136ModelsUrl($c, $headers)
    If $url = "" Then
        _UI_Notify($p136SetWnd, "選擇模型", ($c.Item("protocol") = 4 ? "Google 翻譯（免費）不需要選擇模型。" : "此通道不提供模型清單（Azure 請填部署名稱）。"), $AUI_NOTIFY_INFO, 5000)
        Return
    EndIf
    If $c.Item("key") = "" And P136NeedsKey($c) Then
        _UI_Notify($p136SetWnd, "缺少 API Key", "取得模型清單需要 API Key。", $AUI_NOTIFY_WARNING, 5000)
        Return
    EndIf
    $p136HttpConfig = $c
    If Not P136StartHttp("models", "GET", $url, $headers, "") Then
        _UI_Notify($p136SetWnd, "選擇模型", "無法送出請求：" & $p136Com, $AUI_NOTIFY_WARNING, 6000)
        Return
    EndIf
    _UI_SetText($p136SetWnd, $p136Fields[8], "正在取得模型清單…")
EndFunc

; 主迴圈呼叫：處理測試連線或模型清單的回應。
Func P136PollHttp()
    If Not IsObj($p136Http) Then Return
    Local $http = $p136Http, $done = $http.WaitForResponse(0), $err = @error
    If Not $err And Not $done Then
        If TimerDiff($p136HttpClock) < 90000 Then Return
        $http.Abort()
    EndIf
    Local $mode = $p136HttpMode, $status = 0, $text = ""
    $p136Http = 0
    $p136HttpMode = ""
    If Not $err And $done Then
        $status = $http.Status
        $text = P136ResponseText($http)
    EndIf
    If $p136SetWnd = 0 Or Not _UI_IsAlive($p136SetWnd) Then Return
    If $status <> 200 Then
        _UI_SetText($p136SetWnd, $p136Fields[8], "失敗：HTTP " & $status)
        P136Info($p136SetWnd, ($mode = "test" ? "測試連線失敗" : "取得模型清單失敗"), P136ErrorText($status, $text))
        Return
    EndIf
    If $mode = "test" Then
        Local $reply = P136Reply($p136HttpConfig.Item("protocol"), $text)
        _UI_SetText($p136SetWnd, $p136Fields[8], "測試成功")
        P136Info($p136SetWnd, "測試連線成功", "模型回應：" & StringLeft(StringStripWS($reply, 3), 200))
        Return
    EndIf
    Local $ids
    If $p136HttpConfig.Item("protocol") = 1 Then
        Local $blocks = StringRegExp($text, '(?s)\{\s*"name"\s*:\s*"models/[^"]+".*?(?=\{\s*"name"\s*:\s*"models/|\z)', 3)
        Local $list[0]
        If Not @error Then
            For $i = 0 To UBound($blocks) - 1
                If Not StringInStr($blocks[$i], '"generateContent"') Then ContinueLoop
                Local $m = StringRegExp($blocks[$i], '"name"\s*:\s*"models/([^"]+)"', 1)
                If @error Then ContinueLoop
                ReDim $list[UBound($list) + 1]
                $list[UBound($list) - 1] = $m[0]
            Next
        EndIf
        $ids = $list
    Else
        $ids = P136Strings($text, "id")
    EndIf
    If UBound($ids) = 0 Then
        _UI_SetText($p136SetWnd, $p136Fields[8], "沒有可用模型")
        P136Info($p136SetWnd, "選擇模型", "回應中沒有可用模型，請手動輸入模型名稱。")
        Return
    EndIf
    If UBound($ids) > 1 Then _ArraySort($ids)
    $p136Models = $ids
    _UI_SetText($p136SetWnd, $p136Fields[8], "找到 " & UBound($ids) & " 個模型")
    P136ModelWindow()
EndFunc

; 開啟模型選擇視窗（分頁顯示，每頁 10 個）。
Func P136ModelWindow()
    If $p136ModelWnd <> 0 And _UI_IsAlive($p136ModelWnd) Then _UI_WindowClose($p136ModelWnd)
    $p136ModelWnd = _UI_WindowCreateEx("選擇模型", 0, 0, 560, 480, BitOR($AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $p136ModelWnd = 0 Then Return
    Local $w = $p136ModelWnd
    _UI_ThemeSetMode($w, HelperEffectiveTheme())
    _UI_WindowCenter($w)
    For $i = 0 To 9
        $p136ModelRows[$i] = HH_Button($w, 0, "", $AUI_VAR_DEFAULT, 16, 44 + $i * 34, 528, 30)
        _UI_OnClick($w, $p136ModelRows[$i], "P136ModelClicked")
    Next
    Local $prev = HH_Button($w, 0, "上一頁", $AUI_VAR_DEFAULT, 16, 394, 110, 32)
    $p136ModelLabel = HH_Text($w, 0, "", 140, 398, 270, 26)
    Local $next = HH_Button($w, 0, "下一頁", $AUI_VAR_DEFAULT, 434, 394, 110, 32)
    _UI_OnClick($w, $prev, "P136ModelPrev")
    _UI_OnClick($w, $next, "P136ModelNext")
    _UI_OnClose($w, "P136ModelClosed")
    $p136ModelPage = 0
    P136ModelRender()
    HH_ApplyChildFonts()
    _UI_WindowShowModal($w, $p136SetWnd)
EndFunc

; 顯示目前頁的模型。
Func P136ModelRender()
    Local $pages = Ceiling(UBound($p136Models) / 10)
    If $pages < 1 Then $pages = 1
    If $p136ModelPage >= $pages Then $p136ModelPage = $pages - 1
    If $p136ModelPage < 0 Then $p136ModelPage = 0
    For $i = 0 To 9
        Local $k = $p136ModelPage * 10 + $i
        If $k < UBound($p136Models) Then
            _UI_SetText($p136ModelWnd, $p136ModelRows[$i], $p136Models[$k])
            _UI_SetVisible($p136ModelWnd, $p136ModelRows[$i], True)
        Else
            _UI_SetText($p136ModelWnd, $p136ModelRows[$i], "")
            _UI_SetVisible($p136ModelWnd, $p136ModelRows[$i], False)
        EndIf
    Next
    _UI_SetText($p136ModelWnd, $p136ModelLabel, "第 " & ($p136ModelPage + 1) & " / " & $pages & " 頁，共 " & UBound($p136Models) & " 個")
EndFunc

; 模型清單上一頁。
Func P136ModelPrev($id)
    #forceref $id
    $p136ModelPage -= 1
    P136ModelRender()
EndFunc

; 模型清單下一頁。
Func P136ModelNext($id)
    #forceref $id
    $p136ModelPage += 1
    P136ModelRender()
EndFunc

; 選取模型並填回設定視窗。
Func P136ModelClicked($id)
    For $i = 0 To 9
        If $p136ModelRows[$i] <> $id Then ContinueLoop
        Local $k = $p136ModelPage * 10 + $i
        If $k >= UBound($p136Models) Then Return
        If $p136SetWnd <> 0 And _UI_IsAlive($p136SetWnd) Then _UI_SetText($p136SetWnd, $p136Fields[5], $p136Models[$k])
        _UI_WindowClose($p136ModelWnd)
        Return
    Next
EndFunc

; 模型選擇視窗已關閉的回呼。
Func P136ModelClosed($id)
    #forceref $id
    HH_ClearChildFonts($p136ModelWnd)
    $p136ModelWnd = 0
EndFunc

; ---------- AUI：網頁翻譯目的語言 ----------
Func HH_WebLangPrompt()
    If $gWebLangCode = "zh-TW" Then Return "繁體中文（台灣用語）"
    Return $gWebLangName
EndFunc

; 從 INI 讀取網頁翻譯目的語言。
Func HH_WebLangLoad()
    Local $idx = Number(_IniRead($p136Ini, "WebTranslate", "Language", "0"))
    Local $a = StringSplit($p136Languages, "|", 2), $code, $lcid
    If $idx < 0 Or $idx >= UBound($a) Then $idx = 0
    P136LangInfo($idx, $code, $lcid)
    $gWebLangIndex = $idx
    If $code = "custom" Then
        $gWebLangName = StringStripWS(_IniRead($p136Ini, "WebTranslate", "CustomName", ""), 3)
        $gWebLangCode = StringStripWS(_IniRead($p136Ini, "WebTranslate", "CustomCode", ""), 3)
        If $gWebLangName = "" And $gWebLangCode = "" Then
            $gWebLangIndex = 0
            $gWebLangName = "繁體中文（臺灣）"
            $gWebLangCode = "zh-TW"
        ElseIf $gWebLangName = "" Then
            $gWebLangName = $gWebLangCode
        EndIf
    Else
        $gWebLangName = $a[$idx]
        $gWebLangCode = $code
    EndIf
EndFunc

; 開啟「翻譯目的語言」視窗。
Func HH_WebLangOpen()
    If $gWebLangWnd <> 0 And _UI_IsAlive($gWebLangWnd) Then
        _UI_WindowShow($gWebLangWnd)
        Return
    EndIf
    $gWebLangWnd = _UI_WindowCreateEx("Html Helper｜翻譯目的語言", 0, 0, 640, 400, BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $gWebLangWnd = 0 Then Return
    Local $w = $gWebLangWnd
    _UI_ThemeSetMode($w, HelperEffectiveTheme())
    _UI_WindowCenter($w)
    HH_Text($w, 0, "網頁右鍵「AI 翻譯／Google 翻譯」的目的語言（來源語言自動辨識）", 20, 44, 600, 24)
    $gWebLangFields[0] = HH_Combo($w, 0, $p136Languages, $gWebLangIndex, 20, 72, 600, 34)
    HH_Text($w, 0, "自訂語言名稱（AI 使用，例如：粵語（香港））", 20, 120, 600, 24)
    $gWebLangFields[1] = HH_Input($w, 0, "例如：粵語（香港）", "", 20, 146, 600, 34)
    HH_Text($w, 0, "自訂語言代碼（Google 使用，例如：yue、fr-CA、zh-HK）", 20, 194, 600, 24)
    $gWebLangFields[2] = HH_Input($w, 0, "例如：yue", "", 20, 220, 600, 34)
    If $gWebLangIndex = UBound(StringSplit($p136Languages, "|", 2)) - 1 Then
        _UI_SetText($w, $gWebLangFields[1], $gWebLangName)
        _UI_SetText($w, $gWebLangFields[2], $gWebLangCode)
    EndIf
    Local $ok = HH_Button($w, 0, "儲存", $AUI_VAR_PRIMARY, 330, 310, 140, 38)
    Local $cancel = HH_Button($w, 0, "取消", $AUI_VAR_DEFAULT, 480, 310, 140, 38)
    _UI_OnClick($w, $ok, "HH_WebLangSave")
    _UI_OnClick($w, $cancel, "HH_WebLangCancel")
    _UI_OnClose($w, "HH_WebLangClosed")
    HH_ApplyChildFonts()
    _UI_WindowShowModal($w, $gWnd)
EndFunc

; 儲存目的語言（自訂語言需填代碼才能用 Google 翻譯）。
Func HH_WebLangSave($id)
    #forceref $id
    Local $w = $gWebLangWnd, $idx = _UI_ComboGetSelected($w, $gWebLangFields[0]), $code, $lcid
    If $idx < 0 Then $idx = 0
    P136LangInfo($idx, $code, $lcid)
    Local $name = StringStripWS(_UI_GetText($w, $gWebLangFields[1]), 3)
    Local $custom = StringStripWS(_UI_GetText($w, $gWebLangFields[2]), 3)
    If $code = "custom" Then
        If $custom <> "" And Not StringRegExp($custom, "^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})?$") Then
            _UI_Notify($w, "語言代碼不正確", "請輸入如 yue、fr-CA、zh-HK 的語言代碼。", $AUI_NOTIFY_WARNING, 5000)
            Return
        EndIf
        If $name = "" And $custom = "" Then
            _UI_Notify($w, "缺少語言", "請輸入自訂語言名稱或代碼。", $AUI_NOTIFY_WARNING, 5000)
            Return
        EndIf
        If $custom = "" Then $custom = P136CodeFor($name)
        If $custom = "" Then _UI_Notify($w, "提醒", "未填語言代碼，Google 翻譯將無法使用此語言（AI 翻譯可用）。", $AUI_NOTIFY_INFO, 5000)
    EndIf
    _IniWrite($p136Ini, "WebTranslate", "Language", String($idx))
    _IniWrite($p136Ini, "WebTranslate", "CustomName", $name)
    _IniWrite($p136Ini, "WebTranslate", "CustomCode", $custom)
    HH_WebLangLoad()
    _UI_WindowClose($w)
    _UI_Notify($gWnd, "翻譯目的語言", "已設定為：" & $gWebLangName & ($gWebLangCode <> "" ? "（" & $gWebLangCode & "）" : ""), $AUI_NOTIFY_INFO, 3000)
EndFunc

; 「取消」按鈕。
Func HH_WebLangCancel($id)
    #forceref $id
    _UI_WindowClose($gWebLangWnd)
EndFunc

; 目的語言視窗已關閉的回呼。
Func HH_WebLangClosed($id)
    #forceref $id
    HH_ClearChildFonts($gWebLangWnd)
    $gWebLangWnd = 0
EndFunc

; ---------- AUI：開啟網址（取代 InputBox） ----------
Func P136OpenUrl()
    If $p136UrlWnd <> 0 And _UI_IsAlive($p136UrlWnd) Then Return
    $p136UrlWnd = _UI_WindowCreateEx("Html Helper｜開啟網址", 0, 0, 640, 210, BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED))
    If $p136UrlWnd = 0 Then Return
    Local $w = $p136UrlWnd
    _UI_ThemeSetMode($w, HelperEffectiveTheme())
    _UI_WindowCenter($w)
    HH_Text($w, 0, "輸入網站網址（https://...）", 20, 44, 600, 24)
    $p136UrlInput = HH_Input($w, 0, "https://", "", 20, 72, 600, 36)
    _UI_SetText($w, $p136UrlInput, "https://")
    Local $ok = HH_Button($w, 0, "開啟", $AUI_VAR_PRIMARY, 330, 130, 140, 38)
    Local $cancel = HH_Button($w, 0, "取消", $AUI_VAR_DEFAULT, 480, 130, 140, 38)
    _UI_OnClick($w, $ok, "P136UrlOk")
    _UI_OnClick($w, $cancel, "P136UrlCancel")
    _UI_OnClose($w, "P136UrlClosed")
    HH_ApplyChildFonts()
    _UI_WindowShowModal($w, $gWnd)
EndFunc

; 「開啟」按鈕：交給主迴圈開啟網址。
Func P136UrlOk($id)
    #forceref $id
    Local $url = StringStripWS(_UI_GetText($p136UrlWnd, $p136UrlInput), 3)
    _UI_WindowClose($p136UrlWnd)
    If $url <> "" And $url <> "https://" Then $gPendingDropPath = $url
EndFunc

; 「取消」按鈕。
Func P136UrlCancel($id)
    #forceref $id
    _UI_WindowClose($p136UrlWnd)
EndFunc

; 開啟網址視窗已關閉的回呼。
Func P136UrlClosed($id)
    #forceref $id
    HH_ClearChildFonts($p136UrlWnd)
    $p136UrlWnd = 0
EndFunc
