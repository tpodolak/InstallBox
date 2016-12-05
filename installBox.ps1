$ErrorActionPreference = "Stop"
# Boxstarter options
$Boxstarter.RebootOk=$true
$Boxstarter.NoPassword=$false
$Boxstarter.AutoLogin=$true

$regexPath = (Join-Path $env:USERPROFILE "AppData\Local\Temp\Microsoft.PackageManagement") -replace "\\","\\"

$pendingFileRenames = @( "\\\?\?\\$($regexPath)" + "*.+" )

function Clear-Known-Pending-Renames($pendingRenames){
    $regKey = "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager\"
    $regProperty = "PendingFileRenameOperations"
    $currentValue = Get-ItemProperty -Path $regKey | Select -ExpandProperty $regProperty

    foreach($value in $pendingFileRenames){
        $currentValue = $currentValue -replace $value, ""
    }
    Set-ItemProperty -Path $regKey -Name $regProperty -Value $currentValue
}

function Install-From-Process ($packageName, $silentArgs, $filePath, $validExitCodes = @( 0)){
    Write-Host "Installing $($packageName)"
    $expandedFilePath = Expand-String $filePath
    $expandedSilentArgs = Expand-String $silentArgs;

    $process = Start-Process $expandedFilePath $expandedSilentArgs -NoNewWindow -Wait -PassThru
    if($validExitCodes -notcontains $process.ExitCode){
        Write-Error "Process $($filePath) returned invalid exit code $($process.ExitCode)"
        Write-Error "Package $($packageName) was not installed correctly"   
    }else{
        Write-Host "Package $($packageName) was successfully installed"
    }
}

function Install-Local-Packages ($packages, $installedPackages){
    foreach ($package in $packages) {
        if($installedPackages -like "*$($package.name)*"){
            Write-Warning "Package $($package.name) already installed"
        }else{
            $expandedArgs = Expand-String $package.args
            $expandedPath = Expand-String $package.path
            Install-From-Process $package.name $expandedArgs $expandedPath $package.validExitCodes
        }
    }
}

function Install-Choco-Packages ($packages){
    foreach ($package in $packages) {
        cinst $package
    }
}

function Install-Windows-Features ($packages){
    foreach ($package in $packages) {
        cinst $package -Source windowsfeatures
    }
}

function Copy-Configs ($packages){
    foreach ($package in $packages) {
        $source = Expand-String $package.source
        $destination = Expand-String $package.destination

        Write-Host "Copying configs for $($package.name)"
        
        Restore-Folder-Structure $destination
        if($package.deleteIfExists -and (Test-Path $destination)) {
            cmd /c rmdir /s /q $destination
        }

        if($package.symlink){
            New-Directory-Symlink $source $destination
        }else{
            Copy-Item $source $destination -Recurse -Force
        }

        Write-Host "Config copied"
    }
}

function New-TaskBar-Items ($packages){
    foreach ($package in $packages) {
        $path = Expand-String $package.path
        Write-Host "Pinning $($package.name)"
        Install-ChocolateyPinnedTaskBarItem $path
        Write-Host "Item pinned"
    }
}

function Invoke-Custom-Scripts ($scripts) {
    foreach ($script in $scripts) {
        Write-Host "Abount to run custom script $($script.name)"
        Invoke-Expression $script.value
        Write-Host "Finished running $($script.name) script"        
    }
}

function Restore-Folder-Structure ($path){
    if(!(Test-Path $path)){
        New-Item -ItemType Directory -Path $path
    }
}

function New-Directory-Symlink ($source,$destination){
    cmd /c mklink /D $destination $source
}

function Expand-String($source){
    return $ExecutionContext.InvokeCommand.ExpandString($source)
}

#just for test
#[environment]::SetEnvironmentVariable("BoxstarterConfig","E:\\OneDrive\\Configs\\Boxstarter\\config.json", "Machine")

$installedPrograms = Get-Package -ProviderName Programs | select -Property Name
$config = Get-Content ([environment]::GetEnvironmentVariable("BoxstarterConfig","Machine")) -Raw  | ConvertFrom-Json
if($config -eq $null){
    throw "Unable to load config file"
}

$ErrorActionPreference = "Continue"

Write-Host "Config file loaded $($config)"

Write-Host "Abount to clean known pending renames"
Clear-Known-Pending-Renames $pendingFileRenames
Write-Host "Pending renames cleared"

Write-Host "About to install choco packages"
Install-Choco-Packages $config.chocolateyPackages
Write-Host "Choco packages installed"

refreshenv

Write-Host "About to install windows features"
Install-Windows-Features $config.windowsFeatures
Write-Host "Windows features installed"

Write-Host "About to install local packages"
Install-Local-Packages $config.localPackages $installedPrograms
Write-Host "Local packages installed"

Write-Host "About to run custom scripts"
Invoke-Custom-Scripts $config.customScripts
Write-Host "Custom scripts run";

Write-Host "About to copy configs"
Copy-Configs $config.configs
Write-Host "Configs copied"

Write-Host "About to pin taskbar items"
New-TaskBar-Items $config.taskBarItems
Write-Host "Taskbar items pinned"

Write-Host "About to install windows updates"
Install-WindowsUpdate -Full -SuppressReboots
Write-Host "Windows updates installed"

