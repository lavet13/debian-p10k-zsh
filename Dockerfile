# syntax=docker/dockerfile:1
#
# Dev-environment image — mirrored from wsl-setup.sh.
#
# RECONSTRUCTION NOTICE: rebuilt from the provisioning script + the Docker-
# specific pieces we discussed, NOT a byte-for-byte copy of your original.
# Sanity-check these before trusting it:
#   - base image tag (trixie vs bookworm — see FROM)
#   - the Docker CLI section (codename + whether your host socket needs a
#     matching group GID)
#   - Gemini is REMOVED (you're off it); re-add snippet is at the bottom.
#
# Build context must be the repo root (so `COPY dotfiles/...` resolves).

FROM debian:trixie-slim
# ^ If your original was bookworm, change this. The Docker repo line below
#   derives its codename from the base automatically, so it follows along.

# ---- build args (override with --build-arg) -----------------------------
ARG USERNAME=devuser
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_MAJOR=22
ARG NVIM_VERSION=v0.11.6
ARG NVIM_CONFIG_REF=nvim-0.11.6-r14
ARG NVIM_CONFIG_REPO=https://github.com/lavet13/nvim-lsp.git
ARG GIT_USER_NAME=lavet13
ARG GIT_USER_EMAIL=lavet13@mail.ru

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

# ---- 1. system packages -------------------------------------------------
# locales-all gives en_US.UTF-8 (your .zshrc exports LANG/LC_ALL=en_US.UTF-8).
# procps gives pgrep/pkill (tmux-sessionizer uses pgrep). gnupg for the docker key.
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo zsh tmux fzf procps locales-all git curl ca-certificates gnupg \
      ripgrep fd-find unzip \
      python3 python3-pip python3-venv \
      build-essential \
    && rm -rf /var/lib/apt/lists/*

# ---- 2. Node.js + corepack ---------------------------------------------
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y nodejs \
    && corepack enable \
    && rm -rf /var/lib/apt/lists/*

# ---- 3. Neovim (pinned tarball) ----------------------------------------
RUN curl -L "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
      -o /tmp/nvim.tar.gz \
    && tar -C /tmp -xzf /tmp/nvim.tar.gz \
    && mv /tmp/nvim-linux-x86_64 /opt/nvim \
    && ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim \
    && rm /tmp/nvim.tar.gz

# ---- 4. Docker CLI (docker-outside-of-docker) --------------------------
# Only the CLI — it talks to the HOST daemon via the socket your compose file
# mounts (-v /var/run/docker.sock:/var/run/docker.sock). For the mounted socket
# to be writable by devuser, devuser must be in a group whose GID matches the
# socket's owner GID on the host; handle that in compose (group_add) or with a
# DOCKER_GID build-arg + groupadd. Verify against your setup.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
         -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
         > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# ---- 5. non-root user with passwordless sudo ---------------------------
RUN groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /usr/bin/zsh "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME"

USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR /home/$USERNAME

# ---- 6. git identity ----------------------------------------------------
# core.autocrlf input added to match the WSL script (normalizes endings on commit).
RUN git config --global user.name  "$GIT_USER_NAME" \
    && git config --global user.email "$GIT_USER_EMAIL" \
    && git config --global --add safe.directory '*' \
    && git config --global core.autocrlf input

# ---- 7. Oh My Zsh + p10k + plugins -------------------------------------
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
         "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" \
    && git clone https://github.com/zsh-users/zsh-autosuggestions \
         "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting \
         "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

# ---- 8. Neovim config (pinned ref) -------------------------------------
RUN git clone "$NVIM_CONFIG_REPO" "$HOME/.config/nvim" \
    && git -C "$HOME/.config/nvim" checkout "$NVIM_CONFIG_REF"

# ---- 9. obsidian.nvim workspaces ---------------------------------------
# chzzk-dl-live ADDED (was missing) — obsidian.nvim errors on a missing workspace.
# Empty dirs only: the image stays rebuildable; sync real notes via git at runtime
# rather than baking a stale snapshot in.
RUN mkdir -p "$HOME/notes/personal" "$HOME/notes/donbass-post" \
             "$HOME/notes/donbass-tour" "$HOME/notes/chzzk-dl-live"

# ---- 10. dotfiles -------------------------------------------------------
COPY --chown=$USERNAME:$USERNAME dotfiles/.zshrc            $HOME/.zshrc
COPY --chown=$USERNAME:$USERNAME dotfiles/.p10k.zsh         $HOME/.p10k.zsh
COPY --chown=$USERNAME:$USERNAME dotfiles/.tmux.conf        $HOME/.tmux.conf
COPY --chown=$USERNAME:$USERNAME dotfiles/tmux-sessionizer  $HOME/.local/bin/tmux-sessionizer
# COPY pulls these from the Windows host, so strip CRLF or zsh/tmux break on \r.
RUN chmod +x "$HOME/.local/bin/tmux-sessionizer" \
    && sed -i 's/\r$//' "$HOME/.zshrc" "$HOME/.p10k.zsh" "$HOME/.tmux.conf" \
         "$HOME/.local/bin/tmux-sessionizer" \
    && mkdir -p "$HOME/workspace"

# ---- 11. pipx + CLIs ----------------------------------------------------
# black + isort REPLACED by ruff (ruff covers format + import-sort + lint).
# Debian's Python is externally managed (PEP 668), hence --break-system-packages.
RUN python3 -m pip install --user --break-system-packages pipx \
    && "$HOME/.local/bin/pipx" ensurepath \
    && "$HOME/.local/bin/pipx" install tldr \
    && "$HOME/.local/bin/pipx" install ruff

# ---- 12. pre-warm Neovim (lazy sync + Mason) ---------------------------
RUN nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
RUN nvim --headless \
      "+MasonInstall css-lsp eslint-lsp html-lsp intelephense json-lsp \
       lua-language-server prettier prisma-language-server pyright ruff \
       stylua tailwindcss-language-server taplo typescript-language-server \
       yaml-language-server" \
      +qa 2>/dev/null || true

# ~/.ssh is mounted read-only by your compose file — no copy step here (this is
# where the WSL script differs: WSL has no mount, so it copies keys from Windows).

CMD ["zsh"]

# ===================== Re-adding Gemini (if you ever want it) =============
# Removed to match wsl-setup.sh. To restore, add after the Node step:
#   RUN npm install -g @google/gemini-cli
# and COPY your GEMINI.md / slash-command files into place as before.
