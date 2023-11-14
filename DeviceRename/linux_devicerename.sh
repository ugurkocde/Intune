#!/bin/bash

# Define the log file location
LOG_FILE="/var/log/hostname.log"

# Check if the dmidecode command is available
if ! command -v dmidecode &> /dev/null
then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - dmidecode command not found, cannot retrieve serial number" | sudo tee -a "$LOG_FILE"
    exit 1
fi

# Retrieve the serial number of the machine
FULL_SERIAL_NUMBER=$(sudo dmidecode -s system-serial-number)

# Use the last 6 characters of the serial number
SERIAL_NUMBER=${FULL_SERIAL_NUMBER:(-8)}

# Set the hostname
sudo hostnamectl set-hostname "LT-$SERIAL_NUMBER"

# Log the outcome
if [ $? -eq 0 ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Successfully changed hostname to LT-$SERIAL_NUMBER" | sudo tee -a "$LOG_FILE"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Failed to change hostname" | sudo tee -a "$LOG_FILE"
fi
