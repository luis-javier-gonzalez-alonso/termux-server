#!/data/data/com.termux/files/usr/bin/bash

echo "Starting Server Environment..."

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
proot-distro login alpine --isolated -- /bin/sh -c "
    if [ -f /opt/termux-server/tools/script-runner/startup.list ]; then
        while IFS='|' read -r sname cmd; do
            if [ -n \"\$sname\" ]; then
                if ! tmux has-session -t \"\$sname\" 2>/dev/null; then
                    tmux new-session -d -s \"\$sname\" \"\$cmd\"
                    echo \"Started Script Runner session: \$sname\"
                fi
            fi
        done < /opt/termux-server/tools/script-runner/startup.list
    fi
"

echo "Server started."
echo "You can now enter the server environment by running:"
echo "  proot-distro login alpine --isolated"
