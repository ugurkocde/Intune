#!/bin/bash

# Script to check Apple security and software update services connectivity
#
# For more scripts and guides on macOS and Intune, visit: IntuneMacAdmins.com

# Set up logging
LOG_DIR="/Users/uk/Library/Logs/Microsoft/Custom Attributes"
LOG_FILE="$LOG_DIR/icloud_connectivity.log"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create log directory" >&2
        exit 1
    fi
fi

# Logging function
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >>"$LOG_FILE"
}

# Start logging
log_message "Starting connectivity checks"

# Check for required commands
for cmd in nc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error_msg="Required command not found: $cmd"
        log_message "ERROR: $error_msg"
        echo "Error: $error_msg" >&2
        exit 1
    fi
done

# Function to check TCP connectivity
check_tcp_connection() {
    local domain="$1"
    local port="$2"

    log_message "Checking TCP connectivity to $domain:$port"
    # Use nc (netcat) to test TCP connection with 2 second timeout
    if nc -zw2 "$domain" "$port" 2>/dev/null; then
        log_message "$domain:$port is CONNECTED"
        return 0
    else
        log_message "$domain:$port connection FAILED"
        return 1
    fi
}

# Main execution
log_message "Starting security services checks"

# Initialize unreachable arrays for each category
security_unreachable=()
update_unreachable=()

# Check security services
log_message "Checking security services"
if ! check_tcp_connection "ocsp.apple.com" "443"; then
    security_unreachable+=("ocsp.apple.com")
fi
if ! check_tcp_connection "crl.apple.com" "443"; then
    security_unreachable+=("crl.apple.com")
fi
if ! check_tcp_connection "ppq.apple.com" "443"; then
    security_unreachable+=("ppq.apple.com")
fi
if ! check_tcp_connection "api.apple-cloudkit.com" "443"; then
    security_unreachable+=("api.apple-cloudkit.com")
fi

# Check OS/Software update services
log_message "Checking update services"
if ! check_tcp_connection "osrecovery.apple.com" "443"; then
    update_unreachable+=("osrecovery.apple.com")
fi
if ! check_tcp_connection "oscdn.apple.com" "443"; then
    update_unreachable+=("oscdn.apple.com")
fi
if ! check_tcp_connection "swcdn.apple.com" "443"; then
    update_unreachable+=("swcdn.apple.com")
fi
if ! check_tcp_connection "swdist.apple.com" "443"; then
    update_unreachable+=("swdist.apple.com")
fi
if ! check_tcp_connection "swdownload.apple.com" "443"; then
    update_unreachable+=("swdownload.apple.com")
fi
if ! check_tcp_connection "swscan.apple.com" "443"; then
    update_unreachable+=("swscan.apple.com")
fi
if ! check_tcp_connection "updates.cdn-apple.com" "443"; then
    update_unreachable+=("updates.cdn-apple.com")
fi

# Format the output
result=""

# Check security services status
if [ ${#security_unreachable[@]} -eq 0 ]; then
    result="Security services: All reachable"
else
    security_list=$(
        IFS=,
        echo "${security_unreachable[*]}"
    )
    result="Security services unreachable: $security_list"
fi

# Add update services status
if [ ${#update_unreachable[@]} -eq 0 ]; then
    result="$result | Update services: All reachable"
else
    update_list=$(
        IFS=,
        echo "${update_unreachable[*]}"
    )
    result="$result | Update services unreachable: $update_list"
fi

# Log the final result
log_message "Check completed. Result: $result"

# Output the result
echo "$result"

exit 0
