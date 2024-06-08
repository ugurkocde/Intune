#!/bin/bash

# Download the background image
wget -O /usr/share/backgrounds/my_background.jpg https://raw.githubusercontent.com/ugurkocde/Intune/main/Linux/media/Thermenresort_Loipersdorf.jpg

# Create the set-background.service
echo "[Unit]
Description=Set Desktop Background
After=graphical.target

[Service]
ExecStart=/usr/local/bin/set-background.sh
Type=oneshot

[Install]
WantedBy=default.target" > /etc/systemd/system/set-background.service

# Create the set-background.sh script
echo "#!/bin/bash
for user in \$(ls /home); do
  sudo -u \$user DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u \$user)/bus gsettings set org.gnome.desktop.background picture-uri \"file:///usr/share/backgrounds/my_background.jpg\"
done" > /usr/local/bin/set-background.sh

# Make the set-background.sh script executable
chmod +x /usr/local/bin/set-background.sh

# Enable the set-background service
systemctl enable set-background.service
