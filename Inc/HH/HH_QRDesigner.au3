#include-once
; =============================================================================
; Html Helper － QR 樣式工坊頁面
;
; QR 工坊的完整 HTML／CSS／JS（離線 Canvas 繪製）。
; 下拉選單與色彩選擇為網頁自繪，避免 WebView2 原生彈出視窗在視窗移動後跑位。
;
; 本檔只包含函式；全域變數集中宣告在 HH_Globals.au3。
; =============================================================================

; ---------------------------------------------------------------------------
; QR Code 樣式工坊頁面（離線 Canvas 繪製）。
; 下拉選單與色彩選擇改用網頁自繪：WebView2 的 <select>／色盤是原生彈出視窗，
; AUI 視窗最大化或移動後彈出位置會沿用舊座標而跑位。
; ---------------------------------------------------------------------------
Func HH_QR_DesignerHtml()
    Local Static $s = ""
    If $s <> "" Then Return $s
    $s &= "<!doctype html>" & @LF
    $s &= "<html lang=""zh-Hant"">" & @LF
    $s &= "<head>" & @LF
    $s &= "<meta charset=""utf-8"">" & @LF
    $s &= "<meta name=""viewport"" content=""width=device-width,initial-scale=1"">" & @LF
    $s &= "<title>QR Code 樣式工坊</title>" & @LF
    $s &= "<style>" & @LF
    $s &= "*{box-sizing:border-box}" & @LF
    $s &= "body{margin:0;background:linear-gradient(145deg,#111827,#253451);color:#edf3ff;font:14px ""Microsoft JhengHei"",sans-serif;min-height:100vh}" & @LF
    $s &= "main{display:grid;grid-template-columns:minmax(300px,460px) minmax(320px,1fr);gap:24px;max-width:1200px;margin:20px auto;padding:20px}" & @LF
    $s &= ".tools,.preview{background:#ffffff0d;border:1px solid #ffffff24;border-radius:20px;padding:22px;box-shadow:0 16px 48px #0003}" & @LF
    $s &= ".tools h2{margin:0 0 6px;font-size:23px}" & @LF
    $s &= ".sub{color:#b4c8e8;margin-bottom:14px}" & @LF
    $s &= ".section{font-size:12px;color:#9cc5fa;letter-spacing:1px;margin:22px 0 9px;font-weight:bold}" & @LF
    $s &= ".field{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:10px 0;min-height:36px}" & @LF
    $s &= ".field>.lab{flex:none}" & @LF
    $s &= ".field>.ctl{width:60%;display:flex;align-items:center;justify-content:flex-end;gap:8px}" & @LF
    $s &= ".ctl input[type=range]{flex:1;accent-color:#86b4ff;cursor:pointer}" & @LF
    $s &= ".ctl .val{width:42px;text-align:right;color:#b8c7df}" & @LF
    $s &= ".ctl input[type=checkbox]{accent-color:#7baaff;width:18px;height:18px;cursor:pointer}" & @LF
    $s &= ".ctl input[type=text]{width:100%;background:#1e2a40;color:#fff;border:1px solid #50627e;border-radius:8px;padding:8px 10px;font:inherit}" & @LF
    $s &= ".logobox{display:flex;align-items:center;gap:12px;margin:10px 0;padding:12px;border:1.5px dashed #5a6f90;border-radius:12px;background:#ffffff08;transition:border-color .15s,background .15s}" & @LF
    $s &= ".logobox .thumb{width:56px;height:56px;flex:none;border-radius:10px;border:1px solid #ffffff30;background:repeating-conic-gradient(#ffffff1a 0 25%,transparent 0 50%) 0 0/12px 12px;display:flex;align-items:center;justify-content:center;overflow:hidden;color:#7f93b3;font-size:22px}" & @LF
    $s &= ".logobox .thumb img{max-width:100%;max-height:100%;display:block}" & @LF
    $s &= ".logobox .info{flex:1;min-width:0}" & @LF
    $s &= ".logobox .name{color:#edf3ff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}" & @LF
    $s &= ".logobox .meta{color:#8fa3c2;font-size:12px;margin-top:2px}" & @LF
    $s &= ".logobox .acts{display:flex;gap:6px;flex:none}" & @LF
    $s &= ".logobox .acts button{padding:7px 12px;font-size:13px}" & @LF
    $s &= ".logobox .acts .ghost{background:transparent;border-color:#5a6f90;color:#c9d6ea}" & @LF
    $s &= ".logobox .acts .ghost:hover{background:#ffffff14}" & @LF
    $s &= "#logo{display:none}" & @LF
    $s &= "textarea{width:100%;background:#1e2a40;color:#fff;border:1px solid #50627e;border-radius:8px;padding:10px;resize:vertical;font:inherit}" & @LF
    $s &= "button{padding:10px 16px;border:1px solid #779de4;border-radius:10px;background:#365ea7;color:#fff;cursor:pointer;font:inherit}" & @LF
    $s &= "button:hover{background:#4b77cb}" & @LF
    $s &= ".row{display:flex;gap:10px;flex-wrap:wrap;margin-top:10px}" & @LF
    $s &= ".presets{display:grid;grid-template-columns:repeat(auto-fill,minmax(92px,1fr));gap:8px}" & @LF
    $s &= ".presets button{font-size:12px;padding:8px 6px;display:flex;align-items:center;gap:6px;justify-content:center}" & @LF
    $s &= ".presets i{display:inline-block;width:14px;height:14px;border-radius:4px;flex:none}" & @LF
    $s &= ".preview{display:flex;flex-direction:column;align-items:center;gap:14px;position:sticky;top:16px;align-self:start}" & @LF
    $s &= "canvas{width:min(100%,480px);height:auto;border-radius:14px;box-shadow:0 16px 45px #0005;background:repeating-conic-gradient(#ffffff14 0 25%,transparent 0 50%) 0 0/20px 20px}" & @LF
    $s &= "small{line-height:1.8;color:#b8c7df}" & @LF
    $s &= "#status{color:#a9d5ff;text-align:center}" & @LF
    $s &= "#warn{color:#ffd28a;text-align:center;min-height:1.2em}" & @LF
    $s &= "/* 自繪下拉選單：不使用 WebView2 原生彈出視窗，避免位置跑掉 */" & @LF
    $s &= ".dd{position:relative;width:100%}" & @LF
    $s &= ".dd-btn{width:100%;text-align:left;background:#1e2a40;color:#fff;border:1px solid #50627e;border-radius:8px;padding:8px 30px 8px 10px;position:relative;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}" & @LF
    $s &= ".dd-btn:hover{background:#26344d}" & @LF
    $s &= ".dd-btn::after{content:""\25BE"";position:absolute;right:10px;top:50%;transform:translateY(-50%);opacity:.8}" & @LF
    $s &= ".dd-list{display:none;position:absolute;left:0;right:0;top:calc(100% + 4px);max-height:280px;overflow:auto;background:#1b2639;border:1px solid #5a6f90;border-radius:10px;box-shadow:0 12px 30px #0009;z-index:50;padding:4px}" & @LF
    $s &= ".dd.up .dd-list{top:auto;bottom:calc(100% + 4px)}" & @LF
    $s &= ".dd.open .dd-list{display:block}" & @LF
    $s &= ".dd-item{padding:7px 10px;border-radius:7px;cursor:pointer;white-space:nowrap}" & @LF
    $s &= ".dd-item:hover{background:#2f4566}" & @LF
    $s &= ".dd-item.sel{background:#365ea7}" & @LF
    $s &= "/* 自繪色彩選擇 */" & @LF
    $s &= ".cp .dd-btn{display:flex;align-items:center;gap:8px;padding-right:10px}" & @LF
    $s &= ".cp .dd-btn::after{content:none}" & @LF
    $s &= ".cp .sw{width:22px;height:22px;border-radius:6px;border:1px solid #ffffff55;flex:none}" & @LF
    $s &= ".cp .dd-list{left:auto;width:236px;padding:10px}" & @LF
    $s &= ".cp .grid{display:grid;grid-template-columns:repeat(8,1fr);gap:6px;margin-bottom:10px}" & @LF
    $s &= ".cp .grid div{width:22px;height:22px;border-radius:6px;border:1px solid #ffffff40;cursor:pointer}" & @LF
    $s &= ".cp .grid div:hover{outline:2px solid #fff}" & @LF
    $s &= ".cp .hexrow{display:flex;gap:6px}" & @LF
    $s &= ".cp .hexrow input{flex:1;min-width:0;width:0;background:#101827;color:#fff;border:1px solid #50627e;border-radius:6px;padding:6px 8px;font:13px Consolas,monospace}" & @LF
    $s &= ".cp .hexrow button{padding:6px 10px;font-size:12px;white-space:nowrap;flex:none}" & @LF
    $s &= "@media(max-width:820px){main{display:block}.preview{position:static;margin-top:20px}}" & @LF
    $s &= "</style>" & @LF
    $s &= "</head>" & @LF
    $s &= "<body>" & @LF
    $s &= "<main>" & @LF
    $s &= "<section class=""tools"">" & @LF
    $s &= "<h2>✦ QR Code 樣式工坊</h2>" & @LF
    $s &= "<div class=""sub"">17 種點陣造型、7 種定位框、獨立定位框配色、透明背景與標籤文字</div>" & @LF
    $s &= "" & @LF
    $s &= "<div class=""section"">QR 內容（不限網址）</div>" & @LF
    $s &= "<textarea id=""qrcontent"" rows=""3"" maxlength=""2000"" placeholder=""輸入網址、文字、Wi-Fi、聯絡資訊等""></textarea>" & @LF
    $s &= "<div class=""row""><button id=""updateqr"" type=""button"">更新 QR 內容</button></div>" & @LF
    $s &= "" & @LF
    $s &= "<div class=""section"">快速主題</div>" & @LF
    $s &= "<div class=""presets"" id=""presets""></div>" & @LF
    $s &= "" & @LF
    $s &= "<div class=""section"">點陣造型</div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">資料模組</span><div class=""ctl""><select id=""shape"">" & @LF
    $s &= "<option value=""square"">經典方塊</option>" & @LF
    $s &= "<option value=""soft"">圓角方塊</option>" & @LF
    $s &= "<option value=""smooth"">平滑相連（圓角輪廓）</option>" & @LF
    $s &= "<option value=""dot"">圓點</option>" & @LF
    $s &= "<option value=""bubble"">泡泡（大小錯落）</option>" & @LF
    $s &= "<option value=""mosaic"">馬賽克（大小錯落）</option>" & @LF
    $s &= "<option value=""diamond"">菱形</option>" & @LF
    $s &= "<option value=""hex"">六角形</option>" & @LF
    $s &= "<option value=""cross"">十字</option>" & @LF
    $s &= "<option value=""star"">星芒</option>" & @LF
    $s &= "<option value=""heart"">愛心</option>" & @LF
    $s &= "<option value=""leaf"">葉片</option>" & @LF
    $s &= "<option value=""lineH"">水平線條</option>" & @LF
    $s &= "<option value=""lineV"">垂直線條</option>" & @LF
    $s &= "<option value=""pill"">膠囊線條（相鄰連接）</option>" & @LF
    $s &= "<option value=""fluid"">流體連接</option>" & @LF
    $s &= "<option value=""metro"">地鐵線（點＋細線）</option>" & @LF
    $s &= "</select></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">模組飽滿度</span><div class=""ctl""><input type=""range"" id=""density"" min=""72"" max=""100"" value=""94""><span class=""val"" id=""dv"">94%</span></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">定位框造型</span><div class=""ctl""><select id=""finder"">" & @LF
    $s &= "<option value=""square"">經典方形</option>" & @LF
    $s &= "<option value=""round"">圓角框</option>" & @LF
    $s &= "<option value=""cushion"">柔圓方框</option>" & @LF
    $s &= "<option value=""circle"">圓環</option>" & @LF
    $s &= "<option value=""dotcenter"">方框＋圓心</option>" & @LF
    $s &= "<option value=""leaf"">葉片</option>" & @LF
    $s &= "<option value=""leafin"">方框＋葉片心</option>" & @LF
    $s &= "</select></div></div>" & @LF
    $s &= "" & @LF
    $s &= "<div class=""section"">色彩與背景</div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">主要顏色</span><div class=""ctl""><input type=""color"" id=""fg"" value=""#172b50""></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">漸層終點</span><div class=""ctl""><input type=""color"" id=""fg2"" value=""#497acb""></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">漸層方式</span><div class=""ctl""><select id=""gradient"">" & @LF
    $s &= "<option value=""none"">單色</option>" & @LF
    $s &= "<option value=""diagonal"">斜向漸層</option>" & @LF
    $s &= "<option value=""antidiag"">反斜向漸層</option>" & @LF
    $s &= "<option value=""vertical"">垂直漸層</option>" & @LF
    $s &= "<option value=""horizontal"">水平漸層</option>" & @LF
    $s &= "<option value=""radial"">放射漸層</option>" & @LF
    $s &= "</select></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">背景顏色</span><div class=""ctl""><input type=""color"" id=""bg"" value=""#ffffff""></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">透明背景（PNG）</span><div class=""ctl""><input type=""checkbox"" id=""transparent""></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">定位框自訂顏色</span><div class=""ctl""><input type=""checkbox"" id=""eyecustom""></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">定位框外框</span><div class=""ctl""><input type=""color"" id=""eyeout"" value=""#c0392b""></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">定位框中心</span><div class=""ctl""><input type=""color"" id=""eyein"" value=""#172b50""></div></div>" & @LF
    $s &= "" & @LF
    $s &= "<div class=""section"">版面、Logo 與輸出</div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">四周留白</span><div class=""ctl""><input type=""range"" id=""quiet"" min=""1"" max=""6"" value=""3""><span class=""val"" id=""qv"">3</span></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">底部標籤文字</span><div class=""ctl""><input type=""text"" id=""caption"" maxlength=""40"" placeholder=""例如：掃描開啟""></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">Logo 圖片</span></div>" & @LF
    $s &= "<div class=""logobox"" id=""logobox"">" & @LF
    $s &= "<div class=""thumb"" id=""logothumb"">＋</div>" & @LF
    $s &= "<div class=""info""><div class=""name"" id=""logoname"">尚未選擇</div><div class=""meta"" id=""logometa"">PNG／JPG／WebP，可按 Ctrl+V 貼上圖片</div></div>" & @LF
    $s &= "<div class=""acts""><button type=""button"" id=""logopick"">選擇圖片</button><button type=""button"" class=""ghost"" id=""logopaste"">貼上</button><button type=""button"" class=""ghost"" id=""logoclear"" style=""display:none"">移除</button></div>" & @LF
    $s &= "<input type=""file"" id=""logo"" accept=""image/png,image/jpeg,image/webp"">" & @LF
    $s &= "</div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">Logo 底框</span><div class=""ctl""><select id=""logoframe"">" & @LF
    $s &= "<option value=""round"">圓角方形</option>" & @LF
    $s &= "<option value=""circle"">圓形</option>" & @LF
    $s &= "<option value=""none"">無底框</option>" & @LF
    $s &= "</select></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">Logo 大小</span><div class=""ctl""><input type=""range"" id=""logosize"" min=""8"" max=""20"" value=""13""><span class=""val"" id=""ls"">13%</span></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">自動裁掉 Logo 透明邊</span><div class=""ctl""><input type=""checkbox"" id=""logotrim"" checked></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">Logo 留白</span><div class=""ctl""><input type=""range"" id=""logopad"" min=""0"" max=""30"" value=""6""><span class=""val"" id=""lp"">6%</span></div></div>" & @LF
    $s &= "<div class=""field""><span class=""lab"">輸出尺寸</span><div class=""ctl""><select id=""outsize"">" & @LF
    $s &= "<option value=""512"">512 px</option>" & @LF
    $s &= "<option value=""1024"">1024 px</option>" & @LF
    $s &= "<option value=""2048"">2048 px</option>" & @LF
    $s &= "</select></div></div>" & @LF
    $s &= "<div class=""row""><button id=""save"" type=""button"">儲存 PNG</button><button id=""savetrans"" type=""button"">儲存透明 PNG</button><button id=""copyimg"" type=""button"">複製圖片</button><button id=""reset"" type=""button"">重設樣式</button></div>" & @LF
    $s &= "<p><small>使用 Html Helper 產生的 QR 資料，離線重新繪製。定位框與校正圖案維持完整結構；過細的點陣、低對比配色或大型 Logo 會降低辨識率，請用手機實際掃描確認。</small></p>" & @LF
    $s &= "</section>" & @LF
    $s &= "" & @LF
    $s &= "<section class=""preview"">" & @LF
    $s &= "<canvas id=""canvas"" width=""512"" height=""512""></canvas>" & @LF
    $s &= "<div id=""status"">正在讀取 QR Code…</div>" & @LF
    $s &= "<div id=""warn""></div>" & @LF
    $s &= "<button id=""retryqr"" type=""button"" style=""display:none"">重新讀取 QR 圖片</button>" & @LF
    $s &= "<small>預覽即匯出內容 · PNG 無浮水印</small>" & @LF
    $s &= "</section>" & @LF
    $s &= "</main>" & @LF
    $s &= "" & @LF
    $s &= "<script>" & @LF
    $s &= "const $=id=>document.getElementById(id);" & @LF
    $s &= "const canvas=$(""canvas""),ctx=canvas.getContext(""2d"");" & @LF
    $s &= "let matrix=null,logo=null,qrReady=false;" & @LF
    $s &= "" & @LF
    $s &= "/* ---------- 自繪下拉選單與色彩選擇 ---------- */" & @LF
    $s &= "function closeAll(except){document.querySelectorAll("".dd.open"").forEach(d=>{if(d!==except)d.classList.remove(""open"",""up"")})}" & @LF
    $s &= "document.addEventListener(""click"",()=>closeAll());" & @LF
    $s &= "document.addEventListener(""keydown"",e=>{if(e.key===""Escape"")closeAll()});" & @LF
    $s &= "function openDD(wrap,btn){const r=btn.getBoundingClientRect();closeAll(wrap);const willOpen=!wrap.classList.contains(""open"");wrap.classList.toggle(""open"",willOpen);wrap.classList.toggle(""up"",willOpen&&innerHeight-r.bottom<300&&r.top>300);if(willOpen){const s=wrap.querySelector("".sel"");if(s)s.scrollIntoView({block:""nearest""})}}" & @LF
    $s &= "function fire(el){el.dispatchEvent(new Event(""input"",{bubbles:true}));el.dispatchEvent(new Event(""change"",{bubbles:true}))}" & @LF
    $s &= "function enhanceSelect(sel){" & @LF
    $s &= " sel.style.display=""none"";" & @LF
    $s &= " const wrap=document.createElement(""div""),btn=document.createElement(""button""),list=document.createElement(""div"");" & @LF
    $s &= " wrap.className=""dd"";btn.type=""button"";btn.className=""dd-btn"";list.className=""dd-list"";" & @LF
    $s &= " for(const o of sel.options){const it=document.createElement(""div"");it.className=""dd-item"";it.textContent=o.text;it.dataset.v=o.value;" & @LF
    $s &= "  it.addEventListener(""click"",e=>{e.stopPropagation();sel.value=o.value;closeAll();sel._sync();fire(sel)});list.appendChild(it)}" & @LF
    $s &= " btn.addEventListener(""click"",e=>{e.stopPropagation();openDD(wrap,btn)});" & @LF
    $s &= " list.addEventListener(""click"",e=>e.stopPropagation());" & @LF
    $s &= " wrap.append(btn,list);sel.after(wrap);" & @LF
    $s &= " sel._sync=()=>{const o=sel.options[sel.selectedIndex];btn.textContent=o?o.text:"""";list.querySelectorAll("".dd-item"").forEach(i=>i.classList.toggle(""sel"",i.dataset.v===sel.value))};" & @LF
    $s &= " sel._sync();" & @LF
    $s &= "}" & @LF
    $s &= "const PALETTE=[""#000000"",""#172b50"",""#0b3d91"",""#1565c0"",""#0277bd"",""#00838f"",""#00695c"",""#2e7d32"",""#558b2f"",""#9e9d24"",""#f9a825"",""#ef6c00"",""#d84315"",""#c62828"",""#ad1457"",""#6a1b9a"",""#4527a0"",""#283593"",""#37474f"",""#5d4037"",""#ffffff"",""#f5f5f5"",""#fff8e7"",""#fdecef"",""#e8f5e9"",""#e3f2fd"",""#ede7f6"",""#16b6b3"",""#ff5f6d"",""#ffc371"",""#c12edb"",""#7c4dff""];" & @LF
    $s &= "function enhanceColor(inp){" & @LF
    $s &= " inp.style.display=""none"";" & @LF
    $s &= " const wrap=document.createElement(""div""),btn=document.createElement(""button""),list=document.createElement(""div"");" & @LF
    $s &= " wrap.className=""dd cp"";btn.type=""button"";btn.className=""dd-btn"";list.className=""dd-list"";" & @LF
    $s &= " const sw=document.createElement(""span""),tx=document.createElement(""span"");sw.className=""sw"";btn.append(sw,tx);" & @LF
    $s &= " const grid=document.createElement(""div"");grid.className=""grid"";" & @LF
    $s &= " const set=v=>{v=v.toLowerCase();if(!/^#[0-9a-f]{6}$/.test(v))return false;inp.value=v;inp._sync();fire(inp);return true};" & @LF
    $s &= " PALETTE.forEach(c=>{const d=document.createElement(""div"");d.style.background=c;d.title=c;d.addEventListener(""click"",()=>{set(c);closeAll()});grid.appendChild(d)});" & @LF
    $s &= " const row=document.createElement(""div"");row.className=""hexrow"";" & @LF
    $s &= " const hex=document.createElement(""input"");hex.maxLength=7;hex.placeholder=""#RRGGBB"";" & @LF
    $s &= " const ok=document.createElement(""button"");ok.type=""button"";ok.textContent=""套用"";" & @LF
    $s &= " const apply=()=>{let v=hex.value.trim();if(v&&v[0]!==""#"")v=""#""+v;if(/^#[0-9a-fA-F]{3}$/.test(v))v=""#""+v[1]+v[1]+v[2]+v[2]+v[3]+v[3];if(set(v))closeAll();else hex.style.borderColor=""#ff6b6b""};" & @LF
    $s &= " ok.addEventListener(""click"",apply);hex.addEventListener(""keydown"",e=>{if(e.key===""Enter"")apply()});" & @LF
    $s &= " row.append(hex,ok);list.append(grid,row);" & @LF
    $s &= " btn.addEventListener(""click"",e=>{e.stopPropagation();hex.value=inp.value;hex.style.borderColor="""";openDD(wrap,btn)});" & @LF
    $s &= " list.addEventListener(""click"",e=>e.stopPropagation());" & @LF
    $s &= " wrap.append(btn,list);inp.after(wrap);" & @LF
    $s &= " inp._sync=()=>{sw.style.background=inp.value;tx.textContent=inp.value.toUpperCase()};" & @LF
    $s &= " inp._sync();" & @LF
    $s &= "}" & @LF
    $s &= "document.querySelectorAll(""select"").forEach(enhanceSelect);" & @LF
    $s &= "document.querySelectorAll(""input[type=color]"").forEach(enhanceColor);" & @LF
    $s &= "function syncAll(){document.querySelectorAll(""select,input[type=color]"").forEach(e=>e._sync&&e._sync())}" & @LF
    $s &= "" & @LF
    $s &= "/* ---------- 讀取 Html Helper 產生的 QR 點陣 ---------- */" & @LF
    $s &= "const img=new Image();" & @LF
    $s &= "const qrStatus=(m,retry)=>{$(""status"").textContent=m;$(""retryqr"").style.display=retry?""inline-block"":""none""};" & @LF
    $s &= "window.addEventListener(""error"",e=>qrStatus(""QR 繪圖錯誤：""+(e.message||""未知錯誤""),true));" & @LF
    $s &= "$(""updateqr"").onclick=async()=>{const v=$(""qrcontent"").value;if(!v.trim()){alert(""請輸入 QR 內容"");return}" & @LF
    $s &= " try{const r=await fetch(""/__helper_qr_set__?data=""+encodeURIComponent(v),{cache:""no-store""});if(!r.ok)throw Error(await r.text());$(""retryqr"").click()}catch(e){qrStatus(""更新失敗：""+e.message,true)}};" & @LF
    $s &= "$(""retryqr"").onclick=()=>{qrReady=false;qrStatus(""重新讀取 QR Code…"",false);img.src=""/__helper_qr_image__?t=""+Date.now()};" & @LF
    $s &= "setTimeout(()=>{if($(""qrcontent"").value&&!qrReady)qrStatus(""QR 圖片讀取逾時，請按重新讀取"",true)},8000);" & @LF
    $s &= "img.onload=()=>{try{" & @LF
    $s &= " const c=document.createElement(""canvas"");c.width=img.naturalWidth;c.height=img.naturalHeight;" & @LF
    $s &= " const g=c.getContext(""2d"",{willReadFrequently:true});g.drawImage(img,0,0);" & @LF
    $s &= " const data=g.getImageData(0,0,c.width,c.height).data,w=c.width,h=c.height;" & @LF
    $s &= " const dark=(x,y)=>{if(x<0||y<0||x>=w||y>=h)return false;const k=(Math.floor(y)*w+Math.floor(x))*4;return data[k]+data[k+1]+data[k+2]<390};" & @LF
    $s &= " let minx=w,miny=h,maxx=-1,maxy=-1;" & @LF
    $s &= " for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(dark(x,y)){if(x<minx)minx=x;if(y<miny)miny=y;if(x>maxx)maxx=x;if(y>maxy)maxy=y}" & @LF
    $s &= " if(maxx<minx){qrStatus(""QR 點陣解析失敗"",true);return}" & @LF
    $s &= " let run=0;while(minx+run<w&&dark(minx+run,miny))run++;" & @LF
    $s &= " let pitch=Math.max(1,Math.round(run/7)),n=Math.round((maxx-minx+1)/pitch);" & @LF
    $s &= " if(n<21||n>177||Math.abs(n*pitch-(maxx-minx+1))>pitch*2){pitch=1;n=maxx-minx+1}" & @LF
    $s &= " if(n<21||n>177||n%4!==1){qrStatus(""QR 矩陣尺寸無法辨識：""+n+""，請重新讀取"",true);return}" & @LF
    $s &= " matrix=Array.from({length:n},(_,j)=>Array.from({length:n},(_,i)=>dark(Math.min(w-1,Math.floor(minx+(i+.5)*pitch)),Math.min(h-1,Math.floor(miny+(j+.5)*pitch)))));" & @LF
    $s &= " qrReady=true;render();" & @LF
    $s &= "}catch(e){qrStatus(""QR 點陣處理失敗：""+(e.message||e),true)}};" & @LF
    $s &= "img.onerror=()=>qrStatus(""QR 原始圖片載入失敗，請重新讀取"",true);" & @LF
    $s &= "" & @LF
    $s &= "/* ---------- 繪製 ---------- */" & @LF
    $s &= "function rnd(i,j){let h=Math.imul(i+1,73856093)^Math.imul(j+1,19349663);h=Math.imul(h^(h>>>13),1274126177);h^=h>>>16;return (h>>>0)/4294967295}" & @LF
    $s &= "function finderAt(i,j,n){return (i<7&&j<7)||(i>=n-7&&j<7)||(i<7&&j>=n-7)}" & @LF
    $s &= "function rr(x,y,w,h,r){ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.fill()}" & @LF
    $s &= "function shapePath(x,y,w,kind,r){" & @LF
    $s &= " if(kind===""circle""){ctx.moveTo(x+w,y+w/2);ctx.arc(x+w/2,y+w/2,w/2,0,Math.PI*2)}" & @LF
    $s &= " else if(kind===""leaf"")ctx.roundRect(x,y,w,w,[r,0,r,0]);" & @LF
    $s &= " else if(kind===""rr"")ctx.roundRect(x,y,w,w,r);" & @LF
    $s &= " else ctx.rect(x,y,w,w);" & @LF
    $s &= "}" & @LF
    $s &= "/* [外框形狀, 中心形狀, 外框圓角比例, 中心圓角比例] */" & @LF
    $s &= "const FINDERS={square:[""sq"",""sq"",0,0],round:[""rr"",""rr"",.22,.2],cushion:[""rr"",""rr"",.38,.45],circle:[""circle"",""circle"",0,0],dotcenter:[""rr"",""circle"",.2,0],leaf:[""leaf"",""leaf"",.42,.45],leafin:[""rr"",""leaf"",.18,.5]};" & @LF
    $s &= "function hexLum(h){const v=[1,3,5].map(k=>{let c=parseInt(h.substr(k,2),16)/255;return c<=.03928?c/12.92:Math.pow((c+.055)/1.055,2.4)});return .2126*v[0]+.7152*v[1]+.0722*v[2]}" & @LF
    $s &= "function contrast(a,b){const x=hexLum(a),y=hexLum(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05)}" & @LF
    $s &= "" & @LF
    $s &= "function drawModule(shape,i,j,x,y,step,s,on){" & @LF
    $s &= " const cx=x+step/2,cy=y+step/2,gap=(step-s)/2,left=on(i-1,j),right=on(i+1,j),up=on(i,j-1),down=on(i,j+1);" & @LF
    $s &= " switch(shape){" & @LF
    $s &= " case ""square"":ctx.fillRect(x+gap,y+gap,s,s);break;" & @LF
    $s &= " case ""dot"":ctx.beginPath();ctx.arc(cx,cy,s*.5,0,Math.PI*2);ctx.fill();break;" & @LF
    $s &= " case ""soft"":rr(x+gap,y+gap,s,s,s*.32);break;" & @LF
    $s &= " case ""smooth"":{const r=step*.5,x0=left?x:x+gap,y0=up?y:y+gap,x1=right?x+step:x+step-gap,y1=down?y+step:y+step-gap;" & @LF
    $s &= "  ctx.beginPath();ctx.roundRect(x0,y0,x1-x0+.3,y1-y0+.3,[(!up&&!left)?r:0,(!up&&!right)?r:0,(!down&&!right)?r:0,(!down&&!left)?r:0]);ctx.fill();break}" & @LF
    $s &= " case ""bubble"":ctx.beginPath();ctx.arc(cx,cy,s*.5*(.68+.32*rnd(i,j)),0,Math.PI*2);ctx.fill();break;" & @LF
    $s &= " case ""mosaic"":{const k=s*(.7+.3*rnd(i,j));ctx.fillRect(cx-k/2,cy-k/2,k,k);break}" & @LF
    $s &= " case ""diamond"":ctx.beginPath();ctx.moveTo(cx,cy-s*.58);ctx.lineTo(cx+s*.58,cy);ctx.lineTo(cx,cy+s*.58);ctx.lineTo(cx-s*.58,cy);ctx.closePath();ctx.fill();break;" & @LF
    $s &= " case ""hex"":ctx.beginPath();for(let k=0;k<6;k++){const a=Math.PI/6+k*Math.PI/3;ctx.lineTo(cx+Math.cos(a)*s*.56,cy+Math.sin(a)*s*.56)}ctx.closePath();ctx.fill();break;" & @LF
    $s &= " case ""cross"":{const a=s*.42;ctx.fillRect(x+gap,cy-a/2,s,a);ctx.fillRect(cx-a/2,y+gap,a,s);break}" & @LF
    $s &= " case ""star"":{const o=s*.56,n=s*.3;ctx.beginPath();for(let k=0;k<10;k++){const a=-Math.PI/2+k*Math.PI/5,r=k%2?n:o;ctx.lineTo(cx+Math.cos(a)*r,cy+Math.sin(a)*r)}ctx.closePath();ctx.fill();break}" & @LF
    $s &= " case ""heart"":{const w=s*1.05;ctx.beginPath();ctx.moveTo(cx,cy+w*.42);ctx.bezierCurveTo(cx-w*.66,cy,cx-w*.42,cy-w*.56,cx,cy-w*.22);ctx.bezierCurveTo(cx+w*.42,cy-w*.56,cx+w*.66,cy,cx,cy+w*.42);ctx.fill();break}" & @LF
    $s &= " case ""leaf"":rr(x+gap,y+gap,s,s,[s*.5,0,s*.5,0]);break;" & @LF
    $s &= " case ""lineH"":rr(x+(left?0:gap),cy-s*.24,step-(left?0:gap)-(right?0:gap),s*.48,(left&&right)?0:s*.24);break;" & @LF
    $s &= " case ""lineV"":rr(cx-s*.24,y+(up?0:gap),s*.48,step-(up?0:gap)-(down?0:gap),(up&&down)?0:s*.24);break;" & @LF
    $s &= " case ""pill"":{const hh=s*.56;if(left||right){ctx.fillRect(x+(left?0:gap+hh/2),cy-hh/2,step-(left?0:gap+hh/2)-(right?0:gap+hh/2),hh);if(!left){ctx.beginPath();ctx.arc(x+gap+hh/2,cy,hh/2,0,Math.PI*2);ctx.fill()}if(!right){ctx.beginPath();ctx.arc(x+step-gap-hh/2,cy,hh/2,0,Math.PI*2);ctx.fill()}}else rr(x+gap,cy-hh/2,s,hh,hh/2);break}" & @LF
    $s &= " case ""fluid"":{const r=s*.4;ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.fill();const t=r*1.55;if(right)ctx.fillRect(cx,cy-t/2,step,t);if(down)ctx.fillRect(cx-t/2,cy,t,step);break}" & @LF
    $s &= " case ""metro"":{const r=s*.36;ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.fill();const t=s*.3;if(right)ctx.fillRect(cx,cy-t/2,step,t);if(down)ctx.fillRect(cx-t/2,cy,t,step);break}" & @LF
    $s &= " }" & @LF
    $s &= "}" & @LF
    $s &= "" & @LF
    $s &= "function render(){" & @LF
    $s &= " syncAll();" & @LF
    $s &= " $(""dv"").textContent=$(""density"").value+""%"";$(""ls"").textContent=$(""logosize"").value+""%"";$(""lp"").textContent=$(""logopad"").value+""%"";$(""qv"").textContent=$(""quiet"").value;" & @LF
    $s &= " if(!matrix)return;" & @LF
    $s &= " const n=matrix.length,N=+$(""outsize"").value,q=+$(""quiet"").value,cap=$(""caption"").value.trim(),trans=$(""transparent"").checked;" & @LF
    $s &= " const step=N/(n+2*q),pad=q*step,d=+$(""density"").value/100,shape=$(""shape"").value,capH=cap?Math.round(N*.14):0;" & @LF
    $s &= " canvas.width=N;canvas.height=N+capH;" & @LF
    $s &= " ctx.clearRect(0,0,canvas.width,canvas.height);" & @LF
    $s &= " const bg=$(""bg"").value;" & @LF
    $s &= " if(!trans){ctx.fillStyle=bg;ctx.fillRect(0,0,canvas.width,canvas.height)}" & @LF
    $s &= " let brush=$(""fg"").value;const grad=$(""gradient"").value;" & @LF
    $s &= " if(grad!==""none""){let g;" & @LF
    $s &= "  if(grad===""radial"")g=ctx.createRadialGradient(N/2,N/2,step,N/2,N/2,N*.7);" & @LF
    $s &= "  else if(grad===""antidiag"")g=ctx.createLinearGradient(N-pad,pad,pad,N-pad);" & @LF
    $s &= "  else g=ctx.createLinearGradient(pad,pad,grad===""vertical""?pad:N-pad,grad===""horizontal""?pad:N-pad);" & @LF
    $s &= "  g.addColorStop(0,$(""fg"").value);g.addColorStop(1,$(""fg2"").value);brush=g}" & @LF
    $s &= " /* 定位框、時序線與校正圖案保持原狀 */" & @LF
    $s &= " const guard=Array.from({length:n},()=>Array(n).fill(false));" & @LF
    $s &= " for(let j=0;j<n;j++)for(let i=0;i<n;i++)if(finderAt(i,j,n)||i===6||j===6)guard[j][i]=true;" & @LF
    $s &= " for(let cy=2;cy<n-2;cy++)for(let cx=2;cx<n-2;cx++){" & @LF
    $s &= "  if((cx<9&&cy<9)||(cx>n-10&&cy<9)||(cx<9&&cy>n-10))continue;let ok=true;" & @LF
    $s &= "  for(let dy=-2;dy<=2&&ok;dy++)for(let dx=-2;dx<=2;dx++){const want=Math.max(Math.abs(dx),Math.abs(dy))!==1;if(matrix[cy+dy][cx+dx]!==want){ok=false;break}}" & @LF
    $s &= "  if(ok)for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++)guard[cy+dy][cx+dx]=true}" & @LF
    $s &= " const on=(i,j)=>i>=0&&j>=0&&i<n&&j<n&&matrix[j][i]&&!guard[j][i];" & @LF
    $s &= " /* 定位框 */" & @LF
    $s &= " const f=FINDERS[$(""finder"").value]||FINDERS.square,eye=$(""eyecustom"").checked;" & @LF
    $s &= " for(const [fi,fj] of [[0,0],[n-7,0],[0,n-7]]){" & @LF
    $s &= "  const x=pad+fi*step,y=pad+fj*step,s7=7*step,s5=5*step,s3=3*step;" & @LF
    $s &= "  ctx.fillStyle=eye?$(""eyeout"").value:brush;ctx.beginPath();" & @LF
    $s &= "  shapePath(x,y,s7,f[0],s7*f[2]);shapePath(x+step,y+step,s5,f[0],s5*f[2]*.75);ctx.fill(""evenodd"");" & @LF
    $s &= "  ctx.fillStyle=eye?$(""eyein"").value:brush;ctx.beginPath();shapePath(x+2*step,y+2*step,s3,f[1],s3*f[3]);ctx.fill();" & @LF
    $s &= " }" & @LF
    $s &= " /* 資料模組 */" & @LF
    $s &= " ctx.fillStyle=brush;" & @LF
    $s &= " for(let j=0;j<n;j++)for(let i=0;i<n;i++){" & @LF
    $s &= "  const x=pad+i*step,y=pad+j*step;" & @LF
    $s &= "  if(guard[j][i]){if(!finderAt(i,j,n)&&matrix[j][i])ctx.fillRect(x,y,step+.1,step+.1);continue}" & @LF
    $s &= "  if(on(i,j))drawModule(shape,i,j,x,y,step,step*d,on);" & @LF
    $s &= " }" & @LF
    $s &= " /* Logo */" & @LF
    $s &= " /* Logo：底框依 Logo 實際比例貼合；「Logo 留白」＝Logo 與底框邊緣的距離（Logo 大小的百分比） */" & @LF
    $s &= " let logoCover=0;" & @LF
    $s &= " if(logo){const side=N*+$(""logosize"").value/100,pad2=side*+$(""logopad"").value/100;" & @LF
    $s &= "  const fr=$(""logoframe"").value,ar=(logo.naturalWidth/logo.naturalHeight)||1,cx=N/2,cy=N/2;" & @LF
    $s &= "  ctx.fillStyle=trans?""#ffffff"":bg;" & @LF
    $s &= "  if(fr===""circle""){" & @LF
    $s &= "   /* 圓形：Logo 長邊＝圓的直徑，超出圓的角落裁掉（圓形 Logo 會剛好填滿） */" & @LF
    $s &= "   const R=side/2,dw=ar>=1?side:side*ar,dh=ar>=1?side/ar:side;" & @LF
    $s &= "   ctx.beginPath();ctx.arc(cx,cy,R+pad2,0,Math.PI*2);ctx.fill();" & @LF
    $s &= "   ctx.save();ctx.beginPath();ctx.arc(cx,cy,R,0,Math.PI*2);ctx.clip();ctx.drawImage(logo,cx-dw/2,cy-dh/2,dw,dh);ctx.restore();" & @LF
    $s &= "   logoCover=Math.PI*(R+pad2)*(R+pad2);" & @LF
    $s &= "  }else{" & @LF
    $s &= "   /* 方形／無底框：長邊＝Logo 大小，底框只比 Logo 多出留白 */" & @LF
    $s &= "   const dw=ar>=1?side:side*ar,dh=ar>=1?side/ar:side,x=cx-dw/2,y=cy-dh/2,rad=Math.min(dw,dh)*.12;" & @LF
    $s &= "   if(fr===""round"")rr(x-pad2,y-pad2,dw+2*pad2,dh+2*pad2,rad+pad2);" & @LF
    $s &= "   ctx.save();ctx.beginPath();ctx.roundRect(x,y,dw,dh,fr===""round""?rad:0);ctx.clip();ctx.drawImage(logo,x,y,dw,dh);ctx.restore();" & @LF
    $s &= "   logoCover=(dw+2*pad2)*(dh+2*pad2);" & @LF
    $s &= "  }" & @LF
    $s &= " }" & @LF
    $s &= " /* 底部標籤 */" & @LF
    $s &= " if(cap){const by=N-pad*.35,bh=capH*.82;" & @LF
    $s &= "  ctx.fillStyle=$(""fg"").value;rr(pad,by,N-2*pad,bh,bh*.3);" & @LF
    $s &= "  ctx.fillStyle=trans?""#ffffff"":bg;ctx.textAlign=""center"";ctx.textBaseline=""middle"";" & @LF
    $s &= "  let fs=bh*.5;ctx.font=""bold ""+fs+""px \""Microsoft JhengHei\"",sans-serif"";" & @LF
    $s &= "  while(fs>8&&ctx.measureText(cap).width>N-2*pad-bh*.6){fs-=1;ctx.font=""bold ""+fs+""px \""Microsoft JhengHei\"",sans-serif""}" & @LF
    $s &= "  ctx.fillText(cap,N/2,by+bh/2)}" & @LF
    $s &= " /* 提示 */" & @LF
    $s &= " const w=[];" & @LF
    $s &= " if(!trans&&contrast($(""fg"").value,bg)<3)w.push(""前景與背景對比偏低"");" & @LF
    $s &= " if(!trans&&grad!==""none""&&contrast($(""fg2"").value,bg)<3)w.push(""漸層終點與背景對比偏低"");" & @LF
    $s &= " if(!trans&&hexLum($(""fg"").value)>hexLum(bg))w.push(""淺色點陣＋深色背景（反白）部分掃描器不支援"");" & @LF
    $s &= " if(d<.82)w.push(""點陣較細"");" & @LF
    $s &= " if(logo&&logoCover/(N*N)>.03)w.push(""Logo 遮住的面積偏大（""+(logoCover/(N*N)*100).toFixed(1)+""%），可能無法掃描"");" & @LF
    $s &= " if([""star"",""heart"",""cross"",""metro"",""lineH"",""lineV""].includes(shape)&&d<.9)w.push(""此造型建議飽滿度 90% 以上"");" & @LF
    $s &= " $(""warn"").textContent=w.length?""注意：""+w.join(""、""):"""";" & @LF
    $s &= " qrStatus(""預覽 ""+N+"" × ""+(N+capH)+"" px · ""+n+""×""+n+"" 模組 · 請以手機實測掃描"",false);" & @LF
    $s &= "}" & @LF
    $s &= "document.querySelectorAll(""input,select"").forEach(e=>{if(e.id!==""logo""&&e.id!==""qrcontent"")e.addEventListener(""input"",render)});" & @LF
    $s &= "/* 裁掉 Logo 四周的透明邊（alpha < 16 視為透明），回傳裁切後的 canvas；沒有透明邊時回傳原圖 */" & @LF
    $s &= "let logoSrc=null;" & @LF
    $s &= "function trimLogo(im){" & @LF
    $s &= " const w=im.naturalWidth,h=im.naturalHeight;if(!w||!h)return im;" & @LF
    $s &= " const c=document.createElement(""canvas"");c.width=w;c.height=h;const g=c.getContext(""2d"",{willReadFrequently:true});g.drawImage(im,0,0);" & @LF
    $s &= " let d;try{d=g.getImageData(0,0,w,h).data}catch(e){return im}" & @LF
    $s &= " let x0=w,y0=h,x1=-1,y1=-1;" & @LF
    $s &= " for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(d[(y*w+x)*4+3]>=16){if(x<x0)x0=x;if(x>x1)x1=x;if(y<y0)y0=y;if(y>y1)y1=y}" & @LF
    $s &= " if(x1<0||(x0===0&&y0===0&&x1===w-1&&y1===h-1))return im;" & @LF
    $s &= " const o=document.createElement(""canvas"");o.width=x1-x0+1;o.height=y1-y0+1;o.getContext(""2d"").drawImage(c,x0,y0,o.width,o.height,0,0,o.width,o.height);" & @LF
    $s &= " o.naturalWidth=o.width;o.naturalHeight=o.height;return o;" & @LF
    $s &= "}" & @LF
    $s &= "function applyLogoTrim(){if(!logoSrc)return;logo=$(""logotrim"").checked?trimLogo(logoSrc):logoSrc}" & @LF
    $s &= "function setLogoUI(f,im){" & @LF
    $s &= " const t=$(""logothumb"");t.textContent="""";" & @LF
    $s &= " if(im){const c=document.createElement(""img"");c.src=im.src;t.appendChild(c);$(""logoname"").textContent=f?f.name:""Logo"";" & @LF
    $s &= "  $(""logometa"").textContent=im.naturalWidth+"" × ""+im.naturalHeight+"" px""+(f?"" · ""+(f.size<1048576?Math.max(1,Math.round(f.size/1024))+"" KB"":(f.size/1048576).toFixed(1)+"" MB""):"""");" & @LF
    $s &= "  $(""logopick"").textContent=""更換"";$(""logoclear"").style.display=""""}" & @LF
    $s &= " else{t.textContent=""＋"";$(""logoname"").textContent=""尚未選擇"";$(""logometa"").textContent=""PNG／JPG／WebP，可按 Ctrl+V 貼上圖片"";$(""logopick"").textContent=""選擇圖片"";$(""logoclear"").style.display=""none""}" & @LF
    $s &= "}" & @LF
    $s &= "function loadLogoFile(f){" & @LF
    $s &= " if(!f)return;if(!/^image\/(png|jpeg|webp|gif|bmp|svg\+xml)$/.test(f.type)){qrStatus(""不支援的圖片格式：""+(f.type||f.name),false);return}" & @LF
    $s &= " const r=new FileReader();r.onload=()=>{const im=new Image();im.onload=()=>{logoSrc=im;applyLogoTrim();setLogoUI(f,im);render()};im.onerror=()=>qrStatus(""Logo 載入失敗"",false);im.src=r.result};r.readAsDataURL(f);" & @LF
    $s &= "}" & @LF
    $s &= "function clearLogo(){logo=null;logoSrc=null;$(""logo"").value="""";setLogoUI(null,null);render()}" & @LF
    $s &= "$(""logo"").addEventListener(""change"",e=>{loadLogoFile(e.target.files[0]);e.target.value=""""});" & @LF
    $s &= "$(""logopick"").onclick=()=>$(""logo"").click();" & @LF
    $s &= "$(""logoclear"").onclick=clearLogo;" & @LF
    $s &= "$(""logotrim"").addEventListener(""change"",()=>{applyLogoTrim();render()});" & @LF
    $s &= "$(""logothumb"").onclick=()=>$(""logo"").click();" & @LF
    $s &= "$(""logopaste"").onclick=async()=>{try{const items=await navigator.clipboard.read();" & @LF
    $s &= " for(const it of items){const t=it.types.find(x=>x.startsWith(""image/""));if(t){const b=await it.getType(t);loadLogoFile(new File([b],""剪貼簿圖片.""+t.split(""/"")[1],{type:t}));return}}" & @LF
    $s &= " qrStatus(""剪貼簿裡沒有圖片"",false)}catch(e){qrStatus(""無法讀取剪貼簿，請直接按 Ctrl+V 貼上"",false)}};" & @LF
    $s &= "document.addEventListener(""paste"",e=>{if(document.activeElement&&/^(TEXTAREA|INPUT)$/.test(document.activeElement.tagName))return;const it=[...(e.clipboardData||{}).items||[]].find(i=>i.type.startsWith(""image/""));if(it)loadLogoFile(it.getAsFile())});" & @LF
    $s &= "" & @LF
    $s &= "/* ---------- 快速主題 [名稱, 造型, 定位框, 主色, 終點色, 漸層, 背景, 飽滿度, 定位框自訂, 外框色, 中心色] ---------- */" & @LF
    $s &= "const PRESETS=[" & @LF
    $s &= " [""經典"",""square"",""square"",""#172b50"",""#497acb"",""none"",""#ffffff"",94,false,""#172b50"",""#172b50""]," & @LF
    $s &= " [""深海流線"",""fluid"",""round"",""#053b60"",""#16b6b3"",""diagonal"",""#ffffff"",95,false,"""",""""]," & @LF
    $s &= " [""鎏金圓點"",""dot"",""dotcenter"",""#5c3518"",""#c79043"",""diagonal"",""#fff9ee"",96,false,"""",""""]," & @LF
    $s &= " [""霓虹星芒"",""star"",""circle"",""#3b177d"",""#c12edb"",""radial"",""#ffffff"",100,false,"""",""""]," & @LF
    $s &= " [""日落膠囊"",""pill"",""cushion"",""#c2185b"",""#ff8f00"",""horizontal"",""#fffaf3"",96,false,"""",""""]," & @LF
    $s &= " [""森林葉片"",""leaf"",""leaf"",""#134e2a"",""#3fa34d"",""vertical"",""#f6fbf4"",96,false,"""",""""]," & @LF
    $s &= " [""甜心"",""heart"",""circle"",""#d81b60"",""#8e24aa"",""radial"",""#fff5f9"",100,true,""#8e24aa"",""#d81b60""]," & @LF
    $s &= " [""賽博"",""smooth"",""leafin"",""#0d47a1"",""#00acc1"",""antidiag"",""#f3f8ff"",100,true,""#00acc1"",""#0d47a1""]," & @LF
    $s &= " [""蜂巢"",""hex"",""round"",""#3e2723"",""#f9a825"",""diagonal"",""#fffdf5"",98,false,"""",""""]," & @LF
    $s &= " [""泡泡"",""bubble"",""circle"",""#00695c"",""#26c6da"",""radial"",""#f2fdfc"",98,false,"""",""""]," & @LF
    $s &= " [""馬賽克"",""mosaic"",""square"",""#263238"",""#546e7a"",""vertical"",""#ffffff"",98,false,"""",""""]," & @LF
    $s &= " [""地鐵"",""metro"",""dotcenter"",""#283593"",""#c62828"",""diagonal"",""#ffffff"",100,true,""#c62828"",""#283593""]," & @LF
    $s &= " [""平滑墨黑"",""smooth"",""cushion"",""#111111"",""#111111"",""none"",""#ffffff"",100,false,"""",""""]," & @LF
    $s &= " [""十字繡"",""cross"",""square"",""#b71c1c"",""#4a148c"",""diagonal"",""#fff8f0"",100,false,"""",""""]" & @LF
    $s &= "];" & @LF
    $s &= "PRESETS.forEach((p,k)=>{const b=document.createElement(""button"");b.type=""button"";const i=document.createElement(""i"");" & @LF
    $s &= " i.style.background=p[5]===""none""?p[3]:""linear-gradient(135deg,""+p[3]+"",""+p[4]+"")"";b.append(i,document.createTextNode(p[0]));" & @LF
    $s &= " b.onclick=()=>applyPreset(k);$(""presets"").appendChild(b)});" & @LF
    $s &= "function applyPreset(k){const p=PRESETS[k];$(""shape"").value=p[1];$(""finder"").value=p[2];$(""fg"").value=p[3];$(""fg2"").value=p[4];$(""gradient"").value=p[5];$(""bg"").value=p[6];$(""density"").value=p[7];$(""eyecustom"").checked=p[8];if(p[9])$(""eyeout"").value=p[9];if(p[10])$(""eyein"").value=p[10];$(""transparent"").checked=false;render()}" & @LF
    $s &= "$(""reset"").onclick=()=>{clearLogo();$(""logoframe"").value=""round"";$(""logosize"").value=13;$(""logopad"").value=6;$(""outsize"").value=""512"";$(""quiet"").value=3;$(""caption"").value="""";applyPreset(0)};" & @LF
    $s &= "" & @LF
    $s &= "/* ---------- 輸出 ---------- */" & @LF
    $s &= "/* forceTrans：不論「透明背景」是否勾選，都輸出無底色 PNG，完成後恢復原設定 */" & @LF
    $s &= "const toBlob=(forceTrans)=>new Promise(r=>{const old=$(""transparent"").checked;if(forceTrans)$(""transparent"").checked=true;render();" & @LF
    $s &= " canvas.toBlob(b=>{if(forceTrans&&!old){$(""transparent"").checked=false;render()}r(b)},""image/png"")});" & @LF
    $s &= "/* 不用 WebView2 的 showSaveFilePicker（在 AUI 視窗中會造成程式閃退）：" & @LF
    $s &= "   把 PNG 以 Base64 傳給 Html Helper，由程式本身的「另存新檔」視窗儲存。 */" & @LF
    $s &= "const blobToB64=b=>new Promise((ok,no)=>{const r=new FileReader();r.onload=()=>ok(String(r.result).split("","")[1]||"""");r.onerror=()=>no(r.error);r.readAsDataURL(b)});" & @LF
    $s &= "async function savePng(forceTrans){const blob=await toBlob(forceTrans);if(!blob){qrStatus(""PNG 產生失敗"",false);return}" & @LF
    $s &= " try{const b64=await blobToB64(blob);" & @LF
    $s &= "  const name=forceTrans?""Html_Helper_QR_透明.png"":""Html_Helper_Styled_QR.png"";" & @LF
    $s &= "  const r=await fetch(""/__helper_qr_save__?name=""+encodeURIComponent(name),{method:""POST"",headers:{""Content-Type"":""text/plain""},body:b64,cache:""no-store""});" & @LF
    $s &= "  const t=await r.text();if(!r.ok||t!==""OK"")throw Error(t||(""HTTP ""+r.status));" & @LF
    $s &= "  $(""warn"").textContent=""請在跳出的「另存新檔」視窗選擇儲存位置""}" & @LF
    $s &= " catch(e){alert(""PNG 儲存失敗：""+(e.message||e))}}" & @LF
    $s &= "$(""save"").onclick=()=>savePng(false);" & @LF
    $s &= "$(""savetrans"").onclick=()=>savePng(true);" & @LF
    $s &= "$(""copyimg"").onclick=async()=>{const blob=await toBlob();try{await navigator.clipboard.write([new ClipboardItem({""image/png"":blob})]);$(""warn"").textContent=""圖片已複製到剪貼簿""}catch(e){alert(""複製失敗：""+e.message)}};" & @LF
    $s &= "" & @LF
    $s &= "/* ---------- 初始內容 ---------- */" & @LF
    $s &= "fetch(""/__helper_qr_initial__"",{cache:""no-store""}).then(r=>r.text()).then(v=>{$(""qrcontent"").value=v;" & @LF
    $s &= " if(v)img.src=""/__helper_qr_image__?t=""+Date.now();" & @LF
    $s &= " else{qrReady=false;matrix=null;ctx.clearRect(0,0,canvas.width,canvas.height);qrStatus(""請輸入內容後按「更新 QR 內容」"",false)}" & @LF
    $s &= "}).catch(()=>qrStatus(""無法讀取 QR 初始內容"",true));" & @LF
    $s &= "render();" & @LF
    $s &= "</script>" & @LF
    $s &= "</body>" & @LF
    $s &= "</html>" & @LF
    Return $s
EndFunc
