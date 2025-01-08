#!/bin/bash
#
# Description: This script displays available Updates for Microsoft Apps by checking MAU.
#

# Path to msupdate CLI
MSUPDATE="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"

# Display the available updates
AVAILABLE_UPDATES=$("$MSUPDATE" --list)

echo "$AVAILABLE_UPDATES"
