#!/bin/bash

# Script to configure the Dock on macOS devices
# This script clears existing Dock items, adds specified applications, and logs all actions.
# Tested on macOS 14.5
# 
# Version: 1.0
# Date: 2024-05-23
# Author: Ugur Koc
#
# More Scripts: https://github.com/microsoft/shell-intune-samples/tree/master

# Log file location
log="$HOME/configure_dock.log"

# Function to add an app to the Dock and log the action
add_to_dock() {
    app_path=$1
    echo "Adding $app_path to the Dock..." | tee -a "$log"
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${app_path}</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
}

# Function to check and set the correct path for Microsoft Teams (https://github.com/microsoft/shell-intune-samples/blob/master/macOS/Config/Dock/addAppstoDock.sh)
check_and_set_installed_msteams_path() {
    if [[ -a "/Applications/Microsoft Teams.app" ]]; then
        echo "/Applications/Microsoft Teams.app"
    elif [[ -a "/Applications/Microsoft Teams classic.app" ]]; then
        echo "/Applications/Microsoft Teams classic.app"
    elif [[ -a "/Applications/Microsoft Teams (work or school).app" ]]; then
        echo "/Applications/Microsoft Teams (work or school).app"
    elif [[ -a "/Applications/Microsoft Teams (work preview).app" ]]; then
        echo "/Applications/Microsoft Teams (work preview).app"
    else
        echo ""
    fi
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
    "$(check_and_set_installed_msteams_path)"
    "/Applications/Microsoft Outlook.app"
    "/Applications/Company Portal.app"
    "/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app"
    "/System/Applications/System Settings.app"
)

# Add each application to the Dock and log the action
for app in "${apps[@]}"; do
    if [[ -n "$app" ]]; then
        add_to_dock "$app"
    else
        echo "Skipping empty app path." | tee -a "$log"
    fi
done

# Restart the Dock to apply changes and log the action
echo "Restarting the Dock to apply changes..." | tee -a "$log"
killall Dock

echo "Dock configuration completed." | tee -a "$log"

exit 0