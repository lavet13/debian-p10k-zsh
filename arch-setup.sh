#!/usr/bin/env bash
#
# arch-setup.sh — provision a fresh CachyOS / Arch install into my dev environment.
# Native mirror of wsl-setup.sh: same steps, adapted from Debian/WSL to Arch.
#
# ----------------------------------------------------------------------------
# What changed vs wsl-setup.sh (on purpose):
#   - apt-get            -> pacman   (+ paru for AUR extras)
#   - NodeSource repo    -> pacman nodejs/npm (Arch ships current Node)
#   - /mnt/c SSH copy    -> restore from a backup path you set (SSH_BACKUP),
#                           else generate a fresh ed25519 key.
#   - Docker Desktop/WSL -> native docker + systemd service.
#   - ADDED (WSL left these to the Windows host): WezTerm, fonts, Wayland
#     clipboard, tree-sitter CLI, and locale-gen for en_US.UTF-8.
#
# PREREQUISITES (fresh CachyOS, before this script):
#   sudo pacman -Syu
#   sudo pacman -S --needed git base-devel
#   git clone https://github.com/lavet13/debian-p10k-zsh.git
#   cd debian-p10k-zsh
#   bash arch-setup.sh
#
# Safe to re-run: every step is guarded to skip or harmlessly reapply. Dotfiles
# re-symlink idempotently; the WezTerm .lua is copied+patched once and left alone.
# ----------------------------------------------------------------------------

set -euo pipefail

# ============================ Config (edit me) ============================
NVIM_VERSION="v0.11.6"
NVIM_CONFIG_REPO="lavet13/nvim-lsp"
DOTFILES_REPO="lavet13/debian-p10k-zsh"
NOTES_REPO="lavet13/notes-obsidian"
GIT_USER_NAME="lavet13"
GIT_USER_EMAIL="lavet13@mail.ru"

# Path to a backed-up ~/.ssh to restore (you saved yours to E:). Leave empty to
# skip the copy and generate a fresh key instead. Find E:'s mount with `lsblk`
# or by clicking it in Dolphin — it's usually /run/media/$USER/<label>/...
SSH_BACKUP=""            # e.g. "/run/media/$USER/WIN11/Users/Ivan/.ssh"

INSTALL_DOCKER=1         # 1 = install + enable docker (your bot work needs it)
INSTALL_AMNEZIA=1        # 1 = install amneziavpn-bin from the AUR (needs paru)

# Dotfiles: this script must run from inside the repo (it needs ./dotfiles).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$SCRIPT_DIR/dotfiles" ]; then
  echo ">>> Run this from inside the debian-p10k-zsh repo (needs ./dotfiles)." >&2
  exit 1
fi
DOTFILES="$SCRIPT_DIR/dotfiles"
echo ">>> Using dotfiles from: $DOTFILES"

trap 'echo ">>> arch-setup.sh failed at line $LINENO: $BASH_COMMAND" >&2' ERR

# Pick an SSH remote if a GitHub key works, else HTTPS. Your repos are public,
# so HTTPS clones fine even before you've added a key — you can switch the remote
# to SSH later with `git remote set-url`. (GitHub's `ssh -T` always exits 1, so
# we match on the success text, not the exit code, and `|| true` shields set -e.)
git_url() {
  local out
  out="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  if printf '%s' "$out" | grep -q "successfully authenticated"; then
    printf 'git@github.com:%s.git' "$1"
  else
    printf 'https://github.com/%s.git' "$1"
  fi
}

# ============================ 1. System packages ==========================
# apt -> pacman name map:  procps->procps-ng, fd-find->fd (binary is `fd`, not
# `fdfind` — one fewer alias to carry), build-essential->base-devel,
# python3/-pip/-venv -> python/python-pip (venv is built in). locales-all has no
# Arch package — handled by locale-gen just below. Extras Arch needs that WSL got
# from the Windows host: wezterm, ttf-cascadia-code, wl-clipboard, tree-sitter-cli.
sudo pacman -S --needed --noconfirm \
  zsh tmux fzf procps-ng git curl ca-certificates \
  ripgrep fd unzip shellcheck \
  python python-pip base-devel \
  nodejs npm tree-sitter-cli wl-clipboard \
  ttf-cascadia-code ttf-nerd-fonts-symbols-mono \
  paru

# 1b. Locale — your .zshrc forces LC_ALL=en_US.UTF-8, so make sure it's generated.
if ! locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
  sudo sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  sudo locale-gen
fi

# ============================ 2. Node + corepack ==========================
# Arch shipped a current Node in step 1, so no NodeSource setup — just enable
# corepack for your Yarn 4 workflow.
sudo pacman -S --needed --noconfirm corepack
sudo corepack enable

# ============================ 3. Neovim (pinned tarball) ==================
# Same generic linux-x86_64 build as WSL — runs natively on Arch. Kept over
# `pacman -S neovim` so you get the EXACT version your lazy-lock.json expects.
if [ ! -x /usr/local/bin/nvim ] || ! nvim --version 2>/dev/null | grep -q "${NVIM_VERSION#v}"; then
  tmp_nvim="$(mktemp -d)"
  curl -L "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
    -o "$tmp_nvim/nvim.tar.gz"
  tar -C "$tmp_nvim" -xzf "$tmp_nvim/nvim.tar.gz"
  sudo rm -rf /opt/nvim
  sudo mv "$tmp_nvim/nvim-linux-x86_64" /opt/nvim
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$tmp_nvim"
fi

# ============================ 4. Git identity =============================
git config --global user.name  "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global core.autocrlf input
# (Dropped `safe.directory '*'` — that only mattered across the Windows/WSL
#  ownership boundary; on native ext4/btrfs everything is owned by you.)

# ============================ 5. SSH keys =================================
mkdir -p "$HOME/.ssh"
if [ -n "$SSH_BACKUP" ] && [ -d "$SSH_BACKUP" ]; then
  echo ">>> Restoring SSH keys from $SSH_BACKUP"
  cp -rT "$SSH_BACKUP" "$HOME/.ssh/"
  # Perms: dir 700; every file 600 (correct for any private key), then relax the
  # non-secret ones to 644.
  chmod 700 "$HOME/.ssh"
  find "$HOME/.ssh" -type f -exec chmod 600 {} +
  find "$HOME/.ssh" -type f \( -name '*.pub' -o -name 'known_hosts*' \) -exec chmod 644 {} +
elif [ -z "$(ls "$HOME"/.ssh/id_* 2>/dev/null || true)" ]; then
  echo ">>> No SSH key found — generating a fresh ed25519 key."
  ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
  echo ">>> ADD THIS PUBLIC KEY TO GITHUB (Settings > SSH and GPG keys > New):"
  cat "$HOME/.ssh/id_ed25519.pub"
fi
# Pre-trust github.com so the clones below don't hang on a host-key prompt.
ssh-keygen -F github.com >/dev/null 2>&1 || ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

# ============================ 6. Oh My Zsh + p10k + plugins ===============
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] || \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# ============================ 7. Neovim config (live working copy) =======
if [ ! -d "$HOME/.config/nvim/.git" ]; then
  mkdir -p "$HOME/.config"
  git clone "$(git_url "$NVIM_CONFIG_REPO")" "$HOME/.config/nvim"
fi

# ============================ 8. Notes (obsidian.nvim) ===================
if [ ! -d "$HOME/notes/.git" ]; then
  if [ -d "$HOME/notes" ] && [ -n "$(ls -A "$HOME/notes" 2>/dev/null || true)" ]; then
    tmp_notes="$(mktemp -d)"
    git clone "$(git_url "$NOTES_REPO")" "$tmp_notes"
    cp -rT --update=none "$tmp_notes" "$HOME/notes/"
    rm -rf "$tmp_notes"
  else
    git clone "$(git_url "$NOTES_REPO")" "$HOME/notes"
  fi
else
  git -C "$HOME/notes" pull --ff-only
fi

# ============================ 9. Dotfiles ================================
# Your dotfiles are OS-agnostic (no /mnt/c, no fdfind, no clip.exe) — they
# symlink onto Arch unchanged.
mkdir -p "$HOME/.local/bin" "$HOME/workspace"
chmod +x "$DOTFILES/tmux-sessionizer"
ln -sf "$DOTFILES/.zshrc"           "$HOME/.zshrc"
ln -sf "$DOTFILES/.zshenv"          "$HOME/.zshenv"
ln -sf "$DOTFILES/.p10k.zsh"        "$HOME/.p10k.zsh"
ln -sf "$DOTFILES/.tmux.conf"       "$HOME/.tmux.conf"
ln -sf "$DOTFILES/tmux-sessionizer" "$HOME/.local/bin/tmux-sessionizer"

# ============================ 9b. WezTerm (native) ======================
# WSL left WezTerm to the Windows host; on Arch it's a native app. The .wezterm
# folder ships inside your nvim-lsp repo. Symlink the themes dir so dofile()
# resolves, but COPY + patch the .lua so the tracked repo stays pristine while
# the live config points at a native shell instead of Windows Git Bash.

# Nightly conflicts with the repo build — never both. -Rdd skips dep checks
# since we replace it in the same breath.
if ! pacman -Q wezterm-nightly-bin >/dev/null 2>&1; then
  pacman -Q wezterm >/dev/null 2>&1 && sudo pacman -Rdd --noconfirm wezterm
  paru -S --needed wezterm-nightly-bin
fi

ln -sf "$HOME/.config/nvim/.wezterm" "$HOME/.wezterm"
if [ ! -f "$HOME/.wezterm.lua" ]; then
  cp "$HOME/.config/nvim/.wezterm/wezterm.lua" "$HOME/.wezterm.lua"
  sed -i 's|default_prog = { "G:/Programs/Git/bin/bash.exe" },|default_prog = { "/usr/bin/zsh", "-l" },|' "$HOME/.wezterm.lua"
  echo ">>> Patched ~/.wezterm.lua default_prog -> zsh."
  echo ">>> NOTE: launch_menu still lists WSL entries — edit them if you use that"
  echo "    dropdown (Ctrl+Shift+O). Replace wsl.exe args with:"
  echo '      { label = "zsh (tmux)",    args = { "/usr/bin/zsh", "-l" } },'
  echo '      { label = "zsh (no tmux)", args = { "env", "NO_TMUX=1", "zsh", "-li" } },'
fi

# ============================ 10. pipx + CLIs ============================
command -v pipx >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm python-pipx
pipx install tldr 2>/dev/null || true   # already-installed exits non-zero
pipx install ruff 2>/dev/null || true
if [ ! -x "$HOME/.local/bin/cht.sh" ]; then
  curl -fsSL https://cht.sh/:cht.sh -o "$HOME/.local/bin/cht.sh"
  chmod +x "$HOME/.local/bin/cht.sh"
fi

# ============================ 11. Pre-warm Neovim ========================
# `restore` installs plugins at the committed lazy-lock.json versions (lazy
# auto-installs missing ones first); it does NOT rewrite the lock like `sync`.
nvim --headless "+Lazy! restore" +qa 2>/dev/null || true
nvim --headless \
  "+MasonInstall css-lsp eslint-lsp html-lsp intelephense json-lsp \
   lua-language-server prettier prisma-language-server pyright ruff \
   stylua tailwindcss-language-server taplo typescript-language-server \
   yaml-language-server" \
  +qa 2>/dev/null || true

# ============================ 12. Default shell -> zsh ==================
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

# ============================ 13. Docker (native, optional) =============
if [ "$INSTALL_DOCKER" = "1" ]; then
  sudo pacman -S --needed --noconfirm docker docker-compose
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"   # log out/in for the group to take effect
fi

# ============================ 14. AmneziaVPN (AUR, optional) ============
if [ "$INSTALL_AMNEZIA" = "1" ]; then
  if command -v paru >/dev/null 2>&1; then
    paru -S --needed amneziavpn-bin
  else
    echo ">>> paru not found — skipping AmneziaVPN. Install with: paru -S amneziavpn-bin"
  fi
fi

echo ""
echo ">>> Done. Log out and back in (or reboot) — you'll land in zsh + tmux."
echo ">>> WinPodX (Word/Excel) stays a separate manual install — REVIEW its"
echo "    script before running it:"
echo "      curl -fsSL https://raw.githubusercontent.com/kernalix7/winpodx/main/install.sh -o winpodx.sh"
echo "      less winpodx.sh   # read it, then:  bash winpodx.sh"
