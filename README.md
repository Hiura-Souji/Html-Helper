# Html Helper

CHM／HTML／PDF／文字檔閱讀器，使用 AUI 介面與 WebView2 顯示。同一個 EXE 兼具：

- **閱讀**：不解包直接開啟 CHM，分頁瀏覽，支援目錄、索引與全頁面清單
- **CHM 工具**：完整解包（保留原始檔名）、重新打包並逐檔驗證
- **翻譯**：網頁內 AI／Google 翻譯，以及整份 CHM／資料夾翻譯（保留結構與程式碼）
- **QR Code 樣式工坊**：17 種點陣造型、7 種定位框、Logo、透明 PNG

版本 1.0.0.0　｜　© 2026 [格雷資訊 grayfree.tw](https://www.grayfree.tw/)　｜　Unlicense

---

## 系統需求

| 項目 | 說明 |
|---|---|
| 作業系統 | Windows 10／11 |
| WebView2 Runtime | 必要（Windows 11 已內建） |
| HTML Help Workshop（`hhc.exe`） | 僅「打包成 CHM」需要 |
| 7-Zip | 選用。CHM 無法以 ITSS 讀取時的備援 |

### 從原始碼編譯

- AutoIt 3.3.16 以上（開發環境為 3.3.18）
- `Inc\` 需放置：`AUI.au3`、`_Ini.au3`、`ITSS.au3`、`HHQRCodeEmbedded.au3`
- 以 32 位元編譯（`#AutoIt3Wrapper_UseX64=n`），QR 點陣產生使用 32 位元 DLL

---

## 閱讀

### 支援的格式

| 類型 | 開啟方式 |
|---|---|
| `.chm` | 直接讀取，不解包到硬碟 |
| 資料夾 | 掃描其中的 HTML，讀取 `.hhp`／`.hhc`／`.hhk` 建立目錄與索引 |
| `.htm` `.html` 圖片 影音 | 單檔顯示，相對路徑資源正常載入 |
| `.pdf` | WebView2 內建 PDF 檢視器 |
| 程式碼與文字檔 | 純文字檢視（`.au3` `.py` `.js` `.json` `.md` `.log` 等） |
| 網址 | 一般網頁瀏覽 |

可從「開啟 ▼」選單、網址列、拖放到視窗或命令列開啟。網址列也接受 `檔案.chm::/內頁路徑`。

### CHM 閱讀

- 左側有三個分頁：**目錄**、**索引**、**所有頁面**，上方可篩選
- 開檔時只讀目錄；**索引**與**所有頁面**在第一次點選時才載入
- 解析結果寫入磁碟快取。同一份 CHM 再開（包括關掉程式再開）約 0.15 秒即可顯示
- 側欄寬度可拖曳調整
- 右鍵選單可切換 **CHM 內文編碼** 與 **左側欄編碼**（自動／UTF-8／Big5／GB18030），用於舊版 CHM 亂碼

### 分頁與快捷鍵

| 操作 | 功能 |
|---|---|
| `Ctrl+T` | 新分頁 |
| `Ctrl+W` | 關閉分頁 |
| `Ctrl+Shift+T` | 重新開啟最近關閉的網站分頁（最多 15 筆） |
| `Ctrl+Tab`／`Ctrl+PgDn` | 下一個分頁 |
| `Ctrl+Shift+Tab`／`Ctrl+PgUp` | 上一個分頁 |
| `Ctrl+1`～`Ctrl+8` | 切到第 N 個分頁 |
| `Ctrl+9` | 切到最後一個分頁 |
| 滑鼠側鍵 | 上一頁／下一頁 |
| 中鍵點連結 | 在背景開新分頁 |
| 中鍵點分頁 | 關閉分頁 |
| 拖曳分頁 | 調整順序 |

同一份檔案已經開過時，會直接切到該分頁。程式已在執行時，從檔案總管開啟的檔案會開在同一視窗的新分頁。

### 外觀設定

左側「☰」抽屜 →「設定」：

- **軟體介面**、**左側導航**、**文件內文**三組字型與大小各自獨立。字型清單以 DirectWrite 列舉，列出的都能使用
- **主題**：亮色／暗色／自動（跟隨 Windows）
- **文件內容配色**：維持原樣／暗黑模式／高亮模式，與軟體主題分開設定
- **註冊為預設程式**：寫入 `HKCU64`，再開啟 Windows「預設應用程式」設定確認；「還原」會移除所有註冊

---

## 網頁翻譯

在頁面上按右鍵：

| 選項 | 說明 |
|---|---|
| AI 翻譯選取文字 | 結果以對話框顯示，可複製 |
| AI 翻譯本頁 | 同時送出多個請求，失敗的批次自動補翻一次 |
| AI 還原原文 | 還原整頁翻譯 |
| Google 翻譯選取文字／本頁 | 免費、免 Key。結果永久快取；目的語言為繁中時會改用台灣用語 |
| 停止整頁翻譯 | 已翻譯的部分保留 |
| 翻譯目的語言… | 14 種語言或自訂 |

只翻譯可見文字，程式碼區塊、函式名稱、`$變數`、`@巨集` 與網址都保持原樣。

### AI API 設定

左側「☰」抽屜 →「AI API 設定」。可建立多組設定檔，翻譯時使用「使用中」的那一組。

- **支援通道**：OpenAI 相容、Google Gemini、Anthropic、Azure OpenAI、Google 翻譯（免費）
- **內建範本**：OpenAI、Gemini、Anthropic、Azure、DeepSeek、xAI、Mistral、OpenRouter、Groq、Perplexity、Qwen、Moonshot、智譜、Ollama、LM Studio
- **API Key 保存方式**：以 Windows DPAPI 加密保存（只有同一個 Windows 帳號能解密），或只用於本次執行、不寫入設定檔
- 可**測試連線**，可從清單**選擇模型**
- 可調整溫度、每批段數與字元上限、同時請求數、請求間隔、逾時

---

## 整份 CHM／資料夾翻譯

左側「☰」抽屜 →「AI 翻譯 CHM／資料夾」：

- **來源**：已解包的資料夾或 `.chm`（CHM 會先自動解包）
- **引擎**：AI（使用中的設定檔）或 Google 翻譯（免費）
- **選項**：是否翻譯程式碼註解（`;` `//` `#cs…#ce`）、目錄、索引、HHP 標題
- 資料夾結構與非文字檔逐位元組複製，HTML 以原編碼寫回
- 中斷後以相同設定再執行即可續譯。狀態與快取存在 `輸出資料夾.hhtrans\`
- 保留原文的段落列在 `輸出資料夾.hhtrans\errors.txt`
- 輸出資料夾可直接用「將資料夾打包成 CHM」重新打包

---

## CHM 解包與打包

「開啟 ▼」選單：

- **ITSS 完整匯出 CHM**：匯出所有內部檔案，包括 `#` 與 `$` 開頭的特殊項目。無法當作 Windows 檔名的字元會轉碼，並寫出對照表 `__htmlhelper_manifest.tsv`；沒有 HHP 的 CHM 會依中繼資料重建 HHP、MAP、ALIAS 與還原報告
- **將資料夾打包成 CHM**：還原原始檔名、保留原 HHP 設定，以 `hhc.exe` 編譯後逐檔比對 SHA-256，並驗證目錄與索引。驗證失敗不會產生輸出檔，也不會覆寫已存在的檔案

缺少的中繼資料只回報、不臆造。

---

## 命令列

```bat
:: 開啟（程式已在執行時開在新分頁）
Html_Helper.exe "D:\Docs\AutoIt.chm"
Html_Helper.exe "D:\Docs\AutoIt.chm" "html/functions/MsgBox.htm"

:: 解包
Html_Helper.exe --extract-chm "D:\Docs\AutoIt.chm" "D:\Work\AutoIt_src"

:: 打包
Html_Helper.exe --build-chm "D:\Work\AutoIt_src" "D:\Work\AutoIt_new.chm"
Html_Helper.exe --build-chm "D:\Work\AutoIt_src" "D:\Work\AutoIt_new.chm" --compiler "C:\Program Files (x86)\HTML Help Workshop\hhc.exe" --home "html\index.htm" --project "AutoIt.hhp"

:: 翻譯
Html_Helper.exe --translate-chm "D:\Docs\AutoIt.chm" "D:\Work\AutoIt_zh" --profile 1 --lang "繁體中文（臺灣）" --lcid 1028 --comments 1 --toc 1 --index 0 --hhp 1
Html_Helper.exe --translate-chm "D:\Work\AutoIt_src" "D:\Work\AutoIt_zh" --engine google --code zh-TW

:: 顯示所有參數
Html_Helper.exe --help
```

| 參數 | 說明 |
|---|---|
| `--compiler` | `hhc.exe` 路徑（未指定時自動尋找） |
| `--home` | 首頁，相對於來源資料夾 |
| `--project` | 指定 `.hhp`（來源有多個 HHP 時必填） |
| `--profile` | AI 設定檔編號（預設為使用中） |
| `--lang` | 目標語言名稱 |
| `--lcid` | 輸出 CHM 語系（1028＝繁體中文） |
| `--comments` `--toc` `--index` `--hhp` | `1`／`0`：是否翻譯註解、目錄、索引、專案標題 |
| `--engine` | `ai` 或 `google` |
| `--code` | Google 語言代碼，例如 `zh-TW`、`ja`、`en` |

輸出路徑必須是不存在或空白的資料夾；打包時輸出檔已存在則不覆寫。

批次檔請用 `start /wait "" Html_Helper.exe …`，結束後再檢查 `%ERRORLEVEL%`。

### 結束代碼

| 代碼 | 意義 |
|---|---|
| 0 | 成功 |
| 2 | 參數錯誤 |
| 3 | CHM 無法開啟 |
| 4 | 讀取失敗 |
| 5 | 輸出資料夾不可用 |
| 10 | 來源／專案錯誤 |
| 11 | 找不到 `hhc.exe` |
| 12 | 工作區錯誤 |
| 13 | 編譯失敗 |
| 14 | 新 CHM 驗證失敗 |
| 15 | 無法輸出 |
| 20 | 使用者停止（已完成的檔案與快取保留） |
| 21 | 完成，但部分段落保留原文（見 `errors.txt`） |
| 30 | AI API 停止（Key 無效、額度用完等） |

每次執行的紀錄寫在 `<輸出路徑>.<PID>.log`。

---

## QR Code 樣式工坊

右鍵「網址 QR Code」以目前網址產生，或從左側「☰」抽屜 →「建立 QR Code」輸入任意內容（網址、文字、Wi-Fi、聯絡資訊）。

- **點陣造型 17 種**：方塊、圓角、平滑相連、圓點、泡泡、馬賽克、菱形、六角形、十字、星芒、愛心、葉片、水平線、垂直線、膠囊、流體、地鐵線
- **定位框 7 種**，外框與中心可分別上色
- **配色**：單色或漸層（斜向、反斜向、垂直、水平、放射），背景色或透明背景；另有 14 組快速主題
- **Logo**：選擇或按 `Ctrl+V` 貼上；可自動裁掉透明邊；底框可選圓角方形、圓形或無底框，並調整大小與留白
- **版面**：四周留白、底部標籤文字；輸出 512／1024／2048 px
- **輸出**：儲存 PNG、儲存透明 PNG（由程式的「另存新檔」視窗儲存）、複製圖片

定位框、時序線與校正圖案維持完整結構。Logo 遮住面積、配色對比或點陣過細有風險時會提示；請以手機實際掃描確認。

---

## 程式產生的檔案

| 位置 | 內容 |
|---|---|
| `Html_Helper.ini`（程式旁） | 顯示設定、最近開啟、AI 設定檔（Key 為 DPAPI 加密）、翻譯語言、QR 儲存位置 |
| `%LOCALAPPDATA%\HtmlHelper\chmcache\` | CHM 目錄、索引與檔案清單快取（保留最近 40 份，CHM 變更時自動失效） |
| `%LOCALAPPDATA%\HtmlHelper\gcache\` | Google 翻譯快取 |
| `Html_Helper_Perf.log`（程式旁） | CHM 開檔各階段耗時 |
| `Html_Helper_Extract.log`（程式旁） | 舊版 CHM 解包流程的診斷紀錄 |
| `%TEMP%\HtmlHelper_instance.dat` | 單一執行個體的連線資訊（程式結束時刪除） |
| 開始功能表 `Html Helper.lnk` | 工作列跳躍清單需要的捷徑 |

所有快取都可以直接刪除，下次使用時會重新建立。

---

## 原始碼結構

```
Html_Helper.au3              啟動流程、主視窗建立、主迴圈
Inc\HH\
  HH_Globals.au3             全域變數（依模組分組）
  HH_Core.au3                回呼佇列、WebView 腳本、字串／URL／編碼工具
  HH_Dialogs.au3             對話框與翻譯通知
  HH_Window.au3              主視窗、工具列選單、設定抽屜、最小化、結束清理
  HH_Instance.au3            單一執行個體、工作列、跳躍清單
  HH_Http.au3                127.0.0.1 本機 HTTP 服務
  HH_OpenFiles.au3           開檔流程、資料夾掃描、舊版解包
  HH_Reader.au3              閱讀器頁面（側欄目錄／索引＋內文）
  HH_VChm.au3                虛擬 CHM、磁碟快取、效能紀錄
  HH_Tabs.au3                自繪分頁列、分頁切換與快捷鍵
  HH_Navigation.au3          網址列、上一頁／下一頁／首頁
  HH_LinkPolicy.au3          中鍵開新分頁
  HH_WebMenu.au3             網頁右鍵選單
  HH_TranslateAI.au3         網頁 AI 翻譯
  HH_TranslateGoogle.au3     網頁 Google 翻譯
  HH_QR.au3                  QR 點陣產生與 PNG 儲存
  HH_QRDesigner.au3          QR 樣式工坊頁面
  HH_Settings.au3            軟體設定、關於、檔案關聯
  HH_FontPicker.au3          字型選擇視窗
  HH_CliHelp.au3             命令列說明視窗
  HH_ChmPack.au3             CHM 解包／打包核心
  HH_ChmProject.au3          HHP 處理與重建
  HH_ChmJobUI.au3            解包／打包的 GUI 流程
  HH_AIConfig.au3            AI 設定檔、API Key 加密、請求組裝
  HH_AISettingsUI.au3        AI 設定、目的語言、開啟網址視窗
  HH_TranslateJobUI.au3      整份翻譯的 GUI
  HH_TranslateEngine.au3     整份翻譯引擎（命令列）
  HH_TranslateHtml.au3       HTML／目錄／專案的翻譯切分與寫回
```

所有全域變數集中在 `HH_Globals.au3`，各模組只放函式。

**本機服務**：閱讀器透過 `127.0.0.1:19860`～`19899` 的本機服務提供 CHM 內容，只接受本機連線，並禁止路徑穿越。
