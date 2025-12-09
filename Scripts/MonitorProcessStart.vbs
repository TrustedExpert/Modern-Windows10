Set WshShell = WScript.CreateObject("WScript.Shell")
Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2") 
Set objEvents = objWMIService.ExecNotificationQuery("SELECT * FROM Win32_ProcessStartTrace")

Do
    Set objReceivedEvent = objEvents.NextEvent
    Set colItems = objWMIService.ExecQuery("Select * From Win32_Process where ProcessID=" & objReceivedEvent.ProcessID)
    For Each itm in ColItems
         wscript.echo objReceivedEvent.ProcessName & VBNewLine _
         	& "Creation Date = " _
         	&  itm.CreationDate & VBNewLine _
			& "Command = " _
			& itm.CommandLine & VBNewLine _
			& "#################################"
    Next
Loop