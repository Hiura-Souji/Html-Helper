#include-Once

#cs\\\\\\\\\\\\\\\\\\\\\\\\\\\\ #include <_Ini.au3> \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

	　　編寫本函數庫的原因：
	　　1，內置函數對於某些ini文件由於編碼問題讀寫錯誤，本庫系列函數增加打開模式(如32)，以正確讀寫。
	　　2，內置函數有效數據僅有32767字符可以被正常返回，本庫系列函數無此限制。

	　　當前版本：v1.2.3.0

	　　函數說明：
	　　_IniDelete-----------;從INI結構文件中刪除某個鍵值.
	　　_IniRead-------------;從INI結構文件中讀取某個鍵值.
	　　_IniReadSection------;從INI結構文件中讀取某個字段中的所有關鍵字及值.
	　　_IniReadSectionNames-;從INI結構文件中讀取所有字段名.
	　　_IniRenameSection----;重命名INI結構文件里面的字段名.
	　　_IniRenameKey--------;重命名INI結構文件里面的關鍵字.
	　　_IniWrite------------;寫入一個鍵值到INI結構文件.
	　　_IniWriteSection-----;將數據寫入到INI結構文件的一個字段.

	　　_IniReadSection_str--;從(非)標準INI結構文件中讀取某個字段中的所有字符.
	　　_IniReadSection_line-;從(非)標準INI結構文件中讀取某個字段中的行字符串.
	　　_FileRead------------;用指定的FileOpen打開模式返回讀取文件的字符串.
	　　_IniDelete_line------;從(非)標準INI結構文件中刪除(含有)關鍵字的行.

	　　註意：
	　　對於特殊的鍵與值，如“abc=123=AAA” 原則上“abc”應該才為關鍵字，“123=AAA”為值，
	　　本想規範之，但覺得有時候可能會有“abc=123”為關鍵字，“AAA”為值的需求（內置函數是沒得選的），
	　　因此，這里不強制為第一種情況，只需註意如下幾點（當然，只有1個等號就無需註意這些了）：
	　　1，_IniReadSection 這個將保持為僅適用第一種情況，“abc”為關鍵字，“123=AAA”為值
	　　2，_IniDelete、_IniRead、_IniRenameKey、_IniWrite 可同時適用兩種情況。

	　　　　　　　　　　-- Afan -- http://www.autoitx.com -- 2010-6-28 --更新於 2015-06-07
#ce\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\


; 函數名:_IniDelete;=============================================================================
; 說明:　從INI結構文件中刪除某個數值。
; 語法:　_IniDelete('ini文件路徑', '字段名'[, '關鍵字'[, 打開模式]])
; 參數:　可選參數'關鍵字'，要刪除的關鍵字，若不指定關鍵字或使用Default關鍵字則整個字段將被刪除。
; 返回值:成功: 返回1。
;　　　　失敗: 返回0。並設置 @Error 為以下值：
;　　　　　　　　　　　　　　@Error=1 文件不存在；
;　　　　　　　　　　　　　　@Error=2 字段不存在；
;　　　　　　　　　　　　　　@Error=3 關鍵字不存在
;　　　　　　　　　　　　　　@Error=4 文件具有只讀屬性或者無法寫入數據設置。
;==========================================================================================start
Func _IniDelete($iFile, $Section, $key = '', $mode = 0)
	Local $s_data
	If Not FileExists($iFile) Then Return SetError(1, 0, 0)
	Local $s_File = _FileRead($iFile, $mode)
	Local $_Section = StringRegExpReplace($Section, '^\h*(.+?)\h*$', '$1')
	Local $_key = StringRegExpReplace($key, '^\h*(.+?)\h*$', '$1')
	$_Section = StringRegExpReplace($_Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	$_Section = '\[\h*' & $_Section & '\h*\]'
	$_key = StringRegExpReplace($_key, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\|\=)', '\\$1')
	If Not StringRegExp(@CRLF & $s_File, '\r?\n\h*' & $_Section & '\s*') Then Return SetError(2, 0, 0)
	If $key <> '' And $key <> Default Then
		Local $vr = _IniRead($iFile, $Section, $key, @LF, $mode)
		If $vr = @LF Then Return SetError(3, 0, 0)
		$s_data = StringRegExpReplace(@CRLF & $s_File & @CRLF, '(?si)(.*?\r?\n\h*' & $_Section & '\h*\r?\n.*?)(\h*' & $_key & '\h*\=.*?\r?\n)(.*)', '$1$3')
	Else
		$s_data = StringRegExpReplace(@CRLF & $s_File & @CRLF & '[', '(?si)(.*?\r?\n)(\h*' & $_Section & '.*?)(\r?\n\h*\[.*)', '$1$3')
	EndIf
	$s_data = StringTrimLeft($s_data, 2)
	$s_data = StringTrimRight($s_data, 3)
	Local $FO = FileOpen($iFile, $mode + 2)
	Local $Write = FileWrite($FO, $s_data)
	FileClose($FO)
	If $Write = 0 Then Return SetError(4, 0, 0)
	Return 1
EndFunc   ;==>_IniDelete


; 函數名:_IniRead;=============================================================================
; 說明:　從INI結構文件中讀取某個數值。
; 語法:　_IniRead('ini文件路徑', '字段名', '關鍵字'[, '默認值'[, 打開模式]])
; 返回值:成功: 返回指定的關鍵字的值。
;　　　　失敗: 返回默認值。如INI文件或字段不存在或讀取錯誤 將設置 @error=1；@Error=2 關鍵字不存在。
;==========================================================================================start
Func _IniRead($iFile, $Section, $key, $default = '', $mode = 0)
	Local $s_Sec = _IniReadSection_str($iFile, $Section, $mode)
	If @error = 1 Then Return SetError(1, 0, $default)
	If @error = 2 Then Return SetError(3, 0, $default)
	Local $_key = StringRegExpReplace($key, '^\h*|\h*$', '')
	$_key = StringRegExpReplace($_key, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\|\=)', '\\$1')
	Local $aVal = StringRegExp($s_Sec, '(?mi)^\h*' & $_key & '\h*\=\h*(\V*?)\s*$', 1)
	If @error Then Return SetError(2, 0, $default)
	Return $aVal[0]
EndFunc   ;==>_IniRead


; 函數名:_IniReadSection;======================================================================
; 說明:　從INI結構文件中讀取某個字段中的所有關鍵字或值。
;　　　　原IniReadSection函數只有在字段中的前32767字符可以被正常返回,本函數無此限制(初衷在於此)。
;　　　　原IniReadSection函數遇到某些文件特殊的回車及換行組合會停止繼續而返回，本函數會完整讀出。
;　　　　其它與原IniReadSection函數不同：不返回無關鍵字的值;既無關鍵字又無值只有等號的也不被返回。
; 語法:　_IniReadSection('ini文件路徑', '字段名'[, 打開模式])
; 返回值:成功: 返回一個二維數組,其中：元素[0][0]=大小、元素[n][0]=關鍵字、元素[n][1]=對應的數值。
;　　　　失敗: 返回0。如INI文件讀取錯誤或字段不存在將設置 @error=1；字段內容為空將設置 @error=2
;==========================================================================================start
Func _IniReadSection($iFile, $Section, $mode = 0)
	Local $s_Sec, $a_1, $ii = 1, $i
	$s_Sec = _IniReadSection_str($iFile, $Section, $mode)
	If @error Then Return SetError(@error, 0, 0)
	$a_1 = StringRegExp($s_Sec, '(?m)^\h*([^=;\s][^=\v]*?)\h*\=\h*(\V*?)\s*$', 3)
	If @error Then Return SetError(2, 0, 0)
	Local $2_array[UBound($a_1) / 2 + 1][2] = [[UBound($a_1) / 2]]
	For $i = 0 To UBound($a_1) - 1 Step 2
		$2_array[$ii][0] = $a_1[$i]
		$2_array[$ii][1] = $a_1[$i + 1]
		$ii += 1
	Next
	Return $2_array
EndFunc   ;==>_IniReadSection


; 函數名:_IniReadSectionNames;===============================================================
; 說明:　從INI結構文件中讀取所有字段的信息。
;　　　　原IniReadSectionNames函數只有前32767字符有效,本函數無此限制。
;　　　　其它與原IniReadSectionNames函數不同：
;　　　　    - 本函數可選擇打開模式，以便完整讀出所有字段名。
;　　　　    - 不返回外面無"]"包括的字段名;
;　　　　    - 不返回空的字段名（即"[]"）;
;　　　　    - 可返回由"[]"包括的行內所有字符為字段名，可包含[]，如"[a[b]]"返回名為"a[b]"的字段名，
;　　　　      如需讀取"a[b]"之類包含"["或"]"字段的關鍵字或值，需使用 _IniReadSection() 函數。
; 語法:　_IniReadSectionNames('ini文件路徑'[, 打開模式[, 標誌]])
; 參數:　可選參數“標誌”，標誌=1時返回的數組0號元素為數組的元素數量(默認)；標誌=0時關閉0元素返回數量
; 返回值:成功: 返回一個含有所有字段名的數組。
;　　　　失敗: 返回0。如INI文件讀取錯誤或字段不存在將設置 @error=1
;=====================================================================================start
Func _IniReadSectionNames($iFile, $mode = 0, $flag = 1)
	Local $s_File = _FileRead($iFile, $mode)
	Local $Section = StringRegExp(@LF & $s_File, '\n\h*\[\h*(.*[^\s])\s*\]', 3)
	If @error Then Return SetError(1, 0, 0)
	If $flag = 0 Then Return $Section
	Local $_Section[UBound($Section) + 1], $i
	$_Section[0] = UBound($Section)
	For $i = 0 To $_Section[0] - 1
		$_Section[$i + 1] = $Section[$i]
	Next
	Return $_Section
EndFunc   ;==>_IniReadSectionNames


; 函數名:_IniRenameSection;=====================================================================
; 說明:　重命名INI結構文件里面的字段。
; 語法:　_IniRenameSection('ini文件路徑', '原字段名', '新字段名'[, 打開模式])
; 返回值:成功: 返回1。
;　　　　失敗: 返回0。並設置 @Error 為以下值：
;　　　　　　　　　　　　　　@Error=1 原字段不存在；
;　　　　　　　　　　　　　　@Error=2 新字段已存在；
;　　　　　　　　　　　　　　@Error=3 文件具有只讀屬性或者無法寫入數據。
;==========================================================================================start
Func _IniRenameSection($iFile, $Section, $new_Section, $mode = 0)
	Local $s_File = _FileRead($iFile, $mode)
	Local $_Section = StringRegExpReplace($Section, '^\h*(.+?)\h*$', '$1')
	$_Section = StringRegExpReplace($_Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	$_Section = '\[\h*' & $_Section & '\h*\]'
	If Not StringRegExp(@CRLF & $s_File, '\r?\n\h*' & $_Section & '\s*') Then Return SetError(1, 0, 0)
	$new_Section = StringRegExpReplace($new_Section, '^\h*(.+?)\h*$', '$1')
	$new_Section = StringRegExpReplace($new_Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	If StringRegExp(@CRLF & $s_File, '\r?\n\h*\[\h*' & $new_Section & '\h*\]\s*') Then Return SetError(2, 0, 0)
	Local $resdata = StringRegExpReplace(@CRLF & $s_File, '(?si)(.*\r?\n\h*)(' & $_Section & '\h*)(.*)', '${1}[' & $new_Section & ']$3', 1)
	$resdata = StringTrimLeft($resdata, 2)
	Local $FO = FileOpen($iFile, $mode + 2)
	Local $Write = FileWrite($FO, $resdata)
	FileClose($FO)
	If $Write = 0 Then Return SetError(3, 0, 0)
	Return 1
EndFunc   ;==>_IniRenameSection


; 函數名:_IniRenameKey;========================================================================
; 說明:　重命名INI結構文件里面的關鍵字。
; 語法:　_IniRenameKey('ini文件路徑', '字段名', '原關鍵字', '新關鍵字'[, 打開模式])
; 返回值:成功: 返回1。
;　　　　失敗: 返回0。並設置 @Error 為以下值：
;　　　　　　　　　　　　　　@Error=1 原關鍵字不存在；
;　　　　　　　　　　　　　　@Error=2 新關鍵字已存在；
;　　　　　　　　　　　　　　@Error=3 新關鍵字為空或僅含有空格或首個非空格字符為“[”
;　　　　　　　　　　　　　　@Error=4 文件具有只讀屬性或者無法寫入數據。
;==========================================================================================start
Func _IniRenameKey($iFile, $Section, $Key, $new_key, $mode = 0)
	If StringRegExp($new_key, '^\s*(?:\[.*)?$') Then Return SetError(3, 0, 0)
	_IniRead($iFile, $Section, $Key, @LF, $mode)
	If @error Then Return SetError(1, 0, 0)
	_IniRead($iFile, $Section, $new_key, @LF, $mode)
	If Not @error Then Return SetError(2, 0, 0)
	Local $s_File = _FileRead($iFile, $mode)
	Local $_Section = StringRegExpReplace($Section, '^\h*(.+?)\h*$', '$1')
	$_Section = StringRegExpReplace($_Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	$_Section = '\[\h*' & $_Section & '\h*\]'
	Local $_key = StringRegExpReplace($Key, '^\h*(.+?)\h*$', '$1')
	$_key = StringRegExpReplace($_key, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\|\=)', '\\$1')
	Local $_new_key = StringRegExpReplace($new_key, '^\h*(.+?)\h*$', '$1')
	$_new_key = StringRegExpReplace($_new_key, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\|\=)', '\\$1')
	Local $resdata = StringRegExpReplace(@CRLF & $s_File, '(?si)(.*\r?\n\h*' & $_Section & '.*?\r?\n)\h*(' & $_key & ')\h*(\=.*)', '${1}' & $_new_key & '$3')
	$resdata = StringTrimLeft($resdata, 2)
	Local $FO = FileOpen($iFile, $mode + 2)
	Local $Write = FileWrite($FO, $resdata)
	FileClose($FO)
	If $Write = 0 Then Return SetError(4, 0, 0)
	Return 1
EndFunc   ;==>_IniRenameKey


; 函數名:_IniWrite;=============================================================================
; 說明:　寫入一個值到INI結構文件。
; 語法:　_IniWrite('ini文件路徑', '字段名', '關鍵字', '值'[, 打開模式])
; 返回值:成功: 正常寫入返回1；已存在相同的關鍵字及值則不寫入，返回2。
;　　　　失敗: 返回0。文件具有只讀屬性或者無法寫入數據。
;==========================================================================================start
Func _IniWrite($iFile, $Section, $key, $Val, $mode = 0)
	Local $_Val = StringRegExpReplace($Val, '^\h*(.+?)\h*$', '$1')
	Local $vr = _IniRead($iFile, $Section, $key, @LF, $mode)
	Local $Error = @error, $s_data, $Write
	If $vr = $_Val Then Return 2
	Local $s_File = _FileRead($iFile, $mode)
	Local $_Section = StringRegExpReplace($Section, '^\h*(.+?)\h*$', '$1')
	Local $_key = StringRegExpReplace($key, '^\h*(.+?)\h*$', '$1')
	Local $data = '[' & $_Section & ']' & @CRLF & $_key & '=' & $_Val
	Local $FO = FileOpen($iFile, $mode + 2)
	$_Section = StringRegExpReplace($_Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	$_Section = '\[\h*' & $_Section & '\h*\]'
	$_key = StringRegExpReplace($_key, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\|\=)', '\\$1')
	$_Val = StringRegExpReplace($_Val, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\|\=)', '\\$1')
	Switch $Error
		Case 0
			$s_data = StringRegExpReplace(@CRLF & $s_File & @CRLF & '[', '(?si)(.*?\r?\n\h*' & $_Section & '.*?\r?\n\h*' & $_key & '\h*\=)(\V*)(.*)', '${1}' & $_Val & '$3')
			$s_data = StringTrimLeft($s_data, 2)
			$s_data = StringTrimRight($s_data, 3)
			$Write = FileWrite($FO, $s_data)
		Case 1
			If $s_File <> '' Then $s_File = StringRegExpReplace($s_File, '(\r?\n)*$', '') & @CRLF
			$Write = FileWrite($FO, $s_File & $data & @CRLF)
		Case 2, 3
			$s_data = StringRegExpReplace(@CRLF & $s_File & @CRLF & '[', '(?si)(.*?\r?\n\h*' & $_Section & '.*?)((?:\r?\n)+)(\h*\[.*)', '$1' & @CRLF & $_key & '=' & $_Val & '$2$3')	;131022修正*為+
			$s_data = StringTrimLeft($s_data, 2)
			$s_data = StringTrimRight($s_data, 3)
			$Write = FileWrite($FO, $s_data)
	EndSwitch
	FileClose($FO)
	If $Write = 0 Then Return 0
	Return 1
EndFunc   ;==>_IniWrite


; 函數名:_IniWriteSection;=====================================================================
; 說明:　將數據寫入到INI結構文件的一個字段。
;　　　　且本函數在寫入前會先對數據進行整理，去除無效的鍵值及多余的首尾空格，而非原IniWriteSection
;　　　　函數不加分析的全部寫入。
; 語法:　_IniWriteSection('ini文件路徑', '字段名', '數據'[, '索引'[, 打開模式]])
; 參數:　可選參數'索引'，此參數僅在數據為數組時有效, 指定開始寫入的索引，默認為 1。
; 返回值:成功: 返回1。
;　　　　失敗: 返回0。並設置 @Error 為以下值：
;　　　　　　　　　　　　　　@Error=1 數組非2維或第2維非2；
;　　　　　　　　　　　　　　@Error=2 數據格式錯誤；
;　　　　　　　　　　　　　　@Error=3 文件具有只讀屬性或者無法寫入數據設置。
; 註意:　如果字段已存在，將會先清空原鍵值。
;==========================================================================================start
Func _IniWriteSection($iFile, $Section, $data, $index = 1, $mode = 0)
	Local $_data, $s_data = '', $s_Section = '', $key, $i, $FO, $Write, $CRLF = @CRLF
	If IsArray($data) Then
		If UBound($data, 0) <> 2 Or UBound($data, 2) <> 2 Then Return SetError(1, 0, 0)
		For $i = $index To UBound($data) - 1
			$key = StringRegExpReplace($data[$i][0], '^\h*([^=;\s].+?)\h*$', '$1')
			If Not StringRegExp($key, '^\s*$') Then $s_Section &= $key & '=' & StringRegExpReplace($data[$i][1], '^\h*([^=;\s].+?)\h*$', '$1') & @CRLF
		Next
		If $s_Section = '' Then Return SetError(2, 0, 0)
	Else
		$_data = StringRegExp(@CRLF & $data & @CRLF, '\n\h*([^=;\s].*?)\h*\=\h*(.*?)\h*(?=\r?\n)', 3)
		If @error Then Return SetError(2, 0, 0)
		For $i = 0 To UBound($_data) - 1 Step 2
			$s_Section &= $_data[$i] & '=' & $_data[$i + 1] & @CRLF
		Next
	EndIf
	Local $s_File = _FileRead($iFile, $mode)
	Local $_Section = StringRegExpReplace($Section, '^\h*(.+?)\h*$', '$1')
	$Section = '[' & $_Section & ']' & @CRLF
	$_Section = StringRegExpReplace($_Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	$_Section = '\[\h*' & $_Section & '\h*\]'
	$s_data = StringRegExpReplace(@CRLF & $s_File & @CRLF & '[', '(?si)(.*?\r?\n)\h*' & $_Section & '.*?(\[.*)', '${1}' & $Section & $s_Section & '$2')
	If @extended > 0 Then
		$s_data = StringTrimLeft($s_data, 2)
		$s_data = StringTrimRight($s_data, 3)
	Else
		If $s_File = '' Then $CRLF = ''
		$s_data = StringRegExpReplace($s_File, '(\r?\n)*$', '') & $CRLF & $Section & $s_Section
	EndIf
	$FO = FileOpen($iFile, $mode + 2)
	$Write = FileWrite($FO, $s_data)
	FileClose($FO)
	If $Write = 0 Then Return SetError(3, 0, 0)
	Return 1
EndFunc   ;==>_IniWriteSection


; 函數名:_IniReadSection_str;===================================================================
; 說明:　從(非)標準INI結構文件中讀取某個字段(可選重複字段名)中的所有字符。
; 語法:　_IniReadSection_str('ini文件路徑', '字段名'[, 打開模式[, 重複標誌]])
; 參數:　重複標誌 - [可選]，有些inf文件會有重複的字段名，設置此標誌為1時可讀取所有內容。
; 返回值:成功: 返回字段中的所有字符。
;　　　　失敗: 返回0。如INI文件讀取錯誤或字段不存在將設置 @error=1；字段內容為空將設置 @error=2
;==========================================================================================start
Func _IniReadSection_str($iFile, $Section, $mode = 0, $nFlag = 0)
	Local $s_File = _FileRead($iFile, $mode), $line_all
	Local $_Section = StringRegExpReplace($Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	Local $s_Sec = StringRegExp($s_File & @CRLF & '[', '(?si)(?:^|\n)\h*\[\h*' & $_Section & '\h*\]\V*(.*?)\n\h*(?=\[)', 3)
	If @error Then Return SetError(1, 0, 0)
	$line_all = StringRegExpReplace($s_Sec[0], '^\r?\n|\r$', '')
	If $nFlag Then
        	For $i = 1 To UBound($s_Sec) - 1
                	$line_all &= StringRegExpReplace($s_Sec[$i], '^\r?\n|\r$', '')
        	Next
	Endif
	If Not StringRegExp($line_all, '\V') Then Return SetError(2, 0, 0)
	Return $line_all
EndFunc   ;==>_IniReadSection_str


; 函數名:_IniReadSection_line;===================================================================
; 說明:　從(非)標準INI結構文件中逐行讀取某個字段中的字符到一個1維數組。
; 語法:　_IniReadSection_line('ini文件路徑', '字段名'[, 打開模式[, 重複標誌]])
; 參數:　重複標誌 - [可選]，有些inf文件會有重複的字段名，設置此標誌為1時可讀取所有內容。
; 返回值:成功: 返回一個1維數組，每個元素為字段中一行字符。
;　　　　失敗: 返回0。如INI文件讀取錯誤或字段不存在將設置 @error=1；字段內容為空將設置 @error=2
; 註意:　每行字符串的首尾空格均會排除；不會返回第一個非空格字符為“;”的註釋行。
;==========================================================================================start
Func _IniReadSection_line($iFile, $Section, $mode = 0, $nFlag = 0)
	Local $s_Sec = _IniReadSection_str($iFile, $Section, $mode, $nFlag)
	If @error Then Return SetError(@error, 0, 0)
	Local $s_line = StringRegExp($s_Sec, '(?m)^\h*([^;\s]\V*?)\s*$', 3)
	If @error Then Return SetError(2, 0, 0)
	Return $s_line
EndFunc   ;==>_IniReadSection_line


; 函數名:_FileRead;============================================================================
; 說明:　用FileOpen的打開模式返回讀取文件的字符串
;==========================================================================================start
Func _FileRead($iFile, $mode = 0)
	Local $o_File = FileOpen($iFile, $mode)
	Local $s_File = String(FileRead($o_File))
	FileClose($o_File)
	Return $s_File
EndFunc   ;==>_FileRead


; 函數名:_IniDelete_line;=============================================================================
; 說明:　從(非)標準INI結構文件中刪除(含有)關鍵字的行。
; 語法:　_IniDelete_line('ini文件路徑', '字段名', '關鍵字'[, 匹配標誌[, 打開模式]])
; 參數:　可選參數 匹配標誌，= 0 含有要刪除的關鍵字(默認)； = 1 完整匹配關鍵字。
; 返回值:成功: 返回1。
;　　　　失敗: 返回0。並設置 @Error 為以下值：
;　　　　　　　　　　　　　　@Error=1 文件或字段不存在；
;　　　　　　　　　　　　　　@Error=3 根據匹配標誌未匹配到關鍵字(不存在)；
;　　　　　　　　　　　　　　@Error=4 文件具有只讀屬性或者無法寫入數據設置。
; 註意:　該函數僅執行一次刪除行，如有多行(含有)關鍵字的行需要刪除，可多次執行。
;==========================================================================================start
Func _IniDelete_line($iFile, $Section, $key, $flag = 0, $mode = 0)
	Local $s_File = _FileRead($iFile, $mode)
	Local $_Section = StringRegExpReplace($Section, '^\h*(.+?)\h*$', '$1')
	$_Section = StringRegExpReplace($_Section, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\)', '\\$1')
	$_Section = '\[\h*' & $_Section & '\h*\]'
	If Not StringRegExp(@CRLF & $s_File, '\r?\n\h*' & $_Section & '\s*') Then Return SetError(1, 0, 0)
	Local $_key = StringRegExpReplace($key, '(\.|\||\*|\?|\+|\(|\)|\{|\}|\[|\]|\^|\$|\\|\=)', '\\$1')
	If $flag = 0 Then $_key = '[^\r?\n]*?' & $_key & '.*?'
	Local $s_data = StringRegExpReplace(@CRLF & $s_File & @CRLF, '(?si)(.*?\r?\n\h*' & $_Section & '\h*\r?\n(?:\h*[^\[\r\n]*\r?\n)*?)' & $_key & '\r?\n(.*)', '${1}$2')
	If @Extended = 0 Then Return SetError(3, 0, 0)
	$s_data = StringTrimRight(StringTrimLeft($s_data, 2), 2)
	Local $FO = FileOpen($iFile, $mode + 2)
	Local $Write = FileWrite($FO, $s_data)
	FileClose($FO)
	If $Write = 0 Then Return SetError(4, 0, 0)
	Return 1
EndFunc   ;==>_IniDelete_line

