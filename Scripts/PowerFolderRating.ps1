### Global Values ###

Clear-Host
echo @'
To install this script, even for a single user, you must have Admin permissions
and run this code in an Admin PowerShell window. This is due to the need to create
the property mapping entries under HKLM.

But the context menu entries and file location can be created for machine-wide
use or only for the user running this script.

Do you wish to install this script for all users or just the currently logged-in user?

'@
Do {} Until ((Read-Host 'A(ll users) or C(urrent user)') -match 'a|c')

$Drive = If ($Matches[0] -eq 'a') {'HKLM:'} ELse {'HKCU:'}

$Null  = Read-Host @'


If you're installing this script for all users, be sure to select a file location
where all users have at least read permissions, such as the folders uner
"C:\Users\Public".

:--- Press <Enter> to continue ---
'@

$BrowseRoot  = If ( $Drive -eq 'HKLM:' ) {"shell:Public"} Else {"shell:UsersFilesFolder"}
$ScriptFiles = (New-Object -com shell.application).BrowseForFolder(0,"Script files location",0x50,$BrowseRoot).Self.Path

echo ('Script files will be created in "{0}"...' -f $ScriptFiles)

### Registry entries creation ###

echo 'Creating registry entries...'

####### Property Mapping ###

$IniPropMap  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\DesktopIniPropertyMap\PropertySetStorage'
$RatingMap   = "$IniPropMap\{64440492-4C8B-11D1-8B70-080036B11A03}\9"

Set-ItemProperty (mkdir $RatingMap -Force).PSPath -InputObject ([PSCustomObject]@{
    'Key'     = 'Rating'
    'Section' = 'Custom'
    'VarType' = 0x17
})

####### Context menu entries ###

########### Set Rating ###

$TopKeys     = @( (Join-Path $Drive 'SOFTWARE\Classes\Directory\Background\Shell\RateFolder') ,
                  (Join-Path $Drive 'SOFTWARE\Classes\Directory\Shell\RateFolder') )
$Ratings     = @( 0 , 1 , 25 , 50 , 75 , 99 )

Set-ItemProperty (mkdir $TopKeys -Force).PSPath -InputObject ([PSCustomObject]@{
    'MUIVerb'         = 'Set Rating'
    'Position'        = 'Top'
    'SeparatorBefore' = ''
    'SubCommands'     = ''
})
Set-ItemProperty $TopKeys 'Icon' '%SystemRoot%\system32\imageres.dll,-1024' -Type ExpandString

0..5 | %{
    $splat = @{
        'Name'  = 'MuiVerb'
        'Value' = If ($_) {'★' * $_} Else {'(None)'}
        'Type'  = 'ExpandString'
    }
    Set-ItemProperty (mkdir (Join-Path $TopKeys "Shell\$_") -Force).PSPath @splat | out-null

    $splat = @{
        'Name'  = '(Default)'
        'Value' = ('"{0}\AddProp.bat" "{2}%V{2}" {1} Rating' -f $ScriptFiles , $Ratings[$_] , "'")
        'Type'  = 'String'
    }
    Set-ItemProperty (mkdir (Join-Path $TopKeys "Shell\$_\Command") -Force).PSPath @splat | out-null
}
########### Add Comment ###

$TopKeys     = @( (Join-Path $Drive 'SOFTWARE\Classes\Directory\Background\Shell\AddComment') ,
                  (Join-Path $Drive 'SOFTWARE\Classes\Directory\Shell\AddComment') )
Set-ItemProperty (mkdir $TopKeys -Force).PSPath -InputObject ([PSCustomObject]@{
    'MUIVerb'         = 'Add Comment'
    'Position'        = 'Top'
    'SeparatorAfter' = ''
})
$splat = @{
    'Name'  = '(Default)'
    'Value' = ('powershell.exe -NoProfile -Command "{0}\Set-FolderProps.ps1" "{1}%V{1}" Comment' -f $ScriptFiles , "'")
    'Type'  = 'String'
}
Set-ItemProperty (mkdir (Join-Path $TopKeys 'Command') -Force).PSPath @splat  



### Set-FolderProps.dll creation ###
###
###     Compiled Add-Type to access/wrap the APIs:
###       - ShowWindow() - https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow
###       - WritePrivateProfileString() - https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-writeprivateprofilestringa
###       - SHGetSetFolderCustomSettings() - https://docs.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shgetsetfoldercustomsettings
###
###     Exposed Functions:
###       - [API]::ShowWindow(hWnd,nCmdShow)
###       - [Desktop.ini]::SetInfoTip(FolderPath,InfoTip)
###       - [Desktop.ini]::GetInfoTip(FolderPath)
###       - [Desktop.ini]::SetRating (FolderPath,Rating)

echo 'Creating "Set-FolderProps.dll"...'

Add-Type @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;

public class API {

    public enum SW : int {
        Hide            = 0,
        Normal          = 1,
        ShowMinimized   = 2,
        Maximize        = 3,
        ShowNoActivate  = 4,
        Show            = 5,
        Minimize        = 6,
        ShowMinNoActive = 7,
        ShowNA          = 8,
        Restore         = 9,
        Showdefault     = 10,
        Forceminimize   = 11
    }
    [DllImport("user32.dll")]
    public static extern int ShowWindow(IntPtr hwnd, SW nCmdShow);
}


namespace Desktop {
    public class ini {

        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool WritePrivateProfileString(
            [MarshalAs(UnmanagedType.LPWStr)] string lpAppName,
            [MarshalAs(UnmanagedType.LPWStr)] string lpKeyName,
            [MarshalAs(UnmanagedType.LPWStr)] string lpString,
            [MarshalAs(UnmanagedType.LPWStr)] string lpFileName );

        [DllImport("shell32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern int SHGetSetFolderCustomSettings(
            SHFolderCustomSettings           pSettings,
            [MarshalAs(UnmanagedType.LPWStr)]
            string                           pszPath,
            FCS                              dwReadWrite);

        [StructLayout(LayoutKind.Sequential)]
        public class SHFolderCustomSettings {
            public int    Size;
            public FCSM   Mask;
            public IntPtr pvid;
            public IntPtr pszWebViewTemplate;
            public int    cchWebViewTemplate;
            public IntPtr pszWebViewTemplateVersion;
            public IntPtr pInfoTip;
            public int    ccInfoTip;
            public IntPtr pclsid;
            public int    dwFlags;
            public IntPtr pszIconFile;
            public int    cchIconFile;
            public int    iIconIndex;
            public IntPtr pszLogo;
            public int    cchLogo;
        }


        public static int  SetInfoTip ( string FolderPath,
                                        string InfoTip      ) {

            SHFolderCustomSettings
                MySettings       = new SHFolderCustomSettings();

            MySettings.Size      = Marshal.SizeOf(MySettings);
            MySettings.Mask      = FCSM.INFOTIP;
            MySettings.pInfoTip  = Marshal.StringToHGlobalUni( InfoTip );
            MySettings.ccInfoTip = 0;

            int Result = SHGetSetFolderCustomSettings( MySettings,
                                                       FolderPath,
                                                       FCS.FORCEWRITE );
            Marshal.FreeHGlobal( MySettings.pInfoTip );
            return Result;
        }

        public static string  GetInfoTip ( string FolderPath ) {

            SHFolderCustomSettings
                MySettings       = new SHFolderCustomSettings();
            MySettings.Size      = Marshal.SizeOf(MySettings);
            MySettings.Mask      = FCSM.INFOTIP;
            MySettings.pInfoTip  = Marshal.AllocHGlobal(1024);
            MySettings.ccInfoTip = 1024 / 2 ;

            int Result = SHGetSetFolderCustomSettings( MySettings,
                                                       FolderPath,
                                                       FCS.READ );
            string InfoTip = "";
            if ( Result == 0 )
            {
                InfoTip = Marshal.PtrToStringUni( MySettings.pInfoTip );
            }
            else
            {
                InfoTip = "";
            }
            Marshal.FreeHGlobal( MySettings.pInfoTip );
            return InfoTip;
        }

        public static void SetRating ( string FolderPath,
                                       int    Rating      )
        {
            DirectoryInfo dir = new DirectoryInfo(FolderPath);
            AddItem ( FolderPath,
                      @"Custom",
                      @"Rating",
                      Rating.ToString() );
            dir.Attributes |= FileAttributes.ReadOnly;
        }

        public static bool AddItem ( string FolderPath,
                                     string Section,
                                     string KeyName,
                                     string Value       )
        {
            string   IniFilePath   = Path.Combine(FolderPath, @"desktop.ini");
         
            bool Return = WritePrivateProfileString( Section,
                                                     KeyName,
                                                     Value,
                                                     IniFilePath );
            File.SetAttributes( IniFilePath,
                                ( FileAttributes.Hidden |
                                  FileAttributes.System |
                                  FileAttributes.Archive  ));
            return Return;
        }
         
        public static int  SetNone ( string FolderPath ) {

            SHFolderCustomSettings
                MySettings       = new SHFolderCustomSettings();
            MySettings.Size      = Marshal.SizeOf(MySettings);
            MySettings.Mask      = FCSM.NONE;

            int Result = SHGetSetFolderCustomSettings( MySettings,
                                                       FolderPath,
                                                       FCS.FORCEWRITE );
            return Result;
        }

        private enum FCS : uint {
            READ            = 0x00000001,
            FORCEWRITE      = 0X00000002,
            WRITE           = 0X00000003,
        }

        [FlagsAttribute]
        public enum FCSM : uint {
            NONE            = 0x00000000,
            VIEWID          = 0x00000001,
            WEBVIEWTEMPLATE = 0x00000002,
            INFOTIP         = 0x00000004,
            CLSID           = 0x00000008,
            ICONFILE        = 0x00000010,
            LOGO            = 0x00000020,
            FLAGS           = 0x00000040
        }
    }
}
'@ -OutputAssembly "$ScriptFiles\Set-FolderProps.dll"

### Set-FolderProps.ps1 cration ###
###    Script file as Here-String written
###    to $ScrptFiles folder selected by user

echo 'Creating "Set-FolderProps.ps1"...'

@'
Add-Type -Path "{0}\Set-FolderProps.dll"
$ThisWindow = [System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle

Switch ($Args[-1]) {
    'Rating'
    {
        [API]::ShowWindow($ThisWindow ,'Hide') | out-null
        $return = [Desktop.ini]::SetRating($Args[0],[Int]$Args[1])
        $Return = [Desktop.ini]::SetInfoTip($Args[0],([Desktop.ini]::GetInfoTip($Args[0])))
        @((New-Object -com shell.application).Windows()).Foreach({ $_.Refresh() })
    }
    'Comment'
    {
        [API]::ShowWindow($ThisWindow ,'Show') | out-null
        $Comment = Read-Host Comment
        [API]::ShowWindow($ThisWindow ,'Hide') | out-null
        $return = [Desktop.ini]::SetInfoTip($Args[0],$Comment)
        @((New-Object -com shell.application).Windows()).Foreach({ $_.Refresh() })
    }
}

'@ -replace ('\{0\}',$ScriptFiles) | Set-Content "$ScriptFiles\Set-FolderProps.ps1"

### AddProp.bat cration ###
###     Wrapper to hide PowerShell window flash

echo 'Creating "AddProp.bat"...'

@'
:: Batch wrappoer to hide PowerShell window

 cmd /c start /min "" powershell.exe -NoProfile -Command "{0}\Set-FolderProps.ps1" %1 %2 %3

:: Troubleshooting
:: powershell.exe -NoExit -NoProfile -Command "{0}\Set-FolderProps.ps1" '%1' %2 %3

::Usage: SetProp.bat %V <PropertyValue>[Rating|Comment]

'@ -f $ScriptFiles | Set-Content "$ScriptFIles\AddProp.bat"

echo 'Done!'