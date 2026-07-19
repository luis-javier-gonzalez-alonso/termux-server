#!/data/data/com.termux/files/usr/bin/bash

echo "Updating Termux packages..."
pkg update -y

echo "Installing proot-distro..."
pkg install -y proot-distro

echo "Installing Alpine Linux..."
proot-distro install alpine

echo "Testing Alpine environment architecture..."
if ! proot-distro login alpine -- /bin/true 2>/dev/null; then
    echo "WARNING: 'exec format error' or similar detected."
    echo "Attempting to fallback to 32-bit (arm) Alpine..."
    proot-distro remove alpine
    proot-distro install alpine --architecture arm
fi

echo "Running initialization inside Alpine..."
# We use --bind to safely mount the current directory into /opt/termux-server
# This completely avoids guessing where the rootfs is stored on the disk.
proot-distro login alpine --bind "$PWD:/opt/termux-server" -- /bin/sh /opt/termux-server/proot-init.sh

echo ""
echo "================================================="
echo "Setup complete! The Alpine environment is ready."
echo "To start the server (SSH and Ngrok), run:"
echo "  ./start-server.sh"
echo "================================================="
