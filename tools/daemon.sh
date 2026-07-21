#!/bin/sh
# Termux Server Master Daemon
# This script keeps the proot environment permanently alive for background processes.

# 1. Force start the tmux daemon so it is owned by this master proot instance
tmux start-server

# 2. Start Ngrok in the background via tmux if authtoken exists
if grep -q authtoken /root/.config/ngrok/ngrok.yml 2>/dev/null; then
    if ! grep -q 'tunnels:' /root/.config/ngrok/ngrok.yml 2>/dev/null; then
        echo 'tunnels:' >> /root/.config/ngrok/ngrok.yml
    fi
    if ! tmux has-session -t "ngrok-system" 2>/dev/null; then
        tmux new-session -d -s "ngrok-system" "ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout; echo ''; echo '--- Ngrok Exited ---'; echo 'Press Enter to close...'; read r"
    fi
fi

# 3. Start user's saved tmux scripts
if [ -f /usr/local/share/termux-server/tools/script-runner/boot.sh ]; then
    sh /usr/local/share/termux-server/tools/script-runner/boot.sh
fi

# 4. Block forever to prevent proot-distro from exiting and killing the background processes
while true; do
    sleep 3600
done
