FROM debian:bookworm-slim

# Pin the Neovim binary version and (optionally) the nvim config ref.
# Use a git branch/tag/commit SHA for NVIM_CONFIG_REF.
ARG NVIM_VERSION=v0.11.6
ARG NVIM_CONFIG_REF=nvim-0.11.6-r13

# Install required packages
# procps - gives you pgrep, pkill, ps
RUN apt-get update && apt-get install -y \
    zsh \
    docker.io \
    tmux \
    fzf \
    procps \
    locales-all \
    git \
    curl \
    ripgrep \
    fd-find \
    unzip \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# NodeSource's setup script adds their apt repo for a specific Node version.
# We curl and pipe to bash — standard practice for NodeSource.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Download and install Neovim from the official release archive
RUN curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" && \
    tar -xzf nvim-linux-x86_64.tar.gz && \
    mv nvim-linux-x86_64 /opt/nvim && \
    ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim && \
    rm nvim-linux-x86_64.tar.gz

# Create a non-root user (much safer and recommended)
RUN useradd -m -s /bin/zsh devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/devuser && \
    chmod 0440 /etc/sudoers.d/devuser

# Add devuser to the root group (GID 0) which owns /var/run/docker.sock on the host.
# This gives devuser socket access without needing full root privileges.
RUN usermod -aG root devuser

# Install Gemini CLI globally via npm.
# Requires Node 20+, which is why we installed from NodeSource above.
RUN npm install -g @google/gemini-cli

USER devuser
WORKDIR /home/devuser

# Configure git identity and safe directory for devuser.
# Without this, git complains about dubious ownership on mounted volumes
# (because the workspace folder is owned by a different UID on the host).
RUN git config --global user.name "lavet13" && \
    git config --global user.email "lavet13@mail.ru" && \
    git config --global --add safe.directory /home/devuser/workspace && \
    git config --global --add safe.directory '*'

# Install Oh My Zsh (unattended)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install Powerlevel10k theme
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# ====================== Install Oh My Zsh plugins ======================
RUN git clone https://github.com/zsh-users/zsh-autosuggestions \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Clone Neovim config and checkout the requested ref (branch/tag/commit)
RUN mkdir -p "$HOME/.config" && \
    git clone https://github.com/lavet13/nvim-lsp.git "$HOME/.config/nvim" && \
    cd "$HOME/.config/nvim" && \
    git checkout "$NVIM_CONFIG_REF"

# Prevent obsidian.nvim startup error by creating expected note workspaces
RUN mkdir -p "$HOME/notes/personal" "$HOME/notes/donbass-post" "$HOME/notes/donbass-tour"

# --chown ensures copied files are owned by devuser, not root.
# Without this, COPY always creates files owned by root even after USER devuser.
# Copy your custom config files (this brings in your plugins, cleaned PATH, p10k settings, etc.)
COPY --chown=devuser:devuser dotfiles/.zshrc .zshrc
COPY --chown=devuser:devuser dotfiles/.p10k.zsh .p10k.zsh
COPY --chown=devuser:devuser dotfiles/.tmux.conf .tmux.conf

COPY --chown=devuser:devuser dotfiles/tmux-sessionizer .local/bin/tmux-sessionizer
RUN chmod +x ~/.local/bin/tmux-sessionizer

# Strip Windows CRLF line endings from dotfiles copied from Windows host.
# tmux, zsh and most Unix tools break silently with \r\n line endings.
RUN sed -i 's/\r//' ~/.tmux.conf ~/.zshrc ~/.p10k.zsh \
    ~/.local/bin/tmux-sessionizer

# Pre-install all lazy.nvim plugins during build so they're baked into the image.
# --headless runs Neovim without UI (safe for scripting inside Docker).
# "+Lazy! sync" tells lazy to install/sync all plugins from the lockfile.
# "|| true" prevents build failure if any plugin has a non-fatal warning.
RUN nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

# Pre-install Mason LSP servers, linters and formatters during build.
# These are the exact packages from your current setup.
# Mason package names use kebab-case and must match the Mason registry exactly.
RUN nvim --headless \
    "+MasonInstall css-lsp eslint-lsp html-lsp intelephense json-lsp \
    lua-language-server prettier prisma-language-server pylint pyright \
    stylua tailwindcss-language-server taplo typescript-language-server \
    yaml-language-server" \
    +qa 2>/dev/null || true

# Install pipx and tldr (as the devuser)
RUN python3 -m pip install --user --break-system-packages pipx && \
    ~/.local/bin/pipx ensurepath && \
    ~/.local/bin/pipx install tldr && \
    ~/.local/bin/pipx install black && \
    ~/.local/bin/pipx install isort

CMD ["zsh"]
