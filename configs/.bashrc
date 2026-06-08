# ~/.bashrc
# Customised for OmniArch

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Custom aliases
# Note: CLI flags use US spelling 'color', but UI references use Aus English 'colours'.
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -laF'
alias la='ls -A'
alias l='ls -CF'

# Package management aliases
alias update='yay -Syu'
alias install='yay -S'
alias remove='yay -Rns'
alias search='yay -Ss'
alias clean='yay -Sc'

# Terminal utilities
if command -v bat &> /dev/null; then
    alias cat='bat'
fi

# Oh My Posh initialisation (if installed)
if command -v oh-my-posh &> /dev/null; then
    eval "$(oh-my-posh init bash)"
fi

# Run fastfetch on terminal startup (if installed)
if command -v fastfetch &> /dev/null; then
    fastfetch
fi
