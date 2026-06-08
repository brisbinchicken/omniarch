#!/usr/bin/env bash
# OmniArch - Interactive Arch Linux Post-Install & Dotfile Manager
# This script is designed to be executed via: curl -sL <url> | bash

set -e

# Error handling
trap 'echo -e "\n\e[1;31m[ERROR]\e[0m An error occurred on line $LINENO. Exiting."; exit 1' ERR

# Vibrant colours for output
RED='\e[1;31m'
GREEN='\e[1;32m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
MAGENTA='\e[1;35m'
YELLOW='\e[1;33m'
RESET='\e[0m'

# Phase 1: The Bootstrap (Running in memory)

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR]${RESET} Please do not run this script as root. Sudo will be used where necessary."
    exit 1
fi

echo -e "${CYAN}[INFO]${RESET} Checking for internet connectivity..."
if ! ping -c 1 archlinux.org -W 5 &> /dev/null; then
    echo -e "${RED}[ERROR]${RESET} No internet connection. Please check your network and try again."
    exit 1
fi

echo -e "${CYAN}[INFO]${RESET} Ensuring git and base-devel are installed..."
sudo pacman -S --needed --noconfirm git base-devel

REPO_URL="https://github.com/brisbinchicken/omniarch.git"
CLONE_DIR="$HOME/.omniarch"

if [ -d "$CLONE_DIR" ]; then
    echo -e "${CYAN}[INFO]${RESET} OmniArch directory already exists. Pulling latest changes..."
    cd "$CLONE_DIR"
    git pull origin main
else
    echo -e "${CYAN}[INFO]${RESET} Cloning OmniArch repository..."
    git clone "$REPO_URL" "$CLONE_DIR"
    cd "$CLONE_DIR"
fi

# Transition execution: The script should now source or call functions from the cloned ~/.omniarch directory.
# This ensures it has access to local files. We use an environment variable to prevent an infinite loop.
if [[ "$OMNIARCH_LOCAL_EXEC" != "1" ]]; then
    export OMNIARCH_LOCAL_EXEC=1
    echo -e "${MAGENTA}[INFO]${RESET} Transitioning execution to the cloned local repository..."
    exec bash "$CLONE_DIR/setup.sh"
fi

# Phase 2: Dependency Fulfillment

if ! command -v yay &> /dev/null; then
    echo -e "${YELLOW}[INFO]${RESET} yay not found. Building and installing yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd "$CLONE_DIR"
    rm -rf /tmp/yay
fi

echo -e "${CYAN}[INFO]${RESET} Ensuring gum is installed for the UI..."
yay -S --needed --noconfirm gum

# Phase 3: Package Arrays

CORE_PKGS=(btrfs-progs btrfs-assistant snapper snap-pac fwupd downgrade reflector)
CLI_PKGS=(btop fastfetch bat duf oh-my-posh-bin tldr trash-cli)
IT_NET_PKGS=(rustdesk-bin filezilla openssh wireguard-tools dnsmasq nmap bind)
DESKTOP_PKGS=(plasma-desktop breeze-gtk ttf-cascadia-code-nerd dolphin konsole spectacle)

# Phase 4: The Interactive UI (using gum)

clear
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 60 --margin "1 2" --padding "1 4" \
    "OmniArch Setup" "Interactive Arch Linux Post-Install"

echo -e "${CYAN}Please select the categories you wish to install or customise:${RESET}"

SELECTIONS=$(gum choose --no-limit --cursor-prefix "[ ] " --selected-prefix "[x] " --unselected-prefix "[ ] " \
    "Core System" \
    "Terminal Utilities" \
    "IT/Networking" \
    "Desktop Environment" \
    "Apply Custom Dotfiles")

# If the user pressed Esc or selected nothing
if [ -z "$SELECTIONS" ]; then
    echo -e "${YELLOW}[INFO]${RESET} No options selected. Exiting."
    exit 0
fi

INSTALL_LIST=()
APPLY_DOTFILES=0

while IFS= read -r choice; do
    case "$choice" in
        "Core System")
            INSTALL_LIST+=("${CORE_PKGS[@]}")
            ;;
        "Terminal Utilities")
            INSTALL_LIST+=("${CLI_PKGS[@]}")
            ;;
        "IT/Networking")
            INSTALL_LIST+=("${IT_NET_PKGS[@]}")
            ;;
        "Desktop Environment")
            INSTALL_LIST+=("${DESKTOP_PKGS[@]}")
            ;;
        "Apply Custom Dotfiles")
            APPLY_DOTFILES=1
            ;;
    esac
done <<< "$SELECTIONS"

# Phase 5: Execution & Dotfile Symlinking

if [ ${#INSTALL_LIST[@]} -gt 0 ]; then
    echo -e "${MAGENTA}[INFO]${RESET} Installing selected packages..."
    
    # Refresh sudo timestamp so makepkg doesn't prompt for a password inside gum spin
    sudo -v
    
    # Use gum spin to provide a loading spinner
    gum spin --spinner dot --title "Installing packages with yay..." -- yay -S --needed --noconfirm "${INSTALL_LIST[@]}"
    
    echo -e "${GREEN}[SUCCESS]${RESET} Packages installed successfully!"
fi

if [ "$APPLY_DOTFILES" -eq 1 ]; then
    echo -e "${CYAN}[INFO]${RESET} Applying custom dotfiles..."
    
    # Backup and symlink .bashrc
    if [ -f "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ]; then
        echo -e "${YELLOW}[INFO]${RESET} Backing up existing .bashrc to .bashrc.bak"
        mv "$HOME/.bashrc" "$HOME/.bashrc.bak"
    fi
    ln -sf "$CLONE_DIR/configs/.bashrc" "$HOME/.bashrc"
    
    # Fastfetch config
    mkdir -p "$HOME/.config/fastfetch"
    if [ -f "$HOME/.config/fastfetch/config.jsonc" ] && [ ! -L "$HOME/.config/fastfetch/config.jsonc" ]; then
        echo -e "${YELLOW}[INFO]${RESET} Backing up existing fastfetch config to config.jsonc.bak"
        mv "$HOME/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc.bak"
    fi
    ln -sf "$CLONE_DIR/configs/fastfetch.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    
    echo -e "${GREEN}[SUCCESS]${RESET} Dotfiles applied successfully!"
fi

echo -e "${GREEN}[SUCCESS]${RESET} OmniArch setup is complete! Please restart your terminal or log out and back in to realise all changes."
