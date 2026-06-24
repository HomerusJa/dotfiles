# Dotfiles
 
Personal Arch Linux configuration for an ASUS ROG Strix G17 G713 (Ryzen 9 5900HX, RTX 3070).
Windows dual boot retained for Fusion 360 and other Windows-only software.
Every decision is documented here with rationale, tradeoffs, and links.
 
## Setup Workflow

1. Install Arch via archinstall (dual boot, see below)
2. git clone <this repo> ~/dotfiles
3. `cd ~/dotfiles && bash install.sh` (Needed the first time. After that, use the
   `,install_dotfiles` alias.)
4. Work through the manual steps printed at the end
 
`install.sh` is fully idempotent — safe to re-run at any time to sync a machine to
the current state of this repo.

## TODOs

- [ ] Make themes work with Zen
- [ ] Dual boot bluetooth setup
- [ ] Maybe explicitly add audio (pipewire and so on) to dotfiles?
- [ ] Maybe explicitly add printing to dotfiles?
- [ ] Gnome Extensions setup complete?
- [ ] In the archinstall configuration, a swap partition was defined but not enabled?! Check that.
- [ ] Look over other solutions for the timezone thingy with dualboot. I dont want it to be wrong forever.
- [ ] Add signing to git for GitHub
- [ ] Add signing to mail for i.e. jakob@schluse.com
- [ ] Revisit Outlook calendar
- [ ] Add iCloud calendar
 
## Boot & Installation
 
### Dual Boot with Windows
 
- **Decision:** Keep Windows for Fusion 360 and other Windows-only programs.
- **Reference:** [Dual boot with Windows — ArchWiki](https://wiki.archlinux.org/index.php/Dual_boot_with_Windows)

### Bootloader: systemd-boot (not GRUB)
 
- **Why:** A Windows update can silently overwrite GRUB in the EFI partition, breaking
  the boot menu. `systemd-boot` lives in a separate EFI entry and is immune to this.
  The official asus-linux.org guide also explicitly recommends systemd-boot and says
  to avoid GRUB.
- **When GRUB is worth it:** Complex multi-OS setups, or if Btrfs snapshots need to be
  bootable from the menu (requires grub-btrfs). Neither applies here.
- **Reference:**
  - [systemd-boot — ArchWiki](https://wiki.archlinux.org/title/Systemd-boot)
  - [asus-linux.org Arch guide](https://asus-linux.org/guides/arch-guide/)

### Filesystem: Ext4 (not Btrfs)
 
- **Why:** Avoiding Btrfs removes the need for GRUB entirely (Btrfs boot-menu snapshots
  require grub-btrfs), keeps the setup simpler, and avoids Btrfs's write amplification
  on the SSD for this use case.
- **Tradeoff:** Timeshift runs in `rsync` mode instead of snapshot mode. Snapshots on
  Btrfs are near-instant and storage-efficient; rsync copies are slower and use more
  disk. Acceptable for a personal laptop.
- **Revisit if:** Reinstalling from scratch — Btrfs + snapshot-mode Timeshift is a
  meaningful upgrade if GRUB is acceptable.

### Kernels: `linux`

- While a `linux` + `linux-lts` setup was considered for a long time, it was finally
  overturned as it would be too big for the EFI partition and the additional
  complexitly was not deemed wothy. So this is the totally normal install.

### Firmware & Microcode
 
- `linux-firmware`: required for hardware firmware blobs (WiFi, etc.)
- `amd-ucode`: CPU microcode updates for the Ryzen 9 5900HX. Loaded by the bootloader
  at early boot. `intel-ucode` would be used instead on Intel systems.
- **Reference:** [Microcode — ArchWiki](https://wiki.archlinux.org/title/Microcode)

### Installer: archinstall
 
- **Why:** Fast, reproducible, no manual partitioning required. Manual installation
  is only worth the time for highly custom partition layouts.
- Configuration for this install can be found in `archinstall_config.json`.
- **Reference:** [archinstall — ArchWiki](https://wiki.archlinux.org/title/Archinstall)

### Time setup

As the [ArchWiki](https://wiki.archlinux.org/title/Dual_boot_with_Windows#Time_standard)
points out, you have to put some care into how you set up you time so that the OS's don't
interfere with each other. Here are the steps I took to make this work:

1. Windows
   1. Open the Registry Editor as Administrator
   2. Create a new key called `RealTimeIsUniversal` of the type DWORD32 at
      `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation`
   3. Set this key to 1
2. BIOS
   1. Boot into the BIOS
   2. For my machine, at the top, I can set the clock to some value manually. Open a
      time website on another device and set it pretty accurately.
3. Arch Linux
   1. Run `timedatectl`
   2. It should output something like this:
      ```
                     Local time: Wed 2026-06-24 16:11:41 CEST
                 Universal time: Wed 2026-06-24 14:11:41 UTC
                       RTC time: Wed 2026-06-24 14:11:41
                      Time zone: Europe/Brussels (CEST, +0200)
      System clock synchronized: yes
                    NTP service: active
                RTC in local TZ: no
      ```
   3. Set the timezone with: `timedatectl set-timezone Europe/Brussels`
   4. If "RTC in local TZ" is set to yes, run `timedatectl set-local-rtc 0`. This tells
      Arch the hardware clock is set to UTC instead of the local time.

 
## Desktop Environment
 
### GNOME (with Hyprland planned)
 
- **Why GNOME first:** Already familiar from VM use. Wayland-native, polished, zero
  configuration overhead.
- **Why not Hyprland immediately:** Requires manual setup of every component (bar,
  launcher, notifications, screensharing, idle daemon). High value, high cost.
- **Migration note:** When switching to Hyprland, GNOME Keyring PAM initialization
  needs manual setup (see SSH/GPG section).

 
## System & Hardware Maintenance
 
### Backups: Timeshift (rsync mode)
 
- **Why Timeshift:** Simple GUI + CLI, well-documented restore from TTY.
- **Why rsync mode:** Required for Ext4. Btrfs snapshot mode is faster but tied to Btrfs.
- **Reference:** [Timeshift — GitHub](https://github.com/linuxmint/timeshift)

### Package Cache: paccache.timer
 
- **Why:** pacman/paru accumulate old package versions in `/var/cache/pacman/pkg/`.
  `paccache` (from `pacman-contrib`) keeps the last 3 versions and ships a systemd
  timer for weekly automation.
- **Reference:** [paccache — ArchWiki](https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache)

 
## ASUS ROG Hardware
 
### g14 Pacman Repo
 
- **What it is:** A pacman repo maintained by the asus-linux.org team, providing
  asusctl, rog-control-center, and related packages as precompiled binaries.
  The name "g14" is historical — it applies to all ROG laptops.
- **Why use it over AUR:** The guide explicitly states that `asusctl-git` and other
  AUR variants are **not supported**. The g14 repo is the only supported installation
  method.
- **Setup:** Add the signing key, append the repo to `/etc/pacman.conf`, then run a
  full system sync before installing any packages from it. `install.sh` handles this.
- **Reference:** [asus-linux.org Arch guide — Repo](https://asus-linux.org/guides/arch-guide/#repo)

### asusctl
 
- **What it does:** Fan profiles, keyboard RGB, battery charge thresholds.
- **Install:** `sudo pacman -S asusctl` (from g14 repo — **not AUR**)
- **asusd service:** intentionally NOT enabled via systemctl. It is triggered
  automatically by a udev rule once the keyboard driver is ready. Enabling it manually
  can cause race conditions on boot.
- **Reference:** [asus-linux.org — asusctl](https://asus-linux.org/guides/arch-guide/#asusctl-custom-fan-profiles-anime-led-control-etc)

### ROG Control Center
 
- **What it is:** GUI frontend for asusctl. Previously bundled with asusctl, now
  a separate package in the g14 repo.
- **Install:** `sudo pacman -S rog-control-center`
- **Reference:** [asus-linux.org — ROG Control Center](https://asus-linux.org/guides/arch-guide/#rog-control-center)

### power-profiles-daemon
 
- **Why:** asusctl is designed to work with power-profiles-daemon for power profile
  management. Other power management tools (e.g. TLP, auto-cpufreq) **conflict** with
  asusctl and must not be installed alongside it.
- **Reference:** [asus-linux.org — asusctl](https://asus-linux.org/guides/arch-guide/#asusctl-custom-fan-profiles-anime-led-control-etc)

### supergfxctl — NOT installed (deprecated)
 
- **Why not:** The asus-linux.org guide explicitly marks supergfxctl as deprecated and
  advises against installing it: *"unless you require vfio for virtual machines or have
  problems turning off your dGPU don't install it."*
- The RTX 3070 (Ampere) handles dynamic power gating via `nvidia-laptop-power-cfg` and
  the nvidia power management services instead. supergfxctl is not needed.
- **Reference:** [asus-linux.org — supergfxctl (Deprecated)](https://asus-linux.org/guides/arch-guide/#supergfxctl-graphics-switching-Deprecated)


## NVIDIA (RTX 3070 — Ampere)
 
### Driver
 
- **Package:** `nvidia-open` — the open-source kernel module, appropriate for Ampere
  architecture and later. The proprietary `nvidia` package is only needed for Turing
  (RTX 2000) and older where GSP firmware must be disabled.
- **Also install:** `nvidia-utils` (userspace libraries) and `vulkan-icd-loader`
  (Vulkan ICD loader, required).

### nvidia-laptop-power-cfg
 
- **What it does:** Provides udev rules and modprobe configuration for proper dGPU
  dynamic power gating on Ampere laptops. Without it, the GPU may not power down when
  idle, draining battery.
- **Install:** This is also on the g14 repo. The guide on asus-linux.org is wrong about that.
- > [!NOTE]
  > Copilot mentioned the following. Consider it when debugging. In the config files installed by this package,
  > these options are commented out.
  > 
  > > NVIDIA Suspend/Hibernate parameters: You enable nvidia-suspend.service, nvidia-hibernate.service, and nvidia-resume.service. For these to actually work, NVIDIA requires you to pass NVreg_PreserveVideoMemoryAllocations=1 to the nvidia kernel module (usually via /etc/modprobe.d/nvidia.conf). Without this, saving VRAM to RAM on sleep will fail. (You will also want nvidia-drm.modeset=1 in your boot parameters for Wayland support when you move to Hyprland).

- **Reference:**
  - [nvidia-laptop-power-cfg — GitLab](https://gitlab.com/asus-linux/nvidia-laptop-power-cfg)
  - [asus-linux.org — Ampere](https://asus-linux.org/guides/arch-guide/#ampere-architecture-rtx-3000-or-later)

### NVIDIA systemd services
 
These four services are enabled to handle GPU state across power transitions:
 
```
nvidia-suspend.service    # saves GPU state before system suspend
nvidia-hibernate.service  # saves GPU state before hibernation
nvidia-resume.service     # restores GPU state on wake
nvidia-powerd             # runtime power management daemon (started immediately)
```
 
### Verifying S0ix Power Management
 
After first boot, verify that S0ix power management is active (critical for idle
power consumption and sleep):
 
```bash
cat /proc/driver/nvidia/gpus/*/power
# Expected: "Status: Enabled" under "S0ix Power Management"
```
 
Use bash tab-completion on the path if the glob doesn't work.
 
- **Reference:** [asus-linux.org — Next steps](https://asus-linux.org/guides/arch-guide/#next-steps)

 
## Package Management
 
### paru (AUR helper)
 
- **Why paru over yay:** Written in Rust, actively maintained, feature-complete. But to be honest, it was just a vibe decision. And it does not really matter anyway.
- **Idempotency:** `paru -S --needed` skips already-installed packages.
- **Reference:** [paru — GitHub](https://github.com/Morganamilo/paru)


## Programs
 
### Editor: Visual Studio Code (`visual-studio-code-bin`)
 
- **Why the Microsoft AUR build, not `code`:** The open-source `code` build uses
  OpenVSX, which lacks proprietary extensions (Copilot, official remote dev tools).
- **`settings.json`** tracked at `home/.config/Code/User/settings.json`. Key settings:
  - `"telemetry.telemetryLevel": "error"` — error reporting only, no usage telemetry
  - ruff as default formatter and linter for Python
  - ty handles type checking (pylance type checking disabled)
  - rust-analyzer with clippy and inlay hints
  - Catppuccin Mocha theme (install the extension to activate)
- **Reference:** [VSCode — ArchWiki](https://wiki.archlinux.org/title/Visual_Studio_Code),
  [Telemetry docs](https://code.visualstudio.com/docs/configure/telemetry)

#### VSCode Extensions Notes

- **"C/C++"** by *Microsoft* ([ms-vscode.cpptools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools)):

  Using this extension for debugging, as it support the GDB compiler, which is installed
  on my system as opposed to LLVM.

### Python: uv + ruff + ty
 
- **uv:** Fast Python package and project manager. Replaces pip, virtualenv, pyenv.
  [uv — GitHub](https://github.com/astral-sh/uv)
- **ruff:** Linter and formatter, installed as a uv tool (globally available).
  [ruff — GitHub](https://github.com/astral-sh/ruff)
- **ty:** Type checker from Astral. Fast, modern alternative to mypy/pyright.
  [ty — GitHub](https://github.com/astral-sh/ty)
- Both also installed as VSCode extensions for inline feedback.

### AI Coding
 
- **Status:** To be determined.
- **Options:** [Continue](https://www.continue.dev/) + [GitHub Models API](https://github.com/marketplace/models)
  (free but rate-limited); [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

### OneDrive: abraunegg/onedrive
 
- **Key settings** (tracked in `home/.config/onedrive/config`):
  - `skip_size = "50"`: skip files over 50 MB to keep the local footprint small
  - `sync_list_file`: points to `sync_list` for whitelist-mode selective sync
- **`sync_list`** (tracked in `home/.config/onedrive/sync_list`): template with
  commented-out example paths. Edit to add the folders you want synced locally,
  then run `onedrive --sync --resync --verbose` for the initial sync.
- **Note:** First-time auth (`onedrive` browser flow) and the initial sync are
  manual steps — interactive by nature and cannot be scripted.
- **Reference:** [abraunegg/onedrive — GitHub](https://github.com/abraunegg/onedrive),
  [Usage docs](https://github.com/abraunegg/onedrive/blob/master/docs/usage.md)

### Password Manager: KeepassXC
 
- Open-source, no cloud account. Database stored on OneDrive for cross-device access
  without trusting a third-party vault.
- **Reference:** [KeepassXC](https://keepassxc.org/)

### Browser

#### Zen Browser
- Primary browser
- Zenful browsing experience

#### Brave
- Secondary browser after Zen
- Chromium support allows native PWA support, so this browser is kept for that.

### WhatsApp: Brave PWA
 
- No native Linux client. Brave handles PWAs natively as a Chromium-based browser.
  Previous setup used Firefox + PWAs-for-Firefox extension, which caused WhatsApp to
  open in the foreground on startup. Brave solves this cleanly.
- **Setup:** `web.whatsapp.com` in Brave → install icon in address bar.

### Markdown Editor: MarkText
 
- After trying Ghostwriter (moved to Fedora, outdated on Arch), Apostrophe (no syntax
  highlighting), and Zettlr (too publication-focused), MarkText best fits the minimal
  requirement.
- **Install:** `paru -S marktext-bin`
- **Reference:** [MarkText — GitHub](https://github.com/marktext/marktext)
- > [!NOTE]
  > I am thinking about trying out Obsidian. It's just `paru -S obsidian`.

### Music Notation: LilyPond + Frescobaldi
 
- LilyPond: text-based notation, PDF output. [lilypond.org](https://lilypond.org)
- Frescobaldi: GUI editor for LilyPond. [frescobaldi.org](https://www.frescobaldi.org)

### Containerization: Podman (not Docker)
 
- Daemonless (saves battery), rootless by default (better security).
- `podman-docker` aliases all `docker` commands to `podman` transparently.
- **Reference:** [Podman](https://podman.io/)

### Mail: Thunderbird

- Using the most recent version of Thunderbird gives me Exchange support [5],
  which is not provided by Betterbird as of now (it will be included by July 2026 [4])
- EWS support does not seem to work for me right now. I will revisit this at a later date.
- Also, the Exchange support is by no means full. Calendars are NOT supported [6]
- **References:**
  1. [Arch Linux Wiki - Thunderbird](https://wiki.archlinux.org/title/Thunderbird)
  2. [Betterbird Homepage](https://www.betterbird.eu/)
  3. [Arch User Repository](https://aur.archlinux.org/packages/betterbird-bin)
  4. [r/Betterbird - Exchange support](https://www.reddit.com/r/Betterbird/comments/1pcbjz2/exchange_support/)
  5. [Thunderbird Blog - Thunderbird Adds Native Microsoft Exchange Email Support](https://blog.thunderbird.net/2025/11/thunderbird-adds-native-microsoft-exchange-email-support/)
  6. [Mozilla Support - Thunderbird and Exchange](https://support.mozilla.org/en-US/kb/thunderbird-and-exchange)


## Shell
 
### Terminal: Ghostty
 
- GPU-accelerated, configured via a single text file at `~/.config/ghostty/config.ghostty`
  (it was just `config` prior to version 1.2.3), works out of the box.
- **Reference:**
  - [Ghostty — GitHub](https://github.com/ghostty-org/ghostty)
  - [Config Docs - Ghostty](https://ghostty.org/docs/config)

### Shell: Zsh (scripts stay in Bash)
 
- Zsh for interactive use: better completion, richer plugins.
- Bash for scripts: POSIX-compatible, available everywhere.
- **Reference:** [Zsh — ArchWiki](https://wiki.archlinux.org/title/Zsh)

### Prompt: Starship
 
- Cross-shell, Rust-based, no perceptible latency.
- Config at `~/.config/starship.toml` — **vendored directly in this repo**.
  Based on the catppuccin-powerline preset, adjusted and documented inline.
  No manual preset command needed after install.
- **Why vendor instead of running a preset:** A vendored config is version-controlled,
  reviewable, and doesn't depend on a network call during setup. Customisations are
  visible in git history rather than silently overwritten.
- To swap to a different preset: `starship preset <name> -o ~/.config/starship.toml`
  then commit the result.
- **Reference:** [starship.rs](https://starship.rs/), [Presets](https://starship.rs/presets/)

### Zsh Plugins (pacman-managed, no plugin manager)
 
- **Why no Oh My Zsh / Zinit:** Startup latency, extra dependency. Arch repos ship
  the main plugins; sourcing them directly in `.zshrc` is simpler and faster.
- `zsh-syntax-highlighting`: real-time command highlighting
- `zsh-autosuggestions`: Fish-like history suggestions
- `zsh-completions`: extra completions for Docker, Git, Node, etc.

### Modern CLI Utilities
 
| Tool                                            | Replaces         | Why                                        |
| ----------------------------------------------- | ---------------- | ------------------------------------------ |
| [fzf](https://github.com/junegunn/fzf)          | `Ctrl+R` history | Fuzzy search over history, files, anything |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd`             | Learns frecency, jump by partial name      |
| [eza](https://github.com/eza-community/eza)     | `ls`             | Color-coded, Git status, tree view         |
| [bat](https://github.com/sharkdp/bat)           | `cat`            | Syntax highlighting, Git diff              |


 
## Rust
 
- **Toolchain manager:** `rustup` (installed via pacman)
- **Why `base-devel`:** Rust crates with C dependencies need `gcc`, `make`, `binutils`.
- **VSCode:** `rust-analyzer` extension.
- **Reference:** [Rust installation](https://doc.rust-lang.org/book/ch01-01-installation.html)

 
## SSH / GPG Keys
 
- **Managed via:** GNOME Keyring (unlocks on login).
- **Hyprland migration note:** GNOME Keyring needs a PAM snippet that GNOME sets up
  automatically. Must be added manually when switching to Hyprland, or replaced with
  another agent.

 
## Dotfile Management
 
### GNU Stow
 
- `home/` mirrors `~/` exactly. `stow --restow home` creates all symlinks in one call.
- **Why not bare git:** Requires a custom alias instead of normal git commands; confusing
  to revisit.
- **Why not manual symlinks:** More script code, same result.
- **`--restow`:** Removes and recreates symlinks on each run — idempotent.
- **Reference:** [GNU Stow](https://www.gnu.org/software/stow/)


## Fonts

Mass-installing fonts on arch is not the way to do things, as it introduces a few bad practices
for an Arch install:

- *Bloat:* I would be installing hundreds of megabytes of fonts I would never look at or use.

- *Font Conflicts & Hierarchy Issues:* When I install multiple major font families (like Arial alternatives ttf-liberation and ttf-croscore simultaneously), my browser and system configuration tools can get confused about which font to prioritize as the default system sans-serif. This can lead to ugly text rendering on certain web pages.

- *The Ghostty/Terminal Mess:* Having too many monospace variants installed can sometimes make font selection menus cluttered and messy.

Instead, following my selection:

1. **`noto-fonts` + `emoji` + `cjk**`: A bulletproof safety net. WhatsApp emojis work, and random foreign characters in GitHub code won't show up as boxes.
2. **`ttf-liberation`**: Fulfills the standard system metrics so PDFs and document layouts don't break.
3. **`inter-font`**: Makes your GNOME desktop environment look beautiful and incredibly clean.
4. **`ttf-firacode-nerd`**: Your absolute daily driver for Ghostty and VSCode.

 
## Manual Steps (after reboot)
 
**Reboot first.** The NVIDIA driver and asusd udev rule both need a clean boot.
 
1. **Verify NVIDIA S0ix** — critical for battery life and sleep:
   ```bash
   cat /proc/driver/nvidia/gpus/*/power
   # Expected: "Status: Enabled" under "S0ix Power Management"
   ```
   If disabled, see [asus-linux.org — Next steps](https://asus-linux.org/guides/arch-guide/#next-steps).

2. **OneDrive auth:** Run `onedrive`, follow browser flow. Config and `sync_list`
   are already in place via stow. Edit `~/.config/onedrive/sync_list` to add your
   folders, then: `onedrive --sync --resync --verbose`.

3. **KeepassXC:** Open the app and point it to the database on OneDrive.

4. **Setup Git for GitHub:**
   ```bash
   gh auth login
   gh auth setup-git
   ```

5. **WhatsApp PWA:** Brave → `web.whatsapp.com` → install icon in address bar.

6. **VSCode extensions:** Install manually or sign in to Settings Sync.
   `settings.json` is already in place via stow.
   > [!NOTE]
   > As mentioned above, this step should become obsolete.

7. **Timeshift:** Open GUI → set snapshot location and schedule.
