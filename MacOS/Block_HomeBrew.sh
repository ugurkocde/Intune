#!/bin/bash
# Description: Block Homebrew on Intune managed macOS devices
# Author: Ugur Koc, @ugurkocde

# Set the path to the Homebrew installation
CPU_TYPE=$(sysctl -n machdep.cpu.brand_string)
if [[ "$CPU_TYPE" == *"Apple"* ]]; then
    HOMEBREW_PATH="/opt/homebrew"
else
    HOMEBREW_PATH="/usr/local"
fi

# Check if Homebrew directory exists
if [ -d "$HOMEBREW_PATH" ]; then
    echo "$HOMEBREW_PATH exists. Setting permissions."
    # Change ownership to root and set permissions to root only
    sudo chown -R root:wheel "$HOMEBREW_PATH"
    sudo chmod -R 700 "$HOMEBREW_PATH"
else
    echo "$HOMEBREW_PATH does not exist. Creating directory and setting permissions."
    # Create the directory and set ownership and permissions
    sudo mkdir -p "$HOMEBREW_PATH"
    sudo chown -R root:wheel "$HOMEBREW_PATH"
    sudo chmod -R 700 "$HOMEBREW_PATH"
fi

# Change ownership to root and set permissions to root only
sudo chown -R root:wheel "$HOMEBREW_PATH"
sudo chmod -R 700 "$HOMEBREW_PATH"

# Alias message
alias_message="echo 'Brew is disabled on this managed device to avoid conflicts with patch management.'"

# Function to add alias to a shell profile
add_alias_to_profile() {
    profile_path=$1
    echo "Checking $profile_path"

    # Check if the profile file exists and is writable
    if [[ -w "$profile_path" ]]; then
        echo "Adding alias to $profile_path"

        # Check if alias already exists in the profile
        if ! grep -q "alias brew=" "$profile_path"; then
            # Add alias
            echo "alias brew=$alias_message" >>"$profile_path"
        else
            echo "Alias already exists in $profile_path"
        fi
    else
        echo "$profile_path not found or not writable."
    fi
}

# Add the sudoers configuration to restrict chmod on Homebrew directory
add_sudoers_restriction() {
    echo "Attempting to add sudoers restriction for Homebrew directory"

    # Define the command alias and restriction
    sudoers_content="Cmnd_Alias HOMEBREW_CHMOD = /bin/chmod * /opt/homebrew*, /usr/bin/chmod * /opt/homebrew*\n%admin ALL=(ALL) ALL, !HOMEBREW_CHMOD"

    # Create a temporary file for safe sudoers editing
    tmp_sudoers=$(mktemp)

    # Check if tmp_sudoers is created
    if [[ -f "$tmp_sudoers" ]]; then
        # Add the current sudoers file to the temporary file
        sudo cat /etc/sudoers >"$tmp_sudoers"

        # Add the new restrictions to the temporary file
        echo -e "$sudoers_content" >>"$tmp_sudoers"

        # Check for syntax errors and update the sudoers file if none are found
        sudo visudo -cf "$tmp_sudoers" && sudo cp "$tmp_sudoers" /etc/sudoers && echo "Sudoers file updated successfully."

        # Clean up the temporary file
        rm "$tmp_sudoers"
    else
        echo "Failed to create temporary sudoers file."
    fi
}

# Paths to user profiles for Bash and Zsh
BASH_PROFILE="$HOME/.bash_profile"
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

# Add alias to each profile
add_alias_to_profile "$BASH_PROFILE"
add_alias_to_profile "$BASHRC"
add_alias_to_profile "$ZSHRC"

# Add sudoers restriction
add_sudoers_restriction

echo "Script execution completed."
