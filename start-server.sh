#!/data/data/com.termux/files/usr/bin/bash

echo "Starting Server Environment..."

# Start sshd and ngrok in the background inside ubuntu
# Note: ngrok requires an auth token to run tcp tunnels.
# You need to run `ngrok config add-authtoken <token>` inside ubuntu first.
proot-distro login ubuntu-20.04 -- /bin/bash -c "
    if ! pgrep -x sshd > /dev/null; then
        /usr/sbin/sshd
        echo 'SSH daemon started.'
    else
        echo 'SSH daemon already running.'
    fi

    if ! pgrep -x ngrok > /dev/null; then
        # Check if ngrok is configured
        if grep -q authtoken /root/.config/ngrok/ngrok.yml 2>/dev/null; then
            nohup ngrok tcp 8022 --log=stdout > /var/log/ngrok.log 2>&1 &
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
echo "  proot-distro login ubuntu-20.04"
