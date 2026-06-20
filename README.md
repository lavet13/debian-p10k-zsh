# Debian + Zsh + Powerlevel10k — провижининг WSL

Скрипт `wsl-setup.sh` быстро превращает свежий **WSL Debian** в готовое окружение
разработки: zsh + Powerlevel10k, Neovim, tmux, Node и нужные инструменты.

Раньше это был Docker-образ. Теперь всё ставится **прямо в WSL** — нативная
файловая система ext4 заметно быстрее, чем bind-mount больших проектов в Docker
через границу Windows ↔ Linux.

---

## Что внутри

- **Zsh** + **Oh My Zsh** + **Powerlevel10k**
- Плагины: `zsh-autosuggestions`, `zsh-syntax-highlighting`, `git`
- **Neovim** (закреплённая версия, бинарник из официального релиза) + конфиг
  [`nvim-lsp`](https://github.com/lavet13/nvim-lsp) + Mason LSP-серверы и форматтеры
- **tmux** + `tmux-sessionizer` (fzf-переключатель проектов)
- **Node.js** (NodeSource) + `corepack` (для Yarn)
- `pipx` + `tldr` + `ruff`, клиент **cheat.sh** (`cht.sh`), `shellcheck`, `info` + `bash-doc`
- Dotfiles: `.zshrc`, `.zshenv`, `.p10k.zsh`, `.tmux.conf`
- Заметки для obsidian.nvim (клон [`notes-obsidian`](https://github.com/lavet13/notes-obsidian))
- SSH-ключи копируются из Windows (`/mnt/c/Users/<user>/.ssh`)

---

## Установка

На свежем WSL Debian сначала выполни (нужен `git`, чтобы склонировать репозиторий):

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y git
git clone https://github.com/lavet13/debian-p10k-zsh.git
cd debian-p10k-zsh
bash wsl-setup.sh
```

После завершения:

```bash
wsl --shutdown   # из PowerShell / CMD / MINGW64
```

Снова открой Debian — окажешься в zsh.

> **Если на свежем дистрибутиве не работает DNS** («Temporary failure resolving …»),
> почини это **до** запуска скрипта — обычно виноват KillSwitch VPN. Либо добавь
> DNS-серверы в исключения VPN-клиента, либо закрепи `/etc/resolv.conf`
> (`nameserver 1.1.1.1` / `8.8.8.8`) с `[network] generateResolvConf=false` в
> `/etc/wsl.conf`, затем `wsl --shutdown` и открой заново.

---

## Что делает скрипт

1. Системные пакеты (zsh, tmux, fzf, ripgrep, fd-find, shellcheck, info, bash-doc и т.д.)
2. Node.js + corepack (пропускается, если нужная мажорная версия уже стоит)
3. Neovim — закреплённый тарбол в `/opt/nvim`, симлинк в `/usr/local/bin`
4. Git-идентичность + `core.autocrlf input`
5. Копирование SSH-ключей из Windows + правка прав; добавление `github.com` в `known_hosts`
6. Oh My Zsh + Powerlevel10k + плагины
7. Конфиг Neovim — клон `nvim-lsp` (живой рабочий клон на ветке `main`)
8. Заметки — клон `notes-obsidian` (или `git pull --ff-only`, если уже склонировано)
9. Dotfiles + удаление CRLF
10. pipx + tldr + ruff + клиент cheat.sh
11. Прогрев Neovim: `Lazy! restore` (по lock-файлу) + установка Mason-пакетов
12. Смена оболочки по умолчанию на zsh

Скрипт **идемпотентен** — каждый шаг либо пропускается, либо безопасно
применяется повторно. Исключение: dotfiles всегда перезаписываются из
репозитория (репозиторий — источник истины).

---

## Кастомизация

- **Dotfiles**: правь файлы в `dotfiles/`, коммить и пушь — следующий запуск
  скрипта их подхватит.
- **Конфиг Neovim**: `~/.config/nvim` — это живой рабочий клон `nvim-lsp` на
  ветке `main`. Правь на месте, коммить, пушь. Плагины: `:Lazy sync` обновляет
  их и lock-файл — коммить новый `lazy-lock.json`, когда обновляешься осознанно.

---

## Структура проекта

```text
debian-p10k-zsh/
├── wsl-setup.sh
├── dotfiles/
│   ├── .zshrc
│   ├── .zshenv
│   ├── .p10k.zsh
│   ├── .tmux.conf
│   └── tmux-sessionizer
├── .gitattributes        # * text=auto eol=lf — единые LF во всём репозитории
└── README.md
```

---

## Docker для проектов (не для окружения)

Если Docker нужен для самих проектов (например, Postgres/Prisma у бота), не ставь
демон в WSL вручную — включи **Docker Desktop → Settings → Resources → WSL
Integration** для Debian. После этого `docker` работает в WSL без дополнительной
установки.
