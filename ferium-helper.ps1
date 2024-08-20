#region Help
function Show-Help {
    Write-Host "Usage:"
    Write-Host "    $PSCommandPath <source-profile> <target-version> <target-profile>"
    Write-Host "    $PSCommandPath <source-profile> <target-version>"
    Write-Host "    $PSCommandPath <target-profile>"
    Write-Host "    $PSCommandPath update-only"
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "    <source-profile>   : Name of the source profile (optional, only if target profile does not exist)"
    Write-Host "    <target-version>   : Version of the game to target"
    Write-Host "    <target-profile>   : Name of the target profile"
    Write-Host ""
    Write-Host "Description:"
    Write-Host "    Copies the source profile to the target profile with the specified version, if it does not exist."
    Write-Host "    If only two arguments are provided, it uses the first argument as the target version and the second as the target profile."
    Write-Host "    If only one argument is provided, it performs an upgrade on the specified profile without copying from another profile."
}
#endregion


#region Utils
# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split '\n' | % {
        if ($_ -match '[\}\]]') {
            # This line contains  ] or }, decrement the indentation level
            $indent--
        }
        $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
        if ($_ -match '[\{\[]') {
            # This line contains [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}

function Create-Shortcut {
    param (
        [string]$Path, # The file/folder you want to create a shortcut for
        [string]$Target   # The location where the shortcut will be created
    )

    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($Path)
    $Shortcut.TargetPath = $Target
    $Shortcut.Save()
}
#endregion


#region Initialization
if ($args.Count -eq 3) {
    $SOURCE_PROFILE_NAME = $args[0]
    $TARGET_VERSION = $args[1]
    $TARGET_PROFILE_NAME = $args[2]
}
elseif ($args.Count -eq 2) {
    $TARGET_VERSION = $args[0]
    $TARGET_PROFILE_NAME = $args[1]
}
elseif ($args.Count -eq 1) {
    $TARGET_VERSION = $args[0]
    $TARGET_PROFILE_NAME = $TARGET_VERSION
}
else {
    Show-Help
    exit 1
}

# Determine the run directory and mods directory
$GAME_ROOT = Get-Location
Write-Host "Game directory: $GAME_ROOT"

# Move to the script's directory
Set-Location -Path (Get-Item -Path $PSCommandPath).DirectoryName
Write-Host "Ferium directory: $(Get-Location)"
#endregion


#region Check for ferium updates
# Get the latest version from GitHub
$latestReleaseUrl = "https://api.github.com/repos/gorilla-devs/ferium/releases/latest"
$latestRelease = Invoke-RestMethod -Uri $latestReleaseUrl -UseBasicParsing
$latestVersion = $latestRelease.tag_name -replace "v", ""

# Check if the current version matches the latest version
$updateRequired = $true
if (Test-Path .\ferium.exe) {
    $currentVersion = (.\ferium.exe --version) -replace "ferium ", ""
    Write-Host "Current Ferium version: $currentVersion"
    Write-Host "Latest Ferium version: $latestVersion"

    if ($currentVersion -eq $latestVersion) {
        $updateRequired = $false
    }
}

# Download and extract the latest release if needed
if ($updateRequired) {
    $zipFileName = "ferium-windows-msvc.zip"

    Write-Host "Downloading latest Ferium release..."
    $assetUrl = $latestRelease.assets | Where-Object { $_.name -eq $zipFileName } | Select-Object -ExpandProperty browser_download_url
    Invoke-WebRequest -Uri $assetUrl -OutFile $zipFileName
    Expand-Archive -Path $zipFileName -DestinationPath . -Force
    Remove-Item -Path $zipFileName
    Write-Host "Done."
}

if ($TARGET_PROFILE_NAME -eq "update-only") {
    exit 0
}
#endregion


#region Configuration file
$CONFIG_FILE = "$HOME\.config\ferium\config.json"
if (-not (Test-Path -Path $CONFIG_FILE)) {
    Write-Host "File not found: $CONFIG_FILE"
    exit 1
}
#endregion


#region Copy profile data
# Read profiles from the config file
$CONFIG = Get-Content -Path $CONFIG_FILE | ConvertFrom-Json
$PROFILES = $CONFIG.profiles

# Copy source profile if target profile doesn't exist yet
$TARGET_PROFILE = $PROFILES | Where-Object { $_.name -eq $TARGET_PROFILE_NAME }
if (-not $TARGET_PROFILE -and $SOURCE_PROFILE_NAME) {
    $SOURCE_PROFILE = $PROFILES | Where-Object { $_.name -eq $SOURCE_PROFILE_NAME }

    if ($SOURCE_PROFILE) {
        $SOURCE_ROOT = $SOURCE_PROFILE.output_dir -replace '\\mods$', ''

        # Copy game settings and configs
        Copy-Item -Path "$SOURCE_ROOT\options.txt", "$SOURCE_ROOT\servers.dat", "$SOURCE_ROOT\config" -Destination $GAME_ROOT -Recurse

        # Create user mods folder
        New-Item -ItemType Directory -Path "$GAME_ROOT\mods\user" -Force

        # Create new profile based on source profile
        $NEW_PROFILE = $SOURCE_PROFILE | ConvertTo-Json -Compress -Depth 100 | ConvertFrom-Json
        $NEW_PROFILE.game_version = $TARGET_VERSION
        $NEW_PROFILE.name = $TARGET_PROFILE_NAME

        # Add new profile to profiles and sort
        $PROFILES += $NEW_PROFILE
        $PROFILES = $PROFILES | Sort-Object -Property name

        # Update the profiles in the original JSON structure
        $CONFIG.profiles = $PROFILES

        # Write the updated JSON back to the file
        $CONFIG | ConvertTo-Json -Depth 100 | Format-Json | Set-Content -Path $CONFIG_FILE

        Write-Host "Profile copied from $SOURCE_PROFILE_NAME to $TARGET_PROFILE_NAME with version $TARGET_VERSION."
    }
    else {
        Write-Host "Profile with name $SOURCE_PROFILE_NAME not found. Skipping copy."
    }
}
#endregion


#region Shortcuts
# Create config shortcut file
Remove-Item -Path ./config.json.lnk -Force -ErrorAction Ignore
Create-Shortcut -Path ./config.json.lnk -Target $CONFIG_FILE

# Create game directory shortcut
Remove-Item -Path ./.minecraft.lnk -Force -ErrorAction Ignore
Create-Shortcut -Path ./.minecraft.lnk -Target $GAME_ROOT
#endregion


#region Ferium commands
# Perform profile switch, configure mods directory, and upgrade
.\ferium.exe profile switch $TARGET_PROFILE_NAME
.\ferium.exe profile configure --output-dir "$($GAME_ROOT)\mods"
Start-Process powershell "-Command Start-Transcript -Path .\upgrade.log; [console]::windowheight=500; ./ferium upgrade" -Wait
[regex]::Replace((Get-Content .\upgrade.log -Delimiter "This will never appear"), "(\*{22}\r\n.*?\*{22}\r\n(.*?\r\n)?|PS>.*)", "", "Singleline") `
    -replace "\u2713", "+" `
    -replace "\u00d7", "-"
#endregion
