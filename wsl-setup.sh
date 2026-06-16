#!/usr/bin/env bash
#
# wsl-setup.sh — provision a fresh WSL Debian into your dev environment.
# Adapted from your debian-p10k-zsh Dockerfile, minus Gemini CLI.
#
# Differences from the Dockerfile (on purpose):
#   - No FROM / USER juggling: WSL already created your sudo user, so this runs
#     AS you and just uses sudo for system steps. No devuser, no NOPASSWD sudoers.
#   - No Docker engine / socket wiring: in WSL you use Docker Desktop's WSL
#     integration instead (see the note at the bottom). Native dockerd is optional.
#   - No Gemini CLI.
#
# Usage (inside WSL Debian):
#   git clone https://github.com/lavet13/debian-p10k-zsh.git
#   cd debian-p10k-zsh
#   bash wsl-setup.sh
#
# Re-running is safe-ish: the clone/install steps skip work that's already done.

set -euo pipefail

# ============================ Config (edit me) ============================
NVIM_VERSION="v0.11.6"
NVIM_CONFIG_REF="nvim-0.11.6-r14"            # branch / tag / commit for reproducibility
NVIM_CONFIG_REPO="https://github.com/lavet13/nvim-lsp.git"
DOTFILES_REPO="https://github.com/lavet13/debian-p10k-zsh.git"   # fallback if run standalone
GIT_USER_NAME="lavet13"
GIT_USER_EMAIL="lavet13@mail.ru"
NODE_MAJOR="22"

# Where to find the dotfiles: prefer the repo this script lives in, else clone.
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

# ============================ 1. System packages ==========================
# locales-all so en_US.UTF-8 exists (your .zshrc exports LANG/LC_ALL=en_US.UTF-8).
# procps gives pgrep/pkill/ps (tmux-sessionizer uses pgrep).
sudo apt-get update
sudo apt-get install -y \
  zsh tmux fzf procps locales-all git curl ca-certificates \
  ripgrep fd-find unzip \
  python3 python3-pip python3-venv \
  build-essential

# ============================ 2. Node.js + corepack =======================
# NodeSource adds an apt repo pinned to a major version. corepack gives you the
# yarn/pnpm shims (you use Yarn 4 via corepack).
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
sudo apt-get install -y nodejs
sudo corepack enable

# ============================ 3. Neovim (pinned tarball) ==================
# Same approach as the Dockerfile: grab the official release, drop it in /opt,
# symlink the binary onto PATH.
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
# Avoid "dubious ownership" complaints on repos that cross the Windows/WSL boundary.
git config --global --add safe.directory '*'

# ============================ 5. Oh My Zsh + p10k + plugins ===============
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

# ============================ 6. Neovim config (pinned ref) ===============
if [ ! -d "$HOME/.config/nvim" ]; then
  mkdir -p "$HOME/.config"
  git clone "$NVIM_CONFIG_REPO" "$HOME/.config/nvim"
  git -C "$HOME/.config/nvim" checkout "$NVIM_CONFIG_REF"
fi

# ============================ 7. obsidian.nvim workspaces =================
# obsidian.nvim errors on startup if a configured workspace path is missing.
# These must match the workspaces in your nvim config (including chzzk-dl-live).
mkdir -p "$HOME/notes/personal" "$HOME/notes/donbass-post" \
         "$HOME/notes/donbass-tour" "$HOME/notes/chzzk-dl-live"

# ============================ 8. Dotfiles =================================
cp "$DOTFILES/.zshrc"    "$HOME/.zshrc"
cp "$DOTFILES/.p10k.zsh" "$HOME/.p10k.zsh"
cp "$DOTFILES/.tmux.conf" "$HOME/.tmux.conf"
mkdir -p "$HOME/.local/bin"
cp "$DOTFILES/tmux-sessionizer" "$HOME/.local/bin/tmux-sessionizer"
chmod +x "$HOME/.local/bin/tmux-sessionizer"

# Strip any CRLF that rode along from the Windows side — zsh/tmux break silently on \r.
sed -i 's/\r$//' "$HOME/.zshrc" "$HOME/.p10k.zsh" "$HOME/.tmux.conf" \
  "$HOME/.local/bin/tmux-sessionizer"

# tmux-sessionizer searches ~/workspace — make sure it exists.
mkdir -p "$HOME/workspace"

# ============================ 9. pipx + CLIs ==============================
# Debian's Python is "externally managed" (PEP 668), hence --break-system-packages.
python3 -m pip install --user --break-system-packages pipx
"$HOME/.local/bin/pipx" ensurepath
"$HOME/.local/bin/pipx" install tldr || true
"$HOME/.local/bin/pipx" install ruff || true

# ============================ 10. Pre-warm Neovim =========================
# Sync lazy.nvim plugins, then install your Mason tools (same list as the Dockerfile).
# "|| true" so a non-fatal plugin warning doesn't abort the whole script.
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
nvim --headless \
  "+MasonInstall css-lsp eslint-lsp html-lsp intelephense json-lsp \
   lua-language-server prettier prisma-language-server pyright ruff \
   stylua tailwindcss-language-server taplo typescript-language-server \
   yaml-language-server" \
  +qa 2>/dev/null || true

# ============================ 11. Default shell -> zsh ====================
sudo chsh -s "$(command -v zsh)" "$USER"

# ============================ Cleanup =====================================
[ -n "$CLONED_DOTFILES" ] && rm -rf "$CLONED_DOTFILES"

echo ""
echo ">>> Done."
echo ">>> Run 'wsl --shutdown' from PowerShell, then reopen Debian — you'll land in zsh."
echo ""

# ===================== OPTIONAL: Docker inside WSL ========================
# Your Dockerfile installed docker-ce because it was a container talking to the
# host socket. In WSL you have two cleaner choices instead:
#
#   1. (recommended) Docker Desktop on Windows → Settings → Resources →
#      WSL Integration → toggle Debian on. `docker` then works in WSL with
#      ZERO install here.
#
#   2. (no Docker Desktop) Native dockerd. Requires systemd in WSL:
#        printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf
#        # then `wsl --shutdown`, reopen, install docker-ce from Docker's apt repo,
#        # and `sudo systemctl enable --now docker`.
#      This is heavier and only worth it if you're avoiding Docker Desktop.
