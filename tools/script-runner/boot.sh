#!/bin/sh

STARTUP_FILE="/usr/local/share/termux-server/tools/script-runner/startup.list"

if [ -f "$STARTUP_FILE" ]; then
    while IFS='|' read -r sname field2 field3 || [ -n "$sname" ]; do
        if [ -n "$sname" ]; then
            if [ -z "$field3" ]; then
                dir="/root"
                cmd="$field2"
            else
                dir="$field2"
                cmd="$field3"
            fi
            
            if ! tmux has-session -t "$sname" 2>/dev/null; then
                tmux new-session -d -c "$dir" -s "$sname" "$cmd; echo ''; echo '--- Process Exited ---'; echo 'Press Enter to close...'; read r"
                echo "Started Script Runner session: $sname"
            fi
        fi
    done < "$STARTUP_FILE"
fi
