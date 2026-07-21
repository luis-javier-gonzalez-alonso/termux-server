#!/data/data/com.termux/files/usr/bin/bash

echo "Starting Server Environment..."

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Syncing latest scripts to Alpine environment..."
proot-distro login alpine --isolated --bind "$DIR:/opt/termux-server" -- /bin/sh -c "
    cp /opt/termux-server/dashboard.sh /usr/local/bin/dashboard.sh
    chmod +x /usr/local/bin/dashboard.sh
    
    mkdir -p /usr/local/share/termux-server
    # Use -a to preserve permissions and -u to only copy newer files to keep it fast
    cp -au /opt/termux-server/tools /usr/local/share/termux-server/
    
    # Ensure dependencies are up to date
    cd /usr/local/share/termux-server/tools/json-store && npm install --no-audit --no-fund --silent >/dev/null 2>&1
"

# Check if ngrok is configured before dropping into the background script
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

# Check if daemon is already running
if [ -f "$DIR/daemon.pid" ]; then
    PID=$(cat "$DIR/daemon.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Server daemon is already running (PID $PID)."
        DAEMON_RUNNING=1
    fi
fi

if [ -z "$DAEMON_RUNNING" ]; then
    echo "Starting Termux Server background daemon..."
    nohup proot-distro login alpine --isolated -- /bin/sh /usr/local/share/termux-server/tools/daemon.sh > /dev/null 2>&1 &
    echo $! > "$DIR/daemon.pid"
fi

echo "Server started."
echo "You can now enter the server environment by running:"
echo "  proot-distro login alpine --isolated"
