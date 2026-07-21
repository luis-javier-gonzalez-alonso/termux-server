#!/bin/sh

STARTUP_FILE="/usr/local/share/termux-server/tools/script-runner/startup.list"

if [ -f "$STARTUP_FILE" ]; then
    while IFS='|' read -r sname cmd || [ -n "$sname" ]; do
        if [ -n "$sname" ]; then
            if ! tmux has-session -t "$sname" 2>/dev/null; then
                tmux new-session -d -s "$sname" "$cmd"
                echo "Started Script Runner session: $sname"
            fi
        fi
    done < "$STARTUP_FILE"
fi
