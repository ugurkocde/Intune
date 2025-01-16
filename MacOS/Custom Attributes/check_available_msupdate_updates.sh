#!/bin/bash

# Description: This script displays available Updates for Microsoft Apps by checking MAU.
#
# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Path to msupdate CLI
MSUPDATE="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"

# Get the currently logged-in user and their launchctl session
LOGGED_IN_USER=$(stat -f "%Su" /dev/console)
USER_ID=$(id -u "$LOGGED_IN_USER")

# Run msupdate using the user's launchctl session
RAW_OUTPUT=$(launchctl asuser "$USER_ID" sudo -u "$LOGGED_IN_USER" "$MSUPDATE" --list 2>&1)

# Check if "No updates available" is in the output
if echo "$RAW_OUTPUT" | grep -q "No updates available"; then
    echo "No updates available"
else
    # Display the full output if updates are available
    echo "$RAW_OUTPUT"
fi
