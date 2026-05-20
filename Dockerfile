FROM debian:bookworm-slim

# Pin the Neovim binary version and (optionally) the nvim config ref.
# Use a git branch/tag/commit SHA for NVIM_CONFIG_REF.
ARG NVIM_VERSION=v0.11.6
ARG NVIM_CONFIG_REF=nvim-0.11.6

# Install required packages
RUN apt-get update && apt-get install -y \
    zsh \
    git \
    curl \
    ripgrep \
    fd-find \
    unzip \
    nodejs \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    npm \
    sudo \
    && rm -rf /var/lib/apt/lists/*

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

USER devuser
WORKDIR /home/devuser

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

# Copy your custom config files (this brings in your plugins, cleaned PATH, p10k settings, etc.)
COPY dotfiles/.zshrc .zshrc
COPY dotfiles/.p10k.zsh .p10k.zsh

# Install pipx and tldr (as the devuser)
RUN python3 -m pip install --user --break-system-packages pipx && \
    ~/.local/bin/pipx ensurepath && \
    ~/.local/bin/pipx install tldr

CMD ["zsh"]
