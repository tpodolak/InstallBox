$ErrorActionPreference = "Stop"
$installedPrograms = Get-Package -ProviderName Programs | select -Property Name
# Boxstarter options
# $Boxstarter.RebootOk=$true # Allow reboots?
# $Boxstarter.NoPassword=$false # Is this a machine with no login password?
# $Boxstarter.AutoLogin=$true # Save my password securely and auto-login after a reboot

function Install-From-Process($packageName, $silentArgs, $filePath, $validExitCodes = @(0))
{
    Write-Host "Installing $($packageName)"
    $process = Start-Process $filePath $silentArgs -NoNewWindow -Wait -PassThru
    if($validExitCodes -notcontains $process.ExitCode){
        Write-Error "Process $($filePath) returned invalid exit code $($process.ExitCode)"
        Write-Error "Package $($packageName) was not installed correctly"
    }else{
        Write-Host "Package $($packageName) was successfully installed"
    }
}

function Install-Custom-Packages($packages, $installedPackages)
{
    foreach($package in $packages)
    {
        if($installedPackages -like "*$($package.name)*")
        {
            Write-Host "Package $($package.name) already installed"
        }else
        {
           Install-From-Process $package.name $ExecutionContext.InvokeCommand.ExpandString($package.args) $package.path $package.validExitCodes
        }

    }
}

function Install-Local-Packages($packages, $installedPackages)
{
    foreach($package in $packages)
    {
     if($installedPackages -like "*$($package.name)*")
        {
            Write-Host "Package $($package.name) already installed"
        }else
        {
            Install-ChocolateyInstallPackage $package.name $package.extension $ExecutionContext.InvokeCommand.ExpandString($package.args) $package.path $package.validExitCodes
        }
    }
}

function Install-Choco-Packages($packages)
{
    foreach($package in $packages)
    {
        cinst $package
    }
}

function Install-Windows-Features($packages)
{
    foreach($package in $packages)
    {
        cinst $package -source windowsfeatures
    }
}

function Copy-Configs($packages)
{
    foreach($package in $packages){

    $source = $ExecutionContext.InvokeCommand.ExpandString($package.source)
    $destination = $ExecutionContext.InvokeCommand.ExpandString($package.destination)
        Write-Host "Copying configs for $($package.name)"

        Restore-Folder-Structure $destination
        if($package.deleteIfExists -and (Test-Path $destination)){
            cmd /c rmdir /s /q $destination
         }

        if($package.symlink)
        {
            Create-Directory-Symlink $source $destination
        }else
        {
            Copy-Item $source $destination -recurse
        }
   
        Write-Host "Config copied"
   }
}

function Pin-TaskBar-Items($packages)
{
 foreach($package in $packages){

        $path = $ExecutionContext.InvokeCommand.ExpandString($package.path);

        Write-Host "Pinning $($package.name)"         

        Install-ChocolateyPinnedTaskBarItem $path
   
        Write-Host "Item pinned"
   }
}

function Restore-Folder-Structure($path)
{
    #restores all the directories included in path
       if(!(Test-Path $path)){
        New-Item -ItemType Directory -Path $path
   }
}

function New-Directory-Symlink($source, $destination)
{
    cmd /c mklink /D $destination $source
}

[Environment]::SetEnvironmentVariable("BoxstarterConfig", "E:\\Tomek\\Programowanie\\Github\\Boxstarter\\config.json" , "Machine")

$config =  Get-Content ([Environment]::GetEnvironmentVariable("BoxstarterConfig", "Machine")) -Raw | ConvertFrom-Json 

Write-Host "Config file loaded $($config)"

Write-Host "About to install local packages"
Install-Local-Packages $config.localPackages $installedPrograms
Write-Host "Local packages installed"

Write-Host "About to install custom packages"
Install-Custom-Packages $config.customInstallPackages $installedPrograms
Write-Host "Custom packages installed"

Write-Host "About to install choco packages"
Install-Choco-Packages $config.chocolateyPackages
Write-Host "Choco packages installed"

Write-Host "About to install windows features"
Install-Windows-Features $config.features
Write-Host "Windows features installed"

Write-Host "About to copy configs"
Copy-Configs $config.configs
Write-Host "Configs copied"

Write-Host "About to pin taskbar items"
Pin-TaskBar-Items $config.taskBarItems
Write-Host "Taskbar items pinned"

Write-Host "About to install windows updates"
Install-WindowsUpdate -Full -SuppressReboots
Write-Host "Windows updates installed"
