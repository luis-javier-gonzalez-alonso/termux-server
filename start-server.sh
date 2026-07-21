#!/data/data/com.termux/files/usr/bin/bash

echo "Starting Server Environment..."

DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="$HOME/.termux-server"

# Ensure global state directories exist
mkdir -p "$STATE_DIR/apps"

echo "Ensuring json-store dependencies are installed in Alpine..."
proot-distro login alpine --isolated -- /bin/sh -c "cd '$DIR/tools/json-store' && npm install --no-audit --no-fund --silent >/dev/null 2>&1"

# Check if ngrok is configured
if ! proot-distro login alpine --isolated -- grep -q authtoken /root/.config/ngrok/ngrok.yml 2>/dev/null; then
    echo ""
    echo "Ngrok Authtoken not found."
    echo "You can get your authtoken at https://dashboard.ngrok.com/get-started/your-authtoken"
    printf "Enter your Ngrok Authtoken (or press Enter to skip): "
    read TOKEN
    if [ -n "$TOKEN" ]; then
        proot-distro login alpine --isolated -- /bin/sh -c "ngrok config add-authtoken '$TOKEN'"
    fi
fi

echo "Starting Termux Server background processes natively..."
sh "$DIR/tools/script-runner/boot.sh"

echo "Ensuring native Node.js is installed for the Web Dashboard..."
if ! command -v node >/dev/null 2>&1; then
    echo "Installing nodejs natively in Termux..."
    pkg install -y nodejs
fi

echo "Starting Web Dashboard..."
cd "$DIR/tools/web-dashboard" && npm install --no-audit --no-fund --silent >/dev/null 2>&1
if ! tmux has-session -t "web-dashboard" 2>/dev/null; then
    tmux new-session -d -c "$DIR/tools/web-dashboard" -s "web-dashboard" "node server.js"
fi

echo "Server started."
echo "You can now enter the server dashboard directly from Termux by running:"
echo "  ./dashboard.sh"
echo "Or access the Web Dashboard from your browser at: http://localhost:8080"
