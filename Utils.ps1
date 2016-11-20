
function Read-Config($path = "$PSScriptRoot\config.json")
{
  return Get-Content $path -Raw -ErrorAction:Stop | ConvertFrom-Json -ErrorAction:Stop
}

function Create-Directory-Symlink($source, $destination)
{
    cmd /c mklink /D $destination $source
}

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

function Get-Installed-Programs()
{
     
    # Branch of the Registry  
    $Branch='LocalMachine'  
 
    # Main Sub Branch you need to open  
    $SubBranch="SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"  
 
    $registry=[microsoft.win32.registrykey]::OpenRemoteBaseKey('Localmachine',$computername)  
    $registrykey=$registry.OpenSubKey($Subbranch)  
    $SubKeys=$registrykey.GetSubKeyNames()  

    $array = @()
 
    foreach ($key in $subkeys)  
    {  
        $exactkey=$key  
        $NewSubKey=$SubBranch+"\\"+$exactkey  
        $ReadUninstall=$registry.OpenSubKey($NewSubKey)  
        $Value=$ReadUninstall.GetValue("DisplayName")  
        $array += $Value 
    }

    return $array
}

function Restore-Folder-Structure($path)
{
    #restores all the directories included in path
       if(!(Test-Path $path)){
        New-Item -ItemType Directory -Path $path
   }
}