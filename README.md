# Debian + Zsh + Powerlevel10k Docker Image

Готовый удобный Docker-образ на базе Debian с современной настройкой терминала.

### Что внутри

- **Debian Bookworm** (slim)
- **Zsh** + **Oh My Zsh**
- **Powerlevel10k** — самая красивая и быстрая тема для zsh
- Полезные плагины:
  - `zsh-autosuggestions`
  - `zsh-syntax-highlighting`
  - `git`
- `pipx` + `tldr`
- Часовой пояс **Europe/Moscow**
- Чистая и удобная конфигурация `.zshrc`

---

## Как быстро запустить

### 1. Клонировать репозиторий

```bash
git clone https://github.com/lavet13/debian-p10k-zsh.git
cd debian-p10k-zsh
```

### 2. Собрать Docker-образ

```bash
docker build -t my-debian-p10k:latest .
```

### 3. Запустить контейнер

```bash
docker run -it --rm my-debian-p10k:latest
```

Готово! Ты сразу окажешься в красивом терминале с Powerlevel10k.

### Полезные команды

|                           Команды                           |                Описание                 |
| :---------------------------------------------------------: | :-------------------------------------: |
|           docker build -t my-debian-p10k:latest .           |              Собрать образ              |
|          docker run -it --rm my-debian-p10k:latest          |        Запустить новый контейнер        |
| docker run -it -v "$(pwd):/workspace" my-debian-p10k:latest | Запустить с монтированием текущей папки |

### Как добавить свои изменения

- Отредактируй файлы в папке `dotfiles/` (`.zshrc` или `.p10k.zsh`)
- Пересобери образ

```bash
docker build -t my-debian-p10k:latest --no-cache .
```

### Что внутри

- **База**: `debian:bookworm-slim`
- **Оболочка**: Zsh + Oh My Zsh
- Тема: Powerlevel10k (с твоей конфигурацией)
- Плагины: autosuggestions, syntax-highlighting, git
- Утилиты: tldr, pipx, git, curl и другие
