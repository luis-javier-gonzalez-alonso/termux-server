#!/bin/sh

show_ngrok_url() {
    # Extract the ngrok urls from the local API
    JSON=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)
    TUNNELS=$(echo "$JSON" | jq -r '.tunnels[] | "\(.name): \(.public_url)"' 2>/dev/null)
    
    if [ -z "$TUNNELS" ]; then
        whiptail --scrolltext --msgbox "Ngrok is not running or no tunnels are active.\n\nEnsure your authtoken is configured." 0 0
    else
        MSG="Active Ngrok Endpoints:\n\n"
        echo "$TUNNELS" > /tmp/ngrok_tunnels.txt
        while IFS= read -r line; do
            NAME=$(echo "$line" | cut -d':' -f1)
            URL=$(echo "$line" | cut -d' ' -f2-)
            MSG="$MSG- [$NAME] $URL\n"
        done < /tmp/ngrok_tunnels.txt
        rm -f /tmp/ngrok_tunnels.txt
        
        whiptail --scrolltext --msgbox "$MSG" 0 0
    fi
}

show_services() {
    NGROK_STATUS=$(pgrep -x ngrok > /dev/null && echo "Running" || echo "Stopped")
    whiptail --msgbox "Service Status:\n\nNgrok: $NGROK_STATUS" 0 0
}

install_ngrok_token() {
    TOKEN=$(whiptail --inputbox "Enter your Ngrok Authtoken:\n(You can get this from dashboard.ngrok.com)" 0 0 --title "Ngrok Setup" 3>&1 1>&2 2>&3)
    if [ ! -z "$TOKEN" ]; then
        ngrok config add-authtoken "$TOKEN"
        whiptail --msgbox "Authtoken added successfully! You can now start ngrok." 0 0
    fi
}

add_ngrok_service() {
    NAME=$(whiptail --inputbox "Enter a name for the HTTP service (e.g. webapp):" 0 0 --title "Add Ngrok Service" 3>&1 1>&2 2>&3)
    if [ -z "$NAME" ]; then return; fi
    
    PORT=$(whiptail --inputbox "Enter the port number this service runs on (e.g. 11001):" 0 0 --title "Add Ngrok Service" 3>&1 1>&2 2>&3)
    if [ -z "$PORT" ]; then return; fi
    
    # Append to ngrok.yml
    echo "  $NAME:" >> /root/.config/ngrok/ngrok.yml
    echo "    proto: http" >> /root/.config/ngrok/ngrok.yml
    echo "    addr: $PORT" >> /root/.config/ngrok/ngrok.yml
    
    whiptail --msgbox "Service '$NAME' added on port $PORT!\nRestarting Ngrok..." 0 0
    if tmux has-session -t "ngrok-system" 2>/dev/null; then tmux kill-session -t "ngrok-system"; fi
    pkill -x ngrok
    tmux new-session -d -s "ngrok-system" "ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout; echo ''; echo '--- Ngrok Exited ---'; echo 'Press Enter to close...'; read r"
}

while true; do
    CHOICE=$(whiptail --title "Ngrok Manager" --menu "Choose an option" 0 0 0 \
    "1" "View Active Ngrok Endpoints" \
    "2" "View Ngrok Status" \
    "3" "Configure Ngrok Authtoken" \
    "4" "Add Exposed Service (HTTP)" \
    "5" "Back to Dashboard" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) show_ngrok_url ;;
        2) show_services ;;
        3) install_ngrok_token ;;
        4) add_ngrok_service ;;
        5) break ;;
        *) break ;;
    esac
done
