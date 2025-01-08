#!/bin/bash

# Description: This script displays available Updates for Microsoft Apps by checking MAU.
#
# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Path to msupdate CLI
MSUPDATE="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"

# Display the available updates
AVAILABLE_UPDATES=$("$MSUPDATE" --list)

echo "$AVAILABLE_UPDATES"
