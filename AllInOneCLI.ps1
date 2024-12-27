#Requires -Version 3.0

<#
.SYNOPSIS
This is a general Windows Hardening tool created for EKUCCDC purposes.
Requires PS 5.1, .NET 4.8, and Administrator rights.
Will update systems from PS 3.0+ to PS 5.1 and .NET to 4.8 or 4.5.2.

.DESCRIPTION
The features of this tool include:
        -.NET version checking / updating
[ X ]     -Checks for 4.8.x+
[ X ]     -Forcefully installs 4.8 (2012+)
[   ]     -Forcefully installs 4.5.2 (Win7+)
        -WMF/PowerShell version checking / updating
[ X ]     -Checks for 5.1+
[ X ]     -Forcefully installs 5.1 (2012/2012 R2)
[   ]     -Forcefully installs 5.1 (Win7+)
[   ]     -Check for compatibility with PS 7
[ X ]     -Optionally can install 7
        -OS hardening
[ X ]     -Backup HKLM hive
[ X ]     -Disabling and modifying a multitude of potentially vulnerable services
[ X ]     -Flushing DNS cache
[ X ]     -Enabling and enlarging Windows Event logs
[ X ]     -Setting suspicious filetypes to default to notepad
[   ]     -Much more coming for this section!
        -Firewall management
[ X ]     -Firewall toggle
[   ]     -MWCCDC firewall setup (requires recieving the Teampack for 2025)
        -Active Directory management
[ X ]     -Scramble default password for all users and save in a .csv
[ X ]     -Remove groups from all users besides current administrator
[   ]     -Generate new AD users
[   ]     -Begin auditing user permissions
[   ]     -Organizational Unit Management
[   ]     -Group Policy Management
        -Windows update management
[ X ]     -Ability to install updates from .csv list
[ X ]     -Turn on automatic updating
[ X ]     -Modifying/restarting auto updater services to attempt to fix not finding updates
        -General security management
[ X ]     -Installation of sysinternals
[ X ]     -Installation of Bluespawn
[ X ]     -Setting logon banner
[ X ]     -Setting logoff timer
[ X ]   -Taking inventory of current services / versions

.PARAMETER NoNet
Disables .NET version checking

.PARAMETER NoWmf
Disables WMF version checking

.PARAMETER Force
Overrides updating without restarting

.INPUTS
None.

.OUTPUTS
None directly, however a directory is created inside of the root directory of the homedrive.
Within this, temporary files will be stored (such as updates), and logs will be created to track the changes made to the system.

.NOTES
Author: Logan Jackson
Date: 2024

.LINK
Resource: https://gist.github.com/mackwage

.LINK
Website: https://lj-sec.github.io/
#>

param (
    [switch]$Force,
    [switch]$NoNet,
    [switch]$NoWmf
)

# PowerShell 3.0 compatible way of checking for admin, requires admin was introduced later
$currentUser = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentUser.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Warning "`nYou must run this script as an administrator."
    Exit 1
}

if($Force.IsPresent)
{
    [System.Environment]::SetEnvironmentVariable("updatedWithoutRestart","False","Machine")
    Write-Host "Cleared false positive! You may now rerun this script."
    Exit 1
} 
elseif([System.Environment]::GetEnvironmentVariable("updatedWithoutRestart","Machine") -eq "True")
{
    Write-Warning "`nYou have updated without restart! Updates must take effect before rerunning script."
    Write-Host "If you have restarted and this is a false positive (which happens), rerun this script with -Force."
    Exit 1
}

# Creating a log file to note changes made to the system
mkdir -ErrorAction SilentlyContinue $env:HOMEDRIVE\WindowsHardeningCLI | Out-Null
mkdir -ErrorAction SilentlyContinue $env:HOMEDRIVE\WindowsHardeningCLI\Logs | Out-Null
$curTime = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$env:HOMEDRIVE\WindowsHardeningCLI\Logs\log_$curTime.txt"
Write-Host "`nEstablishing a log file at $logFile"
Out-File $logFile

# Write-Log Function to write logs to $logFile
function Write-Log {
    param (
        [string]$message,
        [switch]$NoDate
    )

    if($NoDate.IsPresent)
    {
        Write-Output "// $message" | Out-File $logFile -Append
    }
    else
    {
        $currentTime = Get-Date -Format "MM/dd/yyyy HH:mm:ss K"
        Write-Output "$currentTime - $message" | Out-File $logFile -Append   
    }
}

# For downloads and such
$webClient = New-Object System.Net.WebClient
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Write-Log "Script started!"

# Repo root
$reporoot=$null
git help >$null
if($?)
{
    $reporoot = $(git rev-parse --show-toplevel 2>$null)
}
if(!$reporoot)
{
    Write-Log -NoDate "Repo root could not be established"
}

$update=$false

if(!$NoNet.IsPresent)
{
    # Checking for .NET Frameworks older than 4.8, latest .NET compatible for Windows 2012 and up
    $outdatedNet = $false
    switch -Wildcard ((Get-CimInstance Win32_OperatingSystem).Caption)
    {
        "*2012 R2*"
            {
                if((Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release -lt "528049")
                {
                    $outdatedNet = $true
                    $netUpdateLink = "https://go.microsoft.com/fwlink/?LinkId=2085155"
                }
            }
        "*2012*"
            {
                if((Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release -lt "528049")
                {
                    $outdatedNet = $true
                    $netUpdateLink = "https://go.microsoft.com/fwlink/?LinkId=2085155"
                }
            }
        "*2016*"
            {
                if((Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release -lt "528049")
                {
                    $outdatedNet = $true
                    $netUpdateLink = "https://go.microsoft.com/fwlink/?LinkId=2085155"
                }
            }
        "*2019*"
            {
                if((Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release -lt "528049")
                {
                    $outdatedNet = $true
                    $netUpdateLink = "https://go.microsoft.com/fwlink/?LinkId=2085155"
                }
            }
        "*2022*"
            {
                if((Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release -lt "533325")
                {
                    $outdatedNet = $true
                    $netUpdateLink = "https://go.microsoft.com/fwlink/?LinkId=2203304"
                }
            }
        "*10*"
            {
                if((Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release -lt "533325")
                {
                    $outdatedNet = $true
                    $netUpdateLink = "https://go.microsoft.com/fwlink/?LinkId=2203304"
                }
            }
        "*11*"
            {
                if((Get-ItemProperty -LiteralPath 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release -lt "533320")
                {
                    $outdatedNet = $true
                    $netUpdateLink = "https://go.microsoft.com/fwlink/?LinkId=2203304"
                }
            }
        default
            {
                Write-Warning "`nCould not detect compatible Windows Version, and therefore .NET version.`nThis script has only been tested on Windows Server 2012/Windows 10 and later, with .NET 4.8 and later."
                Write-Host "If you would like to run this script anyway, rerun with -NoNet."
                Exit 1
            }
    }

    if($outdatedNet)
    {
        Write-Log "Outdated .NET Framework detected"
        Write-Warning "`n.NET Framework is not 4.8 or above!"
        $updateNet = Read-Host "Would you like to update now? (Y/n)"

        if($updateNet -ilike "n*")
        {
            Write-Warning "`nScript recommends .NET 4.8+, exiting..."
            Write-Host "If you would like to run this script anyway, rerun with -NoNet."
            Write-Log "Script recommends .NET 4.8+, exiting..."
            Exit 1
        }

        $update = $true
        Write-Host "Updating .NET to 4.8...`n"
        Write-Host "Downloading .NET updater..."
        $webClient.DownloadFile("$netUpdateLink", "$env:HOMEDRIVE\WindowsHardeningCLI\net-updater.exe")
        Write-Host "Running .NET updater..."
        Start-Process -FilePath "$env:HOMEDRIVE\WindowsHardeningCLI\net-updater.exe" -ArgumentList "/quiet","/norestart" -Wait
        Write-Host "Done!"
        Write-Log ".NET was updated"
    }
    else
    {
        Write-Host ".NET is up-to-date, 4.8+"
    }
}
else
{
    Write-Host "-NoNet is present, skipping .NET version checking..."
    Write-Log -NoDate "-NoNet is present, skipping .NET version checking"
}

if (!$NoWmf.IsPresent)
{
    if($PSVersionTable.PSVersion.Major -ge "7" -and $PSVersionTable.PSVersion.Minor -ge "4")
    {
        Write-Host "WMF is up-to-date, 7.4.x"
    }
    elseif($PSVersionTable.PSVersion.Major -ge "5" -and $PSVersionTable.PSVersion.Minor -ge "1")
    {
        Write-Host "WMF is up-to-date, 5.1.x"
        if(!(Test-Path "$env:ProgramFiles\PowerShell\7"))
        {
            $updateWmf = Read-Host "Would you like to optionally install 7.4.1? (y/N)"
            if($updateWmf -ilike "y*")
            {
                $updateWmf = $true
                $wmfLink = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi"
            }
            else
            {
                $updateWmf = $false
            }
        }
    }
    else
    {
        Write-Log "Outdated PowerShell version detected"
        Write-Warning "`nPowerShell is not up-to-date!"
        $updateWmf = Read-Host "WMF/PowerShell 5.1 or later is recommended. Would you like to update now to 5.1? (Y/n)"
        if($updateWmf -ilike "n*")
        {
            Write-Warning "`nPowerShell 5.1 and later is recommended for this script!"
            Write-Host "If you would like to run this script anyway, rerun with -NoWmf."
            Exit 1
        }
        switch -Wildcard ((Get-CimInstance Win32_OperatingSystem).Caption)
        {
            "*2012 R2*"
                {
                    $updateWmf = $true
                    $wmfLink = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1AndW2K12R2-KB3191564-x64.msu"
                }
            "*2012*"
                {
                    $updateWmf = $true
                    $wmfLink = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/W2K12-KB3191565-x64.msu"
                }
            default
                {
                    $updateWmf = $false
                    Write-Warning "`nCould not fetch link to download WMF 5.1. This script has only been tested on Windows Server 2012/Windows 10 (1607) and later, with WMF 5.1+."
                    Write-Host "It is highly recommended to install this version yourself.`nIf you would like to run this script anyway, rerun with -NoWmf"
                    Exit 1
                }
        }
    }

    if($updateWmf)
    {
        $update = $true
        Write-Host "`nUpdating WMF..."
        Write-Host "`nDownloading WMF updater..."
        $webClient.DownloadFile("$wmfLink", "$env:HOMEDRIVE\WindowsHardeningCLI\wmf-updater.msu")
        Write-Host "Running WMF updater..."
        Start-Process -FilePath "$env:HOMEDRIVE\WindowsHardeningCLI\wmf-updater.msu" -ArgumentList "/quiet","/norestart" -Wait
        Write-Host "Done!"
        Write-Log "WMF was updated"
    }
}
else
{
    Write-Host "-NoWmf is present, skipping WMF version checking..."
    Write-Log -NoDate "-NoWmf is present, skipping WMF version checking"
}

if($update)
{
    Start-Sleep 2
    Clear-Host
    $restart = Read-Host "`nNecessary updates complete. Restart right now? (y/N)"
    if($restart -ilike "y*")
    {
        [System.Environment]::SetEnvironmentVariable("updatedWithoutRestart","False","Machine")
        Restart-Computer
    }
    else
    {
        [System.Environment]::SetEnvironmentVariable("updatedWithoutRestart","True","Machine")
        Write-Warning "`nRestart is required for updates to take effect."
        Exit 1
    }
}

# Initializing $try and $catch so that later can determine how program is exited
$try=$false
$catch=$false

# Checking if machine is server, and if so what services running on it
$serverOS = ((Get-WmiObject Win32_OperatingSystem).ProductType -in 2,3)
$activeDirectoryRunning = ((Get-Service -ErrorAction SilentlyContinue -Name NTDS).Status -eq "Running")
$dnsRunning = ((Get-Service -ErrorAction SilentlyContinue -Name DNS).Status -eq "Running")
$dhcpRunning = ((Get-Service -ErrorAction SilentlyContinue -Name DhcpServer).Status -eq "Running")

if($serverOS)
{
    Write-Host "Server Operating System was found"
    Write-Log -NoDate "Server Operating System was found"
}
if($activeDirectoryRunning)
{
    Write-Host "Active Directory Service is running"
    Write-Log -NoDate "Active Directory Service is running"
}
if($dnsRunning)
{
    Write-Host "DNS is running"
    Write-Log -NoDate "DNS is running"
}
if($dhcpRunning)
{
    Write-Host "DHCP is running"
    Write-Log -NoDate "DHCP is running"
}

try {
    $ErrorActionPreference = "SilentlyContinue"

    Write-Host "`n========Windows Hardening========"

    do
    {
        Write-Host "`n---Main Menu---"
        Write-Host "1. Scripted Changes"
        Write-Host "2. Firewall"
        if($activeDirectoryRunning)
        {
            Write-Host "3. Active Directory"
        }
        else
        {
            Write-Host -ForegroundColor Red "3. Active Directory (X)"  
        }
        Write-Host "4. Updates"
        Write-Host "5. General Security"
        Write-Host "6. Inventory"
        Write-Host "7. Exit"

        $userInput = Read-Host "`nYour selection"

        switch($userInput)
        {
            "1"
                {
                    Write-Host "General Windows Hardening will now commence..."
                    Write-Warning "`nThis will make several modifications to your HKLM registry hive and default Windows settings`nIt is strongly recommended you review these before proceeding, and comment out those unnecessary or potentially harmful.`n"
                    Write-Host "A backup of your HKLM will be stored in $env:HOMEDRIVE\WindowsHardeningCLI\RegistryBackups.`n"
                    Read-Host "(ENTER to start or CTRL+C to cancel)"

                    Write-Log "General Windows hardening begins!"
                    
                    Write-Log "Attempting to establish a registry backup..."
                    mkdir -ErrorAction SilentlyContinue $env:HOMEDRIVE\WindowsHardeningCLI\RegistryBackups | Out-Null
                    $curTime = Get-Date -Format "yyyyMMdd_HHmmss"
                    $regFile = "$env:HOMEDRIVE\WindowsHardeningCLI\RegistryBackups\backup_$curTime.reg"
                    $continueHardening = $false

                    reg export HKLM $regFile /y | Out-Null
                    
                    if($LASTEXITCODE -eq "0")
                    {
                        Write-Host "HKLM registry sucessfully backed up at $regFile"
                        Write-Log "HKLM registry successfully backed up at $regFile"
                        $continueHardening = $true
                    }
                    else
                    {
                        Write-Warning "`nHKLM backup failed!"
                        $confirmHardening = Read-Host "Continue without a backup? (Not recommended) (y/N):"
                        if($confirmHardening -ilike "y*")
                        {
                            $continueHardening = $true
                        }
                    }

                    if(!$continueHardening)
                    {
                        Break
                    }

                    #### MAKE CHANGES BELOW IF NECESSARY ####
                    #### MAKE CHANGES BELOW IF NECESSARY ####
                    #### MAKE CHANGES BELOW IF NECESSARY ####

                    # Disable RDP
                    Write-Log "Disabling RDP..." 
                    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f

                    # Disable DNS Multicast
                    Write-Log "Disabling DNS Multicast..."
                    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f

                    # Disable parallel A and AAAA DNS queries
                    Write-Log "Disabling parallel A and AAAA DNS queries..."
                    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v DisableParallelAandAAAA /t REG_DWORD /d 1 /f

                    # Disable SMBv1
                    Write-Log "Disabling SMBv1..."
                    reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 /t REG_DWORD /d 0 /f

                    # Enables UAC and Virtualization
                    Write-Log "Enabling UAC and Virtualization..."
                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f
                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableVirtualization /t REG_DWORD /d 1 /f
                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 2 /f

                    # Enable Safe DLL search mode and protection mode to prevent hijacking
                    Write-Log "Enabling Safe DLL search mode and protection mode..."
                    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v SafeDLLSearchMode /t REG_DWORD /d 1 /f
                    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v ProtectionMode /t REG_DWORD /d 1 /f

                    # Record command line data in process creation events eventid 4688
                    Write-Log "Enabling auditing of command line data in process creations events (ID 4688)..."
                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f

                    # Prevents the application of category-level audit policy from Group Policy and from the Local Security Policy administrative tool
                    Write-Log "Preventing the application of category-level audit policy from Group Policy and from the Local Security Policy administrative tool"
                    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v SCENoApplyLegacyAuditPolicy /t REG_DWORD /d 1 /f

                    # Enable PowerShell Logging
                    Write-Log "Enabling PowerShell logging..."
                    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" /v EnableModuleLogging /t REG_DWORD /d 1 /f
                    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" /v EnableScriptBlockLogging /t REG_DWORD /d 1 /f

                    # Harden Lsass
                    Write-Log "Hardening LSASS..."
                    reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe" /v AuditLevel /t REG_DWORD /d 00000008 /f
                    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL /t REG_DWORD /d 00000001 /f
                    reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential /t REG_DWORD /d 0 /f
                    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" /v AllowProtectedCreds /t REG_DWORD /d 1 /f
                    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" /v AllowDigest /t REG_DWORD /d 0 /f

                    # Encrypt/Sign outgoing secure channel traffic when possible
                    Write-Log "Signing outgoing secure channel traffic when possible..."
                    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" /v SealSecureChannel /t REG_DWORD /d 1 /f
                    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" /v SignSecureChannel /t REG_DWORD /d 1 /f

                    # Enable Windows Event Detailed Login
                    Write-Log "Enabling Windows Event Detailed Logins..."
                    AuditPol /set /subcategory:"Security Group Management" /success:enable /failure:enable
                    AuditPol /set /subcategory:"Process Creation" /success:enable /failure:enable
                    AuditPol /set /subcategory:"Logoff" /success:enable /failure:disable
                    AuditPol /set /subcategory:"Logon" /success:enable /failure:enable 
                    AuditPol /set /subcategory:"Filtering Platform Connection" /success:enable /failure:disable
                    AuditPol /set /subcategory:"Removable Storage" /success:enable /failure:enable
                    AuditPol /set /subcategory:"SAM" /success:disable /failure:disable
                    AuditPol /set /subcategory:"Filtering Platform Policy Change" /success:disable /failure:disable
                    AuditPol /set /subcategory:"IPsec Driver" /success:enable /failure:enable
                    AuditPol /set /subcategory:"Security State Change" /success:enable /failure:enable
                    AuditPol /set /subcategory:"Security System Extension" /success:enable /failure:enable
                    AuditPol /set /subcategory:"System Integrity" /success:enable /failure:enable
                    
                    # Enlarging Windows Event Security Log Size
                    Write-Log "Increaing the size of Windows Event Security Log..."
                    wevtutil sl Security /ms:1024000
                    wevtutil sl Application /ms:1024000
                    wevtutil sl System /ms:1024000
                    wevtutil sl "Windows PowerShell" /ms:1024000
                    wevtutil sl "Microsoft-Windows-PowerShell/Operational" /ms:1024000

                    # Stop Remote Registry
                    Write-Log "Attempting to stop remote registry..."
                    net stop RemoteRegistry

                    # Flush dns
                    Write-Log "Flushing DNS..."
                    ipconfig /flushdns
                    
                    # Stop WinRM
                    Write-Log "Attempting to stop Remote Management..."
                    net stop WinRM

                    # Disable Guest user
                    Write-Log "Disabling the Guest user account..."
                    net user Guest /active:NO 2>$null

                    # Set some common ransomware filetypes to default to notepad
                    Write-Log "Setting .hta, .wsh, .wsf, .bat, .js, .jse, .vbe, .vbs files to default to notepad.exe..."
                    ftype htafile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"
                    ftype wshfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"
                    ftype wsffile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"
                    ftype batfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"
                    ftype jsfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"
                    ftype jsefile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"
                    ftype vbefile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"
                    ftype vbsfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"

                    #### MAKE CHANGES ABOVE IF NECESSARY ####
                    #### MAKE CHANGES ABOVE IF NECESSARY ####
                    #### MAKE CHANGES ABOVE IF NECESSARY ####

                    Write-Log "General Windows Hardening ends!"
                }
            "2" 
                {
                    do
                    {
                        Write-Host -ForegroundColor Red "`n---Firewall---"
                        Write-Host "1. Enable Firewall"
                        Write-Host "2. Disable Firewall"
                        Write-Host "3. MWCCDC Firewall Setup"
                        Write-Host "4. Main menu"
                        $firewallchoice = Read-Host "`nYour selection"
                        switch($firewallchoice)
                        {
                            "1"
                                {
                                    Write-Warning "`nThis will enable the firewall on all profiles with default/already established rules."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }

                                    Write-Log "Firewall enabled on all profiles with default/already established rules"
                                    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
                                }
                            "2"
                                {
                                    Write-Warning "`nThis will disable the firewall on all profiles."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }

                                    Write-Log "Firewall disabled on all profiles"
                                    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
                                }
                            "3"
                                {
                                    Write-Warning "`nThis will setup firewall rules allowing necessary traffic in accordance with the 2024 MWCCDC Topology."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }

                                    ## UNFINISHED FIREWALL SETUP
                                    ## UNFINISHED FIREWALL SETUP
                                    ## UNFINISHED FIREWALL SETUP
                                    Write-Log "Firewall setup for 2024 MWCCDC begins!"

                                    Write-Log "Firewall setup for 2024 MWCCDC ends!"
                                    ## UNFINISHED FIREWALL SETUP
                                    ## UNFINISHED FIREWALL SETUP
                                    ## UNFINISHED FIREWALL SETUP
                                }
                            "4"
                                {
                                    Break
                                }
                            default
                                {
                                    Write-Host "`nInvalid choice."
                                }
                        }
                    } while ($firewallchoice -ne "4")
                }
            "3" 
                {
                    do
                    {
                        if(!$activeDirectoryRunning)
                        {
                            Write-Host -ForegroundColor Red "Active Directory service was not found at start of script!"
                            Break
                        }
                        
                        mkdir -ErrorAction SilentlyContinue $env:HOMEDRIVE\WindowsHardeningCLI\AD | Out-Null

                        Write-Host -ForegroundColor Blue "`n---Active Directory---"
                        Write-Host "1. User Management"
                        Write-Host "2. Group Management"
                        Write-Host "3. Organizational Unit Management"
                        Write-Host "4. Group Policy Management"
                        Write-Host "5. Security, Auditing, and Health"
                        Write-Host "6. Main menu"
                        $adchoice = Read-Host "`nYour selection"
                        switch($adchoice)
                        {
                            "1"
                                {
                                    do
                                    {
                                        Write-Host -ForegroundColor Blue "`n---User Management---"
                                        Write-Host "1. Scramble default password for all users and save in a .csv"
                                        Write-Host "2. Begin auditing user permissions"
                                        Write-Host "3. Remove groups from all users besides current administrator"
                                        Write-Host "4. Generate new AD users"
                                        Write-Host "5. Main menu"
                                        $userManagementChoice = Read-Host "`nYour selection"
                                        switch($userManagementChoice)
                                        {
                                            "1"
                                                {
                                                    Write-Host "`n---Change All Default Passwords---"
                                                    $csvPath = "$env:HOMEDRIVE\WindowsHardeningCLI\AD\AD_Passwords.csv"
                                                    Write-Warning "`nThis generates new passwords for all users in this Active Directory besides the current Administrator and outputs them into a .csv file at $csvPath"
                                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                                    if ($warning -inotlike "y*")
                                                    {
                                                        Break
                                                    }
                                                    Write-Log "Change all default passwords script begins, caught errors will be listed before end message if any."

                                                    function New-Password
                                                    {
                                                        do
                                                        {
                                                            $length = Get-Random -Minimum 12 -Maximum 17
                                                            $characters = @([char[]]("a"[0].."z"[0])+[char[]]("A"[0].."Z"[0])+[char[]]("0"[0].."9"[0])+[char[]]("!@$%^&*()-=_{}[]|:?.~"))
                                                            $new = -join (Get-Random -Count $length -InputObject $characters)
                                                        } until(($new -match "[a-z]") -and ($new -match "[A-Z]") -and ($new -match "[0-9]") -and ($new -match "[!@$%^&*()\-=_{\[\]}|:?.~]"))
                                                        return $new
                                                    }

                                                    $currentAdmin = $env:USERNAME
                                                    $users = Get-ADUser -Filter {SamAccountName -ne $currentAdmin}
                                                    "Username,Password" | Out-File -FilePath $csvPath -Force
                                                    
                                                    foreach ($user in $users)
                                                    {
                                                        $userName = $user.SamAccountName
                                                        $newPass = New-Password
                                                        try
                                                        {
                                                            Set-ADAccountPassword -Identity $userName -NewPassword (ConvertTo-SecureString $newPass -AsPlainText -Force) -Reset
                                                            "$userName,$newPass" | Out-File -Append -FilePath "$csvPath"
                                                            Write-Host -ForegroundColor Green "Password reset for $($userName)"
                                                        } 
                                                        catch
                                                        {
                                                            Write-Host -ForegroundColor Red "Failed to reset password for $userName using $($newPass): $_"
                                                            Write-Log "Failed to reset password for $userName using $($newPass): $_"
                                                        }
                                                    }
                                                    Write-Host -ForegroundColor Cyan "Changed passwords saved to $csvPath, errors saved in $logFile"
                                                    Write-Log "Change all default passwords script ends, changed passwords saved to: $csvPath."
                                                }
                                            "2"
                                                {
                                                    Write-Warning "`nThis will begin the auditing of user permissions and groups on this AD"
                                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                                    if ($warning -inotlike "y*")
                                                    {
                                                        Break
                                                    }
                                                }
                                            "3"
                                                {
                                                    Write-Warning "`nThis will remove *ALL* groups that *ALL* users (besides this current Admin!) on the AD Domain belong to, reducing them all to `"Domain Users`""
                                                    Write-Host "A log of groups that members were previously in will be stored in the $env:HOMEDRIVE\WindowsHardeningCLI\AD directory"
                                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                                    if ($warning -inotlike "y*")
                                                    {
                                                        Break
                                                    }
                                                    Write-Log "Remove all AD users from groups script begins"

                                                    $currentAdmin = $env:USERNAME
                                                    $users = Get-ADUser -Filter {SamAccountName -ne $currentAdmin}

                                                    $curTime = Get-Date -Format "yyyyMMdd_HHmmss"
                                                    $groupLogPath = "$env:HOMEDRIVE\WindowsHardeningCLI\AD\AD_removedgroups_$curTime.txt"
                                                    Out-File -FilePath $groupLogPath -Force
                                                    "Time Start: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss K")" | Out-File -Append -FilePath $groupLogPath 
                                                    
                                                    foreach ($user in $users)
                                                    {
                                                        $userGroups = Get-ADUser $user.SamAccountName | Get-ADPrincipalGroupMembership | Where-Object { $_.SamAccountName -ne "Domain Users" }
                                                        foreach ($group in $userGroups)
                                                        {
                                                            try
                                                            {
                                                                Remove-ADGroupMember -Identity $group.SamAccountName -Members $user.SamAccountName -Confirm:$false
                                                                Write-Host -ForegroundColor Green "Removed $($user.SamAccountName) from group $($group.SamAccountName)"
                                                                "$($user.SamAccountName) was removed from group $($group.SamAccountName)" | Out-File -Append -FilePath $groupLogPath
                                                            }
                                                            catch
                                                            {
                                                                Write-Host -ForegroundColor Red "Failed to remove $($user.SamAccountName) from $(group.SamAccountName): $_"
                                                            }
                                                        }
                                                    }
                                                
                                                    Write-Host -ForegroundColor Cyan "Groups have been removed from all AD users, log saved at: $groupLogPath"
                                                    "Time End: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss K")" | Out-File -Append -FilePath $groupLogPath
                                                    Write-Log "Remove all AD users from groups script ends"
                                                }
                                            "4"
                                                {
                                                    Write-Warning "`nThis will generate users for this AD"
                                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                                    if ($warning -inotlike "y*")
                                                    {
                                                        Break
                                                    }
                                                }
                                            "5"
                                                {
                                                    Break
                                                }
                                            default
                                                {
                                                    Write-Host "`nInvalid choice"
                                                }
                                        }
                                    } while ($userManagementChoice)
                                }
                            "2"
                                {
                                    do
                                    {
                                        Write-Host -ForegroundColor Blue "`n---Group Management---"
                                        Write-Host "1. Main Menu"
                                        $gmchoice = Read-Host "`nYour selection"
                                        switch($gmchoice)
                                        {
                                            "1"
                                                {
                                                    Break
                                                }
                                            default
                                                {
                                                    Write-Host "`nInvalid choice"
                                                }
                                        }
                                    } while ($gmchoice -ne "1")
                                }
                            "3"
                                {
                                    do
                                    {
                                        Write-Host -ForegroundColor Blue "`n---OU Management---"
                                        Write-Host "1. Main Menu"
                                        $ouchoice = Read-Host "`nYour selection"
                                        switch($ouchoice)
                                        {
                                            "1"
                                                {
                                                    Break
                                                }
                                            default
                                                {
                                                    Write-Host "`nInvalid choice"
                                                }
                                        }
                                    } while ($ouchoice -ne "1")
                                }
                            "4"
                                {
                                    do
                                    {
                                        Write-Host -ForegroundColor Blue "`n---GP Management---"
                                        Write-Host "1. Main Menu"
                                        $gpchoice = Read-Host "`nYour selection"
                                        switch($gpchoice)
                                        {
                                            "1"
                                                {
                                                    Break
                                                }
                                            default
                                                {
                                                    Write-Host "`nInvalid choice"
                                                }
                                        }
                                    } while ($gpchoice -ne "1")
                                }
                            "5"
                                {
                                    do
                                    {
                                        Write-Host -ForegroundColor Blue "`n---Security, Auditing, and Health---"
                                        Write-Host "1. Main Menu"
                                        $sahchoice = Read-Host "`nYour selection"
                                        switch($sahchoice)
                                        {
                                            "1"
                                                {
                                                    Break
                                                }
                                            default
                                                {
                                                    Write-Host "`nInvalid choice"
                                                }
                                        }
                                    } while ($sahchoice -ne "1")
                                }
                            "6"
                                {
                                    Break
                                }
                            default
                                {
                                    Write-Host "`nInvalid choice"
                                }
                        }
                    } while ($adchoice -ne "4")
                }
            "4" 
                {
                    do
                    {
                        Write-Host -ForegroundColor Green "`n---Updates---"
                        Write-Host "1. Update via .csv"
                        Write-Host "2. Turn on automatic download of updates"
                        Write-Host "3. Attempt to fix Windows Updater if not finding updates"
                        Write-Host "4. Main menu"
                        $updatechoice = Read-Host "`nYour selection"
                        switch($updatechoice)
                        {
                            "1"
                                {
                                    Write-Host "`n---Manual updating through a CSV list---"
                                    Write-Warning "`nThis will attempt to update via a CSV file consisting of hyperlinks to the Microsoft Update Catalog"
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }

                                    mkdir $env:temp\updates\ -ErrorAction SilentlyContinue | Out-Null
                                    Write-Host "`nEnsure CSV list has headers 'UpdateName' and 'Hyperlinks' respectfully and consists of updates for the correct OS"
                                    $csvList = Read-Host "`nEnter the literal path for CSV list filled of hyperlinks. (I.E. $env:HOMEDRIVE\...\...)"
                                    if(![System.IO.File]::Exists($csvList))
                                    {
                                        Write-Host "`nIncorrect format or path does not exist"
                                        Break
                                    }
                                    if([System.IO.Path]::GetExtension($csvList) -ne ".csv")
                                    {
                                        Write-Host "`nIncorrect file type"
                                        Break
                                    }
                                    if((($csvFile[0].PSObject.Properties.Name)[0] -ne "UpdateName") -or (($csvFile[0].PSObject.Properties.Name)[1] -ne "Hyperlinks"))
                                    {
                                        Write-Host "`nIncorrect headers"
                                        Break
                                    }
                                    $priorityChoice = Read-Host "`nEnter (1) for every update in the list or (2) for every update after a given date"
                                    switch($priorityChoice)
                                    {
                                        "1"
                                            {
                                                $updateHyperlinks = Import-Csv -LiteralPath "$csvList"
                                            }
                                        "2"
                                            {
                                                do
                                                {
                                                    $updateYear = Read-Host "Enter a four-digit year (e.g. 2016)"
                                                } while (($updateYear.Length -ne 4) -or ($updateYear -notmatch "^[\d]+$"))
                                                do
                                                {
                                                    $updateMonth = Read-Host "Enter a two-digit month (e.g. 04)"
                                                } while (($updateMonth.Length -ne 2) -or ($updateMonth -notmatch "^[\d]+$") -or ($updateMonth -gt "12"))
                                                $updateHyperlinks = Import-Csv -LiteralPath "$csvList" | Where-Object {$_.Hyperlinks}
                                            }
                                        default
                                            {
                                                Write-Host "Invalid choice"
                                                Break
                                            }
                                    }
                                    foreach($link in $updateHyperlinks)
                                    {
                                        Write-Host "`nDownloading $($link.UpdateName)..."
                                        $webClient.DownloadFile($link.Hyperlinks,"$env:temp\updates\$($link.UpdateName).msu")
                                        Write-Host "Installing $($link.UpdateName)..."
                                        Start-Process -FilePath "$env:temp\updates\$($link.UpdateName).msu" -ArgumentList "/quiet","/norestart" -Wait
                                    }
                                    $webClient.Dispose()
                                    [System.Console]::Clear()
                                    $restart = Read-Host "`nUpdates from CSV complete. Restart now? (y/N)"
                                    if($restart -ilike "y*")
                                    {
                                        Restart-Computer
                                    }
                                    else
                                    {
                                        Write-Host "Note: restart is required for updates to take effect."
                                    }
                                }
                            "2"
                                {
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }
                                    Write-Host "Setting Windows Automatic Updates"
                                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 3 /f
                                }
                            "3"
                                {
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }
                                    Write-Host "Attempting to fix Windows Updater Service..."
                                    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 1 /f
                                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config\" /v DODownloadMode /t REG_DWORD /d 1 /f
                                    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f
                                    reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f
                                    reg add "HKLM\SYSTEM\Internet Communication Management\Internet Communication" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f
                                    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoWindowsUpdate /t REG_DWORD /d 0 /f
                                    net stop wuauserv
                                    net stop cryptSvc
                                    net stop bits
                                    net stop msiserver
                                    net start wuauserv
                                    net start cryptSvc
                                    net start bits
                                    net start msiserver
                                }
                            "4"
                                {
                                    Break
                                }
                            default
                                {
                                    Write-Host "Invalid choice."
                                }
                        }
                    } while ($updatechoice -ne "4")
                }
            "5" 
                {
                    do
                    {
                        Write-Host -ForegroundColor Magenta "`n---General Security---"
                        if($serverOS)
                        {
                            Write-Host "1. Restart Services"
                        }
                        else
                        {
                            Write-Host -ForegroundColor Red "1. Restart Services (X)"
                        }
                        Write-Host "2. Sysinternals"
                        Write-Host "3. Logon Banner"
                        Write-Host "4. Bluespawn"
                        Write-Host "5. Set Logout Timer"
                        Write-Host "6. Main Menu"
                        $gschoice = Read-Host "`nYour selection"
                        switch($gschoice)
                        {
                            "1"
                                {
                                    if(!$serverOS)
                                    {
                                        Write-Warning "`nServer operating system not detected!`n"
                                    }
                                    Write-Warning "`nThis will attempt to restart the DNS, DHCP, and NTDS services found on this computer."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }

                                    Write-Host "Attempting to restart services..."
                                    Write-Log "Attempting to restart services..."
                                    $ErrorActionPreference = "Stop"
                                    if($dnsRunning)
                                    {
                                        try
                                        {
                                            Write-Host "Restarting DNS..."
                                            Restart-Service DNS -Force
                                            Write-Host -ForegroundColor Green "Successfully restarted DNS"
                                        }
                                        catch
                                        {
                                            Write-Host "Failed to restart DNS: $_"
                                        }
                                    }
                                    else
                                    {
                                        Write-Host "DNS service not found"
                                    }
                                    if($dhcpRunning)
                                    {
                                        try
                                        {
                                            Write-Host "Restarting DHCP..."
                                            Restart-Service DhcpServer -Force
                                            Write-Host -ForegroundColor Green "Successfully restarted DHCP"
                                        }
                                        catch
                                        {
                                            Write-Host "Failed to restart DHCP: $_"
                                        }
                                    }
                                    else
                                    {
                                        Write-Host "DHCP service not found"
                                    }
                                    if($activeDirectoryRunning)
                                    {
                                        try
                                        {
                                            Write-Host "Restarting Active Directory (NTDS)..."
                                            Restart-Service NTDS -Force
                                            Write-Host -ForegroundColor Green "Successfully restarted NTDS"
                                        }
                                        catch
                                        {
                                            Write-Host "Failed to restart NTDS: $_"
                                        }
                                    }
                                    else
                                    {
                                        Write-Host "NTDS service not found"
                                    }
                                    $ErrorActionPreference = "SilentlyContinue"
                                    Write-Log "Restart services script complete"
                                }
                            "2"
                                {
                                    Write-Warning "`nThis will attempt to install the Sysinternals Suite to $env:HOMEDRIVE\Sysinternals."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }

                                    Write-Host "Sysinternals"
                                    if(Test-Path $env:HOMEDRIVE\Windows\SysInternalsSuite)
                                    {
                                        $switchdirSysinternals = Read-Host "Sysinternals installed at $env:HOMEDRIVE\Windows\Sysinternals. Switch directories now? (y/N)"
                                        if($switchdirSysinternals -like "y*")
                                        {
                                            Set-Location "$env:HOMEDRIVE\Windows\Sysinternals"
                                            Break
                                        }
                                    }
                                    elseif(Test-Path $env:HOMEDRIVE\Windows\SysInternalsSuite.zip)
                                    {
                                        $confirmSysUnzip = Read-Host "Unzip Sysinterals?"
                                        if($confirmSysUnzip -ilike "y*")
                                        {
                                            Expand-Archive -Path $env:HOMEDRIVE\Windows\SysInternalsSuite -DestinationPath $env:HOMEDRIVE\Windows\SysInternalsSuite -Force
                                        }
                                    }
                                    else
                                    {
                                        $confirmSysinternals = Read-Host "Sysinternals Suite is not detected, install now?"
                                        if($confirmSysinternals -ilike "y*")
                                        {
                                            Write-Host "Installing sysinternals..."
                                            $webClient.DownloadFile("https://download.sysinternals.com/files/SysinternalsSuite.zip","$env:HOMEDRIVE\Windows\SysInternalsSuite.zip") | Wait-Event
                                        }
                                    }
                                }
                            "3"
                                {
                                    Write-Warning "`nThis will set up a notice of the terms of use of using this resource at logon."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }
                                    Write-Host "Would you like to..."
                                    Write-Host "1. Write your own policy"
                                    Write-Host "2. Use generic terms of use"
                                    $termsChoice = Read-Host "Your selection"
                                    switch($termsChoice)
                                    {
                                        "1"
                                            {
                                                do
                                                {
                                                    $legalNoticeCaption = Read-Host "Enter the legal notice caption (header)"
                                                    $confirm = Read-Host "The header reads the following: `n$legalNoticeCaption`nWould you like to continue? (y/N)"
                                                } while ($confirm -inotlike "y*")
                                                do
                                                {
                                                    $legalNoticeText = Read-Host "Enter the legal notice text (Use ``n for newline)"
                                                    $confirm = Read-Host "The text reads the following (``n will be replaced): `n$legalNoticeText`nWould you like to continue? (y/N)"
                                                } while ($confirm -inotlike "y*")
                                                # I am so sorry
                                                $bytes = [System.Text.Encoding]::Unicode.GetBytes($legalNoticeText)
                                                $oldSequence = [byte[]](0x60, 0x00, 0x6E, 0x00)
                                                $newSequence = [byte[]](0x0D, 0x00)
                                                $modifiedBytes = New-Object System.Collections.Generic.List[byte]
                                                $index = 0
                                                while ($index -lt $bytes.Length)
                                                {
                                                    if ($bytes[$index] -eq $oldSequence[0] -and $bytes[$index+1] -eq $oldSequence[1] -and $bytes[$index+2] -eq $oldSequence[2] -and $bytes[$index+3] -eq $oldSequence[3])
                                                    {
                                                        $modifiedBytes.AddRange($newSequence)
                                                        $index += 4
                                                    }
                                                    else 
                                                    {
                                                        $modifiedBytes.Add($bytes[$index])
                                                        $index++
                                                    }
                                                }
                                                $modifiedBytesArray = $modifiedBytes.ToArray()
                                                $legalNoticeText = [System.Text.Encoding]::Unicode.GetString($modifiedBytesArray)
                                                Write-Host "Setting logon banner..."
                                                reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticecaption /t REG_SZ /d "$legalNoticeCaption"
                                                reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticetext /t REG_SZ /d "$legalNoticeText"
                                            }
                                        "2"
                                            {
                                                do
                                                {
                                                    $domainName = Read-Host "What is the name of the domain that you would like to use?"
                                                    $confirm = Read-Host "The domain name is: $domainName`nWould you like to continue? (y/N)"
                                                } while ($confirm -inotlike "y*")
                                                Write-Host "Setting logon banner..."
                                                reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticecaption /t REG_SZ /d "IMPORANT LEGAL NOTICE:"
                                                reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v legalnoticetext /t REG_SZ /d "By accessing this resource, you consent to monitoring of your activities and understand $domainName may exercise its rights under the law to access, use, and disclose any information obtained from your use of this resource."
                                            }
                                        default
                                            {
                                                Write-Host "Invalid selection"
                                                Break
                                            }
                                        }
                                }
                            "4"
                                {
                                    Write-Warning "`nThis will attempt to download Bluespawn client to current user's Downloads folder."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }
                                    if(Test-Path $env:HOMEPATH\Downloads\BLUESPAWN-client-x64.exe)
                                    {
                                        Write-Host "BLUESPAWN already downloaded at $env:HOMEPATH\Downloads\BLUESPAWN-client-x64.exe"
                                        Write-Host "Launch this tool from the CLI"
                                    }
                                    else
                                    {
                                        Write-Host "Downloading Bluespawn..."
                                        $webClient.DownloadFile("https://github.com/ION28/BLUESPAWN/releases/download/v0.5.1-alpha/BLUESPAWN-client-x64.exe","$env:HOMEPATH\Downloads\BLUESPAWN-client-x64.exe") | Wait-Event
                                    }
                                }
                            "5"
                                {
                                    Write-Warning "`nThis will set an inactivity timeout to the amount of seconds specified by you."
                                    $warning = Read-Host "Are you sure you want to continue? (y/N)"
                                    if ($warning -inotlike "y*")
                                    {
                                        Break
                                    }

                                    $secondsLogout = Read-Host "How many seconds of inactivity before session logout?"
                                    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs /t REG_DWORD /d $secondsLogout /f
                                }
                            "6"
                                {
                                        Break
                                }
                            default
                                {
                                    Write-Host "Invalid choice."
                                }
                        }
                    } while ($gschoice -ne "6")
                }
            "6"
                {
                    Write-Log "Inventory script started..." 

                    mkdir -ErrorAction SilentlyContinue $env:HOMEDRIVE\WindowsHardeningCLI\Inventory | Out-Null

                    $ipv6 = Read-Host "Are you all using IPv6? (y/N)" 
                    $ipv6 = $ipv6 -ilike "y*"

                    $curTime = Get-Date -Format "yyyyMMdd_HHmmss"
                    $inventoryFile = "$env:HOMEDRIVE\WindowsHardeningCLI\Inventory\inventory_$curTime.txt"
                    Write-Log "Inventory being stored in $inventoryFile" 

                    Write-Host "Loading inventory..."

                    Invoke-Command -ScriptBlock {
                        Write-Output "`n<!-- Inventory --!>"
                        Write-Output "`n--Operating System Information--`n"
                        $osInfo = Get-CimInstance Win32_OperatingSystem
                        Write-Output "`tOS: $($osInfo.Caption)`n"
                        Write-Output "`tOS Version: $($osInfo.Version)`n"
                        Write-Output "`tWMF Version: $($PSVersionTable.PSVersion)`n"
                    
                        $netframeworks = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name Version -EA 0 | Where-Object { $_.PSChildName -Match '^(?!S)\p{L}'} | Select-Object PSChildName, Version
                        Write-Output "`t.NET Framework Verisons:"
                    
                        foreach($netframework in $netframeworks)
                        {
                            Write-Output "`t`t$($netframework.PSChildName): $($netframework.Version)"
                        }
                    
                        Write-Output "`n--Interface Information--"
                        $interfaces = Get-NetAdapter
                    
                        foreach($interface in $interfaces)
                        {
                            Write-Output "`n`tInterface $($interface.Name)"
                            if($interface.Status -ne 'Disabled')
                            {
                                Write-Output "`t`tIP Address(es): $((Get-NetIPAddress -InterfaceAlias $interface.Name).IPAddress)"
                            } else
                            {
                                Write-Output "`t`tThis interface is in a disabled state."
                            }
                            Write-Output "`t`tEthernet Address: $($interface.MacAddress)"
                        }
                    
                        Write-Output "`n--Port Information--`n"

                        if($ipv6)
                        {
                            $tcpconnections =  Get-NetTCPConnection | Where-Object { $_.State -eq 'Listen' } | Sort-Object LocalPort, LocalAddress
                            $udpconnections = Get-NetUDPEndpoint | Where-Object { $_.LocalPort -lt '49152' } | Sort-Object LocalPort, LocalAddress
                            $udpephemeral  = Get-NetUDPEndpoint | Where-Object { $_.LocalPort -ge '49152' } | Sort-Object LocalPort, LocalAddress
                        }
                        else
                        {
                            $tcpconnections =  Get-NetTCPConnection | Where-Object { $_.LocalAddress -notlike '*:*' -and $_.State -eq 'Listen' } | Sort-Object LocalPort, LocalAddress
                            $udpconnections = Get-NetUDPEndpoint | Where-Object { $_.LocalAddress -notlike '*:*' -and $_.LocalPort -lt '49152' } | Sort-Object LocalPort, LocalAddress
                            $udpephemeral  = Get-NetUDPEndpoint | Where-Object { $_.LocalAddress -notlike '*:*' -and $_.LocalPort -ge '49152' } | Sort-Object LocalPort, LocalAddress
                        }
                    
                        foreach($tcpconnection in $tcpconnections)
                        {
                            $process = Get-Process -Id $tcpconnection.OwningProcess -ErrorAction SilentlyContinue
                            [PSCustomObject]@{
                                LocalAddress = $tcpconnection.LocalAddress
                                LocalPort = $tcpconnection.LocalPort
                                ProcessName = $process.Name
                            }
                        }

                        Write-Output "^^^^^^^^^ TCP ^^^^^^^^^"
                    
                        foreach($udpconnection in $udpconnections)
                        {
                            $process = Get-Process -Id $udpconnection.OwningProcess -ErrorAction SilentlyContinue
                            [PSCustomObject]@{
                                LocalAddress = $udpconnection.LocalAddress
                                LocalPort = $udpconnection.LocalPort
                                ProcessName = $process.Name
                            }
                        }
                    
                        Write-Output "^^^^^^^^^ UDP ^^^^^^^^^"
                    
                        $connections = $tcpconnections + $udpconnections
                        $portsopen = ($connections | Select-Object -Unique LocalPort).Count
                    
                        Write-Output "`nTotal unique open ports: $($portsopen)"
                        Write-Output "`nEphemeral  UDP ports open: $($udpephemeral.Count)`n"
                    
                        Write-Output "For a list of potential vulnerabilities, visit https://www.cvedetails.com."
                        Write-Output "If searching via vendor, all Windows operating systems are under Microsoft."
                        Write-Output "If searching via product, exclude the Windows edition (such as Standard or Home) when searching (i.e. search `"Windows Server 2012`").`n"
                    } | Out-File $inventoryFile -Encoding UTF8

                    Write-Host "Sucess, inventory saved in $inventoryFile"
                    Write-Log "Sucess, inventory saved in $inventoryFile" 
                }
            "7"
                {
                    Write-Host "`nGoodbye`n"
                    $try = $true
                    Break
                }

            default
                {
                    Write-Host "Invalid choice."
                }
        }
    } while ($userInput -ne "7")
}
catch
{
    Write-Log -NoDate "Terminating error: $($_.Exception.Message)"
    $catch = $true
}
finally
{
    if($try)
    {
        Write-Log "The script was exited via main menu!"
    }
    elseif ($catch)
    {
        Write-Log "The script was closed via terminating error, listed above."
    }
    else
    {
        Write-Log "The script was forcibly exited (potentially Control+C)"    
    }
}