#include-once
; =============================================================================
; Html Helper － AI API 設定檔與請求
;
; 多組 AI 設定檔（INI）、API Key 以 Windows DPAPI 加密，
; 各家協定（OpenAI 相容、Gemini、Anthropic、Azure、Google 翻譯）
; 的請求組裝與回應解析。GUI 與命令列翻譯共用。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ===== 多家 AI API、自有金鑰、CHM／資料夾結構保留翻譯 =====
; 設定介面全部使用 AUI 視窗；API Key 以 Windows DPAPI 加密保存或只保留於本次執行。
; 翻譯工作在同一 EXE 的命令模式子程序執行，GUI 以共享記憶體顯示進度。
Func P136ComError($oError)
    $p136Com = "COM 0x" & Hex($oError.number, 8) & "：" & StringStripWS($oError.description, 3)
EndFunc

; ---------- 設定檔與金鑰 ----------
Func P136Section($n)
    Return "AIProfile_" & $n
EndFunc

; 設定檔數量（沒有時建立預設設定並轉移舊版 [AI] 設定）。
Func P136Count()
    Local $n = Number(_IniRead($p136Ini, "AIProfiles", "Count", "0"))
    If $n < 1 Then
        P136WriteDefaults(1, 2)
        Local $oldUrl = _IniRead($p136Ini, "AI", "Endpoint", "")
        Local $oldModel = _IniRead($p136Ini, "AI", "Model", "")
        If $oldUrl <> "" And Not StringInStr(StringLower($oldUrl), "generativelanguage.googleapis.com") Then
            _IniWrite($p136Ini, P136Section(1), "Provider", "0")
            _IniWrite($p136Ini, P136Section(1), "Protocol", "0")
            _IniWrite($p136Ini, P136Section(1), "Name", "既有 AI 設定")
            _IniWrite($p136Ini, P136Section(1), "Endpoint", $oldUrl)
        EndIf
        If $oldModel <> "" And $oldModel <> "auto" Then _IniWrite($p136Ini, P136Section(1), "Model", $oldModel)
        _IniWrite($p136Ini, "AIProfiles", "Count", "1")
        _IniWrite($p136Ini, "AIProfiles", "Active", "1")
        $n = 1
    EndIf
    Return $n
EndFunc

; 目前使用中的設定檔編號。
Func P136Active()
    Local $n = P136Count(), $a = Number(_IniRead($p136Ini, "AIProfiles", "Active", "1"))
    If $a < 1 Or $a > $n Then $a = 1
    Return $a
EndFunc

; 供應商範本：回傳預設協定、Endpoint 與模型。
Func P136Preset($provider, ByRef $protocol, ByRef $endpoint, ByRef $model)
    $protocol = 0
    $model = ""
    Switch $provider
        Case 1
            $endpoint = "https://api.openai.com/v1/chat/completions"
            $model = "gpt-4.1-mini"
        Case 2
            $protocol = 1
            $endpoint = "https://generativelanguage.googleapis.com/v1beta/models"
            $model = "gemini-2.5-flash"
        Case 3
            $protocol = 2
            $endpoint = "https://api.anthropic.com/v1/messages"
            $model = "claude-sonnet-4-5"
        Case 4
            $protocol = 3
            $endpoint = "https://<資源名稱>.openai.azure.com/openai/deployments/<部署名稱>/chat/completions?api-version=2024-10-21"
            $model = "<部署名稱>"
        Case 5
            $endpoint = "https://api.deepseek.com/chat/completions"
            $model = "deepseek-chat"
        Case 6
            $endpoint = "https://api.x.ai/v1/chat/completions"
            $model = "grok-4"
        Case 7
            $endpoint = "https://api.mistral.ai/v1/chat/completions"
            $model = "mistral-large-latest"
        Case 8
            $endpoint = "https://openrouter.ai/api/v1/chat/completions"
            $model = "openai/gpt-4.1-mini"
        Case 9
            $endpoint = "https://api.groq.com/openai/v1/chat/completions"
            $model = "llama-3.3-70b-versatile"
        Case 10
            $endpoint = "https://api.perplexity.ai/chat/completions"
            $model = "sonar"
        Case 11
            $endpoint = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions"
            $model = "qwen-plus"
        Case 12
            $endpoint = "https://api.moonshot.ai/v1/chat/completions"
            $model = "kimi-k2-0905-preview"
        Case 13
            $endpoint = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
            $model = "glm-4.5"
        Case 14
            $endpoint = "http://127.0.0.1:11434/v1/chat/completions"
            $model = "qwen2.5:7b"
        Case 15
            $endpoint = "http://127.0.0.1:1234/v1/chat/completions"
            $model = "local-model"
        Case 16
            $protocol = 4
            $endpoint = "https://translate.googleapis.com/translate_a/t"
            $model = ""
        Case Else
            $endpoint = "https://"
    EndSwitch
EndFunc

; 供應商名稱。
Func P136ProviderName($i)
    Local $a = StringSplit($p136Providers, "|", 2)
    If $i < 0 Or $i >= UBound($a) Then Return $a[0]
    Return $a[$i]
EndFunc

; 寫入指定供應商的預設設定。
Func P136WriteDefaults($n, $provider)
    Local $protocol, $endpoint, $model, $s = P136Section($n)
    P136Preset($provider, $protocol, $endpoint, $model)
    _IniWrite($p136Ini, $s, "Name", P136ProviderName($provider))
    _IniWrite($p136Ini, $s, "Provider", String($provider))
    _IniWrite($p136Ini, $s, "Protocol", String($protocol))
    _IniWrite($p136Ini, $s, "Endpoint", $endpoint)
    _IniWrite($p136Ini, $s, "Model", $model)
    _IniWrite($p136Ini, $s, "Key", "")
    _IniWrite($p136Ini, $s, "KeyMode", "0")
    _IniWrite($p136Ini, $s, "Temperature", "0.2")
    _IniWrite($p136Ini, $s, "BatchItems", "20")
    _IniWrite($p136Ini, $s, "BatchChars", "5000")
    _IniWrite($p136Ini, $s, "Delay", "250")
    _IniWrite($p136Ini, $s, "Timeout", "120")
    _IniWrite($p136Ini, $s, "Parallel", "3")
    If $protocol = 4 Then
        _IniWrite($p136Ini, $s, "BatchItems", "50")
        _IniWrite($p136Ini, $s, "BatchChars", "4000")
        _IniWrite($p136Ini, $s, "Delay", "300")
        _IniWrite($p136Ini, $s, "Timeout", "60")
    EndIf
EndFunc

; 讀取設定檔（含解密 API Key）。
Func P136Load($n, $withKey = True)
    Local $c = ObjCreate("Scripting.Dictionary"), $s = P136Section($n)
    $c.Item("index") = $n
    $c.Item("name") = _IniRead($p136Ini, $s, "Name", "AI " & $n)
    $c.Item("provider") = Number(_IniRead($p136Ini, $s, "Provider", "0"))
    $c.Item("protocol") = Number(_IniRead($p136Ini, $s, "Protocol", "0"))
    $c.Item("endpoint") = StringStripWS(_IniRead($p136Ini, $s, "Endpoint", ""), 3)
    $c.Item("model") = StringStripWS(_IniRead($p136Ini, $s, "Model", ""), 3)
    $c.Item("keymode") = Number(_IniRead($p136Ini, $s, "KeyMode", "0"))
    $c.Item("temperature") = _IniRead($p136Ini, $s, "Temperature", "0.2")
    $c.Item("items") = Number(_IniRead($p136Ini, $s, "BatchItems", "20"))
    $c.Item("chars") = Number(_IniRead($p136Ini, $s, "BatchChars", "5000"))
    $c.Item("delay") = Number(_IniRead($p136Ini, $s, "Delay", "250"))
    $c.Item("timeout") = Number(_IniRead($p136Ini, $s, "Timeout", "120"))
    $c.Item("parallel") = Number(_IniRead($p136Ini, $s, "Parallel", "3"))
    If $c.Item("parallel") < 1 Or $c.Item("parallel") > 8 Then $c.Item("parallel") = 3
    If $c.Item("protocol") < 0 Or $c.Item("protocol") > 4 Then $c.Item("protocol") = 0
    If $c.Item("items") < 1 Then $c.Item("items") = 20
    If $c.Item("chars") < 500 Then $c.Item("chars") = 5000
    If $c.Item("timeout") < 15 Then $c.Item("timeout") = 120
    Local $stored = _IniRead($p136Ini, $s, "Key", "")
    $c.Item("stored") = ($stored <> "")
    $c.Item("key") = ""
    If $withKey Then
        If $p136Keys.Exists(String($n)) Then
            $c.Item("key") = $p136Keys.Item(String($n))
        ElseIf $stored <> "" Then
            $c.Item("key") = P136Unprotect($stored)
        EndIf
    EndIf
    Return $c
EndFunc

; 以 Windows DPAPI 加密 API Key（只有同一 Windows 帳號能解）。
Func P136Protect($text)
    If $text = "" Then Return ""
    Local $bin = StringToBinary($text, 4), $n = BinaryLen($bin)
    Local $src = DllStructCreate("byte[" & $n & "]")
    DllStructSetData($src, 1, $bin)
    Local $blobIn = DllStructCreate("dword cb;ptr pb"), $out = DllStructCreate("dword cb;ptr pb")
    DllStructSetData($blobIn, "cb", $n)
    DllStructSetData($blobIn, "pb", DllStructGetPtr($src))
    Local $r = DllCall("crypt32.dll", "bool", "CryptProtectData", "struct*", $blobIn, "wstr", "Html Helper AI", "ptr", 0, "ptr", 0, "ptr", 0, "dword", 1, "struct*", $out)
    If @error Or Not IsArray($r) Then Return SetError(1, 0, "")
    If Not $r[0] Then Return SetError(1, 0, "")
    Local $size = DllStructGetData($out, "cb"), $ptr = DllStructGetData($out, "pb")
    Local $buf = DllStructCreate("byte[" & $size & "]", $ptr)
    Local $hex = Hex(DllStructGetData($buf, 1))
    DllCall("kernel32.dll", "handle", "LocalFree", "handle", $ptr)
    Return "dpapi:" & $hex
EndFunc

; 以 Windows DPAPI 解密 API Key。
Func P136Unprotect($value)
    If StringLeft($value, 6) <> "dpapi:" Then Return ""
    Local $hex = StringTrimLeft($value, 6)
    If $hex = "" Or Not StringIsXDigit($hex) Then Return ""
    Local $bin = Binary("0x" & $hex), $n = BinaryLen($bin)
    Local $src = DllStructCreate("byte[" & $n & "]")
    DllStructSetData($src, 1, $bin)
    Local $blobIn = DllStructCreate("dword cb;ptr pb"), $out = DllStructCreate("dword cb;ptr pb")
    DllStructSetData($blobIn, "cb", $n)
    DllStructSetData($blobIn, "pb", DllStructGetPtr($src))
    Local $r = DllCall("crypt32.dll", "bool", "CryptUnprotectData", "struct*", $blobIn, "ptr", 0, "ptr", 0, "ptr", 0, "ptr", 0, "dword", 1, "struct*", $out)
    If @error Or Not IsArray($r) Then Return ""
    If Not $r[0] Then Return ""
    Local $size = DllStructGetData($out, "cb"), $ptr = DllStructGetData($out, "pb")
    Local $buf = DllStructCreate("byte[" & $size & "]", $ptr)
    Local $plain = BinaryToString(DllStructGetData($buf, 1), 4)
    DllCall("kernel32.dll", "handle", "LocalFree", "handle", $ptr)
    Return $plain
EndFunc

; API Key 的遮罩顯示（只露出末 4 碼）。
Func P136Mask($key)
    If $key = "" Then Return "未設定"
    If StringLen($key) <= 6 Then Return "已設定（****）"
    Return "已設定（****" & StringRight($key, 4) & "）"
EndFunc

; 此設定是否需要 API Key（本機服務與 Google 翻譯不需要）。
Func P136NeedsKey($c)
    If $c.Item("protocol") = 4 Then Return False
    Return Not StringRegExp($c.Item("endpoint"), "(?i)^http://(127\.0\.0\.1|localhost|\[::1\])(:|/)")
EndFunc

; Endpoint 是否合法（HTTPS，或 http://127.0.0.1／localhost）。
Func P136ValidEndpoint($url)
    If StringInStr($url, "<") Or StringInStr($url, " ") Then Return False
    If StringRegExp($url, "(?i)^https://[^/\s]+/.+") Then Return True
    Return StringRegExp($url, "(?i)^http://(127\.0\.0\.1|localhost|\[::1\])(:[0-9]+)?/.+") = 1
EndFunc

; 將使用中的設定同步到既有「AI 翻譯選取文字／本頁」功能。
Func P136ApplyActive()
    Local $c = P136Load(P136Active())
    $p136Config = $c
    $p136Protocol = $c.Item("protocol")
    $gAiEndpoint = $c.Item("endpoint")
    $gAiModel = $c.Item("model")
    $gAiKey = $c.Item("key")
    If $gAiKey = "" And Not P136NeedsKey($c) Then $gAiKey = "(none)"
    Return $c
EndFunc

; ---------- 請求組裝與回應解析 ----------
Func P136Build($c, $system, $user, ByRef $url, ByRef $body, ByRef $headers)
    Local $protocol = $c.Item("protocol"), $key = $c.Item("key"), $model = $c.Item("model")
    Local $temp = StringReplace(String($c.Item("temperature")), ",", ".")
    If Not StringRegExp($temp, "^[0-9]+(\.[0-9]+)?$") Then $temp = "0.2"
    If $key = "(none)" Then $key = ""
    $url = $c.Item("endpoint")
    $headers = "Content-Type: application/json; charset=utf-8"
    Switch $protocol
        Case 1
            If StringRight($url, 1) = "/" Then $url = StringTrimRight($url, 1)
            If Not StringInStr($url, ":generateContent") Then
                If StringRegExp($url, "(?i)/models$") Then
                    $url &= "/" & $model & ":generateContent"
                Else
                    $url &= "/models/" & $model & ":generateContent"
                EndIf
            EndIf
            $body = '{"systemInstruction":{"parts":[{"text":' & HH_AI_JsonQuote($system) & '}]},"contents":[{"role":"user","parts":[{"text":' & HH_AI_JsonQuote($user) & '}]}],"generationConfig":{"temperature":' & $temp & '}}'
            If $key <> "" Then $headers &= @LF & "x-goog-api-key: " & $key
        Case 2
            $body = '{"model":' & HH_AI_JsonQuote($model) & ',"max_tokens":8192,"temperature":' & $temp & ',"system":' & HH_AI_JsonQuote($system) & ',"messages":[{"role":"user","content":' & HH_AI_JsonQuote($user) & '}]}'
            $headers &= @LF & "anthropic-version: 2023-06-01"
            If $key <> "" Then $headers &= @LF & "x-api-key: " & $key
        Case 4
            ; Google 翻譯免費端點（translate_a/t，client=gtx）；不使用提示詞與 Key。
            Local $tl = $p136LangCode
            If $tl = "" Or $tl = "custom" Then $tl = $gWebLangCode
            If $tl = "" Then $tl = "zh-TW"
            $url = StringRegExpReplace($url, "\?.*$", "")
            $url &= "?client=gtx&sl=auto&tl=" & P136UrlEncode($tl) & "&format=text"
            $headers = "Content-Type: application/x-www-form-urlencoded; charset=utf-8"
            If $system = Chr(1) Then
                $body = $user
            Else
                $body = "q=" & P136UrlEncode($user)
            EndIf
        Case 3
            $body = '{"messages":[{"role":"system","content":' & HH_AI_JsonQuote($system) & '},{"role":"user","content":' & HH_AI_JsonQuote($user) & '}],"temperature":' & $temp & '}'
            If $key <> "" Then $headers &= @LF & "api-key: " & $key
        Case Else
            $body = '{"model":' & HH_AI_JsonQuote($model) & ',"messages":[{"role":"system","content":' & HH_AI_JsonQuote($system) & '},{"role":"user","content":' & HH_AI_JsonQuote($user) & '}],"temperature":' & $temp & '}'
            If $key <> "" Then $headers &= @LF & "Authorization: Bearer " & $key
            If StringInStr(StringLower($url), "openrouter.ai") Then $headers &= @LF & "X-Title: Html Helper"
    EndSwitch
EndFunc

; 模型清單的網址與標頭（不提供清單的協定回傳空字串）。
Func P136ModelsUrl($c, ByRef $headers)
    Local $url = $c.Item("endpoint"), $key = $c.Item("key")
    If $key = "(none)" Then $key = ""
    $headers = ""
    Switch $c.Item("protocol")
        Case 1
            $url = StringRegExpReplace($url, "(?i)/models/.*$", "/models")
            If StringRight($url, 1) = "/" Then $url = StringTrimRight($url, 1)
            If Not StringRegExp($url, "(?i)/models$") Then $url &= "/models"
            $url &= "?pageSize=1000"
            If $key <> "" Then $headers = "x-goog-api-key: " & $key
        Case 2
            $url = StringRegExpReplace($url, "(?i)/messages.*$", "/models?limit=1000")
            $headers = "anthropic-version: 2023-06-01"
            If $key <> "" Then $headers &= @LF & "x-api-key: " & $key
        Case 3, 4
            Return ""
        Case Else
            $url = StringRegExpReplace($url, "(?i)/chat/completions.*$", "/models")
            If Not StringRegExp($url, "(?i)/models$") Then Return ""
            If $key <> "" Then $headers = "Authorization: Bearer " & $key
    EndSwitch
    Return $url
EndFunc

; 把多行標頭套到 WinHttp 請求。
Func P136SetHeaders($http, $headers)
    If $headers = "" Then Return
    Local $lines = StringSplit($headers, @LF, 2)
    For $i = 0 To UBound($lines) - 1
        Local $p = StringInStr($lines[$i], ":")
        If $p < 2 Then ContinueLoop
        $http.SetRequestHeader(StringLeft($lines[$i], $p - 1), StringStripWS(StringMid($lines[$i], $p + 1), 1))
    Next
EndFunc

; 擷取 JSON 中指定欄位的所有字串值。
Func P136Strings($json, $name)
    Local $m = StringRegExp($json, '"' & $name & '"\s*:\s*"((?:\\.|[^"\\])*)"', 3)
    If @error Then
        Local $empty[0]
        Return $empty
    EndIf
    Return $m
EndFunc

; 從回應 JSON 取出譯文（依協定）。
Func P136Reply($protocol, $json)
    Local $m, $out = ""
    Switch $protocol
        Case 1, 2
            Local $scope = $json
            If $protocol = 1 Then
                Local $p = StringInStr($json, '"candidates"')
                If $p Then $scope = StringMid($json, $p)
                Local $q = StringInStr($scope, '"usageMetadata"')
                If $q Then $scope = StringLeft($scope, $q - 1)
            EndIf
            $m = P136Strings($scope, "text")
            For $i = 0 To UBound($m) - 1
                $out &= HH_AI_Unescape($m[$i])
            Next
        Case 4
            Local $list = P136GoogleList($json)
            If @error Then Return SetError(1, 0, "")
            If $p136GoogleJson Then
                $out = "["
                For $i = 0 To UBound($list) - 1
                    $out &= ($i > 0 ? "," : "") & HH_AI_JsonQuote($list[$i])
                Next
                Return $out & "]"
            EndIf
            For $i = 0 To UBound($list) - 1
                $out &= ($i > 0 ? @LF : "") & $list[$i]
            Next
        Case Else
            $m = P136Strings($json, "content")
            If UBound($m) > 0 Then $out = HH_AI_Unescape($m[0])
    EndSwitch
    If $out = "" Then Return SetError(1, 0, "")
    Return $out
EndFunc

; URL 參數編碼（UTF-8）。
Func P136UrlEncode($s)
    Local $bin = StringToBinary($s, 4), $n = BinaryLen($bin), $out = ""
    If $n = 0 Then Return ""
    Local $st = DllStructCreate("byte[" & $n & "]")
    DllStructSetData($st, 1, $bin)
    For $i = 1 To $n
        Local $c = DllStructGetData($st, 1, $i)
        If ($c >= 48 And $c <= 57) Or ($c >= 65 And $c <= 90) Or ($c >= 97 And $c <= 122) Or $c = 45 Or $c = 46 Or $c = 95 Or $c = 126 Then
            $out &= Chr($c)
        Else
            $out &= "%" & Hex($c, 2)
        EndIf
    Next
    Return $out
EndFunc

; 解析 Google 翻譯多段回應成字串陣列。
Func P136GoogleList($json)
    ; sl=auto 時回應為 [["譯文","en"],...]；固定來源語言時為 ["譯文",...]。
    Local $m = StringRegExp($json, '\[\s*"((?:\\.|[^"\\])*)"\s*,\s*(?:"(?:\\.|[^"\\])*"|null)\s*\]', 3)
    If @error Then
        If Not StringRegExp($json, '^\s*\[\s*"') Then Return SetError(1, 0, 0)
        $m = StringRegExp($json, '"((?:\\.|[^"\\])*)"', 3)
        If @error Then Return SetError(1, 0, 0)
    EndIf
    For $i = 0 To UBound($m) - 1
        $m[$i] = HH_AI_Unescape($m[$i])
    Next
    Return $m
EndFunc

; 把 JSON 字串陣列轉成多個 q 參數。
Func P136GoogleFormJson($json)
    ; 「AI 翻譯本頁」的 JSON 字串陣列逐項轉成多個 q 參數。
    Local $m = StringRegExp($json, '"((?:\\.|[^"\\])*)"', 3), $out = ""
    If @error Then Return "q="
    For $i = 0 To UBound($m) - 1
        $out &= ($i > 0 ? "&" : "") & "q=" & P136UrlEncode(HH_AI_Unescape($m[$i]))
    Next
    Return $out
EndFunc

; Google 免費翻譯的固定設定。
Func P136GoogleConfig()
    Local $c = ObjCreate("Scripting.Dictionary"), $protocol, $endpoint, $model
    P136Preset(16, $protocol, $endpoint, $model)
    $c.Item("index") = 0
    $c.Item("name") = "Google 翻譯（免費）"
    $c.Item("provider") = 16
    $c.Item("protocol") = 4
    $c.Item("endpoint") = $endpoint
    $c.Item("model") = ""
    $c.Item("keymode") = 0
    $c.Item("temperature") = "0"
    $c.Item("items") = 50
    $c.Item("chars") = 4000
    $c.Item("delay") = 300
    $c.Item("timeout") = 60
    $c.Item("stored") = False
    $c.Item("key") = ""
    Return $c
EndFunc

; 語言名稱對應的語言代碼。
Func P136CodeFor($name)
    Local $a = StringSplit($p136Languages, "|", 2), $code, $lcid
    For $i = 0 To UBound($a) - 1
        If $a[$i] = $name Then
            P136LangInfo($i, $code, $lcid)
            If $code <> "custom" Then Return $code
        EndIf
    Next
    If StringRegExp($name, "^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})?$") Then Return $name
    Return ""
EndFunc

; 把 HTTP 錯誤轉成易懂的說明。
Func P136ErrorText($status, $json)
    Local $m = P136Strings($json, "message"), $t = ""
    If UBound($m) > 0 Then $t = HH_AI_Unescape($m[0])
    If $t = "" Then $t = StringLeft(StringStripWS($json, 7), 300)
    Local $hint = ""
    Switch $status
        Case 401, 403
            $hint = "API Key 無效、已停用或沒有此模型權限。"
        Case 404
            $hint = "Endpoint 或模型名稱不存在。"
        Case 429
            $hint = "請求過多或額度已用完。"
        Case 0
            $hint = "無法連線，請檢查網路、防火牆或本機服務。"
    EndSwitch
    Return "HTTP " & $status & ($hint <> "" ? "：" & $hint : "") & ($t <> "" ? @CRLF & StringLeft($t, 400) : "")
EndFunc

; 以 UTF-8 讀取回應內容。
Func P136ResponseText($http)
    Local $raw = $http.ResponseBody
    If @error Or Not IsBinary($raw) Then Return $http.ResponseText
    Return BinaryToString($raw, 4)
EndFunc
