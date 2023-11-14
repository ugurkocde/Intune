#!/bin/bash

# Define the log file location
LOG_FILE="/var/log/hostname.log"

# Retrieve the serial number of the Mac
FULL_SERIAL_NUMBER=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

# Use the last 6 characters of the serial number
SERIAL_NUMBER=${FULL_SERIAL_NUMBER:(-8)}

# Set the computer name, host name, and local host name
sudo scutil --set ComputerName "LT-$SERIAL_NUMBER"
sudo scutil --set HostName "LT-$SERIAL_NUMBER"
sudo scutil --set LocalHostName "LT-$SERIAL_NUMBER"

# Log the outcome
if [ $? -eq 0 ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Successfully changed names to LT-$SERIAL_NUMBER" | sudo tee -a "$LOG_FILE"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Failed to change names" | sudo tee -a "$LOG_FILE"
fi
