#!/bin/bash

# Determine the run directory and mods directory
GAME_ROOT="$PWD"
echo "Game directory: $GAME_ROOT"

cd "$(dirname "$0")" || exit 1
echo "Ferium directory: $PWD"

CONFIG_FILE=~/.config/ferium/config.json
if [ ! -f "$CONFIG_FILE" ]; then
    echo "File not found: $CONFIG_FILE"
    exit 1
fi

if [ -n "$3" ]; then
    SOURCE_PROFILE_NAME="$1"
    TARGET_VERSION="$2"
    TARGET_PROFILE_NAME="$3"
elif [ -n "$2" ]; then
    TARGET_VERSION="$1"
    TARGET_PROFILE_NAME="$2"
else
    TARGET_VERSION="$1"
    TARGET_PROFILE_NAME="$TARGET_VERSION"
fi

# Read profiles from config file
PROFILES=$(jq '.profiles' "$CONFIG_FILE")

# Copy source profile if target profile doesn't exist yet
TARGET_PROFILE=$(echo "$PROFILES" | jq --arg profile_name "$TARGET_PROFILE_NAME" '.[] | select(.name == $profile_name)')
if [ -z "$TARGET_PROFILE" ] && [ -n "$SOURCE_PROFILE_NAME" ]; then
    # Check if source profile exists
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

# Symlink config file if not done yet
if [ ! -f ./config.json ]; then
    ln -s "$CONFIG_FILE" ./config.json
fi

# Symlink game directory and create user mods folder if not exists
rm -f ./_minecraft
ln -s "$GAME_ROOT" ./_minecraft

# Perform profile switch, configure mods directory, and upgrade
./ferium profile switch "$TARGET_PROFILE_NAME"
./ferium profile configure --output-dir "$GAME_ROOT/mods"
stdbuf -o0 script --return --quiet -c  "./ferium upgrade" /dev/null 2>&1 \
    | sed -u -r "s/$(echo -ne '[\u2800-\u28ff].*?2K')//gm"

exit 0
