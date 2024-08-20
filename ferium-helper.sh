#!/bin/bash

#region Help
show_help() {
    echo "Usage:"
    echo "    $0 <source-profile> <target-version> <target-profile>"
    echo "    $0 <source-profile> <target-version>"
    echo "    $0 <target-profile>"
    echo ""
    echo "Arguments:"
    echo "    <source-profile>   : Name of the source profile (optional, only if target profile does not exist)"
    echo "    <target-version>   : Version of the game to target"
    echo "    <target-profile>   : Name of the target profile"
    echo ""
    echo "Description:"
    echo "    Copies the source profile to the target profile with the specified version, if it does not exist."
    echo "    If only two arguments are provided, it uses the first argument as the target version and the second as the target profile."
    echo "    If only one argument is provided, it performs an upgrade on the specified profile without copying from another profile."
}
#endregion

#region Initialization
if [ -n "$3" ]; then
    SOURCE_PROFILE_NAME="$1"
    TARGET_VERSION="$2"
    TARGET_PROFILE_NAME="$3"
elif [ -n "$2" ]; then
    TARGET_VERSION="$1"
    TARGET_PROFILE_NAME="$2"
elif [ -n "$1" ]; then
    TARGET_VERSION="$1"
    TARGET_PROFILE_NAME="$TARGET_VERSION"
else
    show_help
    exit 1
fi
# Determine the run directory and mods directory
GAME_ROOT="$PWD"
echo "Game directory: $GAME_ROOT"

# Move to the script's directory
cd "$(dirname "$0")" || exit 1
echo "Ferium directory: $PWD"

# Configuration file path
CONFIG_FILE=~/.config/ferium/config.json
if [ ! -f "$CONFIG_FILE" ]; then
    echo "File not found: $CONFIG_FILE"
    exit 1
fi
#endregion

#region Check for ferium updates
# Get the latest version from GitHub
LATEST_RELEASE_URL="https://api.github.com/repos/gorilla-devs/ferium/releases/latest"
LATEST_RELEASE=$(curl -s "$LATEST_RELEASE_URL")
LATEST_VERSION=$(echo "$LATEST_RELEASE" | jq -r .tag_name | sed 's/v//')

# Check if the current version matches the latest version
UPDATE_REQUIRED=true
if [ -f ./ferium ]; then
    CURRENT_VERSION=$(./ferium --version | sed 's/ferium //')
    echo "Current Ferium version: $CURRENT_VERSION"
    echo "Latest Ferium version: $LATEST_VERSION"

    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        UPDATE_REQUIRED=false
    fi
fi

# Download and extract the latest release if needed
if [ "$UPDATE_REQUIRED" = true ]; then
    ZIP_FILE_NAME="ferium-linux.zip"

    echo "Downloading latest Ferium release..."
    ASSET_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name == "'$ZIP_FILE_NAME'").browser_download_url')
    curl -L -o $ZIP_FILE_NAME "$ASSET_URL"
    unzip -o $ZIP_FILE_NAME -d .
    rm $ZIP_FILE_NAME
    echo "Done."
fi
#endregion

#region Copy profile data
# Read profiles from the config file
PROFILES=$(jq '.profiles' "$CONFIG_FILE")

# Copy source profile if target profile doesn't exist yet
TARGET_PROFILE=$(echo "$PROFILES" | jq --arg profile_name "$TARGET_PROFILE_NAME" '.[] | select(.name == $profile_name)')
if [ -z "$TARGET_PROFILE" ] && [ -n "$SOURCE_PROFILE_NAME" ]; then
    SOURCE_PROFILE=$(echo "$PROFILES" | jq --arg profile_name "$SOURCE_PROFILE_NAME" '.[] | select(.name == $profile_name)')

    if [ -n "$SOURCE_PROFILE" ]; then
        SOURCE_ROOT=$(echo "$SOURCE_PROFILE" | jq -r '.output_dir' | sed 's/\/mods//')

        # Copy game settings and configs
        cp -r \
            "$SOURCE_ROOT/options.txt" \
            "$SOURCE_ROOT/servers.dat" \
            "$SOURCE_ROOT/config" \
            "$GAME_ROOT"

        # Create user mods folder
        mkdir -p "$GAME_ROOT/mods/user"

        # Create new profile based on source profile
        NEW_PROFILE=$(echo "$SOURCE_PROFILE" | jq --arg new_version "$TARGET_VERSION" --arg new_name "$TARGET_PROFILE_NAME" '.game_version = $new_version | .name = $new_name')

        # Add new profile to profiles and sort
        jq --argjson new_profile "$NEW_PROFILE" '.profiles += [$new_profile] | .profiles |= sort_by(.name)' "$CONFIG_FILE" > tmp.json
        mv tmp.json "$CONFIG_FILE"

        echo "Profile copied from $SOURCE_PROFILE_NAME to $TARGET_PROFILE_NAME with version $TARGET_VERSION."
    else
        echo "Profile with name $SOURCE_PROFILE_NAME not found. Skipping copy."
    fi
fi
#endregion

#region Shortcuts
# Symlink config file if not already done
rm -f ./config.json
ln -s "$CONFIG_FILE" ./config.json

# Symlink game directory and create user mods folder if not exists
rm -f ./_minecraft
ln -s "$GAME_ROOT" ./_minecraft
#endregion

#region Ferium commands
# Perform profile switch, configure mods directory, and upgrade
./ferium profile switch "$TARGET_PROFILE_NAME"
./ferium profile configure --output-dir "$GAME_ROOT/mods"
stdbuf -o0 script --return --quiet -c  "./ferium upgrade" /dev/null 2>&1 \
    | sed -u -r "s/$(echo -ne '[\u2800-\u28ff].*?2K')//gm"
#endregion

exit 0
