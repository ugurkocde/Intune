#!/bin/bash

# Description: Script to check Apple warranty and AppleCare status on macOS devices.
# Source: https://community.jamf.com/t5/jamf-pro/collecting-warranty-status/m-p/298357#M263560

# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Get the current username
loggedInUser=$(stat -f "%Su" /dev/console)
echo "Current logged in user is: $loggedInUser"

# Set the warranty directory path
warrantyDir="/Users/$loggedInUser/Library/Application Support/com.apple.NewDeviceOutreach"

# Check if the directory exists
if [ ! -d "$warrantyDir" ]; then
    echo "Warranty directory not found"
    exit 1
fi

# Check if any Warranty files exist
warrantyFiles=($(ls "$warrantyDir" | grep "_Warranty"))

if [ ${#warrantyFiles[@]} -eq 0 ]; then
    echo "No Warranty Files found"
    exit 0
fi

# Loop through each warranty file
for file in "${warrantyFiles[@]}"; do
    echo "Processing file: $file"
    expires=$(defaults read "$warrantyDir/$file" coverageEndDate)

    if [ -z "$expires" ]; then
        echo "File has no expiration date – skipping this file."
    else
        # Convert epoch to a standard date format
        ACexpires=$(date -r $expires '+%d.%m.%Y')
        echo "Coverage expires on: $ACexpires"
    fi
done
