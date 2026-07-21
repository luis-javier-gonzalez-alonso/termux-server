#!/bin/sh

#!/bin/sh

DIR="$(cd "$(dirname "$0")" && pwd)"

while true; do
    CHOICE=$(whiptail --title "Termux Server Dashboard" --menu "Choose an option" 0 0 0 \
    "1" "Deploy App from GitHub" \
    "2" "Script Runner (tmux)" \
    "3" "JSON Object Storage" \
    "4" "Ngrok Manager" \
    "5" "Open Shell" \
    "6" "Exit to Termux" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) sh "$DIR/tools/app-installer/installer.sh" ;;
        2) sh "$DIR/tools/script-runner/runner.sh" ;;
        3) sh "$DIR/tools/json-store/runner.sh" ;;
        4) sh "$DIR/tools/ngrok-manager/ngrok.sh" ;;
        5) clear; echo "Dropping to proot alpine shell..."; proot-distro login alpine --isolated; break ;;
        6) clear; kill -9 $PPID 2>/dev/null || exit 0 ;;
        *) break ;;
    esac
done
