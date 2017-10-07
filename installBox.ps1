$ErrorActionPreference = "Stop"
Import-Module (Join-Path $Boxstarter.BaseDir Boxstarter.Bootstrapper\Get-PendingReboot.ps1) -global -DisableNameChecking
# # Boxstarter options
$Boxstarter.RebootOk = $true
$Boxstarter.NoPassword = $false
$Boxstarter.AutoLogin = $true


$knownPendingFileRenames = @( ("\??\" + (Join-Path $env:USERPROFILE "AppData\Local\Temp\Microsoft.PackageManagement" )))

function Invoke-Reboot-If-Required() {
    if (($Boxstarter.RebootOk -eq $true) -and (Test-Pending-Reboot -eq $true)) {
        Invoke-Reboot
    }
}

function Clear-Known-Pending-Renames($pendingRenames, $configPendingRenames) {
    $pendingRenames = $pendingRenames + $configPendingRenames
    $regKey = "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\"
    $regProperty = "PendingFileRenameOperations"
    $pendingReboot = Get-PendingReboot

    Write-BoxstarterMessage "Current pending reboot $pendingReboot" | Out-String
    
    if ($pendingReboot.PendFileRename) {

        $output = $pendingReboot.PendFileRenVal | ForEach-Object {$_ -split [Environment]::NewLine} | Where-Object { 
            $current = $_
            ![string]::IsNullOrWhiteSpace($current) -and ($pendingRenames | Where-Object { $current.StartsWith($_)  } ).Length -eq 0 } | Get-Unique

        if ($output -eq $null) {
            $output = @()
        }
        
        Set-ItemProperty -Path $regKey -Name $regProperty -Value ([string]::Join([Environment]::NewLine, $output))
        Write-BoxstarterMessage "Updated pending reboot $(Get-PendingReboot | Out-String)"
    }
}

function Install-From-Process ($packageName, $silentArgs, $filePath, $validExitCodes = @( 0)) {
    Write-Host "Installing $packageName"
    $expandedFilePath = Expand-String $filePath
    $expandedSilentArgs = Expand-String $silentArgs;

    $process = Start-Process $expandedFilePath $expandedSilentArgs -NoNewWindow -Wait -PassThru
    if ($validExitCodes -notcontains $process.ExitCode) {
        Write-Error "Process $filePath returned invalid exit code $process.ExitCode"
        Write-Error "Package $packageName was not installed correctly"
    }
    else {
        Write-Host "Package $packageName was successfully installed"
        Invoke-Reboot-If-Required
    }
}

function Install-Local-Packages ($packages, $installedPackages) {
    foreach ($package in $packages) {
        if ($installedPackages -like "*$($package.name)*") {
            Write-Warning "Package $package.name already installed"
        }
        else {
            $expandedArgs = Expand-String $package.args
            $expandedPath = Expand-String $package.path
            Install-From-Process $package.name $expandedArgs $expandedPath $package.validExitCodes
        }
    }
}

function Install-Choco-Packages ($packages, $ignorechecksums) {
    foreach ($package in $packages) {
        cinst $package --ignorechecksums:$ignorechecksums
    }
}

function Install-Windows-Features ($packages) {
    foreach ($package in $packages) {
        cinst $package -Source windowsfeatures
    }
}

function Copy-Configs ($packages) {
    foreach ($package in $packages) {
        $source = Expand-String $package.source
        $destination = Expand-String $package.destination

        Write-Host "Copying configs for $package.name"
        
        Restore-Folder-Structure $destination
        if ($package.deleteIfExists -and (Test-Path $destination)) {
            cmd /c rmdir /s /q $destination
        }

        if ($package.symlink) {
            New-Directory-Symlink $source $destination
        }
        else {
            Copy-Item $source $destination -Recurse -Force
        }

        Write-Host "Config copied"
    }
}

function New-TaskBar-Items ($packages) {
    foreach ($package in $packages) {
        $path = Expand-String $package.path
        Write-Host "Pinning $package.name"
        Install-ChocolateyPinnedTaskBarItem $path
        Write-Host "Item pinned"
    }
}

function Invoke-Custom-Scripts ($scripts) {
    foreach ($script in $scripts) {
        Write-Host "Abount to run custom script $script.name"
        Invoke-Expression $script.value
        Write-Host "Finished running $script.name script"        
    }
}

function Restore-Folder-Structure ($path) {
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path
    }
}

function Disable-Power-Saving() {
    powercfg -change -standby-timeout-ac 0
    powercfg -change -standby-timeout-dc 0
    powercfg -hibernate off
}

function New-Directory-Symlink ($source, $destination) {
    cmd /c mklink /D $destination $source
}

function Expand-String($source) {
    return $ExecutionContext.InvokeCommand.ExpandString($source)
}

#[environment]::SetEnvironmentVariable("BoxstarterConfig","E:\\OneDrive\\Configs\\Boxstarter\\config.json", "Machine")

$installedPrograms = Get-Package -ProviderName Programs | Select-Object -Property Name
$config = Get-Content ([environment]::GetEnvironmentVariable("BoxstarterConfig", "Machine")) -Raw  | ConvertFrom-Json
if ($config -eq $null) {
    throw "Unable to load config file"
}

$ErrorActionPreference = "Continue"

Write-BoxstarterMessage "Config file loaded $config)" | Out-String

Write-BoxstarterMessage "Abount to clean known pending renames"
Clear-Known-Pending-Renames $knownPendingFileRenames $config.pendingFileRenames
Write-BoxstarterMessage "Known pending renames cleared"

Write-BoxstarterMessage "Abount to disable power saving mode"
Disable-Power-Saving
Write-BoxstarterMessage "Power saving mode disabled"

Write-BoxstarterMessage "About to install choco packages"
Install-Choco-Packages $config.chocolateyPackages $config.ignoreChecksums
Write-BoxstarterMessage "Choco packages installed"

refreshenv

Write-BoxstarterMessage "About to install windows features"
Install-Windows-Features $config.windowsFeatures
Write-BoxstarterMessage "Windows features installed"

Write-BoxstarterMessage "About to install local packages"
Install-Local-Packages $config.localPackages $installedPrograms
Write-BoxstarterMessage "Local packages installed"

Write-BoxstarterMessage "About to run custom scripts"
Invoke-Custom-Scripts $config.customScripts
Write-BoxstarterMessage "Custom scripts run";

Write-BoxstarterMessage "About to copy configs"
Copy-Configs $config.configs
Write-BoxstarterMessage "Configs copied"

Write-BoxstarterMessage "About to pin taskbar items"
New-TaskBar-Items $config.taskBarItems
Write-BoxstarterMessage "Taskbar items pinned"

if ($config.installWindowsUpdates) {
    Write-BoxstarterMessage "About to install windows updates"
    Install-WindowsUpdate -Full -SuppressReboots
    Write-BoxstarterMessage "Windows updates installed"
}

