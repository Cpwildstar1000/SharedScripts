###################################################################
# HP Mini Update Script disigned to update HP 600 G6 Mini devices #
# Creator Christopher Pulvermacher                                #  
# Last Edited: 05/15/2026                                         #
###################################################################


# Progress bar function
function Show-FedoraProgressBar {
    param(
        [int]$Percent,
        [string]$Activity = "Progress"
    )

    $Percent = [Math]::Max(0, [Math]::Min(100, $Percent))
    $width = 40
    $filled = [Math]::Round(($Percent / 100) * $width)
    Write-Host -NoNewline "`r$Activity ["

    for ($i = 0; $i -lt $width; $i++) {
        if ($i -lt $filled) {
            Write-Host -NoNewline "█" -ForegroundColor Cyan
        }
        else {
            Write-Host -NoNewline "░" -ForegroundColor DarkGray
        }
    }
    Write-Host -NoNewline "] "

    if ($Percent -lt 100) {
        Write-Host -NoNewline "$Percent%" -ForegroundColor White
    }
    else {
        Write-Host "Done!" -ForegroundColor Green
    }
}

function Wait-ForRemotePowerShell {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        [int]$TimeoutSeconds = 600,
        [int]$DelaySeconds = 5
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            try {
                $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
                if ($result) {
                    return $true
                }
            }
            catch {
            }
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    return $false
}

# Set up Driver Files in array for later copy
$Drivers = @(
    @{File='INTEL BLUETOOTH'; Name='Intel(R) Wireless Bluetooth(R)'}
    @{File='INTEL MGMT DRIVERS'; Name='Intel(R) Management Engine WMI Provider'}
    @{File='INTEL NIC DRIVER'; Name='Intel(R) Ethernet Connection (11) I219-LM'}
    @{File='INTEL THUNDERBOLT DRIVER'; Name=$null}
    @{File='INTEL VIDEO AND CONTROL PANEL'; Name='Intel(R) UHD Graphics 630'}
    @{File='REALTEK AUDIO DRIVER'; Name='Realtek High Definition Audio'}
    @{File='WIRELESS LAN DRIVERS'; Name='Intel(R) Wi-Fi 6 AX201 160MHz'}
)

# Get directory lists
$userid = Get-CimInstance win32_computersystem | Select-Object -ExpandProperty username
$objUser = New-Object System.Security.Principal.NTAccount("$userid")
$UserSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier]).Value 
$UserProfile = (Get-ItemProperty "Registry::\HKEY_USERS\$UserSID\Volatile Environment").UserProfile
try {$OneDrivePath = (Get-ItemProperty "Registry::\HKEY_USERS\$UserSID\Environment").OneDriveCommercial}
catch {$OneDrivePath = "None"}

if ($OneDrivePath -eq "None") {$DesktopPath = "$UserProfile\Desktop"}
else {$DesktopPath = "$OneDrivePath\Desktop"}

# Get computer name and IP address
$ComputerName = Read-Host "Enter the computer name to update"
$FullComputerName = (Resolve-DnsName $ComputerName).Name
$ComputerIP = (Resolve-DnsName $ComputerName).IPAddress
$DNSComputerName = (Resolve-DnsName $ComputerIP).NameHost

# Test to confirm computer is a HP 600 G6 Mini
$Model = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
    (Get-CimInstance win32_computersystem).model
}

if ($Model -notlike "*600 G6*") {
    "Computer model is not correct. Please check computer and try again." | Write-Host -ForegroundColor Red
    Exit
}

# Create and write to file on computer to store the update log
$LogFileLocation = "$DesktopPath"
$LogFileName = "HPUpdateLog_$ComputerName"
$Date = Get-Date -Format "MMddyy"
$LogFileFormatType = ".txt"
$LogFileFullName = "$LogFileName$Date$LogFileFormatType"
$LogFile = Join-Path $LogFileLocation $LogFileFullName

if (!(Test-Path $LogFile)) {
    New-Item -Path $LogFileLocation -Name $LogFileFullName -ItemType File | Out-Null
    "Created log file: $LogFile" | Tee-Object $LogFile -Append | Write-Host
}

# Confirm DNS Names match
"Full Computer Name: $FullComputerName" | Tee-Object $LogFile -Append | Write-Host
"DNS Computer Name: $DNSComputerName" | Tee-Object $LogFile -Append | Write-Host
#"Test Connection Host: $TestConnectionHost" | Tee-Object $LogFile -Append | Write-Host
Write-Host "Please confirm that the Full Computer Name and DNS Computer Name match. If not test connection to computer and try again." -ForegroundColor Yellow
$Confirmation = Read-Host "Do the computer names match? (Y/N)"

if ($Confirmation -eq "Y") {
    "User confirmed computer names match" | Tee-Object $LogFile -Append | Write-Host
    if (Test-Connection $FullComputerName -Count 1 -Quiet) {
        "Computer is ONLINE" | Tee-Object $LogFile -Append | Write-Host
    }
    else {
        "Computer is offline. Please check computer and try again" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Red
        exit
    }

    try {
        "Updating remote computer: $FullComputerName" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Green

        # gpupdate
        $LastUpdate = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
            [datetime]::FromFileTime(
                ([Int64] ((Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}").startTimeHi) -shl 32) -bor
                ((Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}").startTimeLo)
            )
        }
        "Last gpupdate time: $LastUpdate" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Yellow
        Invoke-Command -ComputerName $FullComputerName -ScriptBlock { gpupdate /force }
        $CurrentUpdate = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
            [datetime]::FromFileTime(
                ([Int64] ((Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}").startTimeHi) -shl 32) -bor
                ((Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}").startTimeLo)
            )
        }
        "Current gpupdate time: $CurrentUpdate" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Yellow

        # Driver folder check/create
        $TestForDriversFolderOnComputer = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
            Test-Path C:\DriverInstallFiles
        }

        if (-not $TestForDriversFolderOnComputer) {
            Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
                New-Item -Path "C:\" -Name "DriverInstallFiles" -ItemType Directory -Force | Out-Null
            }
            "Folder C:\DriverInstallFiles was created" | Tee-Object $LogFile -Append | Write-Host
        }

        if (Invoke-Command -ComputerName $FullComputerName -ScriptBlock { Test-Path C:\DriverInstallFiles }) {
            $totalDrivers = $Drivers.Count
            $currentDriver = 0
            foreach ($Driver in $Drivers) {
                $Percent = [math]::Round(($currentDriver / $totalDrivers) * 100)
                Show-FedoraProgressBar -Percent $Percent -Activity "Copying Drivers"

                $File = $Driver.File
                Copy-Item -Path "\\mad-wsitbob\C$\Shares\Shared\Drivers\HP\HP 600 G6 Mini\$File.exe" `
                        -Destination "\\$FullComputerName\C$\DriverInstallFiles\$File.exe"
                "Copied $File to $FullComputerName" | Tee-Object $LogFile -Append #| Write-Host
                $currentDriver++
                
                if (!(Test-Path "\\$FullComputerName\C$\DriverInstallFiles\$File.exe")) {
                    throw "$File failed to copy"
                }
                if ($currentDriver -eq $totalDrivers) {
                    Show-FedoraProgressBar -Percent 100 -Activity "Copying Drivers"
                }
            }
            Write-Host ""
        }

        # BIOS CHECK (fixed null safety)
        $PreUpdateBIOS = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
            Get-CimInstance Win32_BIOS
        }
        if ($PreUpdateBIOS.SMBIOSBIOSVersion) {
            $biosVersion = [version]($PreUpdateBIOS.SMBIOSBIOSVersion -replace '[^\d\.]')
            if ($biosVersion -lt [version]"2.24") {
                "Please update BIOS on device" | Tee-Object $LogFile -Append | Write-Host
            }
        }

        foreach ($Driver in $Drivers) {
            if ($null -ne $Driver.Name) {
                $driverName = $Driver.Name
                "$driverName" | Tee-Object $LogFile -Append | Write-Host
                $PreUpdateDriver = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
                    param($name)
                    Get-CimInstance Win32_PNPSignedDriver -Filter "Description='$name'"
                } -ArgumentList $driverName
                $PreUpdateDriver.DriverVersion | Tee-Object $LogFile -Append | Write-Host -ForegroundColor DarkYellow
            }
        }

        $totalDrivers = $Drivers.Count
        $currentDriver = 0
        foreach ($Driver in $Drivers) {
            $Percent = [math]::Round(($currentDriver / $totalDrivers) * 100)
            Show-FedoraProgressBar -Percent $Percent -Activity "Installing Drivers"

            $File = $Driver.File
            $result = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
                param($file)
                $job = Start-Job -ScriptBlock {
                    param($file)
                    $proc = Start-Process `
                        -FilePath "C:\DriverInstallFiles\$file.exe" `
                        -ArgumentList '/s' `
                        -PassThru `
                        -Wait
                    return @{
                        ExitCode = $proc.ExitCode
                        ProcessId = $proc.Id
                    }
                } -ArgumentList $file

                if (Wait-Job $job -Timeout 300) {
                    $jobResult = Receive-Job $job
                    Remove-Job $job -Force
                    return @{
                        Status = "Completed"
                        ExitCode = $jobResult.ExitCode
                    }
                }
                else {
                    try {
                        $childProcesses = Get-CimInstance Win32_Process |
                            Where-Object {
                                $_.CommandLine -like "*C:\DriverInstallFiles\$file.exe*"
                            }
                        foreach ($proc in $childProcesses) {
                            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
                        }
                        Stop-Job $job -Force -ErrorAction SilentlyContinue
                        Remove-Job $job -Force -ErrorAction SilentlyContinue
                    }
                    catch {}
                    return @{
                        Status = "TimedOut"
                        ExitCode = $null
                    }
                }
            } -ArgumentList $File

            if ($result.Status -eq "TimedOut") {
                #"$File installer TIMED OUT after 5 minutes" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Red
                $currentDriver++
            }
            else {
                "Installer exit code for $File : $($result.ExitCode)" #| Tee-Object $LogFile -Append | Write-Host
                $currentDriver++
            }
        }
        Write-Host ""

        # Restart computer
        try {
            "Restarting remote computer from target side: $FullComputerName" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Yellow

            try {
                Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
                    Restart-Computer -Force
                } -ErrorAction Stop
            }
            catch {
                $restartConfirmationError = $_.Exception.Message
                "Restart command was issued, but the session closed before confirmation: $restartConfirmationError" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Yellow
            }

            "Waiting for $FullComputerName to come back and accept PowerShell remoting..." | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Yellow
            if (-not (Wait-ForRemotePowerShell -ComputerName $FullComputerName -TimeoutSeconds 600 -DelaySeconds 5)) {
                throw "Remote computer did not return PowerShell remoting within 600 seconds."
            }

            "Remote PowerShell is available on $FullComputerName" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Green
        }
        catch {
            $restartVerificationError = $_.Exception.Message
            "Failed to restart or verify remote PowerShell availability for ${FullComputerName}: $restartVerificationError" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Red
            throw
        }

        foreach ($Driver in $Drivers) {
            if ($null -ne $Driver.Name) {
                $driverName = $Driver.Name
                "$driverName" | Tee-Object $LogFile -Append | Write-Host
                $PreUpdateDriver = Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
                    param($name)
                    Get-CimInstance Win32_PNPSignedDriver -Filter "Description='$name'"
                } -ArgumentList $driverName
                $PreUpdateDriver.DriverVersion | Tee-Object $LogFile -Append | Write-Host -ForegroundColor DarkYellow
            }
        }

        "Update completed successfully on $FullComputerName" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Green

        # Cleanup folder/files
        Invoke-Command -ComputerName $FullComputerName -ScriptBlock {
            Remove-Item C:\DriverInstallFiles -Recurse -Force -ErrorAction Stop
        }

        "Cleaned up driver installation folder" | Tee-Object $LogFile -Append | Write-Host
    }
    catch {
        "An error occurred while updating $FullComputerName : $_" | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Red
    }
}
else {
    "User did not confirm computer names match." | Tee-Object $LogFile -Append | Write-Host -ForegroundColor Red
    exit
}