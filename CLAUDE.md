# Claude Assistant Guidelines

## Accessing Program Documentation

When configuring programs, always try these methods first before searching online:

### 1. Built-in Help Commands
Most programs provide immediate documentation access:

```bash
# General help
program --help
program -h
program help

# Specific command help
program subcommand --help
program help subcommand
```

### 2. Man Pages
Traditional Unix documentation:

```bash
# View man page
man program

# Search man pages by keyword
man -k keyword
apropos keyword

# Check all sections (1-8)
man -a program
```

### 3. Info Pages
GNU programs often have detailed info documentation:

```bash
# View info page
info program

# Search info pages
info --apropos=keyword
```

### 4. Program-Specific Documentation Commands

#### WezTerm
```bash
# Show all available commands
wezterm --help

# Show current key bindings in Lua format
wezterm show-keys --lua

# Show font information
wezterm ls-fonts

# Generate shell completions
wezterm shell-completion --shell bash
```

#### Neovim/Vim
```bash
# View help from command line
nvim -c "help config" -c "only"

# Inside editor
:help           # General help
:help option    # Specific option
:helpgrep term  # Search help
```

#### Git
```bash
# Built-in help
git help config
git config --help

# List all available commands
git help -a

# Show guides
git help -g
```

#### Systemd Services
```bash
# View service documentation
systemctl help service-name
man systemd.service
man systemd.unit
```

#### Package Managers
```bash
# Nix
nix --help
nix search --help
man nix.conf
man configuration.nix

# Apt/Dpkg
apt-get help
man apt
man dpkg

# DNF/YUM
dnf help
man dnf
```

### 5. Configuration File Documentation

Many programs document their config options in:

```bash
# Example config files
ls /usr/share/doc/program/examples/
ls /etc/program/

# Comments in default configs
cat /etc/program/program.conf.example

# Dedicated config man pages
man program.conf
man 5 program  # Section 5 is for config files
```

### 6. Built-in Documentation Viewers

Some programs have internal documentation systems:

```bash
# Python modules
python -c "import module; help(module)"
pydoc module

# Ruby gems  
ri ClassName
ri method_name

# Perl modules
perldoc Module::Name
```

### 7. Generate Sample Configurations

Many programs can output their default configuration:

```bash
# Generate default config
program --dump-config
program --print-defaults
program config dump

# WezTerm example
wezterm show-keys --lua > default-keys.lua
```

### 8. Version-Specific Documentation

Always check version for accurate docs:

```bash
program --version
program -V
program version
```

### 9. List Available Options

Some programs can list all their options:

```bash
# Common patterns
program --list-options
program --show-options
program config list
```

### 10. Tab Completion

Use shell completion to discover options:

```bash
# Enable completions (if available)
program completion bash
program shell-completion --shell bash

# Then use Tab to explore
program <TAB><TAB>
program --<TAB><TAB>
```

## Priority Order for Documentation

1. **Built-in help** (`--help`) - Always try first
2. **Man pages** (`man program`) - Comprehensive Unix docs  
3. **Program-specific commands** (like `wezterm show-keys`)
4. **Example configs** in `/usr/share/doc/` or `/etc/`
5. **Info pages** for GNU programs
6. **Version-specific online docs** - Only if above methods fail

## Tips

- Always check the program version first to ensure documentation matches
- Many programs accept both `--help` and `help` subcommand formats
- Config file formats often have their own man pages in section 5
- Use `which program` or `whereis program` to locate binaries and associated files
- Check `~/.config/program/` for user-specific configs with comments
- Some programs auto-generate config with `program init` or similar

## Common Config Locations

```bash
# User configs
~/.config/program/
~/.program/
~/.programrc

# System configs  
/etc/program/
/usr/local/etc/program/
/opt/program/etc/
```

Remember: Exhausting local documentation before going online ensures accuracy for the specific version installed and reduces errors from outdated web resources.