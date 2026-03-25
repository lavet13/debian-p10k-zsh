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

**Вариант А (просто и быстро):**

```bash
docker run -it --rm my-debian-p10k:latest
```

**Вариант B (рекомендуется — через docker-compose):**

```bash
docker compose up -d
```

```bash
docker compose exec app zsh
```

Готово! Ты сразу окажешься в красивом терминале с Powerlevel10k.

---

### Работа с docker-compose (рекомендуемый способ)

В проекте есть файл `docker-compose.yml`, который сильно упрощает работу.

## Основные команды:

|           Команда           |                 Описание                  |
| :-------------------------: | :---------------------------------------: |
|    docker compose build     |         Собрать/пересобрать образ         |
|    docker compsoe up -d     |        Запустить контейнер в фоне         |
| docker compose exec app zsh | Подключиться к контейнеру (рекомендуется) |
| docker compose run --rm app |  Запустить новый интерактивный контейнер  |
|     docker compose down     |      Остановить и удалить контейнер       |
|      docker compose ps      |        Показать статус контейнеров        |
|   docker compose logs -f    |              Посмотреть логи              |

# Самая удобная ежедневная команда:
```bash
docker compose run --rm app
```

---

### Полезные команды

|                           Команда                           |                Описание                 |
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
или через compose:
```bash
docker compose build
```

## Структура проекта
```text
debian-p10k-zsh/
├── Dockerfile
├── docker-compose.yml
├── dotfiles/
│   ├── .zshrc
│   └── .p10k.zsh
└── README.md
```

---

### Что внутри

- **База**: `debian:bookworm-slim`
- **Оболочка**: Zsh + Oh My Zsh
- Тема: Powerlevel10k (с твоей конфигурацией)
- Плагины: autosuggestions, syntax-highlighting, git
- Утилиты: tldr, pipx, git, curl и другие
