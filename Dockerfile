FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    zsh \
    git \
    curl \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    && rm -rf /var/lib/apt/lists/*

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

# Copy your custom config files (this brings in your plugins, cleaned PATH, p10k settings, etc.)
COPY dotfiles/.zshrc .zshrc
COPY dotfiles/.p10k.zsh .p10k.zsh

# Install pipx and tldr (as the devuser)
RUN python3 -m pip install --user --break-system-packages pipx && \
    ~/.local/bin/pipx ensurepath && \
    ~/.local/bin/pipx install tldr

CMD ["zsh"]
