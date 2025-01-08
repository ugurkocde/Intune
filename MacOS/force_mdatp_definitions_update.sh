#!/bin/bash

# Description: This script updates Microsoft Defender for Endpoint (MDE) definitions using the mdatp CLI.
# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Get initial definitions version
echo "Checking current definitions version..."
initial_version=$(mdatp health | grep "definitions_version" | awk -F'"' '{print $2}')
echo "Current definitions version: $initial_version"

# Update definitions
echo -e "\nUpdating definitions..."
mdatp definitions update

# Get new definitions version
echo -e "\nChecking new definitions version..."
new_version=$(mdatp health | grep "definitions_version" | awk -F'"' '{print $2}')
echo "New definitions version: $new_version"

# Compare versions
if [ "$initial_version" != "$new_version" ]; then
    echo -e "\nDefinitions were successfully updated from $initial_version to $new_version"
else
    echo -e "\nDefinitions version remained at $initial_version. No updates were available."
fi
