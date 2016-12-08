
<#

.SYNOPSIS
This is a Powershell script to restore windows environment based on config.json file using Boxstarter

.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet libraries
and install applications listed in config.json file

#>

[CmdletBinding()]
Param(
    [string]$Config = "config.json",
    [string]$InstallScript = "https://raw.githubusercontent.com/tpodolak/Boxstarter/master/installBox.ps1"
    )

function Get-File ($url, $location) {
    if (!(Test-Path $location)) {
        Write-Host "Downloading {$location}"
        try {
            (New-Object System.Net.WebClient).DownloadFile($url, $location)
        } catch {
            Throw "Could not download {$location}"
        }
    }else{
        Write-Host "File $($location) already exists"
    }
}

$webLaucher = "http://boxstarter.org/package/url?$InstallScript"

$ErrorActionPreference = "Stop"
$Config = [IO.Path]::GetFullPath($Config)
$configSchema = "config.schema.json"
$pathValidationConfig = @{ "localPackages" = @("path"); "configs" = @("source"); }

Write-Host "Preparing to run build script with configuration $Config"

$PSScriptRoot = split-path -parent $MyInvocation.MyCommand.Definition;
$RAW_FILES_URL = "https://raw.githubusercontent.com/tpodolak/Boxstarter/master/"
$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$NUGET_URL = "http://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$PACKAGES_CONFIG = Join-Path $TOOLS_DIR "packages.config"
$CONFIG_SCHEMA_FILE_LOCATION = Join-Path $PSScriptRoot $configSchema
$NEWTONSOFT_JSON_SCHEMA = Join-Path $PSScriptRoot "tools\Newtonsoft.Json.Schema\lib\net40\Newtonsoft.Json.Schema.dll"
$NEWTONSOFT_JSON = Join-Path $PSScriptRoot "tools\Newtonsoft.Json\lib\net40\Newtonsoft.Json.dll"
Write-Host $NEWTONSOFT_JSON_SCHEMA
Write-Host $NEWTONSOFT_JSON

# Make sure tools folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $TOOLS_DIR)) {
    Write-Host  "Creating tools directory..."
    New-Item -Path $TOOLS_DIR -Type directory | out-null
}

# Try find NuGet.exe in path if not exists
if (!(Test-Path $NUGET_EXE)) {
    Write-Host "Trying to find nuget.exe in PATH..."
    $existingPaths = $Env:Path -Split ';' | Where-Object { (![string]::IsNullOrEmpty($_)) -and (Test-Path $_) }
    $NUGET_EXE_IN_PATH = Get-ChildItem -Path $existingPaths -Filter "nuget.exe" | Select -First 1
    if ($NUGET_EXE_IN_PATH -ne $null -and (Test-Path $NUGET_EXE_IN_PATH.FullName)) {
        Write-Host "Found in PATH at $($NUGET_EXE_IN_PATH.FullName)."
        $NUGET_EXE = $NUGET_EXE_IN_PATH.FullName
    }
}

Get-File $NUGET_URL $NUGET_EXE

Get-File ("$($RAW_FILES_URL)config.schema.json") $CONFIG_SCHEMA_FILE_LOCATION

# Restore tools from NuGet
Write-Host "Creating packages.config"
$content = @"
<?xml version="1.0" encoding="utf-8"?>
<packages>
  <package id="Newtonsoft.Json" version="9.0.1" targetFramework="net40" />
  <package id="Newtonsoft.Json.Schema" version="2.0.7" targetFramework="net40" />
</packages>
"@
New-Item "$($PSScriptRoot)\packages.config" -ItemType File -Force -Value $content.ToString()
Write-Host "packages.config created"

Write-Host "Restoring tools from NuGet..."
$NuGetOutput = Invoke-Expression "&`"$NUGET_EXE`" install -ExcludeVersion -OutputDirectory `"$TOOLS_DIR`""
if ($LASTEXITCODE -ne 0) {
    Throw "An error occured while restoring NuGet tools."
}
Write-Host ($NuGetOutput | out-string)

Write-Host "About to load file `{$NEWTONSOFT_JSON}`, `{$NEWTONSOFT_JSON_SCHEMA}` assemblies"

Add-Type -Path $NEWTONSOFT_JSON
Add-Type -Path $NEWTONSOFT_JSON_SCHEMA

Write-Host "Assemblies successfully loaded"

[System.Collections.Generic.List[String]] $errorMessages = New-Object System.Collections.Generic.List[String];
[Newtonsoft.Json.Linq.JToken] $jsonConfig = [Newtonsoft.Json.Linq.JObject]::Parse((Get-Content $Config))
[Newtonsoft.Json.Schema.JSchema] $jsonSchema = [Newtonsoft.Json.Schema.JSchema]::Parse((Get-Content $configSchema -Raw))

if(![Newtonsoft.Json.Schema.SchemaExtensions]::IsValid($jsonConfig, $jsonSchema, [ref] $errorMessages)){
    throw "Config.json does not match the schema:" + [System.Environment]::NewLine + [String]::Join([System.Environment]::NewLine, $errorMessages);
}else{

    $invalidPaths = New-Object System.Collections.Generic.List[string]
    foreach ($item in $pathValidationConfig.GetEnumerator()){
        foreach ($token in $jsonConfig[$item.Key]) {
            foreach ($prop in $item.Value) {
                $expandedPath = $ExecutionContext.InvokeCommand.ExpandString($token[$prop].ToString())
                if(!(Test-Path $expandedPath)){
                    $invalidPaths.Add($expandedPath);
                }
            }
        }
    }

    if($invalidPaths.Count -gt 0){
        throw "Invalid paths detected: " + [System.Environment]::NewLine + [String]::Join([System.Environment]::NewLine, $invalidPaths)
    }

    Write-Host "Valid configuration loaded"
}

Write-Host "About to store config path"
[Environment]::SetEnvironmentVariable("BoxstarterConfig", $Config, "Machine") 
Write-Host "Config path stored"

Write-Host "Abount to launched ClickOnce installer with $($webLaucher)"
#Start-Process "rundll32.exe"  "dfshim.dll,ShOpenVerbApplication $webLaucher" -NoNewWindow -PassThru
$ie = New-Object -ComObject InternetExplorer.Application
$ie.Navigate($webLaucher)
Write-Host "ClickOnce installer launched"


exit $LASTEXITCODE


