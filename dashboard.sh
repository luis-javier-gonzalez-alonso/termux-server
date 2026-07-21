#!/bin/sh

#!/bin/sh

while true; do
    CHOICE=$(whiptail --title "Termux Server Dashboard" --menu "Choose an option" 0 0 0 \
    "1" "Ngrok Manager" \
    "2" "Script Runner (tmux)" \
    "3" "JSON Object Storage" \
    "4" "Open Shell" \
    "5" "Exit to Termux" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) sh /usr/local/share/termux-server/tools/ngrok-manager/ngrok.sh ;;
        2) sh /usr/local/share/termux-server/tools/script-runner/runner.sh ;;
        3) sh /usr/local/share/termux-server/tools/json-store/runner.sh ;;
        4) clear; echo "Dropping to shell. Type 'exit' to log out, or '/usr/local/bin/dashboard.sh' to return to menu."; break ;;
        5) clear; kill -9 $PPID ;;
        *) break ;;
    esac
done
