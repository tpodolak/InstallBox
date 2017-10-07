param(
    [Parameter(Mandatory)] 
    [ValidateSet("LocalBuild", "RemoteBuild")]
    $target
)
$ErrorActionPreference = "Stop"
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path


$integrationTestsScripts = $currentDir | Get-ChildItem -Filter "*.tests.integration.ps1" `
    | Select-Object @{ Label = "Script"; Expression = { @{ Path = $_.FullName; Parameters = @{ rootDir = $currentDir; }; } }} `
    | Select-Object -ExpandProperty Script
                                
$unitTestsScripts = $currentDir | Get-ChildItem -Filter "*tests.unit.ps1" | Select-Object -ExpandProperty FullName

$failedTestsCount = @(
    (Invoke-Pester -Tag $target -Script $integrationTestsScripts -PassThru),
    (Invoke-Pester -Script $unitTestsScripts -PassThru)
) | Measure-Object -Sum -Property FailedCount | Select-Object -ExpandProperty Sum

if ($failedTestsCount -gt 0) {
    Write-Error "$failedTestsCount test(s) failed"
}