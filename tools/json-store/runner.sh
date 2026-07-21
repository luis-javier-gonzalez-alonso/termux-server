#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

start_json_store() {
    PORT=$(whiptail --inputbox "Enter the port for JSON store (e.g. 3000):" 0 0 "3000" --title "Start JSON Object Storage" 3>&1 1>&2 2>&3)
    if [ -z "$PORT" ]; then return; fi
    
    FOLDER=$(whiptail --inputbox "Enter the folder path to serve (e.g. /root/data):" 0 0 "/root/data" --title "Start JSON Object Storage" 3>&1 1>&2 2>&3)
    if [ -z "$FOLDER" ]; then return; fi
    
    if whiptail --yesno "Do you want to automatically expose port $PORT to the internet using Ngrok?" 0 0 --title "Expose Service"; then
        if ! proot-distro login alpine --isolated -- grep -q "addr: $PORT" /root/.config/ngrok/ngrok.yml 2>/dev/null; then
            proot-distro login alpine --isolated -- /bin/sh -c "
                echo '  json-store-$PORT:' >> /root/.config/ngrok/ngrok.yml
                echo '    proto: http' >> /root/.config/ngrok/ngrok.yml
                echo '    addr: $PORT' >> /root/.config/ngrok/ngrok.yml
            "
            if tmux has-session -t "ngrok-system" 2>/dev/null; then tmux kill-session -t "ngrok-system"; fi
            tmux new-session -d -s "ngrok-system" "proot-distro login alpine --isolated -- ngrok start --all --config /root/.config/ngrok/ngrok.yml --log=stdout; echo ''; echo '--- Ngrok Exited ---'; echo 'Press Enter to close...'; read r"
        fi
    fi
    
    tmux new-session -d -c "$FOLDER" -s "json-store-$PORT" "proot-distro login alpine --isolated -- /bin/sh -c 'cd \"$FOLDER\" && node \"$SCRIPT_DIR/index.js\" --port \"$PORT\" --folder \"$FOLDER\"'; echo ''; echo '--- Process Exited ---'; echo 'Press Enter to close...'; read r"
    whiptail --scrolltext --msgbox "JSON Object Storage started on port $PORT!\nServing: $FOLDER\nLogs: /var/log/json-store-$PORT.log" 0 0
}

while true; do
    CHOICE=$(whiptail --title "JSON Object Storage" --menu "Choose an option" 0 0 0 \
    "1" "Start New JSON Object Storage" \
    "2" "Back to Dashboard" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) start_json_store ;;
        2) break ;;
        *) break ;;
    esac
done
