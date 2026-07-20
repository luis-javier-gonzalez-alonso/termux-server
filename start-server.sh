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
    # Create a safe boot script to avoid quoting issues
    cat << 'BOOTEOF' > /usr/local/share/termux-server/boot.sh
#!/bin/sh
if [ -f /usr/local/share/termux-server/tools/script-runner/startup.list ]; then
    while IFS='|' read -r sname cmd || [ -n "$sname" ]; do
        if [ -n "$sname" ]; then
            if ! tmux has-session -t "$sname" 2>/dev/null; then
                tmux new-session -d -s "$sname" "$cmd"
                echo "Started Script Runner session: $sname"
            fi
        fi
    done < /usr/local/share/termux-server/tools/script-runner/startup.list
fi
BOOTEOF
    chmod +x /usr/local/share/termux-server/boot.sh
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

# Start ngrok in the background inside alpine
proot-distro login alpine --isolated -- /bin/sh -c "
    if ! pgrep -x ngrok > /dev/null; then
        if grep -q authtoken /root/.config/ngrok/ngrok.yml 2>/dev/null; then
            # Ensure tunnels config exists
            if ! grep -q 'tunnels:' /root/.config/ngrok/ngrok.yml 2>/dev/null; then
                echo 'tunnels:' >> /root/.config/ngrok/ngrok.yml
            fi
            nohup ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout > /var/log/ngrok.log 2>&1 &
            echo 'Ngrok started.'
        else
            echo 'WARNING: Ngrok not started. No authtoken configured.'
        fi
    else
        echo 'Ngrok already running.'
    fi
"

# Start Script Runner startup scripts
proot-distro login alpine --isolated -- /bin/sh -c "/usr/local/share/termux-server/boot.sh"

echo "Server started."
echo "You can now enter the server environment by running:"
echo "  proot-distro login alpine --isolated"
