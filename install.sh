#!/data/data/com.termux/files/usr/bin/bash

echo "Updating Termux packages..."
pkg update -y

echo "Installing proot-distro..."
pkg install -y proot-distro

echo "Installing Debian..."
proot-distro install debian

echo "Testing Debian environment architecture..."
if ! proot-distro login debian -- /bin/true 2>/dev/null; then
    echo "WARNING: 'exec format error' or similar detected."
    echo "This usually happens if you are using the Play Store version of Termux (which is 32-bit) on a 64-bit device, or if your phone has a 32-bit Android OS."
    echo "Attempting to fallback to 32-bit (arm) Debian..."
    proot-distro remove debian
    proot-distro install debian --architecture arm
fi

echo "Copying initialization scripts to Debian..."
DEBIAN_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/debian"

cp proot-init.sh "$DEBIAN_ROOT/root/"
cp dashboard.sh "$DEBIAN_ROOT/root/"
chmod +x "$DEBIAN_ROOT/root/proot-init.sh"
chmod +x "$DEBIAN_ROOT/root/dashboard.sh"

echo "Running initialization inside Debian..."
proot-distro login debian -- /root/proot-init.sh

echo ""
echo "================================================="
echo "Setup complete! The Debian environment is ready."
echo "To start the server (SSH and Ngrok), run:"
echo "  ./start-server.sh"
echo "================================================="
