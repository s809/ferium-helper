# ferium-helper
A script for automatic updating of all installed mods & profile migration, using [Ferium](https://github.com/gorilla-devs/ferium).

## Why?
https://github.com/PrismLauncher/PrismLauncher/issues/1057

## Why it's so complicated to use?
It was made to solve my own specific issues, like migrating to a new instance alongside with auto-updates. Don't expect to fit your use-case perfectly.

If you have something to improve, feel free to create pull requests.

## How to use it?
1. Clone or download ZIP of this repository into Prism Launcher's root directory, the folder should be alongside `instances`. \
   e.g. For Windows, the resulting path should something like `C:\Users\Username\AppData\Roaming\PrismLauncher\ferium-helper`.
2. Install the latest Ferium release:
   - On Linux: Run `./ferium-helper.sh update-only` in cloned repo's directory.
   - On Windows:
     1. Allow the scripts to run: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force`.
     2. Run `.\ferium-helper.ps1 update-only` in cloned repo's directory.
3. Make sure you have a Ferium profile created with mods added into it. If you haven't created the profile, create it to use below using the downloaded `./ferium` or `.\ferium.exe`.
4. Select an instance to add auto-updating for.
5. Go to Edit -> Settings -> Custom commands, and add pre-launch command:
   - Linux: `sh -c "../../../ferium-helper/ferium-helper.sh '<target-profile>'"`
   - Windows: `powershell -Command ..\..\..\ferium-helper\ferium-helper.ps1 '<target-profile>'`

## Profile migration
This script can migrate mod list and their settings, game settings and server list.

The script accepts up to 2 additional arguments:
- `<source-profile>` is a name of the profile you want to copy from.
- `<target-version>` is the target profile's version. If `<target-profile>` is omitted, it will be used as the profile's name as well.
