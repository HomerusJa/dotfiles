# =============================================================================
# ~/.zshrc
# Zsh interactive shell configuration.
#
# Design principles:
#   - Plugins installed via pacman, sourced directly (no plugin manager)
#   - No Oh My Zsh — avoids startup lag and unnecessary abstraction
#   - Bash kept for scripts; Zsh for interactive use only
# =============================================================================

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS   # Don't record duplicate consecutive commands
setopt HIST_IGNORE_SPACE  # Don't record commands prefixed with a space
setopt SHARE_HISTORY      # Share history across all open Zsh sessions

# ── Completion ────────────────────────────────────────────────────────────────
# zsh-completions adds extra definitions to fpath — must be done before compinit
fpath+=(/usr/share/zsh/site-functions)
autoload -Uz compinit && compinit

# ── Plugins ───────────────────────────────────────────────────────────────────
# Installed via pacman; sourced directly.
# Ref: https://wiki.archlinux.org/title/Zsh#Fish-like_syntax_highlighting_and_autosuggestions

# Fish-like history-based suggestions as you type
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Real-time syntax highlighting (must be sourced last among plugins)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ── Environment Variables ─────────────────────────────────────────────────────
# Prevent duplicate entries in PATH if the shell is re-sourced
typeset -U path PATH

# Prepend custom binary directories to the path array
path=(
  "$HOME/.local/bin"  # Where uv-installed tools and other user binaries go
  "$HOME/.cargo/bin"  # Rust toolchain binaries
  $path
)
export PATH

# ── Modern CLI tool integrations ──────────────────────────────────────────────

# zoxide: smarter cd — learns frecency, jump with partial names
# Ref: https://github.com/ajeetdsouza/zoxide
eval "$(zoxide init zsh)"

# fzf: fuzzy finder — overrides Ctrl+R (history) and Ctrl+T (file find)
# Ref: https://github.com/junegunn/fzf
source <(fzf --zsh)

# ── Aliases ───────────────────────────────────────────────────────────────────
# eza replaces ls — color-coded, Git status markers, explicit grouping
# Don't use --color=always to allow piping to other tools without ANSI codes
# Ref: https://github.com/eza-community/eza
alias ls="eza --color=auto --group-directories-first"
alias ll="eza -la --color=auto --group-directories-first --git"
alias tree="eza --tree --color=auto"

# bat replaces cat — syntax highlighting, Git diff integration
# Ref: https://github.com/sharkdp/bat
alias cat="bat --pager=never"

# ── Starship prompt ───────────────────────────────────────────────────────────
# Must be last line — initializes the prompt engine
# Config: ~/.config/starship.toml
# Ref: https://starship.rs
eval "$(starship init zsh)"
