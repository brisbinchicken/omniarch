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
    echo -e "${YELLOW}[INFO]${RESET} yay not found. Building and installing yay-bin..."
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin
    makepkg -si --noconfirm
    cd "$CLONE_DIR"
    rm -rf /tmp/yay-bin
fi

echo -e "${CYAN}[INFO]${RESET} Ensuring gum is installed for the UI..."
yay -S --needed --noconfirm gum

# Phase 3: Package List Validation

# We now read from pkglist.txt directly. Let's just ensure the file exists.
PKG_LIST_FILE="$CLONE_DIR/configs/pkglist.txt"
if [ ! -f "$PKG_LIST_FILE" ]; then
    echo -e "${RED}[ERROR]${RESET} $PKG_LIST_FILE not found. Cannot proceed with package installation."
    exit 1
fi

# Phase 4: The Interactive UI (using gum)

clear
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 60 --margin "1 2" --padding "1 4" \
    "OmniArch Setup" "Interactive Arch Linux Post-Install"

echo -e "${CYAN}Please select the categories you wish to install or customise:${RESET}"

SELECTIONS=$(gum choose --no-limit --cursor-prefix "[ ] " --selected-prefix "[x] " --unselected-prefix "[ ] " \
    "Install Packages from pkglist.txt" \
    "Apply Custom Dotfiles")

# If the user pressed Esc or selected nothing
if [ -z "$SELECTIONS" ]; then
    echo -e "${YELLOW}[INFO]${RESET} No options selected. Exiting."
    exit 0
fi

INSTALL_PACKAGES=0
APPLY_DOTFILES=0

while IFS= read -r choice; do
    case "$choice" in
        "Install Packages from pkglist.txt")
            INSTALL_PACKAGES=1
            ;;
        "Apply Custom Dotfiles")
            APPLY_DOTFILES=1
            ;;
    esac
done <<< "$SELECTIONS"

# Phase 5: Execution & Dotfile Symlinking

if [ "$INSTALL_PACKAGES" -eq 1 ]; then
    echo -e "${MAGENTA}[INFO]${RESET} Installing applications from pkglist.txt..."
    
    # Refresh sudo timestamp so makepkg doesn't prompt for a password inside gum spin
    echo -e "${MAGENTA}[INFO]${RESET} Authenticating to proceed with package installation..."
    sudo -v
    
    # Start a sudo keep-alive loop in the background to prevent timeouts during long builds
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    
    echo -e "${CYAN}[INFO]${RESET} Installing applications... (Native progress bars will be shown)"
    mapfile -t PKG_ARRAY < "$CLONE_DIR/configs/pkglist.txt"
    yay -S --needed --noconfirm "${PKG_ARRAY[@]}"
    
    echo -e "${GREEN}[SUCCESS]${RESET} Applications installed successfully!"
fi

if [ "$APPLY_DOTFILES" -eq 1 ]; then
    echo -e "${CYAN}[INFO]${RESET} Applying custom dotfiles..."
    
    # Backup and symlink .bashrc
    if [ -f "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ]; then
        echo -e "${YELLOW}[INFO]${RESET} Backing up existing .bashrc to .bashrc.bak"
        mv "$HOME/.bashrc" "$HOME/.bashrc.bak"
    fi
    ln -sf "$CLONE_DIR/configs/.bashrc" "$HOME/.bashrc"
    

    
    echo -e "${GREEN}[SUCCESS]${RESET} Dotfiles applied successfully!"
fi

# Phase 6: Apply Desktop Customisations

if [ "$APPLY_DOTFILES" -eq 1 ]; then
    echo -e "${CYAN}[INFO]${RESET} Applying KDE desktop customisations..."
    
    # Create necessary target directories
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local/share/plasma/look-and-feel"
    mkdir -p "$HOME/.local/share/icons"
    mkdir -p "$HOME/.local/share/fonts"
    mkdir -p "$HOME/Pictures"

    # Fastfetch config
    if [ -f "$CLONE_DIR/configs/fastfetch/config.jsonc" ]; then
        mkdir -p "$HOME/.config/fastfetch"
        if [ -f "$HOME/.config/fastfetch/config.jsonc" ] && [ ! -L "$HOME/.config/fastfetch/config.jsonc" ]; then
            mv "$HOME/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc.bak"
        fi
        ln -sf "$CLONE_DIR/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    fi

    # Symlink kdeglobals
    if [ -f "$HOME/.config/kdeglobals" ] && [ ! -L "$HOME/.config/kdeglobals" ]; then
        mv "$HOME/.config/kdeglobals" "$HOME/.config/kdeglobals.bak"
    fi
    ln -sf "$CLONE_DIR/configs/kde/config/kdeglobals" "$HOME/.config/kdeglobals"

    # Symlink konsolerc
    if [ -f "$HOME/.config/konsolerc" ] && [ ! -L "$HOME/.config/konsolerc" ]; then
        mv "$HOME/.config/konsolerc" "$HOME/.config/konsolerc.bak"
    fi
    ln -sf "$CLONE_DIR/configs/kde/config/konsolerc" "$HOME/.config/konsolerc"

    # Symlink Look and Feel
    if [ -d "$CLONE_DIR/configs/kde/look-and-feel/Kaze-dark" ]; then
        rm -rf "$HOME/.local/share/plasma/look-and-feel/Kaze-dark"
        ln -sfn "$CLONE_DIR/configs/kde/look-and-feel/Kaze-dark" "$HOME/.local/share/plasma/look-and-feel/Kaze-dark"
    fi

    # Symlink Icons
    if [ -d "$CLONE_DIR/configs/kde/icons/Kaze-dark" ]; then
        rm -rf "$HOME/.local/share/icons/Kaze-dark"
        ln -sfn "$CLONE_DIR/configs/kde/icons/Kaze-dark" "$HOME/.local/share/icons/Kaze-dark"
    fi

    # Symlink Fonts
    if [ -d "$CLONE_DIR/configs/kde/fonts" ]; then
        for font in "$CLONE_DIR/configs/kde/fonts"/*; do
            [ -e "$font" ] || continue
            base_font=$(basename "$font")
            rm -rf "$HOME/.local/share/fonts/$base_font"
            ln -sfn "$font" "$HOME/.local/share/fonts/$base_font"
        done
        # Refresh font cache
        if command -v fc-cache &> /dev/null; then
            fc-cache -f "$HOME/.local/share/fonts"
        fi
    fi

    # Handle PWAs
    if [ -d "$CLONE_DIR/configs/pwas" ]; then
        mkdir -p "$HOME/.local/share/applications"
        for pwa in "$CLONE_DIR/configs/pwas"/*.desktop; do
            [ -e "$pwa" ] || continue
            base_pwa=$(basename "$pwa")
            ln -sf "$pwa" "$HOME/.local/share/applications/$base_pwa"
        done
        # Update desktop database so they appear in the app menu
        if command -v update-desktop-database &> /dev/null; then
            update-desktop-database "$HOME/.local/share/applications"
        fi
    fi

    # Handle Wallpaper
    if [ -f "$CLONE_DIR/wallpaper.jpeg" ]; then
        cp "$CLONE_DIR/wallpaper.jpeg" "$HOME/Pictures/wallpaper.jpeg"
        
        # Set wallpaper using the appropriate Plasma 6 command
        if command -v plasma-apply-wallpaperimage &> /dev/null; then
            plasma-apply-wallpaperimage "$HOME/Pictures/wallpaper.jpeg" || true
        else
            kwriteconfig6 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group "Containments" --group "1" --group "Wallpaper" --group "org.kde.image" --group "General" --key "Image" "file://$HOME/Pictures/wallpaper.jpeg" || true
        fi
    fi

    echo -e "${GREEN}[SUCCESS]${RESET} Desktop customisations applied successfully!"

    # Handle SDDM Theme and Config (System-wide, requires sudo)
    if [ -d "$CLONE_DIR/configs/sddm/themes" ]; then
        echo -e "${MAGENTA}[INFO]${RESET} Authenticating to deploy SDDM configuration..."
        sudo -v
        
        gum spin --spinner line --title "Deploying SDDM theme and configuration..." -- bash -c '
            # Copy the theme folder(s) into /usr/share/sddm/themes/
            for theme_dir in "'"$CLONE_DIR"'/configs/sddm/themes/"*; do
                [ -d "$theme_dir" ] || continue
                theme_name=$(basename "$theme_dir")
                sudo cp -r "$theme_dir" /usr/share/sddm/themes/
                sudo chmod -R 755 "/usr/share/sddm/themes/$theme_name"
            done
            
            # Apply the default configuration
            if [ -d "'"$CLONE_DIR"'/configs/sddm/conf" ]; then
                sudo mkdir -p /etc/sddm.conf.d/
                sudo cp -r "'"$CLONE_DIR"'/configs/sddm/conf/"* /etc/sddm.conf.d/
                sudo chmod 644 /etc/sddm.conf.d/*
                
                # Extract deployed theme name and explicitly update Current theme
                theme_name=$(basename "$(ls -d "'"$CLONE_DIR"'/configs/sddm/themes/"*/ | head -n 1)" 2>/dev/null)
                if [ -n "$theme_name" ]; then
                    for conf in /etc/sddm.conf.d/*; do
                        [ -f "$conf" ] && sudo sed -i "s/^Current=.*/Current=$theme_name/" "$conf" 2>/dev/null || true
                    done
                fi
            fi
        '
        echo -e "${GREEN}[SUCCESS]${RESET} SDDM theme and configuration deployed successfully!"
    fi
fi

echo -e "${GREEN}[SUCCESS]${RESET} OmniArch setup is almost complete! Enabling SDDM..."
sudo systemctl enable sddm
echo -e "${GREEN}[SUCCESS]${RESET} OmniArch setup is fully complete! Please restart your system to realise all changes."
