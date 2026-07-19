#!/bin/sh

show_ngrok_url() {
    # Extract the ngrok urls from the local API
    JSON=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)
    TUNNELS=$(echo "$JSON" | jq -r '.tunnels[] | "\(.name): \(.public_url)"' 2>/dev/null)
    
    if [ -z "$TUNNELS" ]; then
        whiptail --msgbox "Ngrok is not running or no tunnels are active.\n\nEnsure your authtoken is configured." 10 60
    else
        MSG="Active Ngrok Endpoints:\n\n"
        echo "$TUNNELS" > /tmp/ngrok_tunnels.txt
        while IFS= read -r line; do
            NAME=$(echo "$line" | cut -d':' -f1)
            URL=$(echo "$line" | cut -d' ' -f2-)
            MSG="$MSG- [$NAME] $URL\n"
        done < /tmp/ngrok_tunnels.txt
        rm -f /tmp/ngrok_tunnels.txt
        
        whiptail --msgbox "$MSG" 16 75
    fi
}

show_services() {
    NGROK_STATUS=$(pgrep -x ngrok > /dev/null && echo "Running" || echo "Stopped")
    
    whiptail --msgbox "Service Status:\n\nNgrok: $NGROK_STATUS" 8 40
}

install_ngrok_token() {
    TOKEN=$(whiptail --inputbox "Enter your Ngrok Authtoken:\n(You can get this from dashboard.ngrok.com)" 10 60 --title "Ngrok Setup" 3>&1 1>&2 2>&3)
    if [ ! -z "$TOKEN" ]; then
        ngrok config add-authtoken "$TOKEN"
        whiptail --msgbox "Authtoken added successfully! You can now start ngrok." 8 60
    fi
}

add_ngrok_service() {
    NAME=$(whiptail --inputbox "Enter a name for the HTTP service (e.g. webapp):" 10 60 --title "Add Ngrok Service" 3>&1 1>&2 2>&3)
    if [ -z "$NAME" ]; then return; fi
    
    PORT=$(whiptail --inputbox "Enter the port number this service runs on (e.g. 11001):" 10 60 --title "Add Ngrok Service" 3>&1 1>&2 2>&3)
    if [ -z "$PORT" ]; then return; fi
    
    # Append to ngrok.yml
    echo "  $NAME:" >> /root/.config/ngrok/ngrok.yml
    echo "    proto: http" >> /root/.config/ngrok/ngrok.yml
    echo "    addr: $PORT" >> /root/.config/ngrok/ngrok.yml
    
    whiptail --msgbox "Service '$NAME' added on port $PORT!\nRestarting Ngrok..." 8 50
    pkill -x ngrok
    nohup ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout > /var/log/ngrok.log 2>&1 &
}

start_json_store() {
    PORT=$(whiptail --inputbox "Enter the port for JSON store (e.g. 3000):" 10 60 "3000" --title "Start JSON Object Storage" 3>&1 1>&2 2>&3)
    if [ -z "$PORT" ]; then return; fi
    
    FOLDER=$(whiptail --inputbox "Enter the folder path to serve (e.g. /opt/termux-server/data):" 10 60 "/opt/termux-server/data" --title "Start JSON Object Storage" 3>&1 1>&2 2>&3)
    if [ -z "$FOLDER" ]; then return; fi
    
    nohup node /opt/termux-server/tools/json-store/index.js --port "$PORT" --folder "$FOLDER" > /var/log/json-store-$PORT.log 2>&1 &
    whiptail --msgbox "JSON Object Storage started on port $PORT!\nServing: $FOLDER\nLogs: /var/log/json-store-$PORT.log" 10 60
}

open_tools() {
    while true; do
        TOOL_CHOICE=$(whiptail --title "Tools Menu" --menu "Choose a tool" 14 65 4 \
        "1" "Start JSON Object Storage" \
        "2" "Back to Main Menu" 3>&1 1>&2 2>&3)
        
        case $TOOL_CHOICE in
            1) start_json_store ;;
            2) break ;;
            *) break ;;
        esac
    done
}


while true; do
    CHOICE=$(whiptail --title "Termux Server Dashboard" --menu "Choose an option" 16 65 6 \
    "1" "View Active Ngrok Endpoints" \
    "2" "View Services Status" \
    "3" "Configure Ngrok Authtoken" \
    "4" "Add Exposed Service (HTTP)" \
    "5" "Tools" \
    "6" "Open Shell" \
    "7" "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) show_ngrok_url ;;
        2) show_services ;;
        3) install_ngrok_token ;;
        4) add_ngrok_service ;;
        5) open_tools ;;
        6) clear; echo "Dropping to shell. Type 'exit' to log out, or '/root/dashboard.sh' to return to menu."; break ;;
        7) clear; exit 0 ;;
        *) break ;;
    esac
done
