#!/bin/sh

echo "Initializing Alpine Server Environment..."
apk update
apk add openssh wget tar sudo curl jq procps newt dialog

# Configure SSH
echo "Configuring SSH..."
mkdir -p /run/sshd
# Alpine requires generating host keys
ssh-keygen -A

# Use port 12020 because Termux cannot bind to ports < 1024 without root
sed -i 's/^#Port 22/Port 12020/' /etc/ssh/sshd_config
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

# Install dashboard system-wide
cp /opt/termux-server/dashboard.sh /usr/local/bin/dashboard.sh
chmod +x /usr/local/bin/dashboard.sh

# Add dashboard to profile so it runs automatically upon login
if ! grep -q "DASHBOARD_SHOWN" /root/.profile 2>/dev/null; then
cat << 'EOF' >> /root/.profile

# Termux Server Dashboard Auto-Start
if [ -z "$DASHBOARD_SHOWN" ] && [ -t 1 ]; then
    if [ -f /usr/local/bin/dashboard.sh ]; then
        export DASHBOARD_SHOWN=1
        /usr/local/bin/dashboard.sh
    fi
fi
EOF
fi

echo "Initialization inside Alpine complete."
