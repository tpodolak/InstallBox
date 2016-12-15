# InstallBox
A script for setting up a Windows PC using [BoxStarter](http://boxstarter.org/) and [Chocolatey](https://chocolatey.org/).
# How to use
Open a elevated PowerShell console and allow to execute PowerShell scripts from remote source
````
Set-ExecutionPolicy Unrestricted
````
Go to folder of your choice and run
````
wget -Uri 'https://raw.githubusercontent.com/tpodolak/Boxstarter/master/bootstrap.ps1' -OutFile "bootstrap.ps1";&Invoke-Command -ScriptBlock { & ".\bootstrap.ps1" PATH_TO_CONFIG_FILE }
````
where ``PATH_TO_CONFIG_FILE`` is path to configuration file described by following  [schema](https://github.com/tpodolak/Boxstarter/blob/master/config.schema.json).
If ``PATH_TO_CONFIG_FILE`` is not provided, the script will assume that config is stored in ``config.json`` file located in current execution directory.
# Config
Config file allows you to specify Chocolatey packages and local applications you want to install. Moreover it allows you to enable windows features,
copy config files and pin taskbar items. In case you need something more specific and you still don't want to create your own Boxstarter package, config file
allows you to specify custom scripts to run during script execution.
## Config properties

- ``ignoreChecksums (bool)`` - Allow to ignore checksums for packages provided by the Chocolatey.
- ``installWindowsUpdates (bool)`` - Allow to install Windows Updates
- ``pendingFileRenames (array[string])`` - a collection of pending file renames to ignore while checking if reboot is needed.
  - ``(string)`` - pending rename (expandable)
- ``chocolateyPackages (array[string])`` - a collection of Chocolatey packages to [install](https://github.com/chocolatey/choco/wiki/CommandsInstall#examples)
  - ``(string)`` - valid chocolatey package name
- ``windowsFeatures (array[string])`` - a collection of windows features to [install](https://github.com/chocolatey/choco/wiki/CommandsList#windows-features)
  - ``(string)`` - valid (from Chocolatey point of view) Windows feature
- ``localPackages (array(object))`` - a collection of local installation packages
  - ``(object)``
    - ``name (string)`` - name of the application
    - ``path (string)`` - path to installation file (expandable)
    - ``extension (string)`` - extension of setup files
    - ``args (string)`` - arguments to pass to installation file
    - ``validExitCodes (array[int])`` - valid exit codes of installation
      * ``(int)`` - exit code
- ``customScripts (array(object))`` - a collection of custom scripts to execute
  - ``(object)``
    - ``name (string)`` - name of the script
    - ``value (string)``- any valid PowerShell script
- ``configs (array(object))`` - a collection of config files to copy
  - ``(object)``
    - ``name (string)`` - config name
    - ``source (string)`` - source path (expandable)
    - ``destination (string)`` - destination path (expandable)
    - ``symlink (string)`` - create symlink
    - ``deleteIfExists (string)`` - replace destination with source
- ``taskBarItems (array(object))`` - a collection of taskbar items to be pinned
  - ``(object)``
    - ``name (string)`` - name of item
    - ``path (string)`` - path to file to be pinned (expandable)

## Config example
````
{
    "ignoreChecksums": true,

    "installWindowsUpdates": true,

    "pendingFileRenames": [],

    "chocolateyPackages": [
        "visualstudiocode",
        "console2"
    ],

    "windowsFeatures": ["NetFx3"],

    "localPackages": [{
        "name": "Visual Studio 2015",
        "extension": "exe",
        "path": "E:\\installs\\MSDN\\en_visual_studio_professional_2015_x86_x64_dvd_6846629\\vs_professional.exe",
        "args": "/passive",
        "validExitCodes": [0, 3010]
    }],

    "customScripts": [{
        "name": "Visual Studio Code - sync plugin install",
        "value": "code --install-extension Shan.code-settings-sync"
    }],

    "configs": [{
        "name": "Visual Studio Code - sync settings",
        "source": "E:\\OneDrive\\Configs\\VisualStudioCode\\-",
        "destination": "$env:USERPROFILE\\AppData\\Roaming\\Code\\User",
        "symlink": false,
        "deleteIfExists": false
    }],

    "taskBarItems": [{
        "name": "Console2",
        "path": "C:\\ProgramData\\chocolatey\\bin\\Console.exe"
    }]
}
````
# Execution order
* Install Chocolatey packages
* Install windows features
* Install local packages
* Run custom scripts
* Copy config files
* Pin taskbar items
* Install windows updates

# Known issues
* Pinning task bar items doesn't work on Windows 10 
