#!/bin/bash
# Script to get the last reboot time formatted

# Extracting the timestamp from the sysctl command
timestamp=$(sysctl kern.boottime | awk '{print $5}' | tr -d ',')

# Converting the timestamp to a formatted date
formatted_date=$(date -r $timestamp "+%Y-%m-%d %H:%M:%S")

echo "Last Reboot Time: $formatted_date"
