#!/data/data/com.termux/files/usr/bin/bash

echo "Updating Termux packages..."
pkg update -y

echo "Installing proot-distro..."
pkg install -y proot-distro

echo "Installing Ubuntu..."
proot-distro install ubuntu

echo "Testing Ubuntu environment architecture..."
if ! proot-distro login ubuntu -- /bin/true 2>/dev/null; then
    echo "WARNING: 'exec format error' or similar detected."
    echo "This usually happens if you are using the Play Store version of Termux (which is 32-bit) on a 64-bit device, or if your phone has a 32-bit Android OS."
    echo "Attempting to fallback to 32-bit (arm) Ubuntu..."
    proot-distro remove ubuntu
    proot-distro install ubuntu --architecture arm
fi

echo "Copying initialization scripts to Ubuntu..."
UBUNTU_ROOT="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"

cp proot-init.sh "$UBUNTU_ROOT/root/"
cp dashboard.sh "$UBUNTU_ROOT/root/"
chmod +x "$UBUNTU_ROOT/root/proot-init.sh"
chmod +x "$UBUNTU_ROOT/root/dashboard.sh"

echo "Running initialization inside Ubuntu..."
proot-distro login ubuntu -- /root/proot-init.sh

echo ""
echo "================================================="
echo "Setup complete! The Ubuntu environment is ready."
echo "To start the server (SSH and Ngrok), run:"
echo "  ./start-server.sh"
echo "================================================="
