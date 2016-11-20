
<#

.SYNOPSIS
This is a Powershell script to restore windows environment based on config.json file using Boxstarter

.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet libraries
and install applications listed in config.json file

#>

[CmdletBinding()]
Param([string]$Config = "config.json")

$ErrorActionPreference = "Stop"
$configSchema = "config.schema.json"

Write-Host "Preparing to run build script..."

$PSScriptRoot = split-path -parent $MyInvocation.MyCommand.Definition;
$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$NUGET_URL = "http://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$PACKAGES_CONFIG = Join-Path $TOOLS_DIR "packages.config"
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

# Try download NuGet.exe if not exists
if (!(Test-Path $NUGET_EXE)) {
    Write-Host "Downloading NuGet.exe..."
    try {
        (New-Object System.Net.WebClient).DownloadFile($NUGET_URL, $NUGET_EXE)
    } catch {
        Throw "Could not download NuGet.exe."
    }
}

# Restore tools from NuGet

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
    throw "Invalid config.json:" + [System.Environment]::NewLine + [String]::Join([System.Environment]::NewLine, $errorMessages);
}else{
    Write-Host "Valid configuration loaded"
}

$key = "BoxstarterConfig"
[Environment]::SetEnvironmentVariable($key, $Config, "Machine") 

exit $LASTEXITCODE
