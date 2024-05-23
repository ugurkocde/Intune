#!/bin/bash

# Script to configure the Dock on macOS devices
# This script clears existing Dock items, adds specified applications, and logs all actions.
# Tested on macOS 14.5
# 
# Version: 1.0
# Date: 2024-05-23
# Author: Ugur Koc

# Log file location
log="$HOME/configure_dock.log"

# Function to add an app to the Dock and log the action
add_to_dock() {
    app_path=$1
    echo "Adding $app_path to the Dock..." | tee -a "$log"
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${app_path}</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
}

# Clear the existing Dock apps and log the action
echo "Clearing existing Dock apps..." | tee -a "$log"
defaults write com.apple.dock persistent-apps -array

# Clear the persistent-others section and log the action
echo "Clearing persistent-others from the Dock..." | tee -a "$log"
defaults write com.apple.dock persistent-others -array

# List of applications to add to the Dock
apps=(
    "/System/Applications/Launchpad.app"
    "/Applications/Microsoft Edge.app"
    "/Applications/Microsoft Teams (work or school).app"
    "/Applications/Microsoft Outlook.app"
    "/Applications/Company Portal.app"
    "/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app"
    "/System/Applications/System Settings.app"
)

# Add each application to the Dock and log the action
for app in "${apps[@]}"; do
    add_to_dock "$app"
done

# Restart the Dock to apply changes and log the action
echo "Restarting the Dock to apply changes..." | tee -a "$log"
killall Dock

echo "Dock configuration completed." | tee -a "$log"

exit 0