param(
    [Parameter(Mandatory)][string]$rootDir
)
$testConfig = "config.test.json";

Describe "Bootstrap local installation script" -Tag "LocalBuild" {
    It "Can run InstallBox with empty config" {
        .\bootstrap.ps1 -Config $testConfig -InstallScript (Join-Path -Path $rootDir -ChildPath  "installBox.ps1") -disableReboots $true
    }
}

Describe "Bootstrap remote installation script" -Tag "RemoteBuild" {
    It "Can run InstallBox with empty config" {
        .\bootstrap.ps1 -Config $testConfig -disableReboots $true
    }
}