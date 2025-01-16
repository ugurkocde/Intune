#!/bin/bash

# Description: This script checks the status of Microsoft AutoUpdate (MAU) and displays
# the version, channel, and last update check time.
#
# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Path to msupdate CLI
MSUPDATE="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"

# Get the configuration output
CONFIG_OUTPUT=$("$MSUPDATE" --config)

# Extract information and display in a single line with | delimiter
echo "MAU Version: $(echo "$CONFIG_OUTPUT" | grep "AutoUpdateVersion =" | awk -F'"' '{print $2}') | Channel: $(echo "$CONFIG_OUTPUT" | grep "ChannelName = " | head -n 1 | awk -F'=' '{print $2}' | sed 's/;//' | xargs) | Last Update Check: $(echo "$CONFIG_OUTPUT" | grep "LastCheckForUpdates =" | awk -F'"' '{print $2}')"
