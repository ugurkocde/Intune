#!/bin/bash
#
# Description: This script forces the installation of all available Microsoft updates
# on macOS systems using the msupdate CLI tool. It will initiate the update process
# immediately without waiting for user confirmation. This will force close any open
# Applications that are being updated.
#
# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Path to msupdate CLI
MSUPDATE="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app/Contents/MacOS/msupdate"

# Force install all available updates with a 15-minute warning
"$MSUPDATE" --install

echo "Force Update triggered."
