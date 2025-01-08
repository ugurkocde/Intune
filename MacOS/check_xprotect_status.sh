#!/bin/bash

# Description: Script to check XProtect, XProtect Remediator, and MRT status
#
# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    exit 1
fi

# Set up logging
LOG_DIR="/Users/uk/Library/Logs/Microsoft/Custom Attributes"
LOG_FILE="$LOG_DIR/xprotect_status.log"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create log directory" >&2
        exit 1
    fi
fi

# Logging function with severity levels
log_message() {
    local severity="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%SZ')
    echo "[$timestamp] [$severity] $message" >>"$LOG_FILE"
}

# Start logging
log_message "INFO" "Starting security status check"

# Get macOS version
os_version=$(sw_vers -productVersion)
build_version=$(sw_vers -buildVersion)
log_message "INFO" "macOS Version: $os_version (Build $build_version)"

# Function to check plist value with error handling
get_plist_value() {
    local plist="$1"
    local key="$2"
    if [ ! -f "$plist" ]; then
        log_message "ERROR" "Plist file not found: $plist"
        return 1
    fi

    local value
    value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_message "WARN" "Key $key not found in $plist"
        return 1
    fi
    echo "$value"
}

# Function to check XProtect version
check_xprotect() {
    local xprotect_meta="/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist"
    local xprotect_version=""

    if [ -f "$xprotect_meta" ]; then
        xprotect_version=$(get_plist_value "$xprotect_meta" "CFBundleShortVersionString")
    else
        log_message "ERROR" "XProtect metadata file not found"
    fi

    log_message "INFO" "XProtect Version: $xprotect_version"
    echo -n "XProtect: v${xprotect_version:-Unknown}"
}

# Function to check XProtect Remediator
check_xprotect_remediator() {
    local remediator_meta="/Library/Apple/System/Library/CoreServices/XProtect.app/Contents/Info.plist"
    local remediator_version=""

    if [ -f "$remediator_meta" ]; then
        remediator_version=$(get_plist_value "$remediator_meta" "CFBundleShortVersionString")
    else
        log_message "ERROR" "XProtect Remediator metadata file not found"
    fi

    log_message "INFO" "XProtect Remediator Version: $remediator_version"
    echo -n " | XProtect Remediator: v${remediator_version:-Unknown}"
}

# Function to check MRT version
check_mrt() {
    local mrt_meta="/Library/Apple/System/Library/CoreServices/MRT.app/Contents/Info.plist"
    local mrt_version=""

    if [ -f "$mrt_meta" ]; then
        mrt_version=$(get_plist_value "$mrt_meta" "CFBundleShortVersionString")
    else
        log_message "ERROR" "MRT metadata file not found"
    fi

    log_message "INFO" "MRT Version: $mrt_version"
    echo -n " | MRT: v${mrt_version:-Unknown}"
}

# Function to check system security settings
check_system_security() {
    local security_status=""

    # Check SIP status
    local sip_output=$(csrutil status 2>&1)
    if echo "$sip_output" | grep -q "System Integrity Protection status: enabled"; then
        security_status="SIP:Enabled"
    else
        security_status="SIP:Disabled"
    fi

    # Check Gatekeeper status
    if spctl --status 2>&1 | grep -q "enabled"; then
        security_status="$security_status,GK:Enabled"
    else
        security_status="$security_status,GK:Disabled"
    fi

    # Check FileVault status
    if fdesetup status | grep -q "On"; then
        security_status="$security_status,FV:Enabled"
    else
        security_status="$security_status,FV:Disabled"
    fi

    echo -n " | Security: $security_status"
}

# Output macOS version
echo -n "macOS: $os_version | "

# Run checks and output in a single line
check_xprotect
check_xprotect_remediator
check_mrt
check_system_security

# Add newline at the end
echo

# Log completion
log_message "INFO" "Security status check completed"

exit 0
