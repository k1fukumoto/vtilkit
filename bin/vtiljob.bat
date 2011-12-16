c:
cd c:\VTILLAB\SVN\bin
C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe -command " & '.\dumpperfdata.ps1'" 2> ..\log\dumperfdata_error.log
C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe -command " & '.\rollupperfdata.ps1'" 2> ..\log\rollupperfdata_error.log
