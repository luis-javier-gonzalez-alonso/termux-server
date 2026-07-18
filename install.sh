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

echo "Copying initialization scripts to Alpine..."
ALPINE_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/alpine"

mkdir -p "$ALPINE_ROOT/opt/termux-server"
cp proot-init.sh "$ALPINE_ROOT/opt/termux-server/"
cp dashboard.sh "$ALPINE_ROOT/opt/termux-server/"
chmod +x "$ALPINE_ROOT/opt/termux-server/proot-init.sh"
chmod +x "$ALPINE_ROOT/opt/termux-server/dashboard.sh"

echo "Running initialization inside Alpine..."
proot-distro login alpine -- /opt/termux-server/proot-init.sh

echo ""
echo "================================================="
echo "Setup complete! The Alpine environment is ready."
echo "To start the server (SSH and Ngrok), run:"
echo "  ./start-server.sh"
echo "================================================="
