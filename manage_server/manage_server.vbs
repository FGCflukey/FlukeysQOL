Set WshShell = WScript.CreateObject("WScript.Shell")

' Where is StartServer64-Manage.bat?
'serverdir = "C:\PZServer"
serverdir = "C:\GameServers\projectzomboid"
	
' Where are you running PZ Manage from?
installdir = "C:\Users\tomva\OneDrive\Desktop\mypzserver"

userdir = WshShell.ExpandEnvironmentStrings("%USERPROFILE%")
logsdir =  userdir & "\Zomboid\Logs\"

' IP of server
serverip = "127.0.0.1"

' Rcon password
rconpass = "4FGCAdminZOnly"

Do While startup <> vbNo

	KillOldProcess
	
	' Show Prompt for Management
	startup = ""
	startup = WshShell.Popup("START Managing PZ Server?", 15, "PZ Server Manager", 4 + 32)

	Select Case startup

		Case 6
			StartPZServer
			HelloMessages
			StartAlerts
			
		Case 7
			' If user selects No. Then exit.
			startup = vbNo
		
		Case Else
			' If time runs out. Start server.
			StartPZServer
			HelloMessages
			StartAlerts

		End Select
		
Loop

'------------------------------------------------------------------------------
Sub HelloMessages()

	MinuteNow = Minute(Now)
	HourNow = Hour(Now)
	
	If HourNow = 6 or HourNow = 12 or HourNow = 0 or HourNow = 18 and MinuteNow < 9 Then

		Dim HelloMsg(12)
	
		HelloMsg(1) = " WELCOME TO FLUKEY'S PZ 42.20.x - 24/7 PRIVATE PVE SERVER !! "
		HelloMsg(2) = " Server Restarts Daily 6 AM/PM & 12 AM/PM! Eastern Standard Time. "

		KillOldRcon	

		' Waiting 10 mins for server to start and people joining..
		srvWait = DateAdd("n", 10, Now())
		Do Until (Now() > srvWait)
			WScript.Sleep 2000
		Loop

		StartRCON
		
		WScript.Sleep 5000
		
		For i = 1 to 2
			Message = HelloMsg(i)
			SendAlert Message
		Next

	End If

End Sub

'------------------------------------------------------------------------------
Sub StartPZServer()

	' Check to see if PZ server running, and don't launch again if it is.
	strComputer = "."
	
	Set objWMIService = GetObject("winmgmts:" _
		& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
	Set colProcessList = objWMIService.ExecQuery _
		("Select Name from Win32_Process WHERE CommandLine LIKE '%StartServer-Here.bat%'")
	If colProcessList.count>0 Then
	Else

		' Delete the steam file to force workshop check
'		steamFile = serverdir & "\" & "steamapps\workshop\appworkshop_108600.acf"
'		Set fso = CreateObject("Scripting.FileSystemObject")
'		If fso.FileExists(steamFile) Then
'			fso.DeleteFile(steamFile)
'		End If
		
		' Update IP in .ini file
		GetExternalIP
		
		' Launch PZ server
		WshShell.CurrentDirectory = serverdir
		startPZ = serverdir & "\" & "StartServer-Here.bat"	
		WshShell.Run Chr(34) & startPZ & Chr(34), 1, false
		
	End If
	
End Sub

'------------------------------------------------------------------------------
Sub RestartServer()

	' Quit the server
	ShowWindow "", "SourceRcon.exe"
	WScript.Sleep 1000
	WshShell.SendKeys "{ENTER}"
	WshShell.SendKeys "quit"
	WshShell.SendKeys "{ENTER}"
	
	WScript.Sleep 40000

	' Search for and terminate any stray java process.
	strComputer = "." 
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\CIMV2") 
	Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE CommandLine LIKE '%java.exe%'",,48) 

	For Each objItem in colItems
	  objItem.Terminate()
	Next
	
End Sub

'------------------------------------------------------------------------------
Sub FlushServer()

	' Quit the server
	ShowWindow "", "SourceRcon.exe"
	WScript.Sleep 1000
	WshShell.SendKeys "{ENTER}"
	WshShell.SendKeys "quit"
	WshShell.SendKeys "{ENTER}"
	
	WScript.Sleep 35000

	' Search for and terminate any stray java process.
	strComputer = "." 
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\CIMV2") 
	Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE CommandLine LIKE '%java.exe%'",,48) 

	For Each objItem in colItems
	  objItem.Terminate()
	Next
	
	' Delete the steam file to force workshop check
	steamFile = serverdir & "\" & "steamapps\workshop\appworkshop_108600.acf"
	Set fso = CreateObject("Scripting.FileSystemObject")
	If fso.FileExists(steamFile) Then
		fso.DeleteFile(steamFile)
	End If

	' Delete the workshop folders under 108600 to ensure clean slate
	workshopfolder=serverdir & "\steamapps\workshop\content\108600"

	On Error Resume Next
	   Set fso = CreateObject("Scripting.FileSystemObject")
	   For Each folder In fso.GetFolder(workshopfolder).SubFolders
		  For Each file In fso.GetFolder(folder.Path).Files
			 fso.DeleteFile file.Path, True
		  Next
		  For Each subFolder In fso.GetFolder(folder.Path).SubFolders
			 fso.DeleteFolder subFolder.Path, True
		  Next
	   Next
	On Error Goto 0	
	
	
End Sub

'------------------------------------------------------------------------------
Sub RebootServer()

	' Search for and terminate any stray cmd process.
	strComputer = "." 
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\CIMV2") 
	Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE CommandLine LIKE '%SourceRcon.exe%'",,48) 

	For Each objItem in colItems
		objItem.Terminate()
	Next

	' Search for and terminate any stray cmd process.
	strComputer = "." 
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\CIMV2") 
	Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE CommandLine LIKE '%cmd.exe%'",,48) 

	For Each objItem in colItems
		objItem.Terminate()
	Next

	' Search for and terminate any stray java process.
	strComputer = "." 
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\CIMV2") 
	Set colItems = objWMIService.ExecQuery("SELECT * FROM Win32_Process WHERE CommandLine LIKE '%java.exe%'",,48) 

	For Each objItem in colItems
		objItem.Terminate()
	Next

	' Perform force Reboot of Server
	WScript.Sleep 5000

	WshShell.Run "%comspec% /c shutdown /r /t 5 /f", , TRUE

	
End Sub

'------------------------------------------------------------------------------
Sub StartAlerts()

	Do While True

		CurrTime = formatdatetime(Now(),4)
		MinuteNow = Minute(Now)
		MinuteNext = MinuteNow + 1
		
		If MinuteNext >= 60 Then
			MinuteNext = 0
		End If
		
		' Check to see if PZ server running, and exit if it's not.
		strComputer = "."
		Set objWMIService = GetObject("winmgmts:" _
			& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
		Set colProcessList = objWMIService.ExecQuery _
			("Select Name from Win32_Process WHERE CommandLine LIKE '%StartServer-Here.bat%'")
			
		If colProcessList.count>0 Then
		Else
			Exit Do
		End If
		
		' Check for files and perform forced Restart and Flush or Reboot action
		serverFlushFile = logsdir & "flush.txt"
		serverRebootFile = logsdir & "reboot.txt"
		Set fso = CreateObject("Scripting.FileSystemObject")
		If fso.FileExists(serverFlushFile) Then
			fso.DeleteFile(serverFlushFile)
			FlushServer
			Exit Do
		ElseIf fso.FileExists(serverRebootFile) Then
			fso.DeleteFile(serverRebootFile)
			RebootServer
			Exit Do
		End If	
		
		
		' Start checking the time...
		
		Select Case CurrTime
		
			Case "03:00", "15:00", "09:00", "21:00"
				' SaveTheServer
				
			Case "03:05", "15:05", "09:05", "21:05"
				SendAlert " WELCOME TO FLUKEY'S 24/7 PRIVATE PVE SERVER !! "
'				SendAlert " Basic Rules For Playing Here! Please Follow Them. "
'				SendAlert " #1 DO NOT Steal from Anyone! Logs Track Everything! "
'				SendAlert " #2 Safehousing in POI's is frowned upon! Check Discord. "
'				SendAlert " #3 Be Respectful To ALL! Little Tolerance Otherwise! "
				SendAlert " Server Restarts at 6 AM/PM & 12 AM/PM! Eastern Standard Time. "
'				SendAlert " ** OUR FGC DISCORD INVITE ** https - discord.gg/Ut4quPA3H7 "
				SendAlert " This Server Is Being Actively Managed. Happy Surviving! "

			Case "01:00", "13:00"
'				SendAlert "Reminder for you Survivor! DISCORD INVITE https - discord.gg/Ut4quPA3H7 "
'				SendAlert "Do Not Take Cars that Appear to Block Gates! AKA Safehouse Protection! "
'				SendAlert "Do Not Trespass on Other Safehouse Property! Unless you are Invited! "
				SendAlert " Tip! Gotta Trait You Don't Want? Press F7 For Traits Respec "

			Case "02:00", "14:00"
'				SendAlert "Reminder for you Survivor! DISCORD INVITE https - discord.gg/Ut4quPA3H7 "
'				SendAlert "Do Not Dismantle POI/Loot Crates OR Shelves! These DON'T Respawn! "
'				SendAlert "Do Not Strip Engine Parts from Cars. Boxes of Engine Parts Spawn ALL Over! "
				SendAlert " Tip! The Higher Your Mechanics = Higher Chance To Pick Locks Successfully "

			Case "04:00", "16:00"
'				SendAlert "Reminder for you Survivor! DISCORD INVITE https - discord.gg/Ut4quPA3H7 "
'				SendAlert "Check Craft Menu, when you right-click something. For recipes! "
'				SendAlert "The Map is Revealed, however may not be 100% Accurate - 10 Years Later. "
				SendAlert " Tip! Be Sure To Search Recipes, There May Be Better Choices & Return. "

			Case "07:00", "19:00"
'				SendAlert "Reminder for you Survivor! DISCORD INVITE https - discord.gg/Ut4quPA3H7 "
'				SendAlert "Having Problems? Ask on our Discord. Use the invite to Join our Discord! "
'				SendAlert "Be sure to ask, before you do something stupid and break rules. "
				SendAlert " Tip! Highly Advise Using BuildingCraft Via Right Click Than Default. "
				
			Case "08:00", "20:00"
'				SendAlert "Reminder for you Survivor! DISCORD INVITE https - discord.gg/Ut4quPA3H7 "
'				SendAlert "Do NOT Steal Community Placed Generators at Gas Stations!! Not Yours!"
'				SendAlert "Blood Cure for Zombie Infection Exists! Search Medical Places for Clues. "
				SendAlert " Tip! If You Have A Pen Or Pencil, You Can Leave Marks On Your Map. "

			Case "10:00", "22:00"
'				SendAlert "Reminder for you Survivor! DISCORD INVITE https - discord.gg/Ut4quPA3H7 "
'				SendAlert "Books = XP Here! You Do Not Farm XP Here! Read and Get XP! "
'				SendAlert "Stealing - Breaking Crates at POI Not Needed Here! Craft better ones! "
				SendAlert " Tip! Update Your Journal Regularly! Keep It At Home In Case You Die! "
				
			Case "05:00", "17:00", "11:00", "23:00"
				SendAlert " ATTENTION SURVIVOR! SERVER RESTARTS IN 1 HOUR! "
				
			' Last 30 minute ALERTs
			Case "05:30", "17:30", "11:30", "23:30"
				SendAlert " ATTENTION SURVIVOR! SERVER RESTARTS IN 30 MINUTES! "
				
			Case "05:45", "17:45", "11:45", "23:45"
				SendAlert " ATTENTION SURVIVOR! SERVER RESTARTS IN 15 MINUTES! "

			Case "05:50", "17:50", "11:50", "23:50"
				SendAlert " ATTENTION SURVIVOR! SERVER RESTARTS IN 10 MINUTES! "
				
			Case "05:55", "17:55", "11:55", "23:55"
				SendAlert " ALERT SURVIVOR! SERVER RESTARTS IN 5 MINUTES!! "

			Case "05:58", "17:58", "11:58", "23:58"
				SendAlert " ALERT SURVIVOR! SERVER RESTARTS IN 2 MINUTES!! "
				SendAlert " If You Are Reading This. You Should Be Disconnecting!! "
				
			Case "05:59", "17:59", "11:59", "23:59"
				SendAlert " ALERT SURVIVOR! SERVER RESTARTS IN 1 MINUTE!! "
				SendAlert " Why Are You Still Here? Go Away! We Need To Restart!! "
				
			Case "06:00", "18:00", "12:00", "00:00"
				SendAlert " SERVER RESTART IS IN PROGRESS!... We Will Be Right Back! "
				RestartServer
					If CurrTime = "06:00" or CurrTime = "06:01" or CurrTime = "06:02" Then
						'UpdateRemovalList_1
					End If
					If CurrTime = "18:00" or CurrTime = "18:01" or CurrTime = "18:02" Then
						'UpdateRemovalList_2
					End If
					If CurrTime = "12:00" or CurrTime = "12:01" or CurrTime = "12:02" Then
						'UpdateRemovalList_3
					End If
					If CurrTime = "00:00" or CurrTime = "00:01" or CurrTime = "00:02"  Then
						'UpdateRemovalList_4
					End If
				Exit Do

		End Select

		Do Until MinuteNow = MinuteNext
			MinuteNow = Minute(Now)
			WScript.Sleep 2000
		Loop
	Loop

End Sub

'------------------------------------------------------------------------------
Sub StartRCON()

	' Most reliable method to activate this window.
	strComputer = "."
	Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
	Set colProcesses = objWMIService.ExecQuery ("Select * from Win32_Process Where Name = 'SourceRcon.exe'")
	
	If colProcesses.count > 0 Then

	Else
		WshShell.CurrentDirectory = installdir
		SourceRcon = chr(34) & "SourceRcon.exe 127.0.0.1 27015 4FGCAdminZOnly" & chr(34)
		cmdID = WshShell.Run("SourceRcon.exe 127.0.0.1 27015 4FGCAdminZOnly", 1, False)
		
		For Each objProcess in colProcesses
			WshShell.AppActivate(objProcess.ProcessID)
			WshShell.SendKeys "% r"
		Next	
		
	End If

End Sub

'------------------------------------------------------------------------------
Sub UpdateServer()

	' Launch steamcmd and check for PZ updates
	
	'WshShell.CurrentDirectory = installdir
	
	On Error Resume Next
	WshShell.CurrentDirectory = installdir
	If Err.Number <> 0 Then
		WScript.Echo "Error " & Err.Number & ": " & Err.Description & " | Path: " & installdir
		Err.Clear
	End If
	On Error Goto 0
	
	StartUpdate = "steamcmd.exe +login anonymous +force_install_dir " &chr(34) &serverdir &chr(34) &" +app_update 380870 validate +exit"
	UpdateReturn = WshShell.Run(StartUpdate, 1, true)
	
	If UpdateReturn <> 0 Then 
	   WScript.Echo "Error running update."
	End If

End Sub

'------------------------------------------------------------------------------
Sub SendAlert(ByVal ServerMessage)
	StartRCON
	ShowWindow "", "SourceRcon.exe"
	WScript.Sleep 1000
	ServerMessage = chr(34) & ServerMessage &chr(34)
	WshShell.SendKeys "servermsg " & ServerMessage
	WshShell.SendKeys "{ENTER}"
	WScript.Sleep 5000				
End Sub

Sub SaveTheServer()
	' Save The World
	ShowWindow "", "SourceRcon.exe"
	WScript.Sleep 1000
	WshShell.SendKeys "{ENTER}"
	WshShell.SendKeys "save"
	WshShell.SendKeys "{ENTER}"
End Sub

'------------------------------------------------------------------------------
Sub ResetSpawnPoints()
	
	' Parse PZ Map Tool file to delete map chunk files.
	
	Const ForReading = 1
	Const ForAppending = 8
	
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	
	SpawnPointFile = "C:\Users\PZ\Desktop\my server\PZ Map Tool\spawnpoints.txt"
	Set objFile = objFSO.OpenTextFile(SpawnPointFile, ForReading)

	countFiles = 0
	
	Do Until objFile.AtEndOfStream
	
		strLine = objFile.readline
		logtime=FormatDateTime(Now, vbGeneralDate)
		
		If Instr(strLine,".bin") <> 0 Then
			' Change to match your server location
			PathToFile = "C:\Users\PZ\Zomboid\Saves\Multiplayer\servertest\" &strLine
			
			If objFSO.FileExists(PathToFile) Then
				objFSO.DeleteFile PathToFile
				countFiles = countFiles + 1
				
			End If
			
		End If
		
	Loop

	objFile.Close
	
	ResetLogFile = "C:\Temp\PZManagerReset.log"
	Set objLog = objFSO.OpenTextFile(ResetLogFile, ForAppending)
	objLog.WriteLine("Map Reset Operation Completed at " &logtime &" - Total Files Deleted = [" &countFiles &"]")
	objLog.Close	
	
End Sub

'------------------------------------------------------------------------------
Sub KillOldProcess()

	' Kill any previous instance of this script that shouldn't exist.
	strComputer = "."
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
	Set colProcessList = objWMIService.ExecQuery _
		("Select * from Win32_Process Where NAME = 'wscript.exe'")

	For Each objProcess in colProcessList
		myStartTime = objProcess.CreationDate
		strReturn = replace(split(WMIDateStringToDate(myStartTime), " ")(1), ":", "")
		Exit For
	Next

	For Each objProcess in colProcessList
		myStartTime = objProcess.CreationDate
		strReturn1 = replace(split(WMIDateStringToDate(myStartTime), " ")(1), ":", "")
		If strReturn <> strReturn1 Then
			objProcess.Terminate()
		End If
	Next	
	
End Sub

'------------------------------------------------------------------------------
Sub KillOldRcon()

	' Kill any previous instance of this script that shouldn't exist.
	strComputer = "."
	Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
	Set colProcessList = objWMIService.ExecQuery _
		("Select * from Win32_Process Where NAME = 'SourceRcon.exe'")

	For Each objProcess in colProcessList
		objProcess.Terminate()
	Next	

End Sub

'------------------------------------------------------------------------------
Sub ShowWindow(appName, titlePattern)
	'@description: Bring a window to the front and activate it.
	'@author: Jeremy England (SimplyCoded)
	  With createobject("wscript.shell")
		.run "powershell -Command ""$type = Add-Type -MemberDefinition '[DllImport(\""user32.dll\"")] " & _ 
			 "public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);[DllImport(\""user32.dll\"")] " & _
			 "public static extern int SetForegroundWindow(IntPtr hwnd);' -Name WindowAPI -PassThru;$hwnd = (Get-Process " & _
			 appName & " | where MainWindowTitle -match '" & titlePattern & "').MainWindowHandle;" & _
			 "$null = $type::ShowWindowAsync($hwnd, 4);$null = $type::SetForegroundWindow($hwnd)""", 0, true
			 
	  End With 
	  
End Sub

'------------------------------------------------------------------------------
Function WMIDateStringToDate(dtmStart)
	' Converts WMI date info
	
    WMIDateStringToDate = CDate(Mid(dtmStart, 5, 2) & "/" & _
        Mid(dtmStart, 7, 2) & "/" & Left(dtmStart, 4) _
            & " " & Mid (dtmStart, 9, 2) & ":" & _
                Mid(dtmStart, 11, 2) & ":" & Mid(dtmStart, _
                    13, 2))
					
End Function

'------------------------------------------------------------------------------
Sub GetExternalIP()

	' Grab External IP
	
	With CreateObject("MSXML2.XMLHTTP")
		.open "GET", "http://checkip.dyndns.org/", False
		.send
		response = .ResponseText
	End With

	num = InStr(response, ":")
	If num > 0 Then
		response = Mid(response, num + 2)
		num = InStr(response, "<")
		If num > 0 Then
			response = Left(response, num - 1)
			'WScript.Echo(response)
		End If
	End If
	
	' Update line in .ini file
	' example - server_browser_announced_ip=184.148.65.173
	
	Const ForReading=1
	Const ForWriting=2

	Set objFSO = CreateObject("Scripting.FileSystemObject")
	folder = "C:\Users\tomva\Zomboid\Server\"
	filePath = folder & "servertest.ini"
	Set myFile = objFSO.OpenTextFile(filePath, ForReading, True)
	Set myTemp= objFSO.OpenTextFile(filePath & ".tmp", ForWriting, True)
	
	responseip = "server_browser_announced_ip=" & response
		
	Do While Not myFile.AtEndofStream
		myLine = myFile.ReadLine
		If InStr(myLine, "server_browser_announced_ip=") Then
			myLine = responseip
		End If
		myTemp.WriteLine myLine
	Loop

	myFile.Close
	myTemp.Close
	objFSO.DeleteFile(filePath)
	objFSO.MoveFile filePath&".tmp", filePath	
	
End Sub

'------------------------------------------------------------------------------
Sub UpdateRemovalList_1()

	Const ForReading=1
	Const ForWriting=2

	Set objFSO = CreateObject("Scripting.FileSystemObject")
	folder = "C:\Users\tomva\Zomboid\Server\"
	filePath = folder & "servertest_SandboxVars.lua"
	Set myFile = objFSO.OpenTextFile(filePath, ForReading, True)
	Set myTemp= objFSO.OpenTextFile(filePath & ".tmp", ForWriting, True)
	removallist = "AdditionalBooks2.BookAiming1,AdditionalBooks2.BookAiming2,AdditionalBooks2.BookAiming3,AdditionalBooks2.BookAiming4,AdditionalBooks2.BookAiming5,AdditionalBooks2.BookAxe1,AdditionalBooks2.BookAxe2,AdditionalBooks2.BookAxe3,AdditionalBooks2.BookAxe4,AdditionalBooks2.BookAxe5,AdditionalBooks2.BookBlunt1,AdditionalBooks2.BookBlunt2,AdditionalBooks2.BookBlunt3,AdditionalBooks2.BookBlunt4,AdditionalBooks2.BookBlunt5,AdditionalBooks2.BookLightfooted1,AdditionalBooks2.BookLightfooted2,AdditionalBooks2.BookLightfooted3,AdditionalBooks2.BookLightfooted4,AdditionalBooks2.BookLightfooted5,AdditionalBooks2.BookLongBlade1,AdditionalBooks2.BookLongBlade2,AdditionalBooks2.BookLongBlade3,AdditionalBooks2.BookLongBlade4,AdditionalBooks2.BookLongBlade5,AdditionalBooks2.BookMaintenance1,AdditionalBooks2.BookMaintenance2,AdditionalBooks2.BookMaintenance3,AdditionalBooks2.BookMaintenance4,AdditionalBooks2.BookMaintenance5,AdditionalBooks2.BookNimble1,AdditionalBooks2.BookNimble2,AdditionalBooks2.BookNimble3,AdditionalBooks2.BookNimble4,AdditionalBooks2.BookNimble5,AdditionalBooks2.BookReloading1,AdditionalBooks2.BookReloading2,AdditionalBooks2.BookReloading3,AdditionalBooks2.BookReloading4,AdditionalBooks2.BookReloading5,AdditionalBooks2.BookSmallBlade1,AdditionalBooks2.BookSmallBlade2,AdditionalBooks2.BookSmallBlade3,AdditionalBooks2.BookSmallBlade4,AdditionalBooks2.BookSmallBlade5,AdditionalBooks2.BookSmallBlunt1,AdditionalBooks2.BookSmallBlunt2,AdditionalBooks2.BookSmallBlunt3,AdditionalBooks2.BookSmallBlunt4,AdditionalBooks2.BookSmallBlunt5,AdditionalBooks2.BookSneaking1,AdditionalBooks2.BookSneaking2,AdditionalBooks2.BookSneaking3,AdditionalBooks2.BookSneaking4,AdditionalBooks2.BookSneaking5,AdditionalBooks2.BookSpear1,AdditionalBooks2.BookSpear2,AdditionalBooks2.BookSpear3,AdditionalBooks2.BookSpear4,AdditionalBooks2.BookSpear5,AdditionalBooks2.BookSprinting1,AdditionalBooks2.BookSprinting2,AdditionalBooks2.BookSprinting3,AdditionalBooks2.BookSprinting4,AdditionalBooks2.BookSprinting5,Base.BookFitness1,Base.BookFitness2,Base.BookFitness3,Base.BookFitness4,Base.BookFitness5,Base.BookStrength1,Base.BookStrength2,Base.BookStrength3,Base.BookStrength4,Base.BookStrength5,AdvancedFishing.FishingAnglerBook1,AdvancedFishing.FishingAnglerBook2,AdvancedFishing.FishingAnglerBook3,AdvancedFishing.FishingAnglerBook4,AdvancedFishing.FishingAnglerBook5,AdvancedFishing.FishingAnglerBook6,AdvancedFishing.FishingAnglerBook7,AdvancedFishing.FishingEncyclopedia,AdvancedFishing.FishingEncyclopedia2,AdvancedFishing.FishingEncyclopedia3,AdvancedFishing.FishingEncyclopedia4,AdvancedFishing.FishingEncyclopedia5,AdvancedFishing.SportFishingBook,Base.LGRBookHunting1,Base.LGRBookHunting2,Base.LGRBookHunting3,Base.LGRBookHunting4,Base.LGRBookHunting5,legourmetfarming.SeedBook,Base.Book,Base.BookBlacksmith1,Base.BookBlacksmith2,Base.BookBlacksmith3,Base.BookBlacksmith4,Base.BookBlacksmith5,Base.BookCarpentry1,Base.BookCarpentry2,Base.BookCarpentry3,Base.BookCarpentry4,Base.BookCarpentry5,Base.BookCooking1,Base.BookCooking2,Base.BookCooking3,Base.BookCooking4,Base.BookCooking5,Base.BookElectrician1,Base.BookElectrician2,Base.BookElectrician3,Base.BookElectrician4,Base.BookElectrician5,Base.BookFarming1,Base.BookFarming2,Base.BookFarming3,Base.BookFarming4,Base.BookFarming5,Base.BookFirstAid1,Base.BookFirstAid2,Base.BookFirstAid3,Base.BookFirstAid4,Base.BookFirstAid5,Base.BookFishing1,Base.BookFishing2,Base.BookFishing3,Base.BookFishing4,Base.BookFishing5,Base.BookForaging1,Base.BookForaging2,Base.BookForaging3,Base.BookForaging4,Base.BookForaging5,Base.BookMechanic1,Base.BookMechanic2,Base.BookMechanic3,Base.BookMechanic4,Base.BookMechanic5,Base.BookMetalWelding1,Base.BookMetalWelding2,Base.BookMetalWelding3,Base.BookMetalWelding4,Base.BookMetalWelding5,Base.BookTailoring1,Base.BookTailoring2,Base.BookTailoring3,Base.BookTailoring4,Base.BookTailoring5,Base.BookTrapping1,Base.BookTrapping2,Base.BookTrapping3,Base.BookTrapping4,Base.BookTrapping5,Base.ComicBook,Base.Notebook,Aquatsar.BoatMag,Aquatsar.SwimMag,Autotsar.AtTuningMagBus,Autotsar.ATADodgeTuningMag,Autotsar.AtTuningMagJeep,Autotsar.ATAPetyarbuiltTuningMag,BasementMod.BasementsMag_large,BasementMod.BasementsMag_medium,BasementMod.BasementsMag_small,Base.LGClimatologyMag,Base.LGCookingMag,Base.LGCookingMag2,Base.LGCookingMag3,Base.LGCookingMag4,Base.LGCookingMag5,Base.LGCookingMag6,Base.LGCookingMag7,Base.LGCookingMag8,Base.LGCookingMag9,Base.MoldesMagBox,Greenfire.AficMag1,Greenfire.CannaMag1,Greenfire.CannaMag2,Greenfire.CannaMag3,AdvancedFishing.OldMagazine,AdvancedFishing.OldMagazine2,AdvancedFishing.OldMagazine3,Base.SurvivalistMag1,Base.SurvivalistMag2,Base.SurvivalistMag3,Base.SurvivalistMag4,Base.SurvivalistMag5,Base.SurvivalistMag6,legourmet.DrinksMag2,legourmet.EnergyMagazine,legourmetfarming.LgFarmMag1,Mining.MiningMag1,Base.BloodCureMag,Base.CookingMag1,Base.CookingMag2,Base.ElectronicsMag1,Base.ElectronicsMag2,Base.ElectronicsMag3,Base.ElectronicsMag4,Base.ElectronicsMag5,Base.EngineerMagazine1,Base.EngineerMagazine2,Base.FarmingMag1,Base.FishingMag1,Base.FishingMag2,Base.HerbalistMag,Base.HuntingMag1,Base.HuntingMag2,Base.HuntingMag3,Base.Magazine,Base.MagazineCrossword1,Base.MagazineCrossword2,Base.MagazineCrossword3,Base.MagazineWordsearch1,Base.MagazineWordsearch2,Base.MagazineWordsearch3,Base.MechanicMag1,Base.MechanicMag2,Base.MechanicMag3,Base.MetalworkMag1,Base.MetalworkMag2,Base.MetalworkMag3,Base.MetalworkMag4,Base.SmithingMag1,Base.SmithingMag2,Base.SmithingMag3,Base.SmithingMag4,Base.TVMagazine,Radio.RadioMag1,Radio.RadioMag2,Radio.RadioMag3,MoreTraits.AntiqueMag1,MoreTraits.AntiqueMag2,MoreTraits.AntiqueMag3,MoreTraits.MedicalMag1,MoreTraits.MedicalMag2,MoreTraits.MedicalMag3,MoreTraits.MedicalMag4,Base.AutomakerMag1,Base.AutomakerMag2,Base.AutomakerMag3,AuthenticZClothing.PonchoBlack,AuthenticZClothing.PonchoBlackDOWN,AuthenticZClothing.PonchoCamoDesert,AuthenticZClothing.PonchoCamoDesertDOWN,AuthenticZClothing.PonchoCamoForest,AuthenticZClothing.PonchoCamoForest2,AuthenticZClothing.PonchoCamoForest2DOWN,AuthenticZClothing.PonchoCamoForestDOWN,AuthenticZClothing.PonchoOliveDrab,AuthenticZClothing.PonchoOliveDrabDOWN,AuthenticZClothing.PonchoOrangePunch,AuthenticZClothing.PonchoOrangePunchDOWN,AuthenticZClothing.PonchoUrbanForest,AuthenticZClothing.PonchoUrbanForestDOWN,AuthenticZClothing.PonchoWhiteTINT,AuthenticZClothing.PonchoWhiteTINTDOWN,AuthenticZClothing.Shirt_Bill_Murray,AuthenticZClothing.Shirt_Bub,AuthenticZClothing.Shirt_Cheerleader,AuthenticZClothing.Shirt_CropTopLVCheerleader,AuthenticZClothing.Shirt_DenimBlack,AuthenticZClothing.Shirt_FormalAsh,AuthenticZClothing.Shirt_FormalBateman,AuthenticZClothing.Shirt_FormalBlack_ShortSleeve,AuthenticZClothing.Shirt_FormalBlue_ShortSleeve,AuthenticZClothing.Shirt_FormalBrad,AuthenticZClothing.Shirt_FormalDayZ,AuthenticZClothing.Shirt_FormalJoker,AuthenticZClothing.Shirt_FormalNick,AuthenticZClothing.Shirt_FormalRed_ShortSleeve,AuthenticZClothing.Shirt_LumberJackShort,AuthenticZClothing.Shirt_LumberJackShortRed,AuthenticZClothing.Shirt_LumberjackTheyLive,AuthenticZClothing.Shirt_MimeBlack,AuthenticZClothing.Shirt_MimeRed,AuthenticZClothing.Shirt_MimeRed2,AuthenticZClothing.Shirt_Walker,AuthenticZClothing.Shirt_WhiteStriped,AuthenticZClothing.Shoes_ArmyBootsOrange,AuthenticZClothing.Shoes_BillMurray,AuthenticZClothing.Shoes_BlackPinkTrainers,AuthenticZClothing.Shoes_BrownBoots,AuthenticZClothing.Shoes_Clown,AuthenticZClothing.Shoes_ClownPolka,AuthenticZClothing.Shoes_ClownStriped,AuthenticZClothing.Shoes_JimmyGibbs,AuthenticZClothing.Shoes_Maid,AuthenticZClothing.Shoes_Nurse,AuthenticZClothing.Shoes_OneBlackBoot,AuthenticZClothing.Shoes_Pale,AuthenticZClothing.Shoes_SlippersBlack,AuthenticZClothing.Shoes_TrainerBlack,AuthenticZClothing.Shoes_TrainerBlackandWhite,AuthenticZClothing.Shoes_TrainerBlackMamba,AuthenticZClothing.Shoes_TrainerGreenandWhite,AuthenticZClothing.Shoes_TrainerPinkandWhite,AuthenticZClothing.Shoes_TrainerRedandBlack,AuthenticZClothing.Shoes_TrainersAZ,AuthenticZClothing.Shoes_TrainerWhite,AuthenticZClothing.Shoes_TrainerWhitePlain,AuthenticZClothing.Shoes_White,AuthenticZClothing.Shorts_LongDenimWhite,AuthenticZClothing.Shorts_LongSport_Blue,AuthenticZClothing.Shorts_LongSportBluePurple,AuthenticZClothing.Shorts_LongSportChiefs,AuthenticZClothing.Shorts_LongSportGold,AuthenticZClothing.Shorts_LongSportGolden,AuthenticZClothing.Shorts_LongSportLightBlue,AuthenticZClothing.Shorts_LongSportNeon,AuthenticZClothing.Shorts_LongSportPatriots,AuthenticZClothing.Shorts_LongSportPinkBlackBlue,AuthenticZClothing.Shorts_LongSportPopcicle,AuthenticZClothing.Shorts_LongSportPurple,AuthenticZClothing.Shorts_LongSportWatermelon,AuthenticZClothing.Shorts_ShortSport_Neon,AuthenticZClothing.Shorts_ShortSport_PinkBlackBlue,AuthenticZClothing.Shorts_ShortSport_Popcicle,AuthenticZClothing.Shorts_ShortSport_Sunset,AuthenticZClothing.Skirt_LVCheerleader,AuthenticZClothing.Skirt_ShortBlack,AuthenticZClothing.Skirt_ShortCheerleader,AuthenticZClothing.Skirt_ShortJessie,AuthenticZClothing.Skirt_ShortPlaid,AuthenticZClothing.Skirt_ShortRedPlaid,AuthenticZClothing.Skirt_ShortXian,AuthenticZClothing.Socks_LegWarmers,AuthenticZClothing.Socks_LegWarmersNeonBlue,AuthenticZClothing.Socks_LegWarmersNeonPink,AuthenticZClothing.Socks_LegWarmersPurple,AuthenticZClothing.Socks_Long_BlueStripedWhite,AuthenticZClothing.Socks_Long_Charcoal,AuthenticZClothing.Socks_Long_DarkGreen,AuthenticZClothing.Socks_Long_MaidStockings,AuthenticZClothing.Socks_Long_MimeLeggings,AuthenticZClothing.Socks_Long_NurseThigh,AuthenticZClothing.Socks_Long_PurpleStripedWhite,AuthenticZClothing.Socks_Long_RedStriped01,AuthenticZClothing.Socks_Long_RedStriped02,AuthenticZClothing.Socks_Long_RedStriped03,AuthenticZClothing.Socks_Long_StockingsBlack,AuthenticZClothing.Suit_JacketBlue,AuthenticZClothing.Suit_JacketGMan,AuthenticZClothing.Suit_JacketJessie,AuthenticZClothing.Suit_JacketJoker,AuthenticZClothing.Suit_JacketNick,AuthenticZClothing.Suit_JacketSamB,AuthenticZClothing.Tie_Big_Long,AuthenticZClothing.Tie_BowTieWorn_Blue,AuthenticZClothing.Tie_BowTieWorn_Green,AuthenticZClothing.Tie_BowTieWorn_Purple,AuthenticZClothing.Tie_BowTieWorn_Red,AuthenticZClothing.Tie_BowTieWorn_Yellow,AuthenticZClothing.Tie_Full_BlueSpy,AuthenticZClothing.Tie_Full_Brad,AuthenticZClothing.Tie_Full_GMan,AuthenticZClothing.Tie_Full_Red,AuthenticZClothing.Tie_Full_White,AuthenticZClothing.Trousers_BarbershopBlue,AuthenticZClothing.Trousers_BarbershopGreen,AuthenticZClothing.Trousers_BarbershopPurple,AuthenticZClothing.Trousers_BarbershopRed,AuthenticZClothing.Trousers_BarbershopYellow,AuthenticZClothing.Trousers_BelAir,AuthenticZClothing.Trousers_Coach,AuthenticZClothing.Trousers_DefaultJeans,AuthenticZClothing.Trousers_DesignerTINT,AuthenticZClothing.Trousers_FiremanNMRIH,AuthenticZClothing.Trousers_Flyboy,AuthenticZClothing.Trousers_Grimes,AuthenticZClothing.Trousers_JeanDark,AuthenticZClothing.Trousers_JohnMorgan,AuthenticZClothing.Trousers_OliveDrab,AuthenticZClothing.Trousers_OliveDrab2,AuthenticZClothing.Trousers_Sport,AuthenticZClothing.Trousers_SportBlue,AuthenticZClothing.Trousers_SportGreen,AuthenticZClothing.Trousers_SportKilla,AuthenticZClothing.Trousers_SportRed,AuthenticZClothing.Trousers_SportYellow,AuthenticZClothing.Trousers_SuitBlack,AuthenticZClothing.Trousers_SuitBrad,AuthenticZClothing.Trousers_SuitBrown,AuthenticZClothing.Trousers_SuitGMan,AuthenticZClothing.Trousers_SuitJoker,AuthenticZClothing.Trousers_SuitNick,AuthenticZClothing.Trousers_SuitVeryRed,AuthenticZClothing.Trousers_Tagilla,AuthenticZClothing.Trousers_UncleSam,AuthenticZClothing.TrousersMesh_Bill,AuthenticZClothing.TrousersMesh_Bub,AuthenticZClothing.TrousersMesh_JimmyGibbs,AuthenticZClothing.TrousersMesh_Rave,AuthenticZClothing.Tshirt_Badass,AuthenticZClothing.TShirt_BrickBuster,AuthenticZClothing.Tshirt_CheeseRoyale,AuthenticZClothing.Tshirt_Coach,AuthenticZClothing.Tshirt_Ellis,AuthenticZClothing.Tshirt_Holly,AuthenticZClothing.Tshirt_Icon,AuthenticZClothing.Tshirt_IconNumbers,AuthenticZClothing.Tshirt_JohnMorgan,AuthenticZClothing.Tshirt_LegoHead,AuthenticZClothing.Tshirt_LoganCarter,AuthenticZClothing.Tshirt_LogoTest,AuthenticZClothing.Tshirt_PostalDude,AuthenticZClothing.Tshirt_PrinceBelAir,AuthenticZClothing.TShirt_RedStriped,AuthenticZClothing.Tshirt_Rochelle,AuthenticZClothing.Tshirt_Rock2,AuthenticZClothing.Tshirt_SpiffoNEW,AuthenticZClothing.Tshirt_SportBluePurple,AuthenticZClothing.Tshirt_SportGold,AuthenticZClothing.Tshirt_SportGrey,AuthenticZClothing.Tshirt_SportKilla,AuthenticZClothing.Tshirt_SportKillaLong,AuthenticZClothing.Tshirt_SportLightBlue,AuthenticZClothing.Tshirt_SportNeon,AuthenticZClothing.Tshirt_SportPinkBlackBlue,AuthenticZClothing.Tshirt_SportPopcicle,AuthenticZClothing.Tshirt_SportPurple,AuthenticZClothing.Tshirt_SportSunset,AuthenticZClothing.Tshirt_SportWatermelon,AuthenticZClothing.Tshirt_SportWhite,AuthenticZClothing.Tshirt_VotePedro,AuthenticZClothing.Vest_BulletBlack,AuthenticZClothing.Vest_BulletKilla,AuthenticZClothing.Vest_BulletRPD,AuthenticZClothing.Vest_BulletTagilla,AuthenticZClothing.Vest_BulletTV110_Bag,AuthenticZClothing.Vest_BulletTV110_Bag_Radio,AuthenticZClothing.Vest_BulletTV110_BulletVest,AuthenticZClothing.Vest_BulletTV110_BulletVest_Radio,AuthenticZClothing.Vest_HighViz_Press,AuthenticZClothing.Vest_Hunting_Beige,AuthenticZClothing.Vest_Hunting_Wally,AuthenticZClothing.Vest_Portal_Tanktop,AuthenticZClothing.Vest_Rim_Duke,AuthenticZClothing.Vest_Rim_TINT,AuthenticZClothing.Vest_Waistcoat_Barbershop_Blue,AuthenticZClothing.Vest_Waistcoat_Barbershop_Green,AuthenticZClothing.Vest_Waistcoat_Barbershop_Purple,AuthenticZClothing.Vest_Waistcoat_Barbershop_Red,AuthenticZClothing.Vest_Waistcoat_Barbershop_Yellow,AuthenticZClothing.Vest_Waistcoat_Joker_Orange,AuthenticZClothing.Vest_Waistcoat_Mime,AuthenticZClothing.WeddingDressBlue,AuthenticZClothing.WeddingDressPink,AuthenticZClothing.Thin01_Apron,AuthenticZClothing.Thin01_Coveralls,AuthenticZClothing.Thin01_HoodieDown,AuthenticZClothing.Thin01_HoodieUP,AuthenticZClothing.Thin01_JacketVarsity,AuthenticZClothing.Thin01_LongJohns,AuthenticZClothing.Thin01_Overalls,AuthenticZClothing.Thin01_PonchoDown,AuthenticZClothing.Thin01_PonchoUP,AuthenticZClothing.Thin01_ShellPants,AuthenticZClothing.Thin01_Shoes,AuthenticZClothing.Thin01_SportShorts,AuthenticZClothing.Thin01_TShirt,AuthenticZClothing.Thin01_Vest_HighViz,AuthenticZClothing.SnowGhillie_Top,AuthenticZClothing.SnowGhillie_Trousers,AuthenticZClothing.CEDAHazmatSuit,AuthenticZClothing.CEDAHazmatSuitBlack,AuthenticZClothing.CEDAHazmatSuitBlackNoMask,AuthenticZClothing.CEDAHazmatSuitBlackNoMaskNoShoes,AuthenticZClothing.CEDAHazmatSuitBlackNoShoes,AuthenticZClothing.CEDAHazmatSuitBlue,AuthenticZClothing.CEDAHazmatSuitBlueNoMask,AuthenticZClothing.CEDAHazmatSuitBlueNoMaskNoShoes,AuthenticZClothing.CEDAHazmatSuitBlueNoShoes,AuthenticZClothing.CEDAHazmatSuitRed,AuthenticZClothing.CEDAHazmatSuitRedNoMask,AuthenticZClothing.CEDAHazmatSuitRedNoMaskNoShoes,AuthenticZClothing.CEDAHazmatSuitRedNoShoes,TAD.BobTA_Samba_Pagode_card,TAD.BobTA_Shim_Sham_Mag,TAD.BobTA_Shimmy_Mag,TAD.BobTA_Shuffling_Mag,TAD.BobTA_Side_to_Side_Mag,TAD.BobTA_Slide_Step_card,TAD.BobTA_Snake_card,TAD.BobTA_Thriller_Four_card,TAD.BobTA_Thriller_One_card,TAD.BobTA_Thriller_Three_card,TAD.BobTA_Thriller_Two_card,TAD.BobTA_Tut_One_card,TAD.BobTA_Tut_Two_card,TAD.BobTA_Twist_One_Mag,TAD.BobTA_Twist_Two_Mag,TAD.BobTA_Uprock_Indian_Step_Mag,TAD.BobTA_Wave_One_card,TAD.BobTA_Wave_Two_card,TAD.BobTA_YMCA_Mag"

	Do While Not myFile.AtEndofStream
		myLine = myFile.ReadLine
		If InStr(myLine, "    WorldItemRemovalList =") Then
			myLine = "    WorldItemRemovalList =" & chr(34) & removallist & chr(34) & ","
		End If
		myTemp.WriteLine myLine
	Loop

	myFile.Close
	myTemp.Close
	objFSO.DeleteFile(filePath)
	objFSO.MoveFile filePath&".tmp", filePath

End Sub

Sub UpdateRemovalList_2()

	Const ForReading=1
	Const ForWriting=2

	Set objFSO = CreateObject("Scripting.FileSystemObject")
	folder = "C:\Users\tomva\Zomboid\Server\"
	filePath = folder & "servertest_SandboxVars.lua"
	Set myFile = objFSO.OpenTextFile(filePath, ForReading, True)
	Set myTemp= objFSO.OpenTextFile(filePath & ".tmp", ForWriting, True)
	removallist = "Base.Armor_6B13,Base.Armor_Arm,Base.Armor_Defender,Base.Armor_Foot,Base.Armor_Juggernaut,Base.Bag_AK_Vest,Base.Bag_AK_Vest_Loose,Base.Bag_ARVN_Rucksack,Base.Bag_Blackhawk,Base.Bag_Blackhawk_Loose,Base.Bag_Bush,Base.Bag_Cat_Pack,Base.Bag_D3M,Base.Bag_D3M_Loose,Base.Bag_Duty_Belt_Back,Base.Bag_Duty_Belt_Front,Base.Bag_Hunting,Base.Bag_Juggernaut_Bag,Base.Bag_M2A1_Pack,Base.Bag_Plate_Carrier,Base.Bag_Radio_Pack,Base.Bag_Robbie_Pack,Base.Bag_Savotta,Base.Bag_SCBA,Base.Bag_Shemagh_Half,Base.Bag_SKS_Vest,Base.Bag_SKS_Vest_Loose,Base.Bag_Smersh_Vest,Base.Bag_Smersh_Vest_Loose,Base.Bag_Sniper_Hood,Base.Bag_Sniper_Pack,Base.Bag_Sniper_Suit,Base.Bag_Sniper_Suit_Off,Base.Bag_SSO,Base.Bag_ST53_Set,Base.Bag_Tactical_Alice,Base.Bag_Tactical_Belt_Back,Base.Bag_Tactical_Belt_Front,Base.Bag_X_Vest,Base.Bag_X_Vest_Loose,Base.Bag_ZIP,Base.Belly_Turtleneck,Base.Combat_Jumper,Base.Combat_Pants,Base.Ela_Jacket,Base.Ela_Pants,Base.Fire_Jacket,Base.Fire_Pants,Base.Glasses_Crewman_Goggles,Base.Glasses_Crewman_Goggles_OFF,Base.Glasses_Napier,Base.Glasses_X1000,Base.Glasses_X1000_OFF,Base.Gorka_Jacket,Base.Gorka_Jacket_New,Base.Gorka_Jacket2,Base.Gorka_Jacket3,Base.Gorka_Pants,Base.Gorka_Pants_New,Base.Gorka_Pants2,Base.Gorka_Pants3,Base.Hat_880_Helmet,Base.Hat_880_Visor,Base.Hat_880_Visor_UP,Base.Hat_Astrocom,Base.Hat_Beret_Tactical_Headset,Base.Hat_Beret_Tactical_Only,Base.Hat_Ela_Hat,Base.Hat_Ela_Hat_Only,Base.Hat_Ela_Headset,Base.Hat_Face_Shield,Base.Hat_FAST_Opscore,Base.Hat_FM53,Base.Hat_Gentex_Helmet,Base.Hat_Helmet_Headset,Base.Hat_HGU56,Base.Hat_HGU56_Shield,Base.Hat_HGU56_Visor,Base.Hat_Killa,Base.Hat_Killa_Visor,Base.Hat_Killa_Visor_UP,Base.Hat_Lisa_Cap,Base.Hat_M1_Helmet,Base.Hat_M1_Helmet_Ori,Base.Hat_M45_GasMask,Base.Hat_M50,Base.Hat_Maska,Base.Hat_Maska_Visor,Base.Hat_Maska_Visor_UP,Base.Hat_Maska_Visor2,Base.Hat_Maska_Visor2_UP,Base.Hat_MCU_GasMask,Base.Hat_MSA_Gas_Mask,Base.Hat_MSA_Gas_Mask_AMP,Base.Hat_MX_Helmet,Base.Hat_MX_Helmet_Glass,Base.Hat_NV18_Harness_OFF,Base.Hat_NV18_Harness_ON,Base.Hat_NV18_OFF,Base.Hat_NV18_ON,Base.Hat_Patrol_Cap,Base.Hat_PSGT_Helmet,Base.Hat_PSGT_Helmet_Camo,Base.Hat_PSGT_Neck,Base.Hat_PSGT_Visor,Base.Hat_PSGT_Visor_UP,Base.Hat_PVS_5,Base.Hat_PVS_5_OFF,Base.Hat_PVS15,Base.Hat_PVS15_Harness_OFF,Base.Hat_PVS15_Harness_ON,Base.Hat_PVS15_OFF,Base.Hat_PVS15_ON,Base.Hat_PVS15_UP,Base.Hat_Rabbit,Base.Hat_Riot_Visor,Base.Hat_Riot_Visor_UP,Base.Hat_Sam_NV,Base.Hat_Sam_NV_OFF,Base.Hat_Sordin,Base.Hat_Tactical_Beret,Base.Hat_Tactical_Boonie,Base.Hat_Tactical_Boonie_Fold,Base.Hat_Tactical_Cap,Base.Hat_Tactical_Cap_Camo,Base.Jacket_Adidas,Base.Jacket_Heather,Base.Killa_Jacket,Base.Killa_Pants,Base.Office_Sweater,Base.Office_Sweater_Long,Base.Pants_Adidas,Base.Pants_Yoga,Base.Police_Jumper,Base.Rabbit_Suit,Base.S_Tank_Top,Base.Sheriff_Jumper,Base.Sheriff_Vest,Base.Sheriff_Vest_Full,Base.Skirt_Nurse,Base.Skirt_Office,Base.Skirt_Office_Long,Base.Suit_Chempak,Base.Turtleneck,Base.Y_Shirts,Base.Y_Shirts_Long,Base.223Box,Base.223Bullets,Base.223Clip,Base.223Silencer,Base.22Clip,Base.22Silencer,Base.308Box,Base.308Bullets,Base.308Silencer,Base.38Silencer,Base.44Clip,Base.45Clip,Base.45Silencer,Base.556Box,Base.556Bullets,Base.556Clip,Base.762x39Box,Base.762x39Bullets,Base.762x51Box,Base.762x51Bullets,Base.9mmClip,Base.9mmCompensator,Base.9mmSilencer,Base.AK_Mag,Base.AK47,Base.AmmoCan223,Base.AmmoCan308,Base.AmmoCan556,Base.AmmoCan762,Base.AmmoCan762x39,Base.AmmoCan9mm,Base.AmmoStock,Base.AmmoStraps,Base.AR15,Base.AssaultRifle,Base.AssaultRifle2,Base.Bullets22,Base.Bullets22Box,Base.Bullets3006,Base.Bullets3006Box,Base.Bullets357,Base.Bullets357Box,Base.Bullets38,Base.Bullets38Box,Base.Bullets44,Base.Bullets4440,Base.Bullets4440Box,Base.Bullets44Box,Base.Bullets45,Base.Bullets45Box,Base.Bullets9mm,Base.Bullets9mmBox,Base.ChokeTubeFull,Base.ChokeTubeImproved,Base.ColtAce,Base.ColtAnaconda,Base.ColtPeacemaker,Base.ColtPython,Base.ColtPythonHunter,Base.ColtSingleAction22,Base.DoubleBarrelShotgun,Base.DoubleBarrelShotgunSawnoff,Base.ExtendedRecoilPad,Base.FN_FAL,Base.FN_FAL_Mag,Base.Glock17,Base.Glock17Mag,Base.GunLightImprovised,Base.GunToolKit,Base.HuntingRifle,Base.HuntingRifle_Sawn,Base.ImprovisedGunToolKit,Base.ImprovisedSilencer,Base.ImprovisedSilencer_Broken,Base.IronSight,Base.Laser,Base.LAW12,Base.LightShotgunStock,Base.M14Clip,Base.M16A2,Base.M1Garand,Base.M1GarandClip,Base.M24Rifle,Base.M37,Base.M37Sawnoff,Base.M60,Base.M60Mag,Base.M733,Base.Mac10,Base.Mac10_Stock_Detracted,Base.Mac10_Stock_Extended,Base.Mac10Mag,Base.Mossberg500,Base.Mossberg500Tactical,Base.MP5,Base.MP5_Stock_Detracted,Base.MP5_Stock_Extended,Base.MP5Mag,Base.Pistol,Base.Pistol2,Base.Pistol3,Base.RecoilPad,Base.RedDot,Base.Remington870Sawnoff,Base.Remington870Wood,Base.Revolver,Base.Revolver_Long,Base.Revolver_Short,Base.Rifle_Bipod,Base.Rossi92,Base.Rugerm7722,Base.Shotgun,Base.ShotgunSawnoff,Base.ShotgunShells,Base.ShotgunShellsBox,Base.ShotgunSilencer,Base.ShotgunStock,Base.Silencer_PopBottle,Base.Silencer_PopBottle_Broken,Base.SKS,Base.Sling,Base.Sling_Camo,Base.Sling_Leather,Base.Sling_Olive,Base.Solvent,Base.SPAS12,Base.SPAS12_Stock_Detracted,Base.SPAS12_Stock_Extended,Base.TacticalStock,Base.UZI,Base.UZI_Stock_Detracted,Base.UZI_Stock_Extended,Base.UZIMag,Base.VarmintRifle,Base.Winchester73,Base.Winchester94,Base.x2LeupoldScope,Base.x2Scope,Base.x4Scope,Base.x4-x12Scope,Base.x8Scope,SMUIClothing.Hat_M17,SMUIClothing.Hat_M17Doff,SMUIClothing.Hat_M1Helmet,SMUIClothing.Hat_M1HelmetAutumnMitchell,SMUIClothing.Hat_M1HelmetAutumnMitchellGoggles,SMUIClothing.Hat_M1HelmetAutumnMitchellGogglesStrapless,SMUIClothing.Hat_M1HelmetAutumnMitchellStrapless,SMUIClothing.Hat_M1HelmetERDL,SMUIClothing.Hat_M1HelmetERDLGoggles,SMUIClothing.Hat_M1HelmetERDLGogglesStrapless,SMUIClothing.Hat_M1HelmetERDLStrapless,SMUIClothing.Hat_M1HelmetGoggles,SMUIClothing.Hat_M1HelmetGogglesStrapless,SMUIClothing.Hat_M1HelmetHawaiian,SMUIClothing.Hat_M1HelmetHawaiianStrapless,SMUIClothing.Hat_M1HelmetMilitaryPolice,SMUIClothing.Hat_M1HelmetMilitaryPoliceGoggles,SMUIClothing.Hat_M1HelmetMilitaryPoliceGogglesStrapless,SMUIClothing.Hat_M1HelmetMilitaryPoliceStrapless,SMUIClothing.Hat_M1HelmetMitchell,SMUIClothing.Hat_M1HelmetMitchellGoggles,SMUIClothing.Hat_M1HelmetMitchellGogglesStrapless,SMUIClothing.Hat_M1HelmetMitchellStrapless,SMUIClothing.Hat_M1HelmetRagtop,SMUIClothing.Hat_M1HelmetRagtopStrapless,SMUIClothing.Hat_M1HelmetStrapless,SMUIClothing.Hat_M1HelmetThreeColor,SMUIClothing.Hat_M1HelmetThreeColorGoggles,SMUIClothing.Hat_M1HelmetThreeColorGogglesStrapless,SMUIClothing.Hat_M1HelmetThreeColorStrapless,SMUIClothing.Hat_M1HelmetWoodland,SMUIClothing.Hat_M1HelmetWoodlandGoggles,SMUIClothing.Hat_M1HelmetWoodlandGogglesStrapless,SMUIClothing.Hat_M1HelmetWoodlandStrapless,SMUIClothing.Hat_M40,SMUIClothing.Hat_M40Doff,SMUIClothing.Hat_M9,SMUIClothing.Hat_MarkIV,SMUIClothing.Hat_MilitaryHelmet,SMUIClothing.Hat_MilitaryHelmetDesert,SMUIClothing.Hat_MilitaryHelmetDesertCombat,SMUIClothing.Hat_MilitaryHelmetDesertCombatGoggles,SMUIClothing.Hat_MilitaryHelmetDesertCombatGogglesStrapless,SMUIClothing.Hat_MilitaryHelmetDesertCombatNVGDOWN,SMUIClothing.Hat_MilitaryHelmetDesertCombatNVGMount,SMUIClothing.Hat_MilitaryHelmetDesertCombatNVGUP,SMUIClothing.Hat_MilitaryHelmetDesertCombatStrapless,SMUIClothing.Hat_MilitaryHelmetDesertGoggles,SMUIClothing.Hat_MilitaryHelmetDesertGogglesStrapless,SMUIClothing.Hat_MilitaryHelmetDesertNVGDOWN,SMUIClothing.Hat_MilitaryHelmetDesertNVGMount,SMUIClothing.Hat_MilitaryHelmetDesertNVGUP,SMUIClothing.Hat_MilitaryHelmetDesertStrapless,SMUIClothing.Hat_MilitaryHelmetGogglesStrapless,SMUIClothing.Hat_MilitaryHelmetHawaiian,SMUIClothing.Hat_MilitaryHelmetHawaiianStrapless,SMUIClothing.Hat_MilitaryHelmetNVGDOWN,SMUIClothing.Hat_MilitaryHelmetNVGMount,SMUIClothing.Hat_MilitaryHelmetNVGUP,SMUIClothing.Hat_MilitaryHelmetRagtop,SMUIClothing.Hat_MilitaryHelmetRagtopStrapless,SMUIClothing.Hat_MilitaryHelmetRiot,SMUIClothing.Hat_MilitaryHelmetRiotUP,SMUIClothing.Hat_MilitaryHelmetShark,SMUIClothing.Hat_MilitaryHelmetSharkStrapless,SMUIClothing.Hat_MilitaryHelmetStrapless,SMUIClothing.Hat_MilitaryTacticalHelmet,SMUIClothing.Hat_MilitaryTacticalHelmetGoggles,SMUIClothing.Hat_MilitaryTacticalHelmetNVGDOWN,SMUIClothing.Hat_MilitaryTacticalHelmetNVGMount,SMUIClothing.Hat_MilitaryTacticalHelmetNVGUP,SMUIClothing.Hat_OG106Cap,SMUIClothing.Hat_OG106CapReversed,SMUIClothing.Hat_PatrolCap,SMUIClothing.Hat_PatrolCapDesert,SMUIClothing.Hat_PatrolCapDesertCombat,SMUIClothing.Hat_PatrolCapDesertCombatReversed,SMUIClothing.Hat_PatrolCapDesertCombatRolled,SMUIClothing.Hat_PatrolCapDesertCombatRolledReversed,SMUIClothing.Hat_PatrolCapDesertReversed,SMUIClothing.Hat_PatrolCapDesertRolled,SMUIClothing.Hat_PatrolCapDesertRolledReversed,SMUIClothing.Hat_PatrolCapERDL,SMUIClothing.Hat_PatrolCapERDLBrown,SMUIClothing.Hat_PatrolCapERDLBrownReversed,SMUIClothing.Hat_PatrolCapERDLBrownRolled,SMUIClothing.Hat_PatrolCapERDLReversed,SMUIClothing.Hat_PatrolCapERDLRolled,SMUIClothing.Hat_PatrolCapOG107,SMUIClothing.Hat_PatrolCapOG107Reversed,SMUIClothing.Hat_PatrolCapOG107Rolled,SMUIClothing.Hat_PatrolCapOG107RolledReversed,SMUIClothing.Hat_PatrolCapReversed,SMUIClothing.Hat_PatrolCapRolled,SMUIClothing.Hat_PatrolCapRolledERDLBrownReversed,SMUIClothing.Hat_PatrolCapRolledERDLReversed,SMUIClothing.Hat_PatrolCapRolledReversed,SMUIClothing.Hat_PatrolCapUrban,SMUIClothing.Hat_PatrolCapUrbanReversed,SMUIClothing.Hat_PatrolCapUrbanRolled,SMUIClothing.Hat_PatrolCapUrbanRolledReversed,SMUIClothing.Hat_PatrolCapWinter,SMUIClothing.Hat_PatrolCapWinterDesert,SMUIClothing.Hat_PVS5Black,SMUIClothing.Hat_PVS5Green,SMUIClothing.Hat_Shemagh,SMUIClothing.Hat_ShemaghDesert,SMUIClothing.Hat_ShemaghDesertDown,SMUIClothing.Hat_ShemaghDown,SMUIClothing.Hat_ShemaghWoodland,SMUIClothing.Hat_ShemaghWoodlandDown,SMUIClothing.Hat_TigerStripeBeret,SMUIClothing.Hat_WatchCap,SMUIClothing.HelmetRags,SMUIClothing.Jacket_ArmyCamoDesert,SMUIClothing.Jacket_ArmyCamoDesertRolled,SMUIClothing.Jacket_ArmyCamoGreen,SMUIClothing.Jacket_ArmyCamoGreenRolled,SMUIClothing.Jacket_ArmyCamoUrban,SMUIClothing.Jacket_ArmyCamoUrbanRolled,SMUIClothing.Jacket_DesertCombat,SMUIClothing.Jacket_DesertCombatRolled,SMUIClothing.Jacket_DuckHunter,SMUIClothing.Jacket_DuckHunterRolled,SMUIClothing.Jacket_ERDL,SMUIClothing.Jacket_ERDLBrown,SMUIClothing.Jacket_ERDLBrownRolled,SMUIClothing.Jacket_ERDLRolled,SMUIClothing.Jacket_FrogSkin,SMUIClothing.Jacket_FrogSkinRolled,SMUIClothing.Jacket_Hawaiian,SMUIClothing.Jacket_HawaiianRolled,SMUIClothing.Jacket_M65FieldJacket,SMUIClothing.Jacket_M65FieldJacketMitchell,SMUIClothing.Jacket_M65FieldJacketWoodland,SMUIClothing.Jacket_ODGreen,SMUIClothing.Jacket_ODGreenRolled,SMUIClothing.Jacket_SharkCamo,SMUIClothing.Jacket_SharkCamoRolled,SMUIClothing.Jacket_TigerStripe,SMUIClothing.Jacket_TigerStripeRolled,SMUIClothing.Jacket_TPattern,SMUIClothing.Jacket_TPatternRolled,SMUIClothing.LBV88Webbing,SMUIClothing.LBV88WebbingBag,SMUIClothing.LBV88WebbingBagTightened,SMUIClothing.LBV88WebbingTightened,SMUIClothing.M17Hood,SMUIClothing.M1956Webbing,SMUIClothing.M1956WebbingBag,SMUIClothing.M1956WebbingBagTightened,SMUIClothing.M1956WebbingTightened,SMUIClothing.M40Hood,SMUIClothing.M67Grenade,SMUIClothing.Mask_ExtremeColdWeather,SMUIClothing.MilitaryWebbing,SMUIClothing.MilitaryWebbingBag,SMUIClothing.MilitaryWebbingBagTightened,SMUIClothing.MilitaryWebbingSuspenders,SMUIClothing.MilitaryWebbingTightened,SMUIClothing.MOPPPackageBottom,SMUIClothing.MOPPPackageTop,SMUIClothing.MOPPPackageWrapper,SMUIClothing.MPBrassard,SMUIClothing.MPBrassardAlternate,SMUIClothing.NBCSuit,SMUIClothing.NBCSuitHood,SMUIClothing.NightVisionGoggles,SMUIClothing.NightVisionMount,SMUIClothing.PistolBeltBag,SMUIClothing.PistolBeltPouches,SMUIClothing.Shirt_OG107UtilityShirt,SMUIClothing.Shirt_OG107UtilityShirtRolled,SMUIClothing.Shoes_HazmatBoots,SMUIClothing.Shoes_JungleBoots,AuthenticZClothing.Jacket_Reporter_Radio,AuthenticZClothing.Jacket_Scandroid,AuthenticZClothing.Jacket_StraightJacket,AuthenticZClothing.Jacket_Thriller,AuthenticZClothing.Jacket_Trenchcoat,AuthenticZClothing.Jacket_Varsity_AZ,AuthenticZClothing.Jacket_Varsity_Thriller,AuthenticZClothing.Jacket_Zoey,AuthenticZClothing.JacquesBeaver,AuthenticZClothing.Jersey_BlueStar,AuthenticZClothing.Jersey_GreenBayPacker0,AuthenticZClothing.Jersey_GreenBayPacker1,AuthenticZClothing.Jersey_GreenBayPacker2,AuthenticZClothing.Jersey_GreenBayPacker3,AuthenticZClothing.Jersey_GreenBayPacker4,AuthenticZClothing.Jersey_GreenBayPacker5,AuthenticZClothing.Jersey_GreenBayPacker6,AuthenticZClothing.Jersey_GreenBayPacker7,AuthenticZClothing.Jersey_GreenBayPacker8,AuthenticZClothing.Jersey_GreenBayPacker9,AuthenticZClothing.Jersey_KCChiefs0,AuthenticZClothing.Jersey_KCChiefs1,AuthenticZClothing.Jersey_KCChiefs2,AuthenticZClothing.Jersey_KCChiefs3,AuthenticZClothing.Jersey_KCChiefs4,AuthenticZClothing.Jersey_KCChiefs5,AuthenticZClothing.Jersey_KCChiefs6,AuthenticZClothing.Jersey_KCChiefs7,AuthenticZClothing.Jersey_KCChiefs8,AuthenticZClothing.Jersey_KCChiefs9,AuthenticZClothing.Jersey_NEPatriots0,AuthenticZClothing.Jersey_NEPatriots1,AuthenticZClothing.Jersey_NEPatriots2,AuthenticZClothing.Jersey_NEPatriots3,AuthenticZClothing.Jersey_NEPatriots4,AuthenticZClothing.Jersey_NEPatriots5,AuthenticZClothing.Jersey_NEPatriots6,AuthenticZClothing.Jersey_NEPatriots7,AuthenticZClothing.Jersey_NEPatriots8,AuthenticZClothing.Jersey_NEPatriots9,AuthenticZClothing.Jersey_RedSkull,AuthenticZClothing.Jumper_DiamondBillMurray,AuthenticZClothing.Jumper_PoloNeckCheeseRoyale,AuthenticZClothing.MakeUp_BillMurray,AuthenticZClothing.MakeUp_ClownFace1Color,AuthenticZClothing.MakeUp_ClownFace2Color,AuthenticZClothing.MakeUp_Freddy,AuthenticZClothing.MakeUp_Insane,AuthenticZClothing.MakeUp_Joker,AuthenticZClothing.MakeUp_JokerColor,AuthenticZClothing.MakeUp_MimeBlack,AuthenticZClothing.MakeUp_MimeRed,AuthenticZClothing.MakeUp_Pennywise,AuthenticZClothing.MakeUp_ShotgunFace,SLEOClothing.Hat_PoliceHelmetGreenGoggles,SLEOClothing.Hat_PoliceHelmetGreenGogglesStrapless,SLEOClothing.Hat_PoliceHelmetGreenStrapless,SLEOClothing.Hat_PoliceHelmetStrapless,SLEOClothing.Hat_PoliceM17,SLEOClothing.Hat_PoliceRiotHelmet,SLEOClothing.Hat_PoliceRiotHelmetUP,SLEOClothing.Hat_PoliceWatchCap,SLEOClothing.Hat_SheriffBaseballCap,SLEOClothing.Hat_SheriffBaseballCapReversed,SLEOClothing.Jacket_PoliceTactical,SLEOClothing.Jacket_PoliceTacticalBlack,SLEOClothing.Jacket_PoliceTacticalBlackRolled,SLEOClothing.Jacket_PoliceTacticalRolled,SLEOClothing.Jacket_SheriffTactical,SLEOClothing.Jacket_SheriffTacticalRolled,SLEOClothing.KneePads,SLEOClothing.LegHolster_Right,SLEOClothing.PoliceDutyBelt,SLEOClothing.PoliceTacticalVest,SLEOClothing.PoliceWebbing,SLEOClothing.PoliceWebbingTightened,SLEOClothing.Shoes_TacticalBoots,SLEOClothing.ShoulderMic,SLEOClothing.ShoulderMicCentered,SLEOClothing.Socks_CopSocks,SLEOClothing.TacticalGoggles,SLEOClothing.TacticalVestUpperArm,SLEOClothing.Trousers_PoliceTactical,SLEOClothing.Trousers_PoliceTacticalBlack,SLEOClothing.Trousers_PoliceTacticalBlackTucked,SLEOClothing.Trousers_PoliceTacticalTucked,SLEOClothing.Trousers_SheriffTactical,SLEOClothing.Trousers_SheriffTacticalTucked,SLEOClothing.TShirt_PoliceBlack,SLEOClothing.TShirt_PoliceWhite,SLEOClothing.Vest_AntiStab,SLEOClothing.Vest_PoliceBulletproofVest,Base.Jacket_ArmyCamoDesert,Base.Jacket_ArmyCamoGreen,Base.Shirt_CamoDesert,Base.Shirt_CamoGreen,Base.Shirt_CamoUrban,Base.Shoes_ArmyBoots,Base.Shoes_ArmyBootsDesert,Base.Trousers_CamoDesert,Base.Trousers_CamoGreen,Base.Trousers_CamoUrban,Base.Tshirt_CamoDesert,Base.Tshirt_CamoGreen,Base.Tshirt_CamoUrban,Base.Vest_BulletArmy,SMUIClothing.Hat_BeretSpecial,SMUIClothing.Hat_BoonieHatERDL,SMUIClothing.Hat_BoonieHatERDLFolded,SMUIClothing.Hat_BoonieHatSixColorDesert,SMUIClothing.Hat_BoonieHatSixColorDesertFolded,SMUIClothing.Hat_BoonieHatThreeColorDesert,SMUIClothing.Hat_BoonieHatThreeColorDesertFolded,SMUIClothing.Hat_BoonieHatTigerStripe,SMUIClothing.Hat_BoonieHatTigerStripeFolded,SMUIClothing.Hat_BoonieHatWoodland,SMUIClothing.Hat_BoonieHatWoodlandFolded,SMUIClothing.Hat_CavalryHat,SMUIClothing.Hat_DH132,SMUIClothing.Hat_DH132Goggles,SMUIClothing.Hat_ERDLBeret,SMUIClothing.Hat_GarrisonCap,SMUIClothing.Hat_HBTBeret"
	
	Do While Not myFile.AtEndofStream
		myLine = myFile.ReadLine
		If InStr(myLine, "    WorldItemRemovalList =") Then
			myLine = "    WorldItemRemovalList =" & chr(34) & removallist & chr(34) & ","
		End If
		myTemp.WriteLine myLine
	Loop

	myFile.Close
	myTemp.Close
	objFSO.DeleteFile(filePath)
	objFSO.MoveFile filePath&".tmp", filePath

End Sub

Sub UpdateRemovalList_3()

	Const ForReading=1
	Const ForWriting=2

	Set objFSO = CreateObject("Scripting.FileSystemObject")
	folder = "C:\Users\tomva\Zomboid\Server\"
	filePath = folder & "servertest_SandboxVars.lua"
	Set myFile = objFSO.OpenTextFile(filePath, ForReading, True)
	Set myTemp= objFSO.OpenTextFile(filePath & ".tmp", ForWriting, True)
	removallist = "Base.Apron_Black,Base.Apron_IceCream,Base.Apron_Jay,Base.Apron_PileOCrepe,Base.Apron_PizzaWhirled,Base.Apron_Spiffos,Base.Apron_White,Base.Apron_WhiteTEXTURE,Base.BellyButton_DangleGold,Base.BellyButton_DangleGoldRuby,Base.BellyButton_DangleSilver,Base.BellyButton_DangleSilverDiamond,Base.BellyButton_RingGold,Base.BellyButton_RingGoldDiamond,Base.BellyButton_RingGoldRuby,Base.BellyButton_RingSilver,Base.BellyButton_RingSilverAmethyst,Base.BellyButton_RingSilverDiamond,Base.BellyButton_RingSilverRuby,Base.BellyButton_StudGold,Base.BellyButton_StudGoldDiamond,Base.BellyButton_StudSilver,Base.BellyButton_StudSilverDiamond,Base.Belt,Base.Belt2,Base.Boilersuit,Base.Boilersuit_BlueRed,Base.Boilersuit_Prisoner,Base.Boilersuit_PrisonerKhaki,Base.Boilersuit_Yellow,Base.Boxers_Hearts,Base.Boxers_RedStripes,Base.Boxers_Silk_Black,Base.Boxers_Silk_Red,Base.Boxers_White,Base.Bra_Strapless_AnimalPrint,Base.Bra_Strapless_Black,Base.Bra_Strapless_FrillyBlack,Base.Bra_Strapless_FrillyPink,Base.Bra_Strapless_FrillyRed,Base.Bra_Strapless_RedSpots,Base.Bra_Strapless_White,Base.Bra_Straps_AnimalPrint,Base.Bra_Straps_Black,Base.Bra_Straps_FrillyBlack,Base.Bra_Straps_FrillyPink,Base.Bra_Straps_FrillyRed,Base.Bra_Straps_White,Base.Bracelet_BangleLeftGold,Base.Bracelet_BangleLeftSilver,Base.Bracelet_BangleRightGold,Base.Bracelet_BangleRightSilver,Base.Bracelet_ChainLeftGold,Base.Bracelet_ChainLeftSilver,Base.Bracelet_ChainRightGold,Base.Bracelet_ChainRightSilver,Base.Bracelet_LeftFriendshipTINT,Base.Bracelet_RightFriendshipTINT,Base.Briefs_AnimalPrints,Base.Briefs_SmallTrunks_Black,Base.Briefs_SmallTrunks_Blue,Base.Briefs_SmallTrunks_Red,Base.Briefs_SmallTrunks_WhiteTINT,Base.Briefs_White,Base.ClosedUmbrellaBlack,Base.ClosedUmbrellaBlue,Base.ClosedUmbrellaRed,Base.ClosedUmbrellaWhite,Base.Dress_Knees,Base.Dress_Long,Base.Dress_long_Straps,Base.Dress_Normal,Base.Dress_SatinNegligee,Base.Dress_Short,Base.Dress_SmallBlackStrapless,Base.Dress_SmallBlackStraps,Base.Dress_SmallStrapless,Base.Dress_SmallStraps,Base.Dress_Straps,Base.DressKnees_Straps,Base.Earring_Dangly_Diamond,Base.Earring_Dangly_Emerald,Base.Earring_Dangly_Pearl,Base.Earring_Dangly_Ruby,Base.Earring_Dangly_Sapphire,Base.Earring_LoopLrg_Gold,Base.Earring_LoopLrg_Silver,Base.Earring_LoopMed_Gold,Base.Earring_LoopMed_Silver,Base.Earring_LoopSmall_Gold_Both,Base.Earring_LoopSmall_Gold_Top,Base.Earring_LoopSmall_Silver_Both,Base.Earring_LoopSmall_Silver_Top,Base.Earring_Pearl,Base.Earring_Stone_Emerald,Base.Earring_Stone_Ruby,Base.Earring_Stone_Sapphire,Base.Earring_Stud_Gold,Base.Earring_Stud_Silver,Base.FrillyUnderpants_Black,Base.FrillyUnderpants_Pink,Base.FrillyUnderpants_Red,Base.Glasses_Aviators,Base.Glasses_Eyepatch_Left,Base.Glasses_Eyepatch_Right,Base.Glasses_Normal,Base.Glasses_Reading,Base.Glasses_SafetyGoggles,Base.Glasses_Shooting,Base.Glasses_SkiGoggles,Base.Glasses_Sun,Base.Glasses_SwimmingGoggles,Base.Gloves_BoxingBlue,Base.Gloves_BoxingRed,Base.Gloves_FingerlessGloves,Base.Gloves_LeatherGloves,Base.Gloves_LeatherGlovesBlack,Base.Gloves_LongWomenGloves,Base.Gloves_Surgical,Base.Gloves_WhiteTINT,Base.Hat_Antlers,Base.Hat_BalaclavaFace,Base.Hat_BalaclavaFull,Base.Hat_Bandana,Base.Hat_BandanaMask,Base.Hat_BandanaMaskTINT,Base.Hat_BandanaTied,Base.Hat_BandanaTiedTINT,Base.Hat_BandanaTINT,Base.Hat_BaseballCap,Base.Hat_BaseballCap_Reverse,Base.Hat_BaseballCapArmy,Base.Hat_BaseballCapArmy_Reverse,Base.Hat_BaseballCapBlue,Base.Hat_BaseballCapBlue_Reverse,Base.Hat_BaseballCapGreen,Base.Hat_BaseballCapGreen_Reverse,Base.Hat_BaseballCapKY,Base.Hat_BaseballCapKY_Red,Base.Hat_BaseballCapKY_Reverse,Base.Hat_BaseballCapRed,Base.Hat_BaseballCapRed_Reverse,Base.Hat_BaseballHelmet_KY,Base.Hat_BaseballHelmet_Rangers,Base.Hat_BaseballHelmet_Z,Base.Hat_Beany,Base.Hat_Beret,Base.Hat_BeretArmy,Base.Hat_BicycleHelmet,Base.Hat_BonnieHat,Base.Hat_BoxingBlue,Base.Hat_BoxingRed,Base.Hat_BucketHat,Base.Hat_BunnyEarsBlack,Base.Hat_BunnyEarsWhite,Base.Hat_ChefHat,Base.Hat_Cowboy,Base.Hat_CrashHelmet,Base.Hat_CrashHelmet_Stars,Base.Hat_CrashHelmetFULL,Base.Hat_DustMask,Base.Hat_EarMuff_Protectors,Base.Hat_EarMuffs,Base.Hat_FastFood,Base.Hat_FastFood_IceCream,Base.Hat_FastFood_Spiffo,Base.Hat_Fedora,Base.Hat_Fedora_Delmonte,Base.Hat_Fireman,Base.Hat_FootballHelmet,Base.Hat_FurryEars,Base.Hat_GasMask,Base.Hat_GoldStar,Base.Hat_GolfHat,Base.Hat_GolfHatTINT,Base.Hat_HardHat,Base.Hat_HardHat_Miner,Base.Hat_HockeyHelmet,Base.Hat_HockeyMask,Base.Hat_Jay,Base.Hat_JockeyHelmet01,Base.Hat_JockeyHelmet02,Base.Hat_JockeyHelmet03,Base.Hat_JockeyHelmet04,Base.Hat_JockeyHelmet05,Base.Hat_JockeyHelmet06,Base.Hat_JokeArrow,Base.Hat_JokeKnife,Base.Hat_NewspaperHat,Base.Hat_PartyHat_Stars,Base.Hat_PartyHat_TINT,Base.Hat_PeakedCapArmy,Base.Hat_Police,Base.Hat_Police_Grey,Base.Hat_Raccoon,Base.Hat_Ranger,Base.Hat_RidingHelmet,Base.Hat_SantaHat,Base.Hat_SantaHatGreen,Base.Hat_ShowerCap,Base.Hat_SPHhelmet,Base.Hat_Spiffo,Base.Hat_SummerHat,Base.Hat_SurgicalCap_Blue,Base.Hat_SurgicalCap_Green,Base.Hat_SurgicalMask_Blue,Base.Hat_SurgicalMask_Green,Base.Hat_Sweatband,Base.Hat_TinFoilHat,Base.Hat_Visor_WhiteTINT,Base.Hat_VisorBlack,Base.Hat_VisorRed,Base.Hat_WeddingVeil,Base.Hat_WinterHat,Base.Hat_WoolyHat,Base.HoodieDOWN_WhiteTINT,Base.HoodieUP_WhiteTINT,Base.HospitalGown,Base.Jacket_Black,Base.Jacket_Chef,Base.Jacket_CoatArmy,Base.Jacket_Fireman,Base.Jacket_LeatherBarrelDogs,Base.Jacket_LeatherIronRodent,Base.Jacket_LeatherWildRacoons,Base.Jacket_NavyBlue,Base.Jacket_Padded,Base.Jacket_PaddedDOWN,Base.Jacket_Police,Base.Jacket_Ranger,Base.Jacket_Shellsuit_Black,Base.Jacket_Shellsuit_Blue,Base.Jacket_Shellsuit_Green,Base.Jacket_Shellsuit_Pink,Base.Jacket_Shellsuit_Teal,Base.Jacket_Shellsuit_TINT,Base.Jacket_Varsity,Base.Jacket_WhiteTINT,Base.JacketLong_Doctor,Base.JacketLong_Random,Base.JacketLong_Santa,Base.JacketLong_SantaGreen,Base.Jumper_DiamondPatternTINT,Base.Jumper_PoloNeck,Base.Jumper_RoundNeck,Base.Jumper_TankTopDiamondTINT,Base.Jumper_TankTopTINT,Base.Jumper_VNeck,Base.MakeUp_BraveHeart,Base.MakeUp_CamoEyes1,Base.MakeUp_CamoEyes2,Base.MakeUp_CamoFullFace1,Base.MakeUp_CamoFullFace2,Base.MakeUp_CamoStripes,Base.MakeUp_ClownFace1,Base.MakeUp_ClownFace2,Base.MakeUp_Crow,Base.MakeUp_EyesShadowBlue,Base.MakeUp_EyesShadowGreen,Base.MakeUp_EyesShadowLightBlue,Base.MakeUp_EyesShadowPink,Base.MakeUp_EyesShadowRed,Base.MakeUp_EyesShadowWhite,Base.MakeUp_EyesShadowYellow,Base.MakeUp_Football,Base.MakeUp_GreenCamo,Base.MakeUp_LipsBlack,Base.MakeUp_LipsBlue,Base.MakeUp_LipsGreen,Base.MakeUp_LipsLightBlue,Base.MakeUp_LipsPink,Base.MakeUp_LipsRed,Base.MakeUp_RedStripes1,Base.MakeUp_RedStripes2,Base.MakeUp_SkullFace1,Base.MakeUp_SkullFace2,Base.MakeupEyeshadow,Base.MakeupFoundation,Base.Necklace_Choker,Base.Necklace_Choker_Amber,Base.Necklace_Choker_Diamond,Base.Necklace_Choker_Sapphire,Base.Necklace_Crucifix,Base.Necklace_DogTag,Base.Necklace_Gold,Base.Necklace_GoldDiamond,Base.Necklace_GoldRuby,Base.Necklace_Pearl,Base.Necklace_Silver,Base.Necklace_SilverCrucifix,Base.Necklace_SilverDiamond,Base.Necklace_SilverSapphire,Base.Necklace_YingYang,Base.NecklaceLong_Amber,Base.NecklaceLong_Gold,Base.NecklaceLong_GoldDiamond,Base.NecklaceLong_Silver,Base.NecklaceLong_SilverDiamond,Base.NecklaceLong_SilverEmerald,Base.NecklaceLong_SilverSapphire,Base.NoseRing_Gold,Base.NoseRing_Silver,Base.NoseStud_Gold,Base.NoseStud_Silver,Base.Ring_Left_MiddleFinger_Gold,Base.Ring_Left_MiddleFinger_GoldDiamond,Base.Ring_Left_MiddleFinger_GoldRuby,Base.Ring_Left_MiddleFinger_Silver,Base.Ring_Left_MiddleFinger_SilverDiamond,Base.Ring_Left_RingFinger_Gold,Base.Ring_Left_RingFinger_GoldDiamond,Base.Ring_Left_RingFinger_GoldRuby,Base.Ring_Left_RingFinger_Silver,Base.Ring_Left_RingFinger_SilverDiamond,Base.Ring_Right_MiddleFinger_Gold,Base.Ring_Right_MiddleFinger_GoldDiamond,Base.Ring_Right_MiddleFinger_GoldRuby,Base.Ring_Right_MiddleFinger_Silver,Base.Ring_Right_MiddleFinger_SilverDiamond,Base.Ring_Right_RingFinger_Gold,Base.Ring_Right_RingFinger_GoldDiamond,Base.Ring_Right_RingFinger_GoldRuby,Base.Ring_Right_RingFinger_Silver,Base.Ring_Right_RingFinger_SilverDiamond,Base.Scarf_StripeBlackWhite,Base.Scarf_StripeBlueWhite,Base.Scarf_StripeRedWhite,Base.Scarf_White,Base.Shirt_Baseball_KY,Base.Shirt_Baseball_Rangers,Base.Shirt_Baseball_Z,Base.Shirt_Bowling_Blue,Base.Shirt_Bowling_Brown,Base.Shirt_Bowling_Green,Base.Shirt_Bowling_LimeGreen,Base.Shirt_Bowling_Pink,Base.Shirt_Bowling_White,Base.Shirt_CropTopNoArmTINT,Base.Shirt_CropTopTINT,Base.Shirt_Denim,Base.Shirt_FormalTINT,Base.Shirt_FormalWhite,Base.Shirt_FormalWhite_ShortSleeve,Base.Shirt_FormalWhite_ShortSleeveTINT,Base.Shirt_HawaiianRed,Base.Shirt_HawaiianTINT,Base.Shirt_Jockey01,Base.Shirt_Jockey02,Base.Shirt_Jockey03,Base.Shirt_Jockey04,Base.Shirt_Jockey05,Base.Shirt_Jockey06,Base.Shirt_Lumberjack,Base.Shirt_OfficerWhite,Base.Shirt_PoliceBlue,Base.Shirt_PoliceGrey,Base.Shirt_Priest,Base.Shirt_PrisonGuard,Base.Shirt_Ranger,Base.Shirt_Scrubs,Base.Shirt_Workman,Base.Shoes_Black,Base.Shoes_BlackBoots,Base.Shoes_BlueTrainers,Base.Shoes_Bowling,Base.Shoes_Brown,Base.Shoes_Fancy,Base.Shoes_FlipFlop,Base.Shoes_Random,Base.Shoes_RedTrainers,Base.Shoes_RidingBoots,Base.Shoes_Sandals,Base.Shoes_Slippers,Base.Shoes_Strapped,Base.Shoes_TrainerTINT,Base.Shoes_Wellies,Base.Shorts_BoxingBlue,Base.Shorts_BoxingRed,Base.Shorts_CamoGreenLong,Base.Shorts_CamoUrbanLong,Base.Shorts_LongDenim,Base.Shorts_LongSport,Base.Shorts_LongSport_Red,Base.Shorts_ShortDenim,Base.Shorts_ShortFormal,Base.Shorts_ShortSport,Base.Skirt_Knees,Base.Skirt_Long,Base.Skirt_Mini,Base.Skirt_Normal,Base.Skirt_Short,Base.Socks_Ankle,Base.Socks_Long,Base.StockingsBlack,Base.StockingsBlackSemiTrans,Base.StockingsBlackTrans,Base.StockingsWhite,Base.Suit_Jacket,Base.Suit_JacketTINT,Base.Swimsuit_TINT,Base.SwimTrunks_Blue,Base.SwimTrunks_Green,Base.SwimTrunks_Red,Base.SwimTrunks_Yellow,Base.Tie_BowTieFull,Base.Tie_BowTieWorn,Base.Tie_Full,Base.Tie_Full_Spiffo,Base.Tie_Worn,Base.Tie_Worn_Spiffo,Base.TightsBlack,Base.TightsBlackSemiTrans,Base.TightsBlackTrans,Base.TightsFishnets,Base.Trousers,Base.Trousers_ArmyService,Base.Trousers_Black,Base.Trousers_Chef,Base.Trousers_DefaultTEXTURE,Base.Trousers_DefaultTEXTURE_HUE,Base.Trousers_DefaultTEXTURE_TINT,Base.Trousers_Denim,Base.Trousers_Fireman,Base.Trousers_JeanBaggy,Base.Trousers_LeatherBlack,Base.Trousers_NavyBlue,Base.Trousers_Padded,Base.Trousers_Police,Base.Trousers_PoliceGrey,Base.Trousers_PrisonGuard,Base.Trousers_Ranger,Base.Trousers_Santa,Base.Trousers_SantaGReen,Base.Trousers_Scrubs,Base.Trousers_Shellsuit_Black,Base.Trousers_Shellsuit_Blue,Base.Trousers_Shellsuit_Green,Base.Trousers_Shellsuit_Pink,Base.Trousers_Shellsuit_Teal,Base.Trousers_Shellsuit_TINT,Base.Trousers_Suit,Base.Trousers_SuitTEXTURE,Base.Trousers_SuitWhite,Base.Trousers_WhiteTEXTURE,Base.Trousers_WhiteTINT,Base.TrousersMesh_DenimLight,Base.TrousersMesh_Leather,Base.Tshirt_ArmyGreen,Base.Tshirt_BusinessSpiffo,Base.Tshirt_DefaultDECAL,Base.Tshirt_DefaultDECAL_TINT,Base.Tshirt_DefaultTEXTURE,Base.Tshirt_DefaultTEXTURE_TINT,Base.Tshirt_Fossoil,Base.Tshirt_Gas2Go,Base.Tshirt_IndieStoneDECAL,Base.Tshirt_McCoys,Base.Tshirt_PileOCrepe,Base.Tshirt_PizzaWhirled,Base.Tshirt_PoliceBlue,Base.Tshirt_PoliceGrey,Base.Tshirt_PoloStripedTINT,Base.Tshirt_PoloTINT,Base.Tshirt_Profession_FiremanBlue,Base.Tshirt_Profession_FiremanRed,Base.Tshirt_Profession_FiremanRed02,Base.Tshirt_Profession_FiremanWhite,Base.Tshirt_Profession_PoliceBlue,Base.Tshirt_Profession_PoliceWhite,Base.Tshirt_Profession_RangerBrown,Base.Tshirt_Profession_RangerGreen,Base.Tshirt_Profession_VeterenGreen,Base.Tshirt_Profession_VeterenRed,Base.Tshirt_Ranger,Base.Tshirt_Rock,Base.Tshirt_Scrubs,Base.Tshirt_SpiffoDECAL,Base.Tshirt_Sport,Base.Tshirt_SportDECAL,Base.Tshirt_ThunderGas,Base.Tshirt_ValleyStation,Base.Tshirt_WhiteLongSleeve,Base.Tshirt_WhiteLongSleeveTINT,Base.Tshirt_WhiteTINT,Base.Underpants_AnimalPrint,Base.Underpants_Black,Base.Underpants_RedSpots,Base.Underpants_White,Base.Vest_BulletCivilian,Base.Vest_DefaultTEXTURE,Base.Vest_DefaultTEXTURE_TINT,Base.Vest_Foreman,Base.Vest_HighViz,Base.Vest_Hunting_Camo,Base.Vest_Hunting_CamoGreen,Base.Vest_Hunting_Grey,Base.Vest_Hunting_Orange,Base.Vest_Waistcoat,Base.Vest_Waistcoat_GigaMart,Base.Vest_WaistcoatTINT,Base.WeddingDress,Base.WeddingJacket,Base.WristWatch_Left_ClassicBlack,Base.WristWatch_Left_ClassicBrown,Base.WristWatch_Left_ClassicGold,Base.WristWatch_Left_ClassicMilitary,Base.WristWatch_Left_DigitalBlack,Base.WristWatch_Left_DigitalDress,Base.WristWatch_Left_DigitalRed,Base.WristWatch_Right_ClassicBlack,Base.WristWatch_Right_ClassicBrown,Base.WristWatch_Right_ClassicGold,Base.WristWatch_Right_ClassicMilitary,Base.WristWatch_Right_DigitalBlack,Base.WristWatch_Right_DigitalDress,Base.WristWatch_Right_DigitalRed,Base.Hat_CrashHelmet_Police,Base.Hat_RiotHelmet,Base.Vest_BulletPolice,SLEOClothing.Bag_DuffelPolice,SLEOClothing.Bag_DuffelSheriff,SLEOClothing.Bag_PoliceUtilityBag,SLEOClothing.Bag_PoliceUtilityBagGreen,SLEOClothing.BlackLegPouch_LLeg,SLEOClothing.BlackLegPouch_RLeg,SLEOClothing.ElbowPads,SLEOClothing.Gloves_TacticalGloves,SLEOClothing.GreenLegPouch_LLeg,SLEOClothing.GreenLegPouch_RLeg,SLEOClothing.Hat_BlackUtilityCap,SLEOClothing.Hat_BlackUtilityCapReversed,SLEOClothing.Hat_BlueUtilityCap,SLEOClothing.Hat_BlueUtilityCapReversed,SLEOClothing.Hat_GreenUtilityCap,SLEOClothing.Hat_GreenUtilityCapReversed,SLEOClothing.Hat_PatrolCapPolice,SLEOClothing.Hat_PatrolCapPoliceBlack,SLEOClothing.Hat_PatrolCapPoliceBlackReversed,SLEOClothing.Hat_PatrolCapPoliceBlackRolled,SLEOClothing.Hat_PatrolCapPoliceBlackRolledReversed,SLEOClothing.Hat_PatrolCapPoliceReversed,SLEOClothing.Hat_PatrolCapPoliceRolled,SLEOClothing.Hat_PatrolCapPoliceRolledReversed,SLEOClothing.Hat_PatrolCapSheriff,SLEOClothing.Hat_PatrolCapSheriffReversed,SLEOClothing.Hat_PatrolCapSheriffRolled,SLEOClothing.Hat_PatrolCapSheriffRolledReversed,SLEOClothing.Hat_PoliceBalaclava,SLEOClothing.Hat_PoliceBalaclavaDown,SLEOClothing.Hat_PoliceBaseballCap,SLEOClothing.Hat_PoliceBaseballCapReversed,SLEOClothing.Hat_PoliceCap,SLEOClothing.Hat_PoliceHelmet,SLEOClothing.Hat_PoliceHelmetGoggles,SLEOClothing.Hat_PoliceHelmetGogglesStrapless,SLEOClothing.Hat_PoliceHelmetGreen,Base.ModernTire1,Base.ModernTire2,Base.ModernTire3,Base.NormalTire1,Base.NormalTire2,Base.NormalTire3,Base.OldTire1,Base.OldTire2,Base.OldTire3,Base.M113Tire1,Base.M113Tire2,Base.M113Tire3,Base.ECTO1tire1_Item,Base.ECTO1tire2_Item,Base.DodgeRTtire3,Base.V102Tire2,Base.KZ1KmodernTire,Base.KZ1KnormalTire,Base.V100Tire2,Base.V100Tires2,Base.E150Tire2,Base.80sOffroadTireA,Base.V101Tire2,Base.R32Tire0,Base.R32Tire1,Base.R32Tire2,Base.R32TireA,Autotsar.ATAMotoBMWModernTire,Autotsar.ATAMotoBMWNormalTire,Autotsar.ATAMotoBMWOldTire,Autotsar.ATAMotoHarleyModernTire,Autotsar.ATAMotoHarleyNormalTire,Autotsar.ATAMotoHarleyOldTire,Base.TirePump,Base.LugWrench,Base.Jack,Base.Screwdriver,Base.WoodenMallet,Base.Wrench,Base.Hammer,Base.GardenSaw,Radio.ElectricWire,Base.ElectronicsScrap,Radio.RadioReceiver,Radio.RadioTransmitter,Base.Amplifier,Base.Battery,Base.LightBulb,Base.LightBulbRed,Base.LightBulbGreen,Base.LightBulbBlue,Base.LightBulbYellow,Base.LightBulbCyan,Base.LightBulbMagenta,Base.LightBulbOrange,Base.LightBulbPurple,Base.LightBulbPink,Base.Shovel,Base.Shovel2,Base.SnowShovel,TAD.BobTA_Afoxe_Samba_Raggae_card,TAD.BobTA_African_Noodle_Mag,TAD.BobTA_African_Rainbow_Mag,TAD.BobTA_Arm_Push_Mag,TAD.BobTA_Arm_Wave_One_Mag,TAD.BobTA_Arm_Wave_Two_Mag,TAD.BobTA_Arms_Hip_Hop_Mag,TAD.BobTA_Around_The_World_Mag,TAD.BobTA_Bboy_Hip_Hop_One_Mag,TAD.BobTA_Bboy_Hip_Hop_Three_Mag,TAD.BobTA_Bboy_Hip_Hop_Two_Mag,TAD.BobTA_Belly_Dancing_One_card,TAD.BobTA_Belly_Dancing_Three_card,TAD.BobTA_Belly_Dancing_Two_card,TAD.BobTA_Body_Wave_Mag,TAD.BobTA_Boogaloo_card,TAD.BobTA_Booty_Step_Mag,TAD.BobTA_Breakdance_1990_card,TAD.BobTA_Breakdance_Brooklyn_Uprock_Mag,TAD.BobTA_Breakdance_Freezes_Combo_card,TAD.BobTA_Cabbage_Patch_Mag,TAD.BobTA_Can_Can_Mag,TAD.BobTA_Charleston_card,TAD.BobTA_Chicken_Mag,TAD.BobTA_Crazy_Legs_Mag,TAD.BobTA_Defile_De_Samba_Parade_Mag,TAD.BobTA_Gandy_card,TAD.BobTA_Hokey_Pokey_Mag,TAD.BobTA_House_Dancing_card,TAD.BobTA_Kick_Step_Mag,TAD.BobTA_Locking_card,TAD.BobTA_Macarena_Mag,TAD.BobTA_Maraschino_Mag,TAD.BobTA_MoonWalk_One_Mag,TAD.BobTA_Moonwalk_Two_card,TAD.BobTA_Northern_Soul_Spin_and_Floor_Work_card,TAD.BobTA_Northern_Soul_Spin_Dip_and_Splits_card,TAD.BobTA_Northern_Soul_Spin_Mag,TAD.BobTA_Northern_Soul_Spin_On_Floor_Mag"

	Do While Not myFile.AtEndofStream
		myLine = myFile.ReadLine
		If InStr(myLine, "    WorldItemRemovalList =") Then
			myLine = "    WorldItemRemovalList =" & chr(34) & removallist & chr(34) & ","
		End If
		myTemp.WriteLine myLine
	Loop

	myFile.Close
	myTemp.Close
	objFSO.DeleteFile(filePath)
	objFSO.MoveFile filePath&".tmp", filePath

End Sub

Sub UpdateRemovalList_4()

	Const ForReading=1
	Const ForWriting=2

	Set objFSO = CreateObject("Scripting.FileSystemObject")
	folder = "C:\Users\tomva\Zomboid\Server\"
	filePath = folder & "servertest_SandboxVars.lua"
	Set myFile = objFSO.OpenTextFile(filePath, ForReading, True)
	Set myTemp= objFSO.OpenTextFile(filePath & ".tmp", ForWriting, True)
	removallist = "SMUIClothing.Shoes_MickeyMouse,SMUIClothing.Shorts_CamoDesertLong,SMUIClothing.SMUI_Facepaint,SMUIClothing.SMUI_MaleHeadStubble,SMUIClothing.Socks_GeneralIssue,SMUIClothing.Trousers_CamoDesert,SMUIClothing.Trousers_CamoDesertTucked,SMUIClothing.Trousers_CamoGreen,SMUIClothing.Trousers_CamoGreenTucked,SMUIClothing.Trousers_CamoUrban,SMUIClothing.Trousers_CamoUrbanTucked,SMUIClothing.Trousers_DesertCombat,SMUIClothing.Trousers_DesertCombatTucked,SMUIClothing.Trousers_DuckHunter,SMUIClothing.Trousers_DuckHunterTucked,SMUIClothing.Trousers_ERDL,SMUIClothing.Trousers_ERDLBrown,SMUIClothing.Trousers_ERDLBrownTucked,SMUIClothing.Trousers_ERDLTucked,SMUIClothing.Trousers_FrogSkin,SMUIClothing.Trousers_FrogSkinTucked,SMUIClothing.Trousers_Hawaiian,SMUIClothing.Trousers_HawaiianTucked,SMUIClothing.Trousers_Mitchell,SMUIClothing.Trousers_MitchellTucked,SMUIClothing.Trousers_NBCPants,SMUIClothing.Trousers_ODGreen,SMUIClothing.Trousers_ODGreenTucked,SMUIClothing.Trousers_OG107Utility,SMUIClothing.Trousers_OG107UtilityTucked,SMUIClothing.Trousers_SharkCamo,SMUIClothing.Trousers_SharkCamoTucked,SMUIClothing.Trousers_TigerStripe,SMUIClothing.Trousers_TigerStripeTucked,SMUIClothing.Trousers_TPattern,SMUIClothing.Trousers_TPatternTucked,SMUIClothing.TShirt_NoveltyGulfWar,SMUIClothing.Vest_MilitaryTacticalVest,SMUIClothing.Vest_MilitaryTankerVest,SMUIClothing.Vest_ODGreen,SMUIClothing.Vest_PASGTDesert,SMUIClothing.Vest_PASGTDesertCombat,SMUIClothing.Vest_PASGTOD,SMUIClothing.Vest_RangerBodyArmorDesert,SMUIClothing.Vest_RangerBodyArmorWoodland,AuthenticZClothing.Bikini_Pattern02,AuthenticZClothing.Bikini_Pattern03,AuthenticZClothing.Bikini_Pattern04,AuthenticZClothing.BlackLeggings_Bottoms,AuthenticZClothing.Blue_LongJohns,AuthenticZClothing.Boilersuit_BigDaddy,AuthenticZClothing.Boilersuit_BlackMamba,AuthenticZClothing.Boilersuit_ClownSuit,AuthenticZClothing.Boilersuit_CrossingGuard,AuthenticZClothing.Boilersuit_GhostbustersSpengler,AuthenticZClothing.Boilersuit_GhostbustersStantz,AuthenticZClothing.Boilersuit_GhostbustersVenkman,AuthenticZClothing.Boilersuit_GhostbustersZeddemore,AuthenticZClothing.Boilersuit_Halloween,AuthenticZClothing.Boilersuit_Pennywise,AuthenticZClothing.Boilersuit_PrisonerClassic,AuthenticZClothing.Boilersuit_Wrinkles,AuthenticZClothing.Dress_Dimitrescu,AuthenticZClothing.Dress_DimitrescuALT,AuthenticZClothing.Dress_Flower,AuthenticZClothing.Dress_Flower_Knees,AuthenticZClothing.Dress_Knees_Black,AuthenticZClothing.Dress_LongBlack,AuthenticZClothing.Dress_LongBlue,AuthenticZClothing.Dress_LongFlower,AuthenticZClothing.Dress_LongPink,AuthenticZClothing.Dress_LongPolkadot,AuthenticZClothing.Dress_Maid,AuthenticZClothing.Dress_NormalBlue,AuthenticZClothing.Dress_NormalPink,AuthenticZClothing.Dress_Nurse,AuthenticZClothing.Dress_Polkadot,AuthenticZClothing.Dress_Polkadot_Knees,AuthenticZClothing.Dress_Purna,AuthenticZClothing.Dress_Short2,AuthenticZClothing.Fat01_AmmoStrap,AuthenticZClothing.Fat01_Apron,AuthenticZClothing.Fat01_Coveralls,AuthenticZClothing.Fat01_Dress_Knees,AuthenticZClothing.Fat01_Dress_Long,AuthenticZClothing.Fat01_Dress_long_Straps,AuthenticZClothing.Fat01_Dress_Normal,AuthenticZClothing.Fat01_Dress_SatinNegligee,AuthenticZClothing.Fat01_Dress_Short,AuthenticZClothing.Fat01_Dress_SmallStrapless,AuthenticZClothing.Fat01_Dress_SmallStraps,AuthenticZClothing.Fat01_Dress_Straps,AuthenticZClothing.Fat01_DressKnees_Straps,AuthenticZClothing.Fat01_HoodieDOWN,AuthenticZClothing.Fat01_HoodieUP,AuthenticZClothing.Fat01_Jacket,AuthenticZClothing.Fat01_JacketLeather,AuthenticZClothing.Fat01_JacketLong,AuthenticZClothing.Fat01_PonchoDown,AuthenticZClothing.Fat01_PonchoUP,AuthenticZClothing.Fat01_ShellPants,AuthenticZClothing.Fat01_Shoes,AuthenticZClothing.Fat01_Skirt_Knees,AuthenticZClothing.Fat01_Skirt_Long,AuthenticZClothing.Fat01_Skirt_Normal,AuthenticZClothing.Fat01_Skirt_Short,AuthenticZClothing.Fat01_SportShorts,AuthenticZClothing.Fat01_TShirt,AuthenticZClothing.Fat01_Vest_HighViz,AuthenticZClothing.Fat01_Vest_TankTop,AuthenticZClothing.Fat02_AmmoStrap,AuthenticZClothing.Fat02_Apron,AuthenticZClothing.Fat02_Boxers,AuthenticZClothing.Fat02_Coveralls,AuthenticZClothing.Fat02_Dress_Knees,AuthenticZClothing.Fat02_Dress_Long,AuthenticZClothing.Fat02_Dress_long_Straps,AuthenticZClothing.Fat02_Dress_Normal,AuthenticZClothing.Fat02_Dress_SatinNegligee,AuthenticZClothing.Fat02_Dress_Short,AuthenticZClothing.Fat02_Dress_SmallStrapless,AuthenticZClothing.Fat02_Dress_SmallStraps,AuthenticZClothing.Fat02_Dress_Straps,AuthenticZClothing.Fat02_DressKnees_Straps,AuthenticZClothing.Fat02_HoodieDOWN,AuthenticZClothing.Fat02_HoodieUP,AuthenticZClothing.Fat02_Jacket,AuthenticZClothing.Fat02_JacketLeather,AuthenticZClothing.Fat02_JacketLong,AuthenticZClothing.Fat02_Overalls,AuthenticZClothing.Fat02_PonchoDown,AuthenticZClothing.Fat02_PonchoUP,AuthenticZClothing.Fat02_ShellPants,AuthenticZClothing.Fat02_Shoes,AuthenticZClothing.Fat02_Skirt_Knees,AuthenticZClothing.Fat02_Skirt_Long,AuthenticZClothing.Fat02_Skirt_Normal,AuthenticZClothing.Fat02_Skirt_Short,AuthenticZClothing.Fat02_SportShorts,AuthenticZClothing.Fat02_TShirt,AuthenticZClothing.Fat02_TShirtCheese,AuthenticZClothing.Fat02_Vest_HighViz,AuthenticZClothing.Fat02_Vest_TankTop,AuthenticZClothing.Fat03_AmmoStrap,AuthenticZClothing.Fat03_Apron,AuthenticZClothing.Fat03_Coveralls,AuthenticZClothing.Fat03_Dress_Knees,AuthenticZClothing.Fat03_Dress_Long,AuthenticZClothing.Fat03_Dress_long_Straps,AuthenticZClothing.Fat03_Dress_Normal,AuthenticZClothing.Fat03_Dress_SatinNegligee,AuthenticZClothing.Fat03_Dress_Short,AuthenticZClothing.Fat03_Dress_SmallStrapless,AuthenticZClothing.Fat03_Dress_SmallStraps,AuthenticZClothing.Fat03_Dress_Straps,AuthenticZClothing.Fat03_DressKnees_Straps,AuthenticZClothing.Fat03_HoodieDOWN,AuthenticZClothing.Fat03_HoodieUP,AuthenticZClothing.Fat03_Jacket,AuthenticZClothing.Fat03_JacketLeather,AuthenticZClothing.Fat03_JacketLong,AuthenticZClothing.Fat03_Jeans,AuthenticZClothing.Fat03_Overalls,AuthenticZClothing.Fat03_PonchoDown,AuthenticZClothing.Fat03_PonchoUP,AuthenticZClothing.Fat03_ShellPants,AuthenticZClothing.Fat03_Shoes,AuthenticZClothing.Fat03_Skirt_Knees,AuthenticZClothing.Fat03_Skirt_Long,AuthenticZClothing.Fat03_Skirt_Normal,AuthenticZClothing.Fat03_Skirt_Short,AuthenticZClothing.Fat03_SportShorts,AuthenticZClothing.Fat03_SuitPants,AuthenticZClothing.Fat03_TShirt,AuthenticZClothing.Fat03_TShirtLongBlart,AuthenticZClothing.Fat03_Vest_BlackOpen,AuthenticZClothing.Fat03_Vest_HighViz,AuthenticZClothing.Fat03_Vest_TankTop,AuthenticZClothing.Glasses_AviatorsSunset,AuthenticZClothing.Glasses_Cheese,AuthenticZClothing.Glasses_Popeyes,AuthenticZClothing.Glasses_ReadingBlack,AuthenticZClothing.Gloves_Black,AuthenticZClothing.Gloves_FingerlessGlovesBlue,AuthenticZClothing.Gloves_FingerlessGlovesRed,AuthenticZClothing.Gloves_FingerlessGlovesWHITE,AuthenticZClothing.Gloves_FreddyKreuger,AuthenticZClothing.Gloves_LeatherGlovesBlackFull,AuthenticZClothing.Gloves_LeatherGlovesWhite,AuthenticZClothing.Gloves_LeatherWalker,AuthenticZClothing.Gloves_LongWomenGlovesWhite,AuthenticZClothing.Gloves_OvenMitts,AuthenticZClothing.Gloves_White,AuthenticZClothing.Gloves_White_Reflective,AuthenticZClothing.Gloves_WhitePatriots,AuthenticZClothing.Hat_AuthenticCrashHelmet,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalBobaFett,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalEvelKnievel,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalGreenDragon,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalKiss,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalOptimus,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalPowerRangerRed,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalShark,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalSimple,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalSnowLeopard,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLDecalVenom,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLRacing,AuthenticZClothing.Hat_AuthenticCrashHelmetFULLTINT,AuthenticZClothing.Hat_BalaclavaSpyBlue,AuthenticZClothing.Hat_BalaclavaSpyRed,AuthenticZClothing.Hat_BandanaDesert,AuthenticZClothing.Hat_BandanaMaskDesert,AuthenticZClothing.Hat_BandanaMaskRed,AuthenticZClothing.Hat_BandanaRed,AuthenticZClothing.Hat_BandanaTiedDesert,AuthenticZClothing.Hat_BandanaTiedRed,AuthenticZClothing.Hat_BaseballCapBossTagilla,AuthenticZClothing.Hat_BaseballCapBossTagilla_Reverse,AuthenticZClothing.Hat_BaseballCapClementine,AuthenticZClothing.Hat_BaseballCapClementine_Reverse,AuthenticZClothing.Hat_BaseballCapDayZ,AuthenticZClothing.Hat_BaseballCapDayZ_Reverse,AuthenticZClothing.Hat_BaseballCapEllis,AuthenticZClothing.Hat_BaseballCapEllis_Reverse,AuthenticZClothing.Hat_BaseballCapHolly,AuthenticZClothing.Hat_BaseballCapHolly_Reverse,AuthenticZClothing.Hat_BaseballCapHunter,AuthenticZClothing.Hat_BaseballCapHunter_Reverse,AuthenticZClothing.Hat_BaseballCapJohnMorgan,AuthenticZClothing.Hat_BaseballCapJohnMorgan_Reverse,AuthenticZClothing.Hat_BaseballCapPrinceBelAir,AuthenticZClothing.Hat_BaseballCapPrinceBelAir_Reverse,AuthenticZClothing.Hat_BaseballCapRedDI,AuthenticZClothing.Hat_BaseballCapRedDI_Reverse,AuthenticZClothing.Hat_BaseballCapSeaHorse,AuthenticZClothing.Hat_BaseballCapSeaHorse_Reverse,AuthenticZClothing.Hat_BaseballCapWalker,AuthenticZClothing.Hat_BaseballCapWalker_Reverse,AuthenticZClothing.Hat_BaseballCapWhite,AuthenticZClothing.Hat_BaseballCapWhite_Reverse,AuthenticZClothing.Hat_BeanyGrey,AuthenticZClothing.Hat_BeretBlack,AuthenticZClothing.Hat_BeretMime,AuthenticZClothing.Hat_Boater_Blue,AuthenticZClothing.Hat_Boater_Green,AuthenticZClothing.Hat_Boater_Purple,AuthenticZClothing.Hat_Boater_Red,AuthenticZClothing.Hat_Boater_Small,AuthenticZClothing.Hat_Boater_Yellow,AuthenticZClothing.Hat_CaptainSkipper,AuthenticZClothing.Hat_CheeseHat,AuthenticZClothing.Hat_ChickenHeadJacket,AuthenticZClothing.Hat_ClownConeHead,AuthenticZClothing.Hat_Cowboy_Freddy,AuthenticZClothing.Hat_Dimitrescu,AuthenticZClothing.Hat_Dimitrescu_Back,AuthenticZClothing.Hat_DRLegoHead,AuthenticZClothing.Hat_EarMuff_Protectors_AZ,AuthenticZClothing.Hat_EarMuff_Protectors_Neck,AuthenticZClothing.Hat_EarMuffs_AZ,AuthenticZClothing.Hat_EarMuffs_Neck,AuthenticZClothing.Hat_FastFood_Donut,AuthenticZClothing.Hat_FedoraWhite,AuthenticZClothing.Hat_FootballHelmet_BlueStar,AuthenticZClothing.Hat_FootballHelmet_Chiefs,AuthenticZClothing.Hat_FootballHelmet_Packers,AuthenticZClothing.Hat_FootballHelmet_Patriots,AuthenticZClothing.Hat_FootballHelmet_RedSkull,AuthenticZClothing.Hat_GasMask,AuthenticZClothing.Hat_GhostFace,AuthenticZClothing.Hat_Gibus,AuthenticZClothing.Hat_Gibus2,AuthenticZClothing.Hat_Grimes,AuthenticZClothing.Hat_HardHat_Miner2,AuthenticZClothing.Hat_HockeyMaskJason,AuthenticZClothing.Hat_JackoLantern,AuthenticZClothing.Hat_JasonSack,AuthenticZClothing.Hat_KillaHelmet,AuthenticZClothing.Hat_LeatherFace,AuthenticZClothing.Hat_Maid,AuthenticZClothing.Hat_MichaelMyers,AuthenticZClothing.Hat_Nurse,AuthenticZClothing.Hat_PyromancerSkull,AuthenticZClothing.Hat_RuneDuel,AuthenticZClothing.Hat_RuneDuel_Back,AuthenticZClothing.Hat_StormtrooperHelmetAZ,AuthenticZClothing.Hat_StormtrooperHelmetSparklesAZ,AuthenticZClothing.Hat_StovePipe,AuthenticZClothing.Hat_SummerWhite,AuthenticZClothing.Hat_SummerWhite_Back,AuthenticZClothing.Hat_SweatbandBlue,AuthenticZClothing.Hat_SweatbandOGP,AuthenticZClothing.Hat_SweatbandPink,AuthenticZClothing.Hat_SweatbandPurple,AuthenticZClothing.Hat_SweatbandRBW,AuthenticZClothing.Hat_TagillaMask,AuthenticZClothing.Hat_TagillaMask2,AuthenticZClothing.Hat_TrueEyeCult,AuthenticZClothing.Hat_UncleSam,AuthenticZClothing.Hat_WeddingVeil_AZ,AuthenticZClothing.Hat_WeddingVeil_Front,AuthenticZClothing.Hat_WeddingVeilBlue,AuthenticZClothing.Hat_WeddingVeilBlue_Front,AuthenticZClothing.Hat_WeddingVeilPink,AuthenticZClothing.Hat_WeddingVeilPink_Front,AuthenticZClothing.Hat_WinslowHelmet,AuthenticZClothing.Hat_Witchy_2,AuthenticZClothing.Hat_Witchy_2_Back,AuthenticZClothing.Hat_WoolyHatWaldo,AuthenticZClothing.Hat_WrinklesMask,AuthenticZClothing.HawaiianLei,AuthenticZClothing.HazmatSuit2,AuthenticZClothing.HazmatSuit2NoMask,AuthenticZClothing.HazmatSuit2NoMaskNoShoes,AuthenticZClothing.HazmatSuit2NoShoes,AuthenticZClothing.HazmatSuitCEDANoMask,AuthenticZClothing.HazmatSuitCEDANoMaskNoShoes,AuthenticZClothing.HazmatSuitCEDANoShoes,AuthenticZClothing.HoodieDOWN_Bengal,AuthenticZClothing.HoodieDOWN_Black,AuthenticZClothing.HoodieDOWN_BluePlaid,AuthenticZClothing.HoodieDOWN_Checkered,AuthenticZClothing.HoodieDOWN_CropTopRave,AuthenticZClothing.HoodieDOWN_CropTopTINT,AuthenticZClothing.HoodieDOWN_GreenPlaid,AuthenticZClothing.HoodieDOWN_GreyPlaid,AuthenticZClothing.HoodieDOWN_OrangePlaid,AuthenticZClothing.HoodieDOWN_PurplePlaid,AuthenticZClothing.HoodieDOWN_RedPlaid,AuthenticZClothing.HoodieDOWN_TurquoisePlaid,AuthenticZClothing.HoodieDOWN_Vegan,AuthenticZClothing.HoodieDOWN_WhiteTINT,AuthenticZClothing.HoodieDOWN_YellowPlaid,AuthenticZClothing.HoodieTied_Bengal,AuthenticZClothing.HoodieTied_Black,AuthenticZClothing.HoodieTied_BluePlaid,AuthenticZClothing.HoodieTied_Checkered,AuthenticZClothing.HoodieTied_CropTopRave,AuthenticZClothing.HoodieTied_CropTopTINT,AuthenticZClothing.HoodieTied_GreenPlaid,AuthenticZClothing.HoodieTied_GreyPlaid,AuthenticZClothing.HoodieTied_OrangePlaid,AuthenticZClothing.HoodieTied_PurplePlaid,AuthenticZClothing.HoodieTied_RedPlaid,AuthenticZClothing.HoodieTied_TurquoisePlaid,AuthenticZClothing.HoodieTied_Vegan,AuthenticZClothing.HoodieTied_WhiteTINT,AuthenticZClothing.HoodieTied_YellowPlaid,AuthenticZClothing.HoodieUP_Bengal,AuthenticZClothing.HoodieUP_Black,AuthenticZClothing.HoodieUP_BluePlaid,AuthenticZClothing.HoodieUP_Checkered,AuthenticZClothing.HoodieUP_CropTopRave,AuthenticZClothing.HoodieUP_CropTopTINT,AuthenticZClothing.HoodieUP_GreenPlaid,AuthenticZClothing.HoodieUP_GreyPlaid,AuthenticZClothing.HoodieUP_OrangePlaid,AuthenticZClothing.HoodieUP_PurplePlaid,AuthenticZClothing.HoodieUP_RedPlaid,AuthenticZClothing.HoodieUP_TurquoisePlaid,AuthenticZClothing.HoodieUP_Vegan,AuthenticZClothing.HoodieUP_WhiteTINT,AuthenticZClothing.HoodieUP_YellowPlaid,AuthenticZClothing.InflatableTube_AZ,AuthenticZClothing.Jacket_ArmyCamoUrban,AuthenticZClothing.Jacket_ArmyOliveDrab,AuthenticZClothing.Jacket_ArmyOliveDrab2,AuthenticZClothing.Jacket_Bateman,AuthenticZClothing.Jacket_Bill,AuthenticZClothing.Jacket_Bub,AuthenticZClothing.Jacket_ChuckGreene,AuthenticZClothing.Jacket_Clementine,AuthenticZClothing.Jacket_CoatNavy,AuthenticZClothing.Jacket_Doctor2,AuthenticZClothing.Jacket_Doctor3,AuthenticZClothing.Jacket_FiremanNMRIH,AuthenticZClothing.Jacket_FiremanNMRIHOpen,AuthenticZClothing.Jacket_Francis,AuthenticZClothing.Jacket_FrankWest,AuthenticZClothing.Jacket_Grimes,AuthenticZClothing.Jacket_Hunter,AuthenticZClothing.Jacket_JimmyGibbs,AuthenticZClothing.Jacket_LoganCarter,AuthenticZClothing.Jacket_Mom,AuthenticZClothing.Jacket_PaddedEvangelo,AuthenticZClothing.Jacket_PaddedEvangeloDOWN,AuthenticZClothing.Jacket_PostalDude,AuthenticZClothing.Jacket_Reporter_3N,AuthenticZClothing.Jacket_Reporter_LBMW,Base.ModernTire1,Base.ModernTire2,Base.ModernTire3,Base.NormalTire1,Base.NormalTire2,Base.NormalTire3,Base.OldTire1,Base.OldTire2,Base.OldTire3,Base.M113Tire1,Base.M113Tire2,Base.M113Tire3,Base.ECTO1tire1_Item,Base.ECTO1tire2_Item,Base.DodgeRTtire3,Base.V102Tire2,Base.KZ1KmodernTire,Base.KZ1KnormalTire,Base.V100Tire2,Base.V100Tires2,Base.E150Tire2,Base.80sOffroadTireA,Base.V101Tire2,Base.R32Tire0,Base.R32Tire1,Base.R32Tire2,Base.R32TireA,Autotsar.ATAMotoBMWModernTire,Autotsar.ATAMotoBMWNormalTire,Autotsar.ATAMotoBMWOldTire,Autotsar.ATAMotoHarleyModernTire,Autotsar.ATAMotoHarleyNormalTire,Autotsar.ATAMotoHarleyOldTire,TAD.BobTA_Raise_The_Roof_Mag,TAD.BobTA_Really_Twirl_Mag,TAD.BobTA_Rib_Pops_Mag,TAD.BobTA_Rick_Dancing_card,TAD.BobTA_Robot_One_card,TAD.BobTA_Robot_Two_card,TAD.BobTA_Rockette_Kick_Mag,TAD.BobTA_Rumba_Dancing_Mag,TAD.BobTA_Running_Man_One_Mag,TAD.BobTA_Running_Man_Three_Mag,TAD.BobTA_Running_Man_Two_Mag,TAD.BobTA_Salsa_Double_Twirl_and_Clap_Mag,TAD.BobTA_Salsa_Double_Twirl_Mag,TAD.BobTA_Salsa_Mag,TAD.BobTA_Salsa_Side_to_Side_Mag,TAD.BobTA_Salsa_Two_card,TAD.BobTA_Samba_Olodum_card"

	Do While Not myFile.AtEndofStream
		myLine = myFile.ReadLine
		If InStr(myLine, "    WorldItemRemovalList =") Then
			myLine = "    WorldItemRemovalList =" & chr(34) & removallist & chr(34) & ","
		End If
		myTemp.WriteLine myLine
	Loop

	myFile.Close
	myTemp.Close
	objFSO.DeleteFile(filePath)
	objFSO.MoveFile filePath&".tmp", filePath

End Sub
