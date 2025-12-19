if status is-interactive
    # Commands to run in interactive sessions can go here
    # Disable fish greeting
    set fish_greeting
end

# removes the mapping <C-t> which is being used to close the terminal in NeoVim
bind --erase --all \ct

fish_config prompt choose scales

set -x EDITOR nvim

# runs zoxide if installed
if type -q zoxide
zoxide init fish --cmd cd | source
end

# runs neofetch if installed
if type -q neofetch
neofetch
end
