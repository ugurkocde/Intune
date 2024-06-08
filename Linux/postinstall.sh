#!/bin/bash

# Create the set-background.sh script
echo "#!/bin/bash

# Define variables
IMAGE_URL=\"https://raw.githubusercontent.com/ugurkocde/Intune/main/Linux/media/Thermenresort_Loipersdorf.jpg\"
IMAGE_NAME=\"new_background.jpg\"
IMAGE_PATH=\"\$HOME/Pictures/\$IMAGE_NAME\"

# Create the Pictures directory if it doesn't exist
mkdir -p \"\$HOME/Pictures\"

# Download the image
wget -O \"\$IMAGE_PATH\" \"\$IMAGE_URL\"

# Set the new desktop background
gsettings set org.gnome.desktop.background picture-uri \"file://\$IMAGE_PATH\"

echo \"Desktop background has been changed to the new image.\"

# Disable the service
systemctl --user disable set-background.service
" > /usr/local/bin/set-background.sh

# Make the set-background.sh script executable
chmod +x /usr/local/bin/set-background.sh

# Create the set-background.service
echo "[Unit]
Description=Set Desktop Background
After=graphical.target

[Service]
ExecStart=/usr/local/bin/set-background.sh
Type=oneshot
User=%I

[Install]
WantedBy=default.target" > /etc/systemd/user/set-background.service

# Enable the service for the first boot
loginctl enable-linger
