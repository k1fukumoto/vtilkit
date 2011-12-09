Attribute VB_Name = "VTILLAB"
Function ListSubdirs(path)
    Dim subdirs() As String
    Dim name As String
    
    i = 0
    name = Dir(path, vbDirectory)
    Do While Len(name) > 0
        If (name = ".") Or (name = "..") Or _
        (name Like "*.csv") Or (name Like "*.xml") Then
        
        Else
            ReDim Preserve subdirs(i)
            subdirs(i) = name
            i = i + 1
        End If

        name = Dir()
    Loop
    ListSubdirs = subdirs
End Function

Sub RefreshAllData()
    ActiveWorkbook.RefreshAll
End Sub

Function SheetName_ESX(pref, host)
' Do some tricks to make the sheet name shorter enough, when needed.
' Following line is one of the example which extracts the host name part from FQDN.
'    arr = Split(host, ".")
    SheetName_ESX = pref & host
End Function

Sub DeployNewBook()
    dataroot = range("DATAROOT")
    destpath = range("CAPMGMTPATH")
    destbase = range("CAPMGMTBOOK")

    tmpl = ActiveWorkbook.name
    
    clusters = ListSubdirs(dataroot & "\cluster\")
    For Each C In clusters
        destsheet = destbase & "-" & C & ".xls"
        Workbooks(tmpl).Sheets(Array("CONSOLE-<cluster>", "CLSTR-<cluster>", "CLSTRDATA-<cluster>")).Copy
        ActiveWorkbook.SaveAs Filename:=destpath & "\" & destsheet
        Call DeployCluster(dataroot, C)
        prev = "CLSTR-" & C
    
        hosts = ListSubdirs(dataroot & "\cluster\" & C & "\host\")
        For Each esx In hosts
            Workbooks(tmpl).Sheets(Array("ESX-<esx>", "ESXPERF-<esx>", "ESXDATA-<esx>")).Copy After:= _
                Workbooks(destsheet).Sheets(prev)
            Call DeployESX(dataroot, C, esx)
            prev = SheetName_ESX("ESXPERF-", esx)
        Next esx
    Next C
End Sub


Sub DeployCluster(dataroot, cluster)
    Sheets("CONSOLE-<cluster>").name = "CONSOLE-" & cluster
    
    Sheets("CLSTRDATA-<cluster>").Select
    Sheets("CLSTRDATA-<cluster>").name = "CLSTRDATA-" & cluster
    
    Call RefreshCLSTRDATA(dataroot, cluster)
    
    Sheets("CLSTR-<cluster>").Select
    Sheets("CLSTR-<cluster>").name = "CLSTR-" & cluster
    
    Call RefreshCLSTR(cluster)
    
    Sheets("CLSTRDATA-" & cluster).Visible = False
End Sub
Sub test()
    dataroot = "c:\kaoru\DK\VTIL\SampleData\vCenterFJ\data"
    cluster = "VS_cluster"

 '   Call RefreshCLSTRDATA(dataroot, cluster)
    Call RefreshCLSTR("<cluster>")
    

End Sub

Sub AddQueryTable(path, r, name, dtypes)
    With ActiveSheet.QueryTables.Add(Connection:= _
        "TEXT;" & path _
        , Destination:=range(r))
        .name = name
        .FieldNames = True
        .RowNumbers = False
        .FillAdjacentFormulas = False
        .PreserveFormatting = True
        .RefreshOnFileOpen = False
        .RefreshStyle = xlInsertDeleteCells
        .SavePassword = False
        .SaveData = True
        .AdjustColumnWidth = True
        .RefreshPeriod = 0
        .TextFilePromptOnRefresh = False
        .TextFilePlatform = 932
        .TextFileStartRow = 1
        .TextFileParseType = xlDelimited
        .TextFileTextQualifier = xlTextQualifierDoubleQuote
        .TextFileConsecutiveDelimiter = False
        .TextFileTabDelimiter = True
        .TextFileSemicolonDelimiter = False
        .TextFileCommaDelimiter = True
        .TextFileSpaceDelimiter = False
        .TextFileColumnDataTypes = dtypes
        .TextFileTrailingMinusNumbers = True
        .Refresh BackgroundQuery:=False
    End With
End Sub

Sub RefreshCLSTRDATA(dataroot, cluster)

    For Each gdef In Array( _
        Array("B2:N100", "cpu_memory", "\cpu_memory.csv", Array(5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)), _
        Array("B101:G150", "cpu_4weeks", "\cpu.usage.average\4weeks_latest.csv", Array(1, 1, 1, 1, 1)), _
        Array("B151:G200", "mem_4weeks", "\mem.usage.average\4weeks_latest.csv", Array(1, 1, 1, 1, 1)), _
        Array("B201:G250", "disk_4weeks", "\disk.usage.average\4weeks_latest.csv", Array(1, 1, 1, 1, 1)), _
        Array("B251:F305", "cpu_breakdown", "\vm_cpu_breakdown.csv", Array(1, 1, 1, 1, 1)) _
    )
        range(gdef(0)).Select
        Selection.QueryTable.Delete
        Selection.ClearContents
    
        path = dataroot & "\cluster\" & cluster & gdef(2)
        Call AddQueryTable(path, gdef(0), gdef(1), gdef(3))
        
    Next gdef
End Sub
    
Sub RefreshCLSTR(cluster)
    
    ActiveSheet.ChartObjects("CPUMEM").Activate
    ActiveChart.SeriesCollection(1).XValues = _
        "='CLSTRDATA-" & cluster & "'!R3C2:R93C2"
    
    ActiveChart.SeriesCollection(1).name = "='CLSTRDATA-" & cluster & "'!R2C27"
    ActiveChart.SeriesCollection(1).Values = _
        "='CLSTRDATA-" & cluster & "'!R3C27:R93C27"
    
    ActiveChart.SeriesCollection(2).name = "='CLSTRDATA-" & cluster & "'!R2C18"
    ActiveChart.SeriesCollection(2).Values = _
        "='CLSTRDATA-" & cluster & "'!R3C18:R93C18"
    
    ActiveChart.SeriesCollection(3).name = "='CLSTRDATA-" & cluster & "'!R2C21"
    ActiveChart.SeriesCollection(3).Values = _
        "='CLSTRDATA-" & cluster & "'!R3C21:R93C21"
    
    ActiveChart.SeriesCollection(4).name = "='CLSTRDATA-" & cluster & "'!R2C22"
    ActiveChart.SeriesCollection(4).Values = _
        "='CLSTRDATA-" & cluster & "'!R3C22:R93C22"
    
    ActiveChart.SeriesCollection(5).name = "='CLSTRDATA-" & cluster & "'!R2C5"
    ActiveChart.SeriesCollection(5).Values = _
        "='CLSTRDATA-" & cluster & "'!R3C5:R93C5"
    
    ActiveChart.ChartTitle.Text = _
        "�L���p�V�e�B���̓O���t (�N���X�^���x��: CPU / �������g�p�� / Power ON VM��)" & Chr(10) & cluster
    
    ActiveSheet.ChartObjects("MEMVM").Activate
    ActiveChart.SeriesCollection(1).XValues = "='CLSTRDATA-" & cluster & "'!R3C2:R93C2"
    
    ActiveChart.SeriesCollection(1).name = "='CLSTRDATA-" & cluster & "'!R2C23"
    ActiveChart.SeriesCollection(1).Values = "='CLSTRDATA-" & cluster & "'!R3C23:R93C23"
    
    ActiveChart.SeriesCollection(2).name = "='CLSTRDATA-" & cluster & "'!R2C24"
    ActiveChart.SeriesCollection(2).Values = "='CLSTRDATA-" & cluster & "'!R3C24:R93C24"
    
    ActiveChart.SeriesCollection(3).name = "='CLSTRDATA-" & cluster & "'!R2C25"
    ActiveChart.SeriesCollection(3).Values = "='CLSTRDATA-" & cluster & "'!R3C25:R93C25"
    
    ActiveChart.SeriesCollection(4).name = "='CLSTRDATA-" & cluster & "'!R2C26"
    ActiveChart.SeriesCollection(4).Values = "='CLSTRDATA-" & cluster & "'!R3C26:R93C26"
    ActiveChart.ChartTitle.Text = _
        "�L���p�V�e�B���̓O���t (�N���X�^���x��: �������g�p��/ ���z�}�V������̃������g�p��)" & Chr(10) & cluster

    ActiveSheet.ChartObjects("MEMPERF").Activate
    ActiveChart.SeriesCollection(1).XValues = _
        "='CLSTRDATA-" & cluster & "'!R3C2:R93C2"
        
    ActiveChart.SeriesCollection(1).name = "='CLSTRDATA-" & cluster & "'!R2C11"
    ActiveChart.SeriesCollection(1).Values = "='CLSTRDATA-" & cluster & "'!R3C11:R93C11"
    
    ActiveChart.SeriesCollection(2).name = "='CLSTRDATA-" & cluster & "'!R2C12"
    ActiveChart.SeriesCollection(2).Values = "='CLSTRDATA-" & cluster & "'!R3C12:R93C12"
    
    ActiveChart.SeriesCollection(3).name = "='CLSTRDATA-" & cluster & "'!R2C6"
    ActiveChart.SeriesCollection(3).Values = "='CLSTRDATA-" & cluster & "'!R3C6:R93C6"
    
    ActiveChart.ChartTitle.Text = _
        "�L���p�V�e�B���̓O���t (�N���X�^���x��: �o���[�� / �X���b�v ������ / Power ON VM��)" & Chr(10) & cluster
               
    r0 = 102
    r1 = range("'CLSTRDATA-" & cluster & "'!" & "R100").Value + r0 - 1
    r0 = "R" & r0
    r1 = "R" & r1
    
    ActiveSheet.ChartObjects("CPU").Activate
    ActiveChart.SeriesCollection(1).XValues = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C2:" & r1 & "C2"
        
    ActiveChart.SeriesCollection(1).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C21:" & r1 & "C21"
    ActiveChart.SeriesCollection(2).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C20:" & r1 & "C20"
    ActiveChart.SeriesCollection(3).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C19:" & r1 & "C19"
    ActiveChart.SeriesCollection(4).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C18:" & r1 & "C18"
    ActiveChart.ChartTitle.Text = _
        "�L���p�V�e�B���̓O���t (�N���X�^���x��: ESX�z�X�g����CPU�g�p��)" & Chr(10) & cluster
    
    r0 = 152
    r1 = range("'CLSTRDATA-" & cluster & "'!" & "R150").Value + r0 - 1
    r0 = "R" & r0
    r1 = "R" & r1
    
    ActiveSheet.ChartObjects("Memory").Activate
    ActiveChart.SeriesCollection(1).XValues = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C2:" & r1 & "C2"
    
    ActiveChart.SeriesCollection(1).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C21:" & r1 & "C21"
    ActiveChart.SeriesCollection(2).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C20:" & r1 & "C20"
    ActiveChart.SeriesCollection(3).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C19:" & r1 & "C19"
    ActiveChart.SeriesCollection(4).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C18:" & r1 & "C18"
    ActiveChart.ChartTitle.Text = _
        "�L���p�V�e�B���̓O���t (�N���X�^���x��: ESX�z�X�g���̃������g�p��)" & Chr(10) & cluster
    
    r0 = 202
    r1 = range("'CLSTRDATA-" & cluster & "'!" & "R200").Value + r0 - 1
    r0 = "R" & r0
    r1 = "R" & r1
    
    ActiveSheet.ChartObjects("Disk").Activate
    ActiveChart.SeriesCollection(1).XValues = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C2:" & r1 & "C2"
        
    ActiveChart.SeriesCollection(1).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C6:" & r1 & "C6"
    ActiveChart.SeriesCollection(2).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C5:" & r1 & "C5"
    ActiveChart.SeriesCollection(3).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C4:" & r1 & "C4"
    ActiveChart.SeriesCollection(4).Values = _
        "='CLSTRDATA-" & cluster & "'!" & r0 & "C3:" & r1 & "C3"
    ActiveChart.ChartTitle.Text = _
        "�L���p�V�e�B���̓O���t (�N���X�^���x��: ESX�z�X�g���̃f�B�X�N�g�p��)" & Chr(10) & cluster
    
    ActiveSheet.ChartObjects("CPU Breakdown").Activate
    ActiveChart.SeriesCollection(1).XValues = _
        "='CLSTRDATA-" & cluster & "'!R252C2:R255C2"
    ActiveChart.SeriesCollection(1).Values = _
        "='CLSTRDATA-" & cluster & "'!R252C18:R255C18"
    ActiveChart.SeriesCollection(2).Values = _
        "='CLSTRDATA-" & cluster & "'!R252C19:R255C19"
    ActiveChart.SeriesCollection(3).Values = _
        "='CLSTRDATA-" & cluster & "'!R252C20:R255C20"
    ActiveChart.SeriesCollection(4).Values = _
        "='CLSTRDATA-" & cluster & "'!R252C6:R255C6"
    ActiveChart.ChartTitle.Text = _
        "�L���p�V�e�B���̓O���t (���z�}�V�����x��: ���蓖��vCPU����CPU�g�p����CPU�ҋ@����)" & Chr(10) & cluster

End Sub


Sub DeployESX(dataroot, cluster, esx)

    Sheets("ESXDATA-<esx>").Select
    Sheets("ESXDATA-<esx>").name = SheetName_ESX("ESXDATA-", esx)
    
    Call RefreshESXDATA(dataroot, cluster, esx)
    
    Sheets("ESX-<esx>").Select
    Sheets("ESX-<esx>").name = SheetName_ESX("ESX-", esx)
    
    Call RefreshESX(esx)
    
    Sheets("ESXPERF-<esx>").Select
    Sheets("ESXPERF-<esx>").name = SheetName_ESX("ESXPERF-", esx)
    
    Call RefreshESXPERF(esx)
    
    Sheets(SheetName_ESX("ESXDATA-", esx)).Visible = False
End Sub

Sub RefreshESXDATA(dataroot, cluster, esx)
    
    range("B2").Select
    With Selection.QueryTable
        .Connection = _
        "TEXT;" & dataroot & "\cluster\" & cluster & "\host\" & esx & "\cpu_memory.csv"
        .TextFilePlatform = 932
        .TextFileStartRow = 1
        .TextFileParseType = xlDelimited
        .TextFileTextQualifier = xlTextQualifierDoubleQuote
        .TextFileConsecutiveDelimiter = False
        .TextFileTabDelimiter = True
        .TextFileSemicolonDelimiter = False
        .TextFileCommaDelimiter = True
        .TextFileSpaceDelimiter = False
        .TextFileColumnDataTypes = Array(5, 1, 1, 1, 1)
        .TextFileTrailingMinusNumbers = True
        .TextFilePromptOnRefresh = False
        .Refresh BackgroundQuery:=False
    End With
    
    range("B102").Select
    With Selection.QueryTable
        .Connection = _
        "TEXT;" & dataroot & "\cluster\" & cluster & "\host\" & esx & "\memory.csv"
        .TextFilePlatform = 932
        .TextFileStartRow = 1
        .TextFileParseType = xlDelimited
        .TextFileTextQualifier = xlTextQualifierDoubleQuote
        .TextFileConsecutiveDelimiter = False
        .TextFileTabDelimiter = True
        .TextFileSemicolonDelimiter = False
        .TextFileCommaDelimiter = True
        .TextFileSpaceDelimiter = False
        .TextFileColumnDataTypes = Array(5, 1, 1, 1, 1, 1, 1, 1, 1)
        .TextFileTrailingMinusNumbers = True
        .TextFilePromptOnRefresh = False
        .Refresh BackgroundQuery:=False
    End With
    
    range("B202").Select
    With Selection.QueryTable
        .Connection = _
        "TEXT;" & dataroot & "\cluster\" & cluster & "\host\" & esx & "\disk.csv"
        .TextFilePlatform = 932
        .TextFileStartRow = 1
        .TextFileParseType = xlDelimited
        .TextFileTextQualifier = xlTextQualifierDoubleQuote
        .TextFileConsecutiveDelimiter = False
        .TextFileTabDelimiter = True
        .TextFileSemicolonDelimiter = False
        .TextFileCommaDelimiter = True
        .TextFileSpaceDelimiter = False
        .TextFileColumnDataTypes = Array(5, 1, 1, 1, 1, 1)
        .TextFileTrailingMinusNumbers = True
        .TextFilePromptOnRefresh = False
        .Refresh BackgroundQuery:=False
    End With
    
    range("B302").Select
    With Selection.QueryTable
        .Connection = _
        "TEXT;" & dataroot & "\cluster\" & cluster & "\host\" & esx & "\net.csv"
        .TextFilePlatform = 932
        .TextFileStartRow = 1
        .TextFileParseType = xlDelimited
        .TextFileTextQualifier = xlTextQualifierDoubleQuote
        .TextFileConsecutiveDelimiter = False
        .TextFileTabDelimiter = True
        .TextFileSemicolonDelimiter = False
        .TextFileCommaDelimiter = True
        .TextFileSpaceDelimiter = False
        .TextFileColumnDataTypes = Array(5, 1, 1, 1, 1, 1)
        .TextFileTrailingMinusNumbers = True
        .TextFilePromptOnRefresh = False
        .Refresh BackgroundQuery:=False
    End With
End Sub
 
Sub RefreshESX(esx)
    esxdata = SheetName_ESX("ESXDATA-", esx)
    
    ActiveSheet.ChartObjects("�O���t 1").Activate
    ActiveChart.SeriesCollection(1).XValues = "='" & esxdata & "'!R2C2:R93C2"
    ActiveChart.SeriesCollection(1).name = "='" & esxdata & "'!R1C4"
    ActiveChart.SeriesCollection(1).Values = "='" & esxdata & "'!R2C4:R93C4"
    ActiveChart.SeriesCollection(2).name = "='" & esxdata & "'!R1C6"
    ActiveChart.SeriesCollection(2).Values = "='" & esxdata & "'!R2C6:R93C6"
    ActiveChart.SeriesCollection(3).name = "='" & esxdata & "'!R1C13"
    ActiveChart.SeriesCollection(3).Values = "='" & esxdata & "'!R2C13:R93C13"
    ActiveChart.SeriesCollection(4).name = "='" & esxdata & "'!R1C14"
    ActiveChart.SeriesCollection(4).Values = "='" & esxdata & "'!R2C14:R93C14"
    ActiveChart.ChartTitle.Text = "�L���p�V�e�B���̓O���t (ESX�z�X�g���x��: CPU / �������g�p��)" & Chr(10) & esx
End Sub

Sub RefreshESXPERF(esx)
    esxdata = SheetName_ESX("ESXDATA-", esx)

    ActiveSheet.ChartObjects("�O���t 1").Activate
    ActiveChart.SeriesCollection(1).name = "='" & esxdata & "'!R101C3"
    ActiveChart.SeriesCollection(1).Values = "='" & esxdata & "'!R102C3:R193C3"
    ActiveChart.SeriesCollection(2).name = "='" & esxdata & "'!R101C5"
    ActiveChart.SeriesCollection(2).Values = "='" & esxdata & "'!R102C5:R193C5"
    ActiveChart.SeriesCollection(3).name = "='" & esxdata & "'!R101C13"
    ActiveChart.SeriesCollection(3).Values = "='" & esxdata & "'!R102C13:R193C13"
    ActiveChart.SeriesCollection(4).name = "='" & esxdata & "'!R101C10"
    ActiveChart.SeriesCollection(4).Values = "='" & esxdata & "'!R102C10:R193C10"
    ActiveChart.SeriesCollection(5).name = "='" & esxdata & "'!R101C7"
    ActiveChart.SeriesCollection(5).Values = "='" & esxdata & "'!R102C7:R193C7"
    ActiveChart.SeriesCollection(6).name = "='" & esxdata & "'!R101C8"
    ActiveChart.SeriesCollection(6).Values = "='" & esxdata & "'!R102C8:R193C8"
    ActiveChart.SeriesCollection(7).name = "='" & esxdata & "'!R101C9"
    ActiveChart.SeriesCollection(7).Values = "='" & esxdata & "'!R102C9:R193C9"
    ActiveChart.SeriesCollection(1).XValues = "='" & esxdata & "'!R102C2:R193C2"
    ActiveChart.ChartTitle.Text = "�L���p�V�e�B���̓O���t (ESX�z�X�g���x��: �������֘A)" & Chr(10) & esx
    
    ActiveSheet.ChartObjects("�O���t 2").Activate
    ActiveChart.SeriesCollection(1).Select
    ActiveChart.SeriesCollection(1).name = "='" & esxdata & "'!R201C3"
    ActiveChart.SeriesCollection(1).Values = "='" & esxdata & "'!R202C3:R293C3"
    ActiveChart.SeriesCollection(2).name = "='" & esxdata & "'!R201C5"
    ActiveChart.SeriesCollection(2).Values = "='" & esxdata & "'!R202C5:R293C5"
    ActiveChart.SeriesCollection(3).name = "='" & esxdata & "'!R201C13"
    ActiveChart.SeriesCollection(3).Values = "='" & esxdata & "'!R202C13:R293C13"
    ActiveChart.SeriesCollection(4).name = "='" & esxdata & "'!R201C8"
    ActiveChart.SeriesCollection(4).Values = "='" & esxdata & "'!R202C8:R293C8"
    ActiveChart.SeriesCollection(1).XValues = "='" & esxdata & "'!R202C2:R293C2"
    ActiveChart.ChartTitle.Text = "�L���p�V�e�B���̓O���t (ESX�z�X�g���x��: �f�[�^�X�g�A�֘A)" & Chr(10) & esx
    
    ActiveSheet.ChartObjects("�O���t 3").Activate
    ActiveChart.SeriesCollection(1).name = "='" & esxdata & "'!R301C3"
    ActiveChart.SeriesCollection(1).Values = "='" & esxdata & "'!R302C3:R393C3"
    ActiveChart.SeriesCollection(2).name = "='" & esxdata & "'!R301C5"
    ActiveChart.SeriesCollection(2).Values = "='" & esxdata & "'!R302C5:R393C5"
    ActiveChart.SeriesCollection(3).name = "='" & esxdata & "'!R301C13"
    ActiveChart.SeriesCollection(3).Values = "='" & esxdata & "'!R302C13:R393C13"
    ActiveChart.SeriesCollection(4).name = "='" & esxdata & "'!R301C14"
    ActiveChart.SeriesCollection(4).Values = "='" & esxdata & "'!R302C14:R393C14"
    ActiveChart.SeriesCollection(5).name = "='" & esxdata & "'!R301C15"
    ActiveChart.SeriesCollection(5).Values = "='" & esxdata & "'!R302C15:R393C15"
    ActiveChart.SeriesCollection(1).XValues = "='" & esxdata & "'!R302C2:R393C2"
    ActiveChart.ChartTitle.Text = "�L���p�V�e�B���̓O���t (ESX�z�X�g���x��: �l�b�g���[�N�֘A)" & Chr(10) & esx
    
End Sub


