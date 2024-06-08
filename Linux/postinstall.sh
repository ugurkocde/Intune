#!/bin/bash

# Define variables
IMAGE_URL="https://raw.githubusercontent.com/ugurkocde/Intune/main/Linux/media/Thermenresort_Loipersdorf.jpg"
IMAGE_NAME="new_background.jpg"
IMAGE_PATH="$HOME/Pictures/$IMAGE_NAME"

# Create the Pictures directory if it doesn't exist
mkdir -p "$HOME/Pictures"

# Download the image
wget -O "$IMAGE_PATH" "$IMAGE_URL"

# Set the new desktop background
gsettings set org.gnome.desktop.background picture-uri "file://$IMAGE_PATH"

echo "Desktop background has been changed to the new image."
