#!/bin/sh

STATE_DIR="$HOME/.termux-server"
APPS_DIR="$STATE_DIR/apps"
STARTUP_FILE="$STATE_DIR/startup.list"

mkdir -p "$APPS_DIR"

URL=$(whiptail --inputbox "Enter the GitHub Repository URL to clone:" 0 0 "https://github.com/username/repo" --title "Deploy App from GitHub" 3>&1 1>&2 2>&3)
if [ -z "$URL" ] || [ "$URL" = "https://github.com/username/repo" ]; then return 0 2>/dev/null || exit 0; fi

# Extract repo name
REPO_NAME=$(basename -s .git "$URL")

APP_DIR="$APPS_DIR/$REPO_NAME"

if [ -d "$APP_DIR" ]; then
    if ! whiptail --yesno "App directory '$REPO_NAME' already exists. Do you want to delete it and clone fresh?" 0 0 --title "App Exists"; then
        return 0 2>/dev/null || exit 0
    fi
    rm -rf "$APP_DIR"
fi

# Clone the repo natively
# Ensure git is installed on host
if ! command -v git >/dev/null 2>&1; then
    whiptail --msgbox "Git is not installed natively in Termux. Please run 'pkg install git' first." 0 0
    return 0 2>/dev/null || exit 0
fi

if ! git clone "$URL" "$APP_DIR"; then
    whiptail --msgbox "Failed to clone repository. Please check the URL and your internet connection." 0 0
    return 0 2>/dev/null || exit 0
fi

# Detect dependencies
DEP_MSG="Cloned successfully into $APP_DIR.\n\n"
INSTALL_CMD=""

if [ -f "$APP_DIR/package.json" ]; then
    DEP_MSG="${DEP_MSG}Found package.json. Will install Node.js dependencies.\n"
    INSTALL_CMD="cd '$APP_DIR' && npm install --no-audit --no-fund --silent"
elif [ -f "$APP_DIR/requirements.txt" ]; then
    DEP_MSG="${DEP_MSG}Found requirements.txt. Will install Python dependencies.\n"
    INSTALL_CMD="cd '$APP_DIR' && pip install -r requirements.txt --break-system-packages"
else
    DEP_MSG="${DEP_MSG}No auto-detectable dependencies found.\n"
fi

whiptail --msgbox "$DEP_MSG" 0 0

if [ -n "$INSTALL_CMD" ]; then
    whiptail --msgbox "Installing dependencies now... This might take a while. Press OK to begin." 0 0
    # Run the install inside Alpine
    proot-distro login alpine --isolated -- /bin/sh -c "$INSTALL_CMD"
    whiptail --msgbox "Dependencies installed!" 0 0
fi

# Prompt for start command
START_CMD=$(whiptail --inputbox "Enter the command to start the app (e.g. 'npm start' or 'python3 main.py'):" 0 0 "" --title "Start Command" 3>&1 1>&2 2>&3)
if [ -z "$START_CMD" ]; then
    whiptail --msgbox "App installed but not added to autostart because no start command was provided." 0 0
    return 0 2>/dev/null || exit 0
fi

SNAME=$(whiptail --inputbox "Enter a unique session name for this app (no spaces):" 0 0 "$REPO_NAME" --title "Session Name" 3>&1 1>&2 2>&3)
if [ -z "$SNAME" ]; then SNAME="$REPO_NAME"; fi

if whiptail --yesno "Run this app automatically on server startup?" 0 0 --title "Startup Config"; then
    if [ -f "$STARTUP_FILE" ]; then
        grep -v "^$SNAME|" "$STARTUP_FILE" > "${STARTUP_FILE}.tmp"
        mv "${STARTUP_FILE}.tmp" "$STARTUP_FILE"
    fi
    echo "$SNAME|$APP_DIR|$START_CMD" >> "$STARTUP_FILE"
    whiptail --msgbox "App added to startup sequence!" 0 0
fi

if whiptail --yesno "Start the app now?" 0 0 --title "Start App"; then
    tmux new-session -d -c "$APP_DIR" -s "$SNAME" "proot-distro login alpine --isolated -- /bin/sh -c 'cd \"\$1\" && eval \"\$2\"' _ \"$APP_DIR\" \"$START_CMD\"; echo ''; echo '--- Process Exited ---'; echo 'Press Enter to close...'; read r"
    whiptail --msgbox "App '$SNAME' started successfully.\nYou can attach to it from the Script Runner menu." 0 0
fi
