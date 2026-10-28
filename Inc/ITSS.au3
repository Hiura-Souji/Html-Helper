#include-once
#include <Array.au3>

; AutoIt-only, read-only Windows ITSS COM binding. No helper DLL or HH viewer.
Global Const $__ITSS_CLSID="{5D02926A-212E-11D0-9DF9-00A0C922E6EC}"
Global Const $__ITSS_IID="{88CC31DE-27AB-11D0-9DF9-00A0C922E6EC}"
Global Const $__ITSS_FACTORY_IID="{00000001-0000-0000-C000-000000000046}"
Global Const $__ITSS_PTR=(@AutoItX64 ? 8 : 4)
Global Const $__ITSS_STAT="align 8;ptr Name;dword Type;uint64 Size;dword MTime[2];dword CTime[2];dword ATime[2];dword Mode;dword Locks;byte ClassID[16];dword StateBits;dword Reserved"
Global $__ITSS_Dll=-1,$__ITSS_Engine=0,$__ITSS_Thread=0,$__ITSS_CoOwn=False,$__ITSS_ExitHook=False
Global $__ITSS_Docs[0][3],$__ITSS_Streams[0][2],$__ITSS_HR=0,$__ITSS_Where=""

Func _ITSS_LastErrorText()
    Return $__ITSS_Where & "｜HRESULT=0x" & Hex($__ITSS_HR,8)
EndFunc
Func _ITSS_LastHResult()
    Return $__ITSS_HR
EndFunc
Func __ITSS_Fail($error,$hr,$where,$value=0)
    $__ITSS_HR=$hr
    $__ITSS_Where=$where
    Return SetError($error,$hr,$value)
EndFunc
Func __ITSS_Tid()
    Local $r=DllCall("kernel32.dll","dword","GetCurrentThreadId")
    If @error Or Not IsArray($r) Then Return 0
    Return $r[0]
EndFunc
Func __ITSS_CheckThread()
    If $__ITSS_Thread<>0 And __ITSS_Tid()=$__ITSS_Thread Then Return True
    Return __ITSS_Fail(4,0,"ITSS 必須在建立它的同一執行緒使用",False)
EndFunc
Func __ITSS_Method($object,$slot)
    Local $v=DllStructGetData(DllStructCreate("ptr",$object),1)
    Return DllStructGetData(DllStructCreate("ptr",$v+$slot*$__ITSS_PTR),1)
EndFunc
Func __ITSS_Release($object)
    If $object=0 Then Return
    DllCallAddress("ulong",__ITSS_Method($object,2),"ptr",$object)
EndFunc
Func __ITSS_Guid($text)
    Local $g=DllStructCreate("byte[16]")
    Local $r=DllCall("ole32.dll","long","CLSIDFromString","wstr",$text,"ptr",DllStructGetPtr($g))
    If @error Or Not IsArray($r) Then Return SetError(1,0,0)
    If $r[0]<0 Then Return SetError(1,$r[0],0)
    Return $g
EndFunc
Func __ITSS_UndoCo()
    If $__ITSS_CoOwn Then DllCall("ole32.dll","none","CoUninitialize")
    $__ITSS_CoOwn=False
    $__ITSS_Thread=0
EndFunc

Func _ITSS_Init()
    If $__ITSS_Engine<>0 Then
        If Not __ITSS_CheckThread() Then Return SetError(4,0,False)
        Return SetError(0,0,True)
    EndIf
    Local $thread=__ITSS_Tid()
    If $thread=0 Then Return __ITSS_Fail(2,0,"無法取得執行緒 ID",False)
    Local $r=DllCall("ole32.dll","long","CoInitializeEx","ptr",0,"dword",2)
    If @error Or Not IsArray($r) Then Return __ITSS_Fail(2,0,"CoInitializeEx 呼叫失敗",False)
    If $r[0]>=0 Then
        $__ITSS_CoOwn=True
    ElseIf Hex($r[0],8)="80010106" Then
        $__ITSS_CoOwn=False ; Caller already owns a different apartment model.
    Else
        Return __ITSS_Fail(2,$r[0],"CoInitializeEx 失敗",False)
    EndIf
    $__ITSS_Thread=$thread
    If $__ITSS_Dll=-1 Then $__ITSS_Dll=DllOpen(@SystemDir & "\itss.dll")
    If $__ITSS_Dll=-1 Then
        __ITSS_UndoCo()
        Return __ITSS_Fail(2,0,"無法載入系統 itss.dll",False)
    EndIf
    Local $clsid=__ITSS_Guid($__ITSS_CLSID),$factoryIID=__ITSS_Guid($__ITSS_FACTORY_IID),$iid=__ITSS_Guid($__ITSS_IID)
    If Not IsDllStruct($clsid) Or Not IsDllStruct($factoryIID) Or Not IsDllStruct($iid) Then
        __ITSS_UndoCo()
        Return __ITSS_Fail(2,0,"GUID 轉換失敗",False)
    EndIf
    $r=DllCall($__ITSS_Dll,"long","DllGetClassObject","ptr",DllStructGetPtr($clsid),"ptr",DllStructGetPtr($factoryIID),"ptr*",0)
    If @error Or Not IsArray($r) Then
        __ITSS_UndoCo()
        Return __ITSS_Fail(2,0,"itss.dll!DllGetClassObject 呼叫失敗",False)
    EndIf
    If $r[0]<0 Or $r[3]=0 Then
        Local $hr=$r[0]
        __ITSS_UndoCo()
        Return __ITSS_Fail(2,$hr,"無法取得 ITStorage 類別工廠",False)
    EndIf
    Local $factory=$r[3]
    $r=DllCallAddress("long",__ITSS_Method($factory,3),"ptr",$factory,"ptr",0,"ptr",DllStructGetPtr($iid),"ptr*",0)
    Local $err=@error
    __ITSS_Release($factory)
    If $err Or Not IsArray($r) Then
        __ITSS_UndoCo()
        Return __ITSS_Fail(2,0,"IClassFactory::CreateInstance 呼叫失敗",False)
    EndIf
    If $r[0]<0 Or $r[4]=0 Then
        $hr=$r[0]
        __ITSS_UndoCo()
        Return __ITSS_Fail(2,$hr,"無法建立 IITStorage",False)
    EndIf
    $__ITSS_Engine=$r[4]
    If Not $__ITSS_ExitHook Then
        OnAutoItExitRegister("_ITSS_Shutdown")
        $__ITSS_ExitHook=True
    EndIf
    $__ITSS_HR=0
    $__ITSS_Where=""
    Return SetError(0,0,True)
EndFunc

Func __ITSS_DocIndex($doc)
    For $i=0 To UBound($__ITSS_Docs)-1
        If $__ITSS_Docs[$i][0]=$doc Then Return $i
    Next
    Return -1
EndFunc
Func __ITSS_StreamIndex($stream)
    For $i=0 To UBound($__ITSS_Streams)-1
        If $__ITSS_Streams[$i][0]=$stream Then Return $i
    Next
    Return -1
EndFunc
Func _ITSS_Open($path)
    If Not _ITSS_Init() Then Return SetError(@error,@extended,0)
    If Not FileExists($path) Or StringInStr(FileGetAttrib($path),"D") Then Return __ITSS_Fail(1,0,"CHM 檔案不存在",0)
    Local $h=FileOpen($path,16)
    If $h=-1 Then Return __ITSS_Fail(1,0,"無法讀取 CHM 檔案",0)
    Local $signature=FileRead($h,4)
    FileClose($h)
    If $signature<>Binary("0x49545346") Then Return __ITSS_Fail(1,0,"檔案開頭不是 CHM ITSF 標記",0)
    Local $full=DllCall("kernel32.dll","dword","GetFullPathNameW","wstr",$path,"dword",32768,"wstr","","ptr",0)
    If Not @error And IsArray($full) Then
        If $full[0]>0 And $full[0]<32768 Then $path=$full[3]
    EndIf
    Local $modes[2]=[0x20,0x10],$r,$root=0,$hr=0,$mode=0
    For $i=0 To 1
        $mode=$modes[$i] ; STGM_READ only, never WRITE/CREATE/CONVERT.
        ; IITStorage::StgOpenStorage is slot 7 (including IUnknown).
        $r=DllCallAddress("long",__ITSS_Method($__ITSS_Engine,7),"ptr",$__ITSS_Engine,"wstr",$path,"ptr",0,"dword",$mode,"ptr",0,"dword",0,"ptr*",0)
        If @error Or Not IsArray($r) Then Return __ITSS_Fail(3,0,"IITStorage::StgOpenStorage 呼叫失敗",0)
        $hr=$r[0]
        If $hr>=0 And $r[7]<>0 Then
            $root=$r[7]
            ExitLoop
        EndIf
    Next
    If $root=0 Then Return __ITSS_Fail(3,$hr,"IITStorage 無法開啟 CHM",0)
    Local $n=UBound($__ITSS_Docs)
    ReDim $__ITSS_Docs[$n+1][3]
    $__ITSS_Docs[$n][0]=$root
    $__ITSS_Docs[$n][1]=$mode
    $__ITSS_Docs[$n][2]=$path
    Return SetError(0,0,$root)
EndFunc
Func _ITSS_Close(ByRef $doc)
    If Not __ITSS_CheckThread() Then Return SetError(4,0,False)
    Local $idx=__ITSS_DocIndex($doc)
    If $idx<0 Then Return __ITSS_Fail(5,0,"無效或已關閉的文件指標",False)
    For $i=UBound($__ITSS_Streams)-1 To 0 Step -1
        If $__ITSS_Streams[$i][1]=$doc Then
            Local $stream=$__ITSS_Streams[$i][0]
            _ITSS_StreamClose($stream)
        EndIf
    Next
    __ITSS_Release($doc)
    _ArrayDelete($__ITSS_Docs,$idx)
    $doc=0
    Return SetError(0,0,True)
EndFunc
Func _ITSS_Shutdown()
    If $__ITSS_Thread=0 Then Return True
    If Not __ITSS_CheckThread() Then Return SetError(4,0,False)
    While UBound($__ITSS_Streams)>0
        Local $stream=$__ITSS_Streams[UBound($__ITSS_Streams)-1][0]
        _ITSS_StreamClose($stream)
    WEnd
    While UBound($__ITSS_Docs)>0
        Local $doc=$__ITSS_Docs[UBound($__ITSS_Docs)-1][0]
        _ITSS_Close($doc)
    WEnd
    __ITSS_Release($__ITSS_Engine)
    $__ITSS_Engine=0
    __ITSS_UndoCo()
    ; Keep the system DLL mapped until process exit; COM pointers have been released.
    Return True
EndFunc

Func __ITSS_OpenStorage($parent,$name,$mode)
    Local $r=DllCallAddress("long",__ITSS_Method($parent,6),"ptr",$parent,"wstr",$name,"ptr",0,"dword",$mode,"ptr",0,"dword",0,"ptr*",0)
    If @error Or Not IsArray($r) Then Return SetError(3,0,0)
    If $r[0]<0 Or $r[7]=0 Then Return SetError(3,$r[0],0)
    Return SetError(0,0,$r[7])
EndFunc
Func __ITSS_OpenStream($storage,$name,$mode)
    Local $r=DllCallAddress("long",__ITSS_Method($storage,4),"ptr",$storage,"wstr",$name,"ptr",0,"dword",$mode,"dword",0,"ptr*",0)
    If @error Or Not IsArray($r) Then Return SetError(3,0,0)
    If $r[0]<0 Or $r[6]=0 Then Return SetError(3,$r[0],0)
    Return SetError(0,0,$r[6])
EndFunc
Func _ITSS_StreamOpen($doc,$name)
    If Not __ITSS_CheckThread() Then Return SetError(4,0,0)
    Local $idx=__ITSS_DocIndex($doc)
    If $idx<0 Then Return __ITSS_Fail(5,0,"無效文件指標",0)
    $name=StringReplace($name,"\","/")
    While StringLeft($name,1)="/"
        $name=StringTrimLeft($name,1)
    WEnd
    If $name="" Or StringInStr($name,Chr(0)) Then Return __ITSS_Fail(9,0,"內部路徑不可空白或含 NUL",0)
    Local $parts=StringSplit($name,"/",1)
    For $i=1 To $parts[0]
        If $parts[$i]="" Or $parts[$i]="." Or $parts[$i]=".." Then Return __ITSS_Fail(9,0,"內部路徑包含無效區段",0)
    Next
    Local $mode=$__ITSS_Docs[$idx][1]
    ; Some ITSS implementations accept a complete internal name directly.
    Local $stream=__ITSS_OpenStream($doc,$name,$mode),$hr=@extended
    If $stream=0 And $parts[0]>1 Then
        Local $current=$doc,$own=False,$failed=False
        For $i=1 To $parts[0]-1
            Local $next=__ITSS_OpenStorage($current,$parts[$i],$mode)
            $hr=@extended
            If $next=0 Then
                $failed=True
                ExitLoop
            EndIf
            If $own Then __ITSS_Release($current)
            $current=$next
            $own=True
        Next
        If Not $failed Then
            $stream=__ITSS_OpenStream($current,$parts[$parts[0]],$mode)
            $hr=@extended
        EndIf
        If $own Then __ITSS_Release($current)
    EndIf
    If $stream=0 Then Return __ITSS_Fail(3,$hr,"IStorage::OpenStream 失敗：" & $name,0)
    Local $n=UBound($__ITSS_Streams)
    ReDim $__ITSS_Streams[$n+1][2]
    $__ITSS_Streams[$n][0]=$stream
    $__ITSS_Streams[$n][1]=$doc
    Return SetError(0,0,$stream)
EndFunc
Func _ITSS_StreamClose(ByRef $stream)
    If Not __ITSS_CheckThread() Then Return SetError(4,0,False)
    Local $idx=__ITSS_StreamIndex($stream)
    If $idx<0 Then Return __ITSS_Fail(5,0,"無效或已關閉的串流指標",False)
    __ITSS_Release($stream)
    _ArrayDelete($__ITSS_Streams,$idx)
    $stream=0
    Return SetError(0,0,True)
EndFunc
Func _ITSS_StreamSize($stream)
    If Not __ITSS_CheckThread() Then Return SetError(4,0,-1)
    If __ITSS_StreamIndex($stream)<0 Then Return __ITSS_Fail(5,0,"無效串流指標",-1)
    Local $stat=DllStructCreate($__ITSS_STAT)
    If DllStructGetSize($stat)<>(@AutoItX64 ? 80 : 72) Then Return __ITSS_Fail(10,0,"STATSTG 結構大小錯誤",-1)
    Local $r=DllCallAddress("long",__ITSS_Method($stream,12),"ptr",$stream,"ptr",DllStructGetPtr($stat),"dword",1)
    If @error Or Not IsArray($r) Then Return __ITSS_Fail(6,0,"IStream::Stat 呼叫失敗",-1)
    If $r[0]<0 Then Return __ITSS_Fail(6,$r[0],"IStream::Stat 失敗",-1)
    Return SetError(0,0,DllStructGetData($stat,"Size"))
EndFunc
Func _ITSS_StreamSeek($stream,$offset,$origin=0)
    If Not __ITSS_CheckThread() Then Return SetError(4,0,-1)
    If __ITSS_StreamIndex($stream)<0 Then Return __ITSS_Fail(5,0,"無效串流指標",-1)
    If $origin<0 Or $origin>2 Then Return __ITSS_Fail(9,0,"Seek origin 必須為 0/1/2",-1)
    Local $r=DllCallAddress("long",__ITSS_Method($stream,5),"ptr",$stream,"int64",$offset,"dword",$origin,"uint64*",0)
    If @error Or Not IsArray($r) Then Return __ITSS_Fail(6,0,"IStream::Seek 呼叫失敗",-1)
    If $r[0]<0 Then Return __ITSS_Fail(6,$r[0],"IStream::Seek 失敗",-1)
    Return SetError(0,0,$r[4])
EndFunc
Func _ITSS_StreamRead($stream,$count=65536)
    If Not __ITSS_CheckThread() Then Return SetError(4,0,Binary(""))
    If __ITSS_StreamIndex($stream)<0 Then Return __ITSS_Fail(5,0,"無效串流指標",Binary(""))
    If $count<1 Or $count>16777216 Or Int($count)<>$count Then Return __ITSS_Fail(9,0,"單次讀取需為 1～16MiB 的整數",Binary(""))
    Local $buffer=DllStructCreate("byte[" & $count & "]")
    If @error Then Return __ITSS_Fail(7,0,"無法配置串流緩衝區",Binary(""))
    Local $r=DllCallAddress("long",__ITSS_Method($stream,3),"ptr",$stream,"ptr",DllStructGetPtr($buffer),"ulong",$count,"ulong*",0)
    If @error Or Not IsArray($r) Then Return __ITSS_Fail(6,0,"IStream::Read 呼叫失敗",Binary(""))
    If $r[0]<0 Then Return __ITSS_Fail(6,$r[0],"IStream::Read 失敗",Binary(""))
    If $r[4]>$count Then Return __ITSS_Fail(6,0,"串流回傳讀取長度錯誤",Binary(""))
    If $r[4]=0 Then Return SetError(0,0,Binary(""))
    Return SetError(0,$r[4],BinaryMid(DllStructGetData($buffer,1),1,$r[4]))
EndFunc

Func _ITSS_Read($doc,$name,$limit=67108864)
    Local $stream=_ITSS_StreamOpen($doc,$name)
    If @error Then Return SetError(@error,@extended,Binary(""))
    Local $size=_ITSS_StreamSize($stream),$e=@error,$hr=@extended
    If $e Then
        _ITSS_StreamClose($stream)
        Return SetError($e,$hr,Binary(""))
    EndIf
    If $size<0 Or $size>2147483632 Or ($limit>0 And $size>$limit) Then
        _ITSS_StreamClose($stream)
        Return __ITSS_Fail(7,0,"資源超過整份讀取限制；請使用串流 API",Binary(""))
    EndIf
    If $size=0 Then
        _ITSS_StreamClose($stream)
        Return SetError(0,0,Binary(""))
    EndIf
    Local $buffer=DllStructCreate("byte[" & $size & "]")
    If @error Then
        _ITSS_StreamClose($stream)
        Return __ITSS_Fail(7,0,"無法配置整份資源緩衝區",Binary(""))
    EndIf
    Local $offset=0,$err=0,$where=""
    While $offset<$size
        Local $wanted=$size-$offset
        If $wanted>1048576 Then $wanted=1048576
        Local $r=DllCallAddress("long",__ITSS_Method($stream,3),"ptr",$stream,"ptr",DllStructGetPtr($buffer)+$offset,"ulong",$wanted,"ulong*",0)
        If @error Or Not IsArray($r) Then
            $err=6
            $hr=0
            $where="IStream::Read 呼叫失敗"
            ExitLoop
        EndIf
        If $r[0]<0 Or $r[4]=0 Or $r[4]>$wanted Then
            $err=6
            $hr=$r[0]
            $where="資源讀取失敗或提早結束，未回傳不完整內容"
            ExitLoop
        EndIf
        $offset+=$r[4]
    WEnd
    _ITSS_StreamClose($stream)
    If $err Then Return __ITSS_Fail($err,$hr,$where,Binary(""))
    Return SetError(0,$size,DllStructGetData($buffer,1))
EndFunc

Func __ITSS_ReadName($ptr)
    If $ptr=0 Then Return SetError(8,0,"")
    Local $r=DllCall("kernel32.dll","int","lstrlenW","ptr",$ptr)
    If @error Or Not IsArray($r) Then Return SetError(8,0,"")
    If $r[0]<1 Or $r[0]>32767 Then Return SetError(8,0,"")
    Return SetError(0,0,DllStructGetData(DllStructCreate("wchar[" & ($r[0]+1) & "]",$ptr),1))
EndFunc
Func __ITSS_FreeName($ptr)
    If $ptr<>0 Then DllCall("ole32.dll","none","CoTaskMemFree","ptr",$ptr)
EndFunc
Func __ITSS_Walk($storage,$prefix,$depth,$mode,$recursive,$maxEntries, ByRef $rows, ByRef $count)
    If $depth>64 Then Return __ITSS_Fail(7,0,"儲存區深度超過 64，未回傳不完整清單",False)
    Local $r=DllCallAddress("long",__ITSS_Method($storage,11),"ptr",$storage,"dword",0,"ptr",0,"dword",0,"ptr*",0)
    If @error Or Not IsArray($r) Then Return __ITSS_Fail(8,0,"IStorage::EnumElements 呼叫失敗",False)
    If $r[0]<0 Or $r[5]=0 Then Return __ITSS_Fail(8,$r[0],"IStorage::EnumElements 失敗",False)
    Local $enumerator=$r[5],$stat=DllStructCreate($__ITSS_STAT),$ok=True
    If DllStructGetSize($stat)<>(@AutoItX64 ? 80 : 72) Then
        __ITSS_Release($enumerator)
        Return __ITSS_Fail(10,0,"STATSTG 結構大小錯誤",False)
    EndIf
    While True
        DllStructSetData($stat,"Name",0)
        $r=DllCallAddress("long",__ITSS_Method($enumerator,3),"ptr",$enumerator,"ulong",1,"ptr",DllStructGetPtr($stat),"ulong*",0)
        Local $err=@error,$namePtr=DllStructGetData($stat,"Name")
        If $err Or Not IsArray($r) Then
            __ITSS_FreeName($namePtr)
            __ITSS_Fail(8,0,"IEnumSTATSTG::Next 呼叫失敗",False)
            $ok=False
            ExitLoop
        EndIf
        If $r[0]<0 Then
            __ITSS_FreeName($namePtr)
            __ITSS_Fail(8,$r[0],"IEnumSTATSTG::Next 失敗",False)
            $ok=False
            ExitLoop
        EndIf
        If $r[4]=0 Then
            __ITSS_FreeName($namePtr)
            ExitLoop
        EndIf
        Local $name=__ITSS_ReadName($namePtr),$nameError=@error
        __ITSS_FreeName($namePtr)
        If $nameError Then
            __ITSS_Fail(8,0,"列舉項目名稱無效",False)
            $ok=False
            ExitLoop
        EndIf
        If $maxEntries>0 And $count>=$maxEntries Then
            __ITSS_Fail(7,0,"超過列舉上限，未回傳不完整清單",False)
            $ok=False
            ExitLoop
        EndIf
        If $count>=UBound($rows) Then ReDim $rows[UBound($rows)*2][3]
        Local $path=$prefix & StringReplace($name,"\","/")
        While StringLeft($path,1)="/"
            $path=StringTrimLeft($path,1)
        WEnd
        Local $type=DllStructGetData($stat,"Type")
        $rows[$count][0]=$path
        $rows[$count][1]=$type
        $rows[$count][2]=DllStructGetData($stat,"Size")
        $count+=1
        If $type=1 And $recursive Then
            Local $child=__ITSS_OpenStorage($storage,$name,$mode),$hr=@extended
            If $child=0 Then
                __ITSS_Fail(8,$hr,"無法列舉子儲存區：" & $path,False)
                $ok=False
                ExitLoop
            EndIf
            Local $childOk=__ITSS_Walk($child,$path & "/",$depth+1,$mode,$recursive,$maxEntries,$rows,$count)
            __ITSS_Release($child)
            If Not $childOk Then
                $ok=False
                ExitLoop
            EndIf
        EndIf
    WEnd
    __ITSS_Release($enumerator)
    Return $ok
EndFunc
Func _ITSS_Enum($doc,$recursive=True,$maxEntries=100000)
    If Not __ITSS_CheckThread() Then Return SetError(4,0,0)
    Local $idx=__ITSS_DocIndex($doc)
    If $idx<0 Then Return __ITSS_Fail(5,0,"無效文件指標",0)
    Local $rows[64][3],$count=0
    If Not __ITSS_Walk($doc,"",0,$__ITSS_Docs[$idx][1],$recursive,$maxEntries,$rows,$count) Then Return SetError(8,$__ITSS_HR,0)
    ReDim $rows[$count][3]
    Return SetError(0,$count,$rows)
EndFunc
Func _ITSS_List($doc,$maxEntries=100000)
    Local $rows=_ITSS_Enum($doc,True,$maxEntries)
    If @error Then Return SetError(@error,@extended,0)
    Local $names[UBound($rows)],$count=0
    For $i=0 To UBound($rows)-1
        If $rows[$i][1]=2 Then
            $names[$count]=$rows[$i][0]
            $count+=1
        EndIf
    Next
    ReDim $names[$count]
    Return SetError(0,$count,$names)
EndFunc

; Compatibility wrappers for the existing Html Helper. No bridge DLL needed.
Func ITSS_List($archive)
    Local $doc=_ITSS_Open($archive)
    If @error Then Return SetError(@error,@extended,0)
    Local $names=_ITSS_List($doc),$err=@error,$hr=@extended
    _ITSS_Close($doc)
    Return SetError($err,$hr,$names)
EndFunc
Func ITSS_Read($archive,$inner,$limit=67108864)
    Local $doc=_ITSS_Open($archive)
    If @error Then Return SetError(@error,@extended,Binary(""))
    Local $bytes=_ITSS_Read($doc,$inner,$limit),$err=@error,$hr=@extended
    _ITSS_Close($doc)
    Return SetError($err,$hr,$bytes)
EndFunc
