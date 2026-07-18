# Termux Android Server Setup

This repository contains a set of scripts to transform an Android phone running Termux into an isolated Ubuntu Linux server accessible over the internet via SSH, complete with a graphical TUI dashboard.

## Overview

The setup relies on `proot-distro` to install a real Ubuntu filesystem inside Termux. This means:
- **No root access required** on your Android device.
- You get a standard Linux environment (`apt`, `systemd` alternatives, standard file paths).
- Your actual Android system files remain safe and untouched.

## Prerequisites

1. Install **Termux** from F-Droid (do not use the Google Play version, it is outdated).
2. Ensure your phone is connected to the internet.
3. (Optional but recommended) Sign up for a free [Ngrok](https://ngrok.com/) account to get an Authtoken. This is required to access your server over the internet via a TCP tunnel.

## Installation

1. Open Termux on your Android phone.
2. Clone or copy this repository into Termux.
   ```bash
   pkg install git
   git clone <repository_url> termux-server
   cd termux-server
   ```
3. Make the scripts executable:
   ```bash
   chmod +x install.sh start-server.sh
   ```
4. Run the installer:
   ```bash
   ./install.sh
   ```
   *This process will take a few minutes as it downloads and extracts the Ubuntu filesystem, and installs dependencies like OpenSSH, Ngrok, and Whiptail.*

## Starting the Server

To start the server environment (which boots up SSH and Ngrok):

```bash
./start-server.sh
```

## Accessing the Dashboard

Once the Ubuntu environment is set up and started, you can drop into the isolated server shell at any time by running:

```bash
proot-distro login ubuntu
```

Upon logging in, you will be greeted by the **Termux Server Dashboard**. From this TUI you can:
- Configure your Ngrok Authtoken.
- View your remote SSH Connection details.
- See which services are running.
- Change the root password (default is `admin`).
- Drop to a standard bash shell.

## Remote SSH Access

Once your Ngrok tunnel is running, you can access your phone remotely from any computer:
```bash
ssh root@<ngrok-host> -p <ngrok-port>
```
When prompted for a password, enter `admin` (or the password you changed it to).
