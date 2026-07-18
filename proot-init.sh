#!/bin/bash

echo "Initializing Debian Server Environment..."
apt-get update
apt-get install -y openssh-server wget tar whiptail sudo curl jq procps inetutils-ping nano

# Configure SSH
echo "Configuring SSH..."
mkdir -p /run/sshd
# Use port 8022 because Termux cannot bind to ports < 1024 without root
sed -i 's/^#Port 22/Port 8022/' /etc/ssh/sshd_config
# Allow root login with password
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set root password to something default
echo "root:admin" | chpasswd

# Install ngrok
echo "Installing ngrok..."
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "armv8l" ]; then
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz"
elif [ "$ARCH" = "x86_64" ]; then
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
else
    # Fallback to arm64
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
fi

wget -q $NGROK_URL -O ngrok.tgz
tar -xzf ngrok.tgz -C /usr/local/bin
rm ngrok.tgz

# Add dashboard to bashrc so it runs automatically upon login
if ! grep -q "DASHBOARD_SHOWN" /root/.bashrc; then
cat << 'EOF' >> /root/.bashrc

# Termux Server Dashboard Auto-Start
if [ -z "$DASHBOARD_SHOWN" ] && [ -t 1 ]; then
    export DASHBOARD_SHOWN=1
    /root/dashboard.sh
fi
EOF
fi

echo "Initialization inside Debian complete."
