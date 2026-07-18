#!/bin/bash

show_ngrok_url() {
    # Extract the ngrok tcp url from the local API
    URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null)
    
    if [ -z "$URL" ] || [ "$URL" == "null" ]; then
        whiptail --msgbox "Ngrok is not running or no tunnel is active.\n\nNgrok requires an authtoken for TCP tunnels. To set it up:\n1. Open Shell\n2. Run: ngrok config add-authtoken <your-token>\n3. Exit shell and run start-server.sh again." 12 65
    else
        # Remove tcp:// prefix
        CLEAN_URL=${URL#tcp://}
        HOST=${CLEAN_URL%:*}
        PORT=${CLEAN_URL##*:}
        whiptail --msgbox "Your server is accessible via SSH over the internet!\n\nUse the following command from your computer:\nssh root@${HOST} -p ${PORT}\n\nPassword is 'admin' (unless you changed it)." 12 70
    fi
}

show_services() {
    SSHD_STATUS=$(pgrep -x sshd > /dev/null && echo "Running" || echo "Stopped")
    NGROK_STATUS=$(pgrep -x ngrok > /dev/null && echo "Running" || echo "Stopped")
    
    whiptail --msgbox "Service Status:\n\nSSH Daemon: $SSHD_STATUS\nNgrok: $NGROK_STATUS" 10 50
}

change_password() {
    if (whiptail --title "Change Root Password" --yesno "Do you want to change the root password?" 8 45); then
        # Switch back to regular terminal input for passwd
        clear
        echo "Changing password for user 'root':"
        passwd
        echo "Press Enter to return to the dashboard..."
        read
    fi
}

install_ngrok_token() {
    TOKEN=$(whiptail --inputbox "Enter your Ngrok Authtoken:\n(You can get this from dashboard.ngrok.com)" 10 60 --title "Ngrok Setup" 3>&1 1>&2 2>&3)
    if [ ! -z "$TOKEN" ]; then
        ngrok config add-authtoken "$TOKEN"
        whiptail --msgbox "Authtoken added successfully! You can now start ngrok." 8 60
    fi
}

while true; do
    CHOICE=$(whiptail --title "Termux Server Dashboard" --menu "Choose an option" 16 65 7 \
    "1" "Show SSH Connection Details (Ngrok)" \
    "2" "View Services Status" \
    "3" "Change Root Password" \
    "4" "Configure Ngrok Authtoken" \
    "5" "Open Shell" \
    "6" "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) show_ngrok_url ;;
        2) show_services ;;
        3) change_password ;;
        4) install_ngrok_token ;;
        5) clear; echo "Dropping to shell. Type 'exit' to log out, or '/root/dashboard.sh' to return to menu."; break ;;
        6) clear; exit 0 ;;
        *) break ;;
    esac
done
