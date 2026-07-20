#!/bin/sh

STARTUP_FILE="/usr/local/share/termux-server/tools/script-runner/startup.list"

start_script() {
    SNAME=$(whiptail --inputbox "Enter a name for this session (no spaces):" 0 0 --title "Start Script" 3>&1 1>&2 2>&3)
    if [ -z "$SNAME" ]; then return; fi
    
    # Remove spaces just in case
    SNAME=$(echo "$SNAME" | tr -d ' ')
    
    CMD=$(whiptail --inputbox "Enter the command to run:" 0 0 --title "Start Script" 3>&1 1>&2 2>&3)
    if [ -z "$CMD" ]; then return; fi

    if whiptail --yesno "Run this script automatically on server startup?" 0 0 --title "Startup Config"; then
        mkdir -p /usr/local/share/termux-server/tools/script-runner
        # Remove old entry if exists to avoid duplicates
        if [ -f "$STARTUP_FILE" ]; then
            grep -v "^$SNAME|" "$STARTUP_FILE" > "${STARTUP_FILE}.tmp"
            mv "${STARTUP_FILE}.tmp" "$STARTUP_FILE"
        fi
        echo "$SNAME|$CMD" >> "$STARTUP_FILE"
        whiptail --msgbox "Added to startup sequence!" 0 0
    fi
    
    tmux new-session -d -s "$SNAME" "$CMD"
    whiptail --msgbox "Session '$SNAME' started successfully.\nYou can attach to it from the menu." 0 0
}

view_scripts() {
    SESSIONS=$(tmux ls 2>/dev/null)
    if [ -z "$SESSIONS" ]; then
        whiptail --msgbox "No active scripts found." 0 0
    else
        whiptail --scrolltext --msgbox "Active Sessions:\n\n$SESSIONS" 0 0
    fi
}

attach_script() {
    SESSIONS=$(tmux ls -F "#{session_name}" 2>/dev/null)
    if [ -z "$SESSIONS" ]; then
        whiptail --msgbox "No active scripts found." 0 0
        return
    fi
    
    set --
    for s in $SESSIONS; do
        set -- "$@" "$s" "Active"
    done
    
    CHOICE=$(whiptail --title "Attach to Session" --menu "Select a session to attach:" 0 0 0 "$@" 3>&1 1>&2 2>&3)
    
    if [ ! -z "$CHOICE" ]; then
        whiptail --msgbox "You are about to attach to '$CHOICE'.\n\nREMEMBER: To detach and keep it running, press:\nCtrl+b, then d" 0 0
        clear
        tmux attach-session -t "$CHOICE"
    fi
}

kill_script() {
    SESSIONS=$(tmux ls -F "#{session_name}" 2>/dev/null)
    if [ -z "$SESSIONS" ]; then
        whiptail --msgbox "No active scripts found." 0 0
        return
    fi
    
    set --
    for s in $SESSIONS; do
        set -- "$@" "$s" "Active"
    done
    
    CHOICE=$(whiptail --title "Kill Session" --menu "Select a session to kill:" 0 0 0 "$@" 3>&1 1>&2 2>&3)
    
    if [ ! -z "$CHOICE" ]; then
        tmux kill-session -t "$CHOICE"
        
        # Optionally remove from startup
        if [ -f "$STARTUP_FILE" ]; then
            if grep -q "^$CHOICE|" "$STARTUP_FILE"; then
                if whiptail --yesno "Also remove '$CHOICE' from startup sequence?" 0 0; then
                    grep -v "^$CHOICE|" "$STARTUP_FILE" > "${STARTUP_FILE}.tmp"
                    mv "${STARTUP_FILE}.tmp" "$STARTUP_FILE"
                    whiptail --msgbox "Removed from startup sequence." 0 0
                fi
            fi
        fi
        
        whiptail --msgbox "Session '$CHOICE' killed." 0 0
    fi
}

while true; do
    CHOICE=$(whiptail --title "Script Runner (tmux)" --menu "Choose an option" 0 0 0 \
    "1" "Start New Script" \
    "2" "View Active Scripts" \
    "3" "Attach to Script Session" \
    "4" "Kill Script Session" \
    "5" "Back to Tools Menu" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) start_script ;;
        2) view_scripts ;;
        3) attach_script ;;
        4) kill_script ;;
        5) break ;;
        *) break ;;
    esac
done
