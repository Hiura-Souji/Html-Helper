#include-once
; =============================================================================
; Html Helper － 全域變數
; 依功能模組分組。所有全域變數集中在此，模組檔只放函式。
; 必須在命令列分流之前載入：命令列模式（解包、打包、翻譯）也會用到其中一部分。
; =============================================================================

; ---------------------------------------------------------------------------
; 程式資訊與設定檔
; ---------------------------------------------------------------------------
Global Const $HH_APP_NAME = "Html Helper", $HH_APP_VERSION = "1.0.0.0", $HH_APP_AUTHOR = "grayfree.tw", $HH_APP_SITE = "https://www.grayfree.tw/"
Global Const $gIni = @ScriptDir & "\Html_Helper.ini"
Global Const $p136Ini = @ScriptDir & "\Html_Helper.ini"

; ---------------------------------------------------------------------------
; 命令列子程序進度（HH_ChmPack.au3：共享記憶體結構與工作紀錄）
; 命令列模式也會用到，必須在命令分流之前宣告。
; ---------------------------------------------------------------------------
Global Const $g133Tag = "dword seq;int percent;uint64 done;uint64 total;wchar phase[128];wchar item[1024]"
Global $g133WorkerPtr = 0, $g133WorkerHandle = 0, $g133WriteClock = TimerInit(), $g133Log = -1
Global $g133BytesBase = 0, $g133BytesTotal = 0, $g133BytePhase = ""

; ---------------------------------------------------------------------------
; AI 設定檔、整份翻譯（HH_AIConfig／HH_AISettingsUI／HH_TranslateJobUI／HH_TranslateEngine／HH_TranslateHtml）
; $p136Trap 是 COM 錯誤處理器，必須保留到程式結束。
; ---------------------------------------------------------------------------
Global $p136Trap = ObjEvent("AutoIt.Error", "P136ComError"), $p136Com = ""
Global $p136Config = 0, $p136Keys = ObjCreate("Scripting.Dictionary"), $p136Protocol = 0
Global $p136SetWnd = 0, $p136Fields[16], $p136Profile = 1, $p136Loading = False
Global $p136Http = 0, $p136HttpClock = 0, $p136HttpMode = "", $p136HttpConfig = 0
Global $p136ModelWnd = 0, $p136ModelRows[10], $p136Models[0], $p136ModelPage = 0, $p136ModelLabel = 0
Global $p136TransWnd = 0, $p136TransFields[12], $p136Pid = 0, $p136Dest = "", $p136Log = "", $p136Cancel = ""
Global $p136ProgressWnd = 0, $p136Phase = 0, $p136Bar = 0, $p136Detail = 0, $p136View = 0, $p136Handle = 0
Global $p136LastSeq = -1, $p136LastPct = -999, $p136LastMode = -1, $p136Clock = TimerInit()
Global $p136LastPhase = "", $p136LastDetail = "", $p136DeleteDialog = 0
Global $p136UrlWnd = 0, $p136UrlInput = 0, $p136State = "", $p136Language = "", $p136Cache = 0
Global $p136Comments = True, $p136Toc = True, $p136Index = False, $p136Hhp = True, $p136Lcid = 1028
Global $p136FileNo = 0, $p136FileTotal = 0, $p136Item = "", $p136ApiCalls = 0, $p136Hits = 0, $p136Error = ""
Global $p136LastRequest = 0, $p136CancelRequested = False, $p136Fatal = False
Global Const $p136Protocols = "OpenAI 相容 Chat Completions|Google Gemini generateContent|Anthropic Messages|Azure OpenAI（api-key）|Google 翻譯（免費，免 Key）"
Global Const $p136Providers = "自訂相容 API|OpenAI|Google Gemini|Anthropic|Azure OpenAI|DeepSeek|xAI|Mistral|OpenRouter|Groq|Perplexity|Qwen|Moonshot|智譜|Ollama（本機）|LM Studio（本機）|Google 翻譯（免費機器翻譯）"
Global Const $p136Languages = "繁體中文（臺灣）|簡體中文|English|日本語|한국어|Deutsch|Français|Español|Português（Brasil）|Русский|Tiếng Việt|ไทย|Bahasa Indonesia|Italiano|自訂語言"
Global $p136SegRaw[64], $p136SegKind[64], $p136SegName[64], $p136SegN = 0, $p136Mode = 0, $p136Out = ""
Global $p136Need = 0, $p136Bad = 0, $p136CacheHandle = -1, $p136ErrHandle = -1, $p136Failed = 0
Global $p136cQuote = "", $p136cStarted = False, $p136cComment = False, $p136cBlock = False, $p136cBlockNext = False, $p136cLast = ""
Global $p136Engine = "", $p136LangCode = "", $p136GoogleJson = False

; ---------------------------------------------------------------------------
; 網頁翻譯目的語言與右鍵選單（HH_AISettingsUI／HH_WebMenu）
; ---------------------------------------------------------------------------
Global $gWebLangName = "繁體中文（臺灣）", $gWebLangCode = "zh-TW", $gWebLangIndex = 0, $gWebLangWnd = 0, $gWebLangFields[4]
Global $gWebMenuPending = -1, $gWebMenuClock = TimerInit()
Global $gWebContextMenu = 0

; ---------------------------------------------------------------------------
; 主視窗與 WebView（HH_Window）
; ---------------------------------------------------------------------------
Global $gWnd = 0, $gWeb = 0, $gStatus = 0, $gBrowserMode = False, $gPdfMode = False
Global $gOpenMenu = 0, $gZoomMenu = 0
Global $gTabSources[0], $gPendingDropPath = "", $gToolbarIds[8]
Global $gLastWidth = 0, $gLastHeight = 0, $gResizeClock = TimerInit()
Global $gMenuHidden = False, $gMenuClock = TimerInit()
Global Const $HH_WM_SYSCOMMAND = 0x0112, $HH_WM_SIZE = 0x0005
Global Const $HH_SC_MINIMIZE = 0xF020, $HH_SIZE_RESTORED = 0, $HH_SIZE_MINIMIZED = 1
Global $gHHWebHiddenForMinimize = False

; ---------------------------------------------------------------------------
; 左側設定抽屜（HH_Window）
; 動畫期間（$gDrawerAnimationMs）主迴圈會暫停重工作，避免卡頓。
; ---------------------------------------------------------------------------
Global $gDrawerAnimationMs = 420, $gDrawerOpen = False, $gSettingsDrawer = 0, $gDrawerControls[12], $gDrawerStateClock = TimerInit(), $gDrawerTransitionClock = TimerInit(), $gDrawerSyncPending = False, $gWindowStateClock = TimerInit(), $gDrawerResizePending = False

; ---------------------------------------------------------------------------
; 單一執行個體與啟動開檔（HH_Instance）
; ---------------------------------------------------------------------------
Global Const $HH_INST_FILE = @TempDir & "\HtmlHelper_instance.dat"
Global $gInstToken = "", $gInstMutex = 0, $gInstWritten = False
Global $gStartupOpen = "", $gStartupClock = TimerInit(), $gRemoteOpen = ""

; ---------------------------------------------------------------------------
; 本機 HTTP 服務與待開啟的網址（HH_Http／HH_OpenFiles）
; ---------------------------------------------------------------------------
Global $gRoot = "", $gTemp = "", $gServer = -1, $gPort = 0, $gIndex = ""
Global $gPendingUrl = "", $gPendingTabId = 0, $gRetry = 0
Global $gDropSources[0], $gDropIds[0]

; ---------------------------------------------------------------------------
; 開檔、資料夾掃描與舊版解包（HH_OpenFiles）
; ---------------------------------------------------------------------------
Global $gTextPaths[0], $gBrowserTabs = 0, $gNewTabButton = 0, $gCloseTabButton = 0, $gTabClock = 0
Global $gExtractHandle = 0, $gExtractCommand = "", $gExtractPollClock = TimerInit(), $gScanTempParent = ""
Global Const $gDiagnostic = @ScriptDir & "\Html_Helper_Extract.log"
Global $gExtractPid = 0, $gExtractTemp = "", $gExtractStarted = 0, $gExtractLastCount = -1, $gExtractStableClock = 0
Global $gBusy = False, $gBusyTitle = "", $gBusyClock = TimerInit(), $gBusyFrame = -1
Global $gScanActive = False, $gScanRoot = "", $gScanRemember = True, $gScanQueue[1], $gScanHead = 0, $gScanTail = 0, $gScanCount = 0
Global $gScanFromChm = False

; ---------------------------------------------------------------------------
; 閱讀器頁面與目錄（HH_Reader）
; ---------------------------------------------------------------------------
Global $gPageFiles[0], $gPageNames[0]
Global $gTocHtml = "", $gKeywordHtml = "", $gDefaultTopic = ""
Global $gRequestedPage = "", $gAppFont = "Microsoft JhengHei", $gAppSize = 14, $gZoom = 100, $gSideWidth = 310

; ---------------------------------------------------------------------------
; 虛擬 CHM、快取與效能紀錄（HH_VChm）
; $gChmCharsetMode：內文編碼；$gChmSidebarModes：每份 CHM 左側目錄各自的解碼方式。
; ---------------------------------------------------------------------------
Global $gVChmPaths[0], $gVChmEntries[0], $gVChmIndexes[0], $gVChmHomes[0], $gVChmStamps[0], $gVChmExe = "", $gVChmSeq = 0
Global $gVChmTocFiles[0], $gVChmKeyFiles[0], $gVChmKeyHtml[0], $gVChmFileHtml[0], $gIndexLazy = False
Global $gProcClock = TimerInit(), $gPerfClock = TimerInit(), $gPerfId = 0, $gPerfStage = 0
Global $gVChmDocs = ObjCreate("Scripting.Dictionary"), $gVChmDocUse = ObjCreate("Scripting.Dictionary"), $gVChmIdleClock = TimerInit()
Global $gChmCharsetMode = 0 ; 內文編碼
Global $gChmSidebarModes[0] ; 每份 CHM 左側目錄獨立編碼
Global $gChmSidebarDecodeMode = 0

; ---------------------------------------------------------------------------
; 分頁（HH_Tabs）
; $g133Tab*：自繪方形分頁；$gTabOrder：拖曳排序後的顯示順序；$gHH92ClosedUrls：最近關閉的網站（只存在記憶體）。
; ---------------------------------------------------------------------------
Global $gTabOrder[0], $g133DragTid = 0, $g133DragX = 0, $g133Dragging = False
Global $g133TabButtons[32], $g133TabIds[32], $g133TabLeft[32]
Global $g133TabTexts[32], $g133TabBars[32], $g133TabHover = -1, $g133TabActive = 0, $g133LeftHeld = False, $g133LeftSlot = -1, $g133HoverClock = TimerInit()
Global $g133TabCount = 0, $g133TabFirst = 0, $g133TabWidth = 0, $g133TabDown = 0, $g133TabSignature = "", $g133TabClock = TimerInit()
Global $gTabPrevButton = 0, $gTabNextButton = 0
Global $gHHShortcutLatch = "", $gHHMouseBackHeld = False, $gHHMouseForwardHeld = False
Global $gHH92ClosedUrls[0], $gHH92RestoreMax = 15
Global $gHH95DownX = -1, $gHH95DownY = -1

; ---------------------------------------------------------------------------
; 網址列與導覽（HH_Navigation）
; ---------------------------------------------------------------------------
Global $gHistoryBack = False, $gHistoryForward = False, $gBackButton = 0, $gNextButton = 0
Global $gAddressEnterClock = TimerInit(), $gAddressEditHold = False, $gAddressLastShown = "", $gAddressTabId = 0

; ---------------------------------------------------------------------------
; 中鍵開新分頁（HH_LinkPolicy）
; ---------------------------------------------------------------------------
Global $gHHLinkTabQueue[0], $gHHLinkPolicyClock = TimerInit()
Global $gHHLinkLastUrl = "", $gHHLinkLastClock = TimerInit()
Global $gHH90HitPending = False, $gHH90HitReq = 0, $gHH90HitClock = TimerInit(), $gHH90HitTab = 0
Global $gHH89MiddleHeld = False
Global $gHH88RestoreTab = 0, $gHH88RestoreClock = TimerInit()
Global $gHH91Due = False, $gHH91Clock = TimerInit(), $gHH91Req = 0, $gHH91Tab = 0, $gHH90PressContent = False

; ---------------------------------------------------------------------------
; 網頁 AI 翻譯（HH_TranslateAI）
; 整頁翻譯槽位狀態：0 閒置／1 擷取／2 等待回應／3 延遲重送／4 套用中。
; ---------------------------------------------------------------------------
Global $gAiKey = "", $gAiEndpoint = "", $gAiModel = "", $gAiRequest = 0
Global $gAiPaused = False, $gAiProgressClock = TimerInit()
Global $gAiPageMode = False, $gAiPageRequest = 0, $gAiPageBatchCount = 0, $gAiPageNodeCount = 0, $gAiPageSkipped = 0, $gAiPageTotal = 0, $gAiPagePosition = 0
Global $gAiHttp = 0, $gAiPendingText = "", $gAiPendingRetry = False, $gAiPendingGemini = False, $gAiRequestClock = 0
Global $gAiBusyRetryCount = 0, $gAiBusyRetryClock = 0, $gAiBusyRetryDelay = 0, $gAiBusyRetryText = ""
Global Const $HH_AI_MAXPAR = 8
Global $gAiSlotState[8], $gAiSlotHttp[8], $gAiSlotId[8], $gAiSlotText[8], $gAiSlotClock[8], $gAiSlotRetry[8], $gAiSlotDelay[8], $gAiSlotReq[8], $gAiSlotGemini[8], $gAiSlotModelTry[8]
Global $gAiPageCfg = 0, $gAiPar = 3, $gAiPageItems = 20, $gAiPageChars = 5000, $gAiPageDelay = 0, $gAiPageTimeout = 120000
Global $gAiTaking = 0, $gAiTakeSlot = -1, $gAiTakeReset = False, $gAiExhausted = False, $gAiRetryPass = False, $gAiLastTake = 0
Global $gTrNotifyId = 0, $gTrNotifyClock = 0

; ---------------------------------------------------------------------------
; 網頁 Google 翻譯（HH_TranslateGoogle）
; ---------------------------------------------------------------------------
Global $gGoogleHttp = 0, $gGoogleClock = 0
Global $gGooglePageMode = False, $gGooglePageRequest = 0, $gGooglePageDone = 0, $gGooglePageCache = ObjCreate("Scripting.Dictionary"), $gGooglePageSource = ""
Global $gGooglePageFailures = 0, $gGooglePageRetryAt = 0, $gGooglePageRetryText = ""
Global $gGoogleCacheHits = 0, $gGooglePageTotal = 0, $gGoogleProgressClock = 0
Global $gGoogleAppliedCount = 0 ; 實際成功套用的節點數
Global $gGoogleBatchCount = 1, $gGoogleBatchSep = "【HH_TRANSLATE_SPLIT_9F3C】", $gGoogleBatchFallback = False

; ---------------------------------------------------------------------------
; QR Code（HH_QR）
; ---------------------------------------------------------------------------
Global $gQRInitialContent = "", $gQRHasImage = False
; 待儲存的 QR PNG（由 HTTP 接收，主迴圈開啟存檔視窗）
Global $gQRSaveData = Binary(""), $gQRSaveName = ""

; ---------------------------------------------------------------------------
; CHM 解包／打包的 GUI 流程（HH_ChmJobUI）
; ---------------------------------------------------------------------------
Global $g133JobPid = 0, $g133JobDest = "", $g133JobLog = "", $g133PollClock = TimerInit(), $g133ParentPtr = 0, $g133ParentHandle = 0
Global $g133ProgressWnd = 0, $g133ProgressPhase = 0, $g133ProgressBar = 0, $g133ProgressDetail = 0, $g133LastSeq = -1, $g133LastPct = -99, $g133LastMode = -1, $g133LastPhase = "", $g133LastDetail = ""
Global $g135Flow = 0, $g135Next = "", $g135Dialog = 0, $g135Retry = "", $g135DialogClock = TimerInit()
Global $g135Clipboard = ObjCreate("Scripting.Dictionary")

; ---------------------------------------------------------------------------
; 命令列說明視窗（HH_CliHelp）
; ---------------------------------------------------------------------------
Global $gDrawerSpacer = 0, $gCliHelpWnd = 0, $gCliHelpCmds[10], $gCliHelpButtons[10], $gCliHelpCount = 0
Global Const $HH_CLI_CODE_LINES = 6, $HH_CLI_NOTE_LINES = 7
Global $gCliHelpDescs[10], $gCliHelpNotes[10], $gCliHelpTitles[10], $gCliHelpPage = 0, $gCliHelpCopyBtn = 0, $gCliHelpTitle = 0
Global $gCliHelpDesc[2], $gCliHelpCode[$HH_CLI_CODE_LINES], $gCliHelpNote[$HH_CLI_NOTE_LINES], $gCliHelpCodeCols = 80, $gCliHelpNoteCols = 90

; ---------------------------------------------------------------------------
; 外觀：主題、字型、子視窗（HH_Settings）
; $gStyleEpoch：外觀版本，其他分頁切換過去時依此補套用。
; ---------------------------------------------------------------------------
Global $gThemeMode = $AUI_THEME_LIGHT, $gThemeClock = TimerInit(), $gAppliedTheme = -1
Global $gStyleEpoch = 0, $gTabStyleEpoch = ObjCreate("Scripting.Dictionary"), $gStyleClock = TimerInit()
Global $gChildFontWnd[0], $gChildFontId[0], $gChildFontBusy = False
Global $gAppearancePending = False, $gAppearanceClock = TimerInit(), $gAppearanceBusy = False
Global Const $HH_SYMBOL_FONT = "Segoe UI Symbol"
Global $gSettingsWnd = 0, $gSettingThemeInput = 0, $gSettingContentThemeInput = 0, $gContentTheme = 0, $gAboutWnd = 0
Global $gSideFont = "Microsoft JhengHei", $gSideSize = 14, $gContentFont = "Microsoft JhengHei", $gContentSize = 14
Global Const $HH_DEFAULT_FONT = "Microsoft JhengHei"
Global $gSettingFontBtn[4] = [0, 0, 0, 0]

; ---------------------------------------------------------------------------
; 字型選擇視窗（HH_FontPicker）
; ---------------------------------------------------------------------------
Global $gFontWin = 0, $gFontTree = 0, $gFontFilter = 0, $gFontSizeCombo = 0, $gFontSample = 0, $gFontPickInfo = 0, $gFontSampleLines[4] = [0, 0, 0, 0]
Global $gFontTarget = 1, $gFontPickFamily = "", $gFontPickSize = 14, $gFontPickBad = False, $gFontFilterText = ""
Global $gFontList[1], $gFontListCount = 0, $gFontNodeNames[1], $gFontNodeCount = 0, $gDWDll = -1
Global $gFontApplyTarget = 0, $gFontApplyFamily = "", $gFontApplySize = 14
Global $gFontPreviewDue = False, $gFontPreviewClock = TimerInit()
Global $gFontSizeChoices = "5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|28|30|32|36|40"

; ---------------------------------------------------------------------------
; 回呼佇列（HH_Core）
; AUI 回呼只排入佇列，由主迴圈執行，避免在回呼內重入造成死當。
; ---------------------------------------------------------------------------
Global $gHHQ[96][4], $gHHQHead = 0, $gHHQTail = 0
