set -gx EDITOR nvim
set fish_greeting

alias cat="bat"
alias find="fd"
alias ls="eza --git --icons --color=always --group-directories-first"
alias la="ls -la"
alias vim="nvim"
alias grep="rg"
alias lg="lazygit"
alias ssh="kitty +kitten ssh"

function yy
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
    builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
