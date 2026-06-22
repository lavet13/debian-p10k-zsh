#!/usr/bin/env bash
#
# wsl-setup.sh — provision a fresh WSL Debian into my dev environment.
#
# ----------------------------------------------------------------------------
# PREREQUISITES (run these first on a fresh WSL Debian, before this script):
#
#   sudo apt-get update && sudo apt-get upgrade -y
#   sudo apt-get install -y git
#   git clone https://github.com/lavet13/debian-p10k-zsh.git
#   cd debian-p10k-zsh
#   bash wsl-setup.sh
#
# If DNS fails on a fresh distro ("Temporary failure resolving ..."), fix that
# BEFORE running this — it's usually a VPN KillSwitch. Either add your DNS
# servers to the VPN client's DNS-exception list, or pin /etc/resolv.conf
# (nameserver 1.1.1.1 / 8.8.8.8) with [network] generateResolvConf=false in
# /etc/wsl.conf, then `wsl --shutdown` and reopen.
# ----------------------------------------------------------------------------
#
# Differences from the Dockerfile (on purpose):
#   - No FROM / USER juggling: WSL already created your sudo user.
#   - No Docker engine: use Docker Desktop's WSL integration (note at bottom).
#   - Copies SSH keys from Windows (the Dockerfile mounted them via compose).
#
# Safe to re-run: every step is guarded to skip or harmlessly reapply. The one
# exception is the dotfiles copy, which always overwrites ~/.zshrc etc. from the
# repo (the repo is the source of truth — local edits there get replaced).

set -euo pipefail

# ============================ Config (edit me) ============================
NVIM_VERSION="v0.11.6"
NVIM_CONFIG_REPO="git@github.com:lavet13/nvim-lsp.git"
DOTFILES_REPO="https://github.com/lavet13/debian-p10k-zsh.git"   # keep HTTPS
NOTES_REPO="git@github.com:lavet13/notes-obsidian.git"
GIT_USER_NAME="lavet13"
GIT_USER_EMAIL="lavet13@mail.ru"
NODE_MAJOR="22"

# Windows username (for copying SSH keys). Auto-detected from the host; override
# by exporting WIN_USER before running if detection fails.
WIN_USER="${WIN_USER:-$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n')}"

# Dotfiles: prefer the repo this script lives in, else clone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/dotfiles" ]; then
  DOTFILES="$SCRIPT_DIR/dotfiles"
  CLONED_DOTFILES=""
else
  CLONED_DOTFILES="$(mktemp -d)"
  git clone --depth=1 "$DOTFILES_REPO" "$CLONED_DOTFILES"
  DOTFILES="$CLONED_DOTFILES/dotfiles"
fi
echo ">>> Using dotfiles from: $DOTFILES"

cleanup() {
  # ${VAR:-} guards against set -u if we die before CLONED_DOTFILES is even set.
  [ -n "${CLONED_DOTFILES:-}" ] && rm -rf "$CLONED_DOTFILES"
}

trap cleanup EXIT
trap 'echo ">>> wsl-setup.sh failed at line $LINENO: $BASH_COMMAND" >&2' ERR

# ============================ 1. System packages ==========================
sudo apt-get update
sudo apt-get install -y \
  zsh tmux fzf procps locales-all git curl ca-certificates \
  ripgrep fd-find unzip shellcheck info bash-doc \
  python3 python3-pip python3-venv \
  build-essential

# ============================ 2. Node.js + corepack =======================
# Skip the NodeSource repo step if the right major is already installed.
if ! command -v node >/dev/null 2>&1 || ! node -v | grep -q "^v${NODE_MAJOR}\."; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  sudo apt-get install -y nodejs
fi
sudo corepack enable

# ============================ 3. Neovim (pinned tarball) ==================
# ! -x means it's either missing or lacks execute permission
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
git config --global --add safe.directory '*' # stops git's "dubious ownership" refusal on repos that straddle the Windows/WSL boundary (different ownership metadata)
# Leave line endings alone on commit-from-Linux; .gitattributes still wins per-repo.
git config --global core.autocrlf input

# ============================ 5. SSH keys from Windows ====================
# WSL has no ~/.ssh mount, so copy keys over and fix Unix permissions.
WIN_SSH="/mnt/c/Users/${WIN_USER}/.ssh"
if [ -n "$WIN_USER" ] && [ -d "$WIN_SSH" ]; then
  echo ">>> Copying SSH keys from $WIN_SSH"
  mkdir -p "$HOME/.ssh"
  # Copy everything — named keys (deploy_key, github_actions_key), id_*, config,
  # known_hosts. Windows ~/.ssh is the source of truth.
  cp -rT "$WIN_SSH" "$HOME/.ssh/"
  # Permissions: dir 700; lock every file to 600 by default (correct for ANY
  # private key regardless of its name), then relax the non-secret ones to 644.
  chmod 700 "$HOME/.ssh"
  find "$HOME/.ssh" -type f -exec chmod 600 {} +
  find "$HOME/.ssh" -type f \( -name '*.pub' -o -name 'known_hosts*' \) -exec chmod 644 {} +
else
  echo ">>> No Windows ~/.ssh found (WIN_USER='$WIN_USER'); skipping SSH copy."
fi

# Pre-trust github.com so the SSH clones in steps 7-8 don't hang on a
# host-key prompt. ssh-keygen -F exits 0 if the host is already known.
if ! ssh-keygen -F github.com >/dev/null 2>&1; then
  ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
fi

# ============================ 6. Oh My Zsh + p10k + plugins ===============
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  # unattended flag means stop launching only if OMZ is absent
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] || \
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# ============================ 7. Neovim config (live working copy) ===============
# Clone if absent; clone leaves you on the default branch (main), ready to edit
# and push. No tag checkout — this is a working copy, not a frozen snapshot.
if [ ! -d "$HOME/.config/nvim/.git" ]; then
  mkdir -p "$HOME/.config"
  git clone "$NVIM_CONFIG_REPO" "$HOME/.config/nvim"
fi

# ============================ 8. Notes (obsidian.nvim) ====================
# Clone the notes repo; its folders are the obsidian.nvim workspaces.
# Handle a pre-existing ~/notes (e.g. an earlier run that only mkdir'd the empty
# workspace dirs): git clone refuses a non-empty target, so graft the clone in
# via a temp dir without clobbering any local files.
if [ ! -d "$HOME/notes/.git" ]; then
  if [ -d "$HOME/notes" ] && [ -n "$(ls -A "$HOME/notes" 2>/dev/null)" ]; then
    tmp_notes="$(mktemp -d)"
    git clone "$NOTES_REPO" "$tmp_notes"
    cp -rT --update=none "$tmp_notes" "$HOME/notes/"
    rm -rf "$tmp_notes"
  else
    git clone "$NOTES_REPO" "$HOME/notes"   # works for absent or empty dir
  fi
else
  # Already a clone — bring it up to date. --ff-only refuses to make a merge
  # commit: if your local notes diverged, it stops loudly instead of tangling them.
  git -C "$HOME/notes" pull --ff-only
fi

# ============================ 9. Dotfiles =================================
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/workspace"   # tmux-sessionizer searches here

if [[ -n "$CLONED_DOTFILES" ]]; then
  cp "$DOTFILES/.zshrc"           "$HOME/.zshrc"
  cp "$DOTFILES/.zshenv"          "$HOME/.zshenv"
  cp "$DOTFILES/.p10k.zsh"        "$HOME/.p10k.zsh"
  cp "$DOTFILES/.tmux.conf"       "$HOME/.tmux.conf"
  cp "$DOTFILES/tmux-sessionizer" "$HOME/.local/bin/tmux-sessionizer"
else
  ln -sf "$DOTFILES/.zshrc"           "$HOME/.zshrc"
  ln -sf "$DOTFILES/.zshenv"          "$HOME/.zshenv"
  ln -sf "$DOTFILES/.p10k.zsh"        "$HOME/.p10k.zsh"
  ln -sf "$DOTFILES/.tmux.conf"       "$HOME/.tmux.conf"
  ln -sf "$DOTFILES/tmux-sessionizer" "$HOME/.local/bin/tmux-sessionizer"
fi

# ============================ 10. pipx + CLIs =============================
python3 -m pip install --user --break-system-packages pipx
"$HOME/.local/bin/pipx" ensurepath
"$HOME/.local/bin/pipx" install tldr || true   # already-installed exits non-zero
"$HOME/.local/bin/pipx" install ruff || true   # already-installed exits non-zero

# cheat.sh client: `cht.sh fd` → example-first docs, fuller than tldr.
# The :cht.sh path returns the installer script itself.
if [ ! -x "$HOME/.local/bin/cht.sh" ]; then
  curl -fsSL https://cht.sh/:cht.sh -o "$HOME/.local/bin/cht.sh"
  chmod +x "$HOME/.local/bin/cht.sh"
fi

# ============================ 11. Pre-warm Neovim =========================
# install plugins at the COMMITTED lockfile versions, no rewrite.
# `restore` brings plugins to the lazy-lock.json state (lazy auto-installs any
# missing ones on startup first); `sync` would UPDATE them and rewrite the lock.
nvim --headless "+Lazy! restore" +qa 2>/dev/null || true
nvim --headless \
  "+MasonInstall css-lsp eslint-lsp html-lsp intelephense json-lsp \
   lua-language-server prettier prisma-language-server pyright ruff \
   stylua tailwindcss-language-server taplo typescript-language-server \
   yaml-language-server" \
  +qa 2>/dev/null || true

# ============================ 12. Default shell -> zsh ====================
sudo chsh -s "$(command -v zsh)" "$USER"

echo ""
echo ">>> Done. Run 'wsl --shutdown' from PowerShell/CMD/MINGW64, then reopen Debian — you'll land in zsh."

# ===================== OPTIONAL: Docker inside WSL ========================
# Prefer Docker Desktop -> Settings -> Resources -> WSL Integration -> toggle
# Debian on; `docker` then works in WSL with zero install here. Native dockerd
# is possible but needs systemd (printf '[boot]\nsystemd=true\n' | sudo tee
# /etc/wsl.conf, then `wsl --shutdown`) and reintroduces systemd-resolved DNS
# management — only worth it if you're avoiding Docker Desktop.
