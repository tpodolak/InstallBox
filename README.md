# Boxstarter
A script for setting up a Windows PC using [BoxStarter](http://boxstarter.org/) and [Chocolatey](https://chocolatey.org/).
# How to use
Open a evelated PowerShell console and allow to execute PowerShell scripts from remote source
````
Set-ExecutionPolicy Unrestricted
````
Go to folder of your choice and run
````
wget -Uri 'https://raw.githubusercontent.com/tpodolak/Boxstarter/master/bootstrap.ps1' -OutFile "bootstrap.ps1";&Invoke-Command -ScriptBlock { & ".\bootstrap.ps1" PATH_TO_CONFIG_FILE }
````
where ``PATH_TO_CONFIG_FILE`` is path to configuration file described by following  [schema](https://github.com/tpodolak/Boxstarter/blob/master/config.schema.json).
If ``PATH_TO_CONFIG_FILE`` is not provided, script will assume that config is stored in ``config.json`` file located in current execution directory.
# Config file

