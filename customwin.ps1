<#
.SYNOPSIS
    Ultimate Desktop Customizer (Rice Automator)
    Installs: Rainmeter, Nexus, Windhawk, Lively Wallpaper, SF Pro Font, Night Owl Theme.
    Downloads: JaxCore, Droptop Four.
    Opens: Moewalls.com
#>

# --- 1. Admin Elevation Check ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# --- 2. Load GUI ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- 3. Configuration & URLs ---
$WorkDir = "$env:TEMP\RiceAutomator"
if (!(Test-Path $WorkDir)) { New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null }

$Tools = @{
    "Lively Wallpaper" = @{
        Url = "https://github.com/rocksdanister/lively/releases/download/v2.0.6.1/Lively.Installer.exe"
        Args = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
        Type = "Exe"
    }
    "Rainmeter" = @{
        Url = "https://github.com/rainmeter/rainmeter/releases/download/v4.5.18.3727/Rainmeter-4.5.18.exe"
        Args = "/S"
        Type = "Exe"
    }
    "Nexus Dock" = @{
        Url = "http://www.winstep.net/nexus.zip"
        Args = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
        Type = "Zip"
    }
    "Windhawk" = @{
        Url = "https://windhawk.net/setup/windhawk_setup_offline.exe"
        Args = "/S"
        Type = "Exe"
    }
}

# Rainmeter Skins (require Rainmeter to be installed first)
$Skins = @{
    "Jax Core" = "https://github.com/Jax-Core/JaxCore/releases/latest/download/JaxCore.rmskin"
    "Droptop Four" = "https://github.com/Droptop-Four/Droptop-Four/releases/latest/download/Droptop.Four.rmskin" 
}

# Fonts (SF Pro Display - using a public GitHub mirror)
$Fonts = @(
    "https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts/raw/master/SF-Pro-Display-Regular.otf",
    "https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts/raw/master/SF-Pro-Display-Bold.otf"
)

# Theme (Night Owl - Windows Theme is rare, downloading a Wallpaper variant and VS Code theme ref)
$NightOwlWall = "https://raw.githubusercontent.com/sdras/night-owl-vscode-theme/main/images/night-owl-preview.png" # Placeholder for actual wallpaper

# --- 4. Logic Functions ---

function Update-Status($Text) {
    $StatusLabel.Text = $Text
    $Form.Refresh()
}

function Install-Font($Url) {
    $FileName = $Url.Split('/')[-1]
    $Dest = "$WorkDir\$FileName"
    Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing
    
    $Shell = New-Object -ComObject Shell.Application
    $FontsFolder = $Shell.Namespace(0x14)
    $FontsFolder.CopyHere($Dest)
    Update-Status "Installed Font: $FileName"
}

function Start-RiceProcess {
    $ButtonRun.Enabled = $false
    
    # 1. Install SF Pro Fonts (First, so skins see them)
    Update-Status "Installing SF Pro Fonts..."
    foreach ($f in $Fonts) { try { Install-Font $f } catch {} }

    # 2. Open Moewalls
    Update-Status "Opening Moewalls..."
    Start-Process "https://moewalls.com"

    # 3. Install Base Tools
    foreach ($ToolName in $Tools.Keys) {
        $Data = $Tools[$ToolName]
        Update-Status "Downloading $ToolName..."
        $SavePath = "$WorkDir\$($Data.Url.Split('/')[-1])"
        
        try {
            Invoke-WebRequest -Uri $Data.Url -OutFile $SavePath -UseBasicParsing
            
            if ($Data.Type -eq "Zip") {
                Expand-Archive -LiteralPath $SavePath -DestinationPath "$WorkDir\$ToolName" -Force
                $Installer = Get-ChildItem -Path "$WorkDir\$ToolName" -Filter "*.exe" -Recurse | Select -First 1
                $SavePath = $Installer.FullName
            }

            Update-Status "Installing $ToolName..."
            $Proc = Start-Process -FilePath $SavePath -ArgumentList $Data.Args -PassThru -Wait -WindowStyle Hidden
        } catch {
            Write-Host "Failed to install $ToolName"
        }
    }

    # 4. Apply Night Owl (Download Wallpaper & Set)
    Update-Status "Applying Night Owl Vibe..."
    $WallPath = "$WorkDir\NightOwl_Wall.png"
    Invoke-WebRequest -Uri $NightOwlWall -OutFile $WallPath -UseBasicParsing
    # Set Wallpaper via Registry/SystemParameterInfo
    $code = @'
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet=CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
'@
    Add-Type -TypeDefinition $code -MemberDefinition '[DllImport("user32.dll")] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);' -Name "Win32" -Namespace Win32
    [Win32.Wallpaper]::SystemParametersInfo(20, 0, $WallPath, 3)


    # 5. Install Rainmeter Skins (Rainmeter must be running)
    # We wait a moment for Rainmeter to initialize if it just installed
    Update-Status "Waiting for Rainmeter..."
    Start-Sleep -Seconds 5
    
    $RainmeterPath = "$env:ProgramFiles\Rainmeter\Rainmeter.exe"
    if (Test-Path $RainmeterPath) {
        foreach ($SkinName in $Skins.Keys) {
            Update-Status "Downloading $SkinName..."
            $SkinUrl = $Skins[$SkinName]
            $SkinFile = "$WorkDir\$SkinName.rmskin"
            Invoke-WebRequest -Uri $SkinUrl -OutFile $SkinFile -UseBasicParsing
            
            Update-Status "Launching $SkinName installer..."
            # Rainmeter command to install skin
            Start-Process -FilePath $RainmeterPath -ArgumentList "!InstallSkin `"$SkinFile`""
            Start-Sleep -Seconds 2
        }
    } else {
        Update-Status "Rainmeter not found. Skins skipped."
    }

    Update-Status "All Actions Complete!"
    $ButtonRun.Enabled = $true
}

# --- 5. Build GUI ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Ultimate Rice Automator"
$Form.Size = New-Object System.Drawing.Size(400, 300)
$Form.StartPosition = "CenterScreen"

$LblInfo = New-Object System.Windows.Forms.Label
$LblInfo.Text = "Installs: Lively, Rainmeter, Nexus, Windhawk`nSkins: JaxCore, Droptop Four`nTheme: Night Owl + SF Pro Font`nOpens: Moewalls"
$LblInfo.Size = New-Object System.Drawing.Size(360, 80)
$LblInfo.Location = New-Object System.Drawing.Point(20, 20)
$Form.Controls.Add($LblInfo)

$ButtonRun = New-Object System.Windows.Forms.Button
$ButtonRun.Text = "Start Transformation"
$ButtonRun.Location = New-Object System.Drawing.Point(100, 120)
$ButtonRun.Size = New-Object System.Drawing.Size(180, 50)
$ButtonRun.Add_Click({ Start-RiceProcess })
$Form.Controls.Add($ButtonRun)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Ready..."
$StatusLabel.AutoSize = $true
$StatusLabel.Location = New-Object System.Drawing.Point(20, 200)
$Form.Controls.Add($StatusLabel)

[void]$Form.ShowDialog()
