#!/bin/sh

show_ngrok_url() {
    # Extract the ngrok urls from the local API
    JSON=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null)
    TUNNELS=$(echo "$JSON" | jq -r '.tunnels[] | "\(.name): \(.public_url)"' 2>/dev/null)
    
    if [ -z "$TUNNELS" ]; then
        whiptail --msgbox "Ngrok is not running or no tunnels are active.\n\nEnsure your authtoken is configured." 10 60
    else
        MSG="Active Ngrok Tunnels:\n\n"
        echo "$TUNNELS" > /tmp/ngrok_tunnels.txt
        while IFS= read -r line; do
            NAME=$(echo "$line" | cut -d':' -f1)
            URL=$(echo "$line" | cut -d' ' -f2-)
            if [ "$NAME" = "ssh" ]; then
                CLEAN_URL=${URL#tcp://}
                HOST=${CLEAN_URL%:*}
                PORT=${CLEAN_URL##*:}
                MSG="$MSG- [SSH] ssh root@${HOST} -p ${PORT}\n"
            else
                MSG="$MSG- [$NAME] $URL\n"
            fi
        done < /tmp/ngrok_tunnels.txt
        rm -f /tmp/ngrok_tunnels.txt
        
        MSG="$MSG\nPassword for SSH is what you set during first login."
        whiptail --msgbox "$MSG" 16 75
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
        read dummy
    fi
}

install_ngrok_token() {
    TOKEN=$(whiptail --inputbox "Enter your Ngrok Authtoken:\n(You can get this from dashboard.ngrok.com)" 10 60 --title "Ngrok Setup" 3>&1 1>&2 2>&3)
    if [ ! -z "$TOKEN" ]; then
        ngrok config add-authtoken "$TOKEN"
        whiptail --msgbox "Authtoken added successfully! You can now start ngrok." 8 60
    fi
}

create_service_user() {
    USERNAME=$(whiptail --inputbox "Enter a username for the new service (e.g. nginx-user, node-app):" 10 60 --title "Create Service User" 3>&1 1>&2 2>&3)
    if [ ! -z "$USERNAME" ]; then
        if id "$USERNAME" >/dev/null 2>&1; then
            whiptail --msgbox "User '$USERNAME' already exists!" 8 45
        else
            clear
            echo "Creating user '$USERNAME'..."
            adduser -D -s /bin/sh "$USERNAME"
            echo "Please set a password for the new service user '$USERNAME':"
            passwd "$USERNAME"
            if [ $? -eq 0 ]; then
                whiptail --msgbox "Service user '$USERNAME' created successfully.\nHome directory: /home/$USERNAME\nThey can now login via SSH using this username and password." 12 60
            else
                deluser "$USERNAME"
                whiptail --msgbox "Failed to set password. User creation aborted." 8 50
            fi
        fi
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

if [ ! -f /root/.password_changed ]; then
    whiptail --msgbox "SECURITY WARNING:\n\nYou must change the default root password before proceeding. 'admin' is not secure." 12 50
    clear
    echo "Changing password for root..."
    while true; do
        passwd
        if [ $? -eq 0 ]; then
            touch /root/.password_changed
            whiptail --msgbox "Password updated successfully." 8 45
            break
        else
            echo "Password change failed. Please try again."
            sleep 2
            clear
            echo "Changing password for root..."
        fi
    done
fi

while true; do
    CHOICE=$(whiptail --title "Termux Server Dashboard" --menu "Choose an option" 18 65 8 \
    "1" "Show Exposed Connection Details (Ngrok)" \
    "2" "View Services Status" \
    "3" "Change Root Password" \
    "4" "Configure Ngrok Authtoken" \
    "5" "Create Service User" \
    "6" "Add Exposed Service (HTTP)" \
    "7" "Open Shell" \
    "8" "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) show_ngrok_url ;;
        2) show_services ;;
        3) change_password ;;
        4) install_ngrok_token ;;
        5) create_service_user ;;
        6) add_ngrok_service ;;
        7) clear; echo "Dropping to shell. Type 'exit' to log out, or '/root/dashboard.sh' to return to menu."; break ;;
        8) clear; exit 0 ;;
        *) break ;;
    esac
done
