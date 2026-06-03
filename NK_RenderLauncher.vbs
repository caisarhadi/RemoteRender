Set objShell = CreateObject("WScript.Shell")
' Get the current directory of this VBScript
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
' Build the exact path to the powershell script
ps1Path = scriptDir & "\NK_RenderLauncher.ps1"

' Run PowerShell completely hidden (0) and do not wait for it to finish (False)
objShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1Path & """", 0, False
