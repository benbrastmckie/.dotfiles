if status is-interactive
    # Commands to run in interactive sessions can go here
    # Disable fish greeting
    set fish_greeting
end

# WezTerm shell integration - update cwd
if set -q WEZTERM_PANE
    function __wezterm_osc7 --on-variable PWD
        printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
    end
    # Send initial cwd
    __wezterm_osc7
end

# removes the mapping <C-t> which is being used to close the terminal in NeoVim
bind --erase --all \ct

fish_config prompt choose scales

set -x EDITOR nvim

# Lean compilation parallelism (optimal for 12-core Ryzen AI 9 HX 370)
# Limits lake/lean parallelism to reduce thermal load during builds
# See: specs/40_investigate_laptop_high_fan_optimize_system
set -gx LEAN_NUM_THREADS 8

# runs zoxide if installed
if type -q zoxide
zoxide init fish --cmd cd | source
end

# runs fastfetch if installed
if type -q fastfetch
fastfetch
end
