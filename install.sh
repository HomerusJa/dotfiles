#!/usr/bin/env bash
# =============================================================================
# install.sh — Arch Linux dotfiles bootstrap
#
# Idempotent: safe to run multiple times on the same machine.
# Docs & decision log: README.md
#
# Usage:
#   bash install.sh
# =============================================================================

# Explanation: https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -euo pipefail
 
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 
# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo ""; echo "▶ $*"; }
ok()   { echo "  ✓ $*"; }
info() { echo "  · $*"; }
 
echo "════════════════════════════════════════"
echo "  Dotfiles install"
echo "════════════════════════════════════════"
 
# ── 0. Bootstrap: paru ────────────────────────────────────────────────────────
# paru is the AUR helper used for AUR packages.
# Docs: https://github.com/Morganamilo/paru
log "Checking for paru..."
if ! command -v paru &>/dev/null; then
  info "paru not found — building from AUR..."
  sudo pacman -S --needed --noconfirm base-devel git
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi
ok "paru ready"

# ── 1. g14 repo ───────────────────────────────────────────────────────────────
# The g14 repo is maintained by the asus-linux.org team and provides asusctl,
# rog-control-center, and related packages as precompiled binaries.
# Installing asusctl from AUR (e.g. asusctl-git) is explicitly NOT supported.
# The name "g14" is historical — it applies to all ROG laptops.
# Ref: https://asus-linux.org/guides/arch-guide/#repo
log "Setting up g14 repo..."
 
# Add signing key (idempotent — pacman-key is a no-op if key already present)
sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
 
# Add repo to pacman.conf if not already present
if ! grep -q "\[g14\]" /etc/pacman.conf; then
  info "Adding [g14] repo to /etc/pacman.conf..."
  printf '\n[g14]\nServer = https://arch.asus-linux.org\n' | sudo tee -a /etc/pacman.conf
else
  info "[g14] repo already in pacman.conf"
fi
 
# Full system sync after adding new repo (required before installing from it)
sudo pacman -Syu --noconfirm
ok "g14 repo ready"

# ── 2. System packages (pacman) ───────────────────────────────────────────────
# --needed: skip packages already installed (idempotent)
log "Installing system packages..."
PACMAN_PKGS=(
  # Firmware & CPU microcode (AMD — Ryzen 9 5900HX)
  linux-firmware
  amd-ucode         # AMD microcode updates; intel-ucode would be used for Intel CPUs
 
  # Build toolchain — required for Rust crates with C deps, and for makepkg
  base-devel
 
  # ASUS laptop tools (from g14 repo — NOT AUR)
  # asusctl: fan profiles, keyboard RGB, battery charge thresholds
  # Ref: https://asus-linux.org/guides/arch-guide/#asusctl-custom-fan-profiles-anime-led-control-etc
  asusctl
 
  # ROG Control Center: GUI for asusctl (separated into its own package)
  # Ref: https://asus-linux.org/guides/arch-guide/#rog-control-center
  rog-control-center
 
  # power-profiles-daemon: required for asusctl to manage power profiles correctly.
  # Other power management tools (e.g. TLP) conflict with asusctl — do not install them.
  # Ref: https://asus-linux.org/guides/arch-guide/#asusctl-custom-fan-profiles-anime-led-control-etc
  power-profiles-daemon

  # nvidia-laptop-power-cfg: required for proper dGPU power management on Ampere laptops.
  # Provides udev rules and modprobe config for dynamic power gating.
  # This is also on the g14 repo. The guide on asus-linux.org is wrong about that.
  # Ref: https://asus-linux.org/guides/arch-guide/#ampere-architecture-rtx-3000-or-later
  # Ref: https://gitlab.com/asus-linux/nvidia-laptop-power-cfg
  nvidia-laptop-power-cfg
 
  # NVIDIA drivers (RTX 3070 = Ampere architecture)
  # nvidia-open: open-source kernel module, appropriate for Ampere+
  # nvidia-utils: userspace utilities and libraries
  # vulkan-icd-loader: required Vulkan loader
  # Ref: https://asus-linux.org/guides/arch-guide/#ampere-architecture-rtx-3000-or-later
  nvidia-open  # Note: May conflict with nvidia-open-dkms. If that happens, just
               #       confirm that nvidia-open will be installed instead of nvidia-open-dkms.
  nvidia-utils
  vulkan-icd-loader
 
  # Shell stack
  zsh                       # Interactive shell (scripts stay in Bash)
  starship                  # Prompt engine — cross-shell, Rust, fast
  zsh-syntax-highlighting   # Real-time command highlighting
  zsh-autosuggestions       # Fish-like history suggestions
  zsh-completions           # Extra completions for Docker, Git, Node, etc.
  ghostty                   # GPU-accelerated terminal emulator
 
  # Modern CLI replacements
  fzf         # Fuzzy finder — overrides Ctrl+R history search
  zoxide      # Smarter cd — learns frecency
  eza         # ls replacement — color, Git status, tree
  bat         # cat replacement — syntax highlighting, Git diff
  github-cli  # gh: PRs, issues, notifications, and more from terminal
 
  # Dotfile manager
  stow     # Symlink farm manager — see README.md § Dotfile Management
 
  # Rust toolchain manager
  # Will conflict with the rust package which might be installed as a dependency of the
  # paru build process. In that case, just confirm that the rust package will be
  # removed in favor of rustup.
  rustup
 
  # Python tooling
  uv       # Fast Python package/project manager
 
  # Containerization
  podman
  podman-compose
  podman-docker   # Aliases `docker` → `podman`
  crun  # oci-runtime
 
  # System tools
  timeshift        # System backups (rsync mode on Ext4)
  pacman-contrib   # Provides paccache for package cache cleanup
 
  # Fonts
  # Reasoning for each can be found in README.md § Fonts
  noto-fonts
  noto-fonts-emoji
  noto-fonts-cjk
  ttf-liberation
  inter-font
  ttf-firacode-nerd

  # Apps
  keepassxc
  lilypond
  frescobaldi
  obsidian  # TODO: This is a test. Remove if it is not liked after testing.

  # GNOME-related tools
  gnome-browser-connector
)
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
ok "System packages installed"

# TODO: Remove unneeded packages from things like gnome and so on...


# ── 3. AUR packages ───────────────────────────────────────────────────────────
log "Installing AUR packages..."
AUR_PKGS=(
  # Official Microsoft VSCode build — needed for proprietary extensions (Copilot etc.)
  # The open-source 'code' on the Arch repo uses OpenVSX, lacking many extensions.
  visual-studio-code-bin
 
  # Brave browser — Chromium engine, aggressive ad-blocking, native PWA support
  brave-bin
 
  # OneDrive client — selective sync via sync_list, file size filtering
  onedrive-abraunegg

  lunar-client
  discord
)
# --needed: skip packages already installed (idempotent)
# Left out --noconfirm for now.
paru -S --needed "${AUR_PKGS[@]}"
ok "AUR packages installed"

# ── 4. VSCode extensions ─────────────────────────────────────────────────────
log "Installing VSCode extensions..."
VSCODE_EXTS=(
  aaron-bond.better-comments
  catppuccin.catppuccin-vsc
  catppuccin.catppuccin-vsc-icons
  tamasfe.even-better-toml
  astral-sh.ty
  charliermarsh.ruff
  rust-lang.rust-analyzer
  yzhang.markdown-all-in-one
  esbenp.prettier-vscode
)
for ext in "${VSCODE_EXTS[@]}"; do
  code --install-extension "$ext" --force
done
ok "VSCode extensions installed"

# ── 5. Dotfiles via GNU Stow ─────────────────────────────────────────────────
# home/ mirrors ~/ exactly. --restow removes and recreates all symlinks —
# making this idempotent. Docs: https://www.gnu.org/software/stow/
log "Symlinking dotfiles..."
stow --dir="$DOTFILES_DIR" --target="$HOME" --restow home
ok "Dotfiles symlinked to $HOME"

# ── 6. Shell: set Zsh as default ─────────────────────────────────────────────
log "Setting Zsh as default shell..."
ZSH_PATH="$(which zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
  fi
  chsh -s "$ZSH_PATH"
  ok "Default shell changed to Zsh (takes effect on next login)"
else
  ok "Zsh already the default shell"
fi

# ── 7. Rust toolchain ────────────────────────────────────────────────────────
log "Setting up Rust toolchain..."
rustup default stable
ok "Rust stable toolchain active"
 
# ── 8. Python tooling via uv ─────────────────────────────────────────────────
log "Installing Python tools via uv..."
uv tool install ruff
uv tool install ty
ok "ruff and ty installed"

# ── 9. Systemd services ──────────────────────────────────────────────────────
log "Enabling system services..."
 
# power-profiles-daemon: required by asusctl for power profile management
sudo systemctl enable --now power-profiles-daemon.service
ok "power-profiles-daemon enabled"
 
# NOTE: asusd is intentionally NOT enabled here.
# It is triggered automatically by a udev rule once the keyboard driver is ready.
# Manually enabling it can cause race conditions.
# Ref: https://asus-linux.org/guides/arch-guide/#asusctl-custom-fan-profiles-anime-led-control-etc
info "asusd: NOT enabled (started automatically via udev — this is correct)"
 
# NVIDIA power management services (Ampere — RTX 3070)
# These handle GPU state across suspend, hibernate, and resume.
# Ref: https://asus-linux.org/guides/arch-guide/#next-steps
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
sudo systemctl enable --now nvidia-powerd
ok "NVIDIA power management services enabled"
 
# Weekly pacman package cache cleanup (keeps last 3 versions per package)
sudo systemctl enable --now paccache.timer
ok "paccache.timer enabled"
 
log "Enabling user services..."
 
# OneDrive continuous sync daemon (runs as current user, not root)
systemctl --user enable --now onedrive
ok "onedrive user service enabled"

# ── 10. Post-install summary ─────────────────────────────────────────────────
cat <<'EOF'
 
════════════════════════════════════════════════════════
  ✅  install.sh complete — reboot now
════════════════════════════════════════════════════════

After the reboot, follow the instructions in the README.md to finish the setup.
EOF
