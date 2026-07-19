#!/data/data/com.termux/files/usr/bin/bash

echo "Starting Server Environment..."

# Start ngrok in the background inside alpine
# Note: ngrok requires an auth token.
# You need to run `ngrok config add-authtoken <token>` inside alpine first.
proot-distro login alpine -- /bin/sh -c "
    if ! pgrep -x ngrok > /dev/null; then
        # Check if ngrok is configured
        if grep -q authtoken /root/.config/ngrok/ngrok.yml 2>/dev/null; then
            # Ensure tunnels config exists
            if ! grep -q 'tunnels:' /root/.config/ngrok/ngrok.yml; then
                echo 'tunnels:' >> /root/.config/ngrok/ngrok.yml
            fi
            nohup ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout > /var/log/ngrok.log 2>&1 &
            echo 'Ngrok started.'
        else
            echo 'WARNING: Ngrok not started. You must configure an authtoken first.'
        fi
    else
        echo 'Ngrok already running.'
    fi
"

echo "Server started."
echo "You can now enter the server environment by running:"
echo "  proot-distro login alpine"
