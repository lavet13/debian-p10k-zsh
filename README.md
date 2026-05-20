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

### Ежедневный workflow с docker compose

В проекте есть `docker-compose.yml` с сервисом `app`. Ниже два режима работы: **постоянный** (рекомендуется) и **временный**.

#### Режим A: постоянный контейнер (рекомендуется)

Этот режим удобен на каждый день: контейнер живёт между сессиями, ты просто заходишь в него через `exec`.

```bash
# 1) Пересобрать образ (когда менялся Dockerfile)
docker compose build app

# 2) Поднять контейнер в фоне
docker compose up -d

# 3) Зайти в shell внутри уже запущенного контейнера
docker compose exec app zsh

# 4) Проверить статус
docker compose ps

# 5) Остановить и удалить контейнеры проекта, когда закончил
docker compose down
```

#### Режим B: временный контейнер (ephemeral)

Этот режим создаёт одноразовый контейнер. С `--rm` он удаляется после выхода.

```bash
docker compose run --rm app
```

Используй этот режим, когда нужна чистая одноразовая сессия. Для повседневной работы обычно удобнее режим A.

#### Полезные команды compose

|            Команда            |                      Описание                       |
| :---------------------------: | :-------------------------------------------------: |
|  `docker compose build app`   |                Пересобрать образ app                |
|    `docker compose up -d`     |      Запустить контейнер(ы) в фоне (detached)       |
| `docker compose exec app zsh` |      Подключиться к уже запущенному контейнеру      |
| `docker compose run --rm app` | Запустить новый одноразовый интерактивный контейнер |
|     `docker compose down`     |   Остановить и удалить контейнеры и сеть проекта    |
|      `docker compose ps`      |              Показать статус сервисов               |
|   `docker compose logs -f`    |          Смотреть логи в реальном времени           |


---

### Ежедневный workflow без compose (docker run + docker exec)

Если не хочешь использовать `docker compose`, можно работать напрямую через `docker run`/`docker exec`.

#### Вариант A: постоянный контейнер (без `--rm`)

```bash
# 1) Собрать образ
docker build -t my-debian-p10k:latest .

# 2) Запустить постоянный контейнер с именем
docker run -it -d --name debian-p10k my-debian-p10k:latest

# 3) Подключиться к уже запущенному контейнеру
docker exec -it debian-p10k zsh

# 4) Проверить, что контейнер жив
docker ps

# 5) Остановить/запустить снова при необходимости
docker stop debian-p10k
docker start debian-p10k
```

#### Вариант B: одноразовый контейнер (`--rm`)

```bash
docker run -it --rm my-debian-p10k:latest
```

Этот вариант полезен для быстрых тестов. Для постоянной ежедневной работы удобнее вариант A.

### Сборка с фиксированной версией Neovim и nvim-конфига

Можно передать версии через build args:

```bash
docker build \
  --build-arg NVIM_VERSION=v0.11.6 \
  --build-arg NVIM_CONFIG_REF=nvim-0.11.6 \
  -t my-debian-p10k:latest .
```

Где `NVIM_CONFIG_REF` может быть веткой, тегом или commit SHA для воспроизводимой сборки.

Проверить внутри контейнера:

```bash
nvim --version
git -C ~/.config/nvim rev-parse --abbrev-ref HEAD
git -C ~/.config/nvim rev-parse HEAD
```

Что делают эти две команды:

- `git -C ~/.config/nvim rev-parse --abbrev-ref HEAD` — показывает **имя текущей ветки** (например `main`) в репозитории конфига.
- `git -C ~/.config/nvim rev-parse HEAD` — показывает **точный commit SHA**, который сейчас checkout-нут.

Зачем это нужно:

- ты быстро видишь, что действительно оказался на нужной ветке/теге;
- если ты пинишь `NVIM_CONFIG_REF` на commit, второй командой можно проверить полную воспроизводимость сборки.

### То же самое через docker compose

Если используешь `docker compose`, образ можно пересобрать с теми же build args:

```bash
docker compose build \
  --build-arg NVIM_VERSION=v0.11.6 \
  --build-arg NVIM_CONFIG_REF=nvim-0.11.6 app
```

После пересборки запусти контейнер и проверь версии:

```bash
docker compose run --rm app zsh -lc 'nvim --version | head -n 1; git -C ~/.config/nvim rev-parse --abbrev-ref HEAD; git -C ~/.config/nvim rev-parse HEAD'
```

### Мини cookbook: merge `--no-ff` и cherry-pick

Ниже короткий практический сценарий для ветки поддержки `nvim-0.11`.

```bash
# 1) Вносим фикс в ветку поддержки
git checkout nvim-0.11
git pull
git checkout -b fix/obsidian-path
# ... правки ...
git add .
git commit -m "fix(obsidian): adjust workspace path handling"
git push -u origin fix/obsidian-path
# (создай PR в nvim-0.11 и смержи)
```

```bash
# 2A) Перенести ВСЕ изменения из nvim-0.11 в main как отдельный merge-коммит
git checkout main
git pull
git merge --no-ff nvim-0.11 -m "merge: bring nvim-0.11 maintenance updates"
git push
```

```bash
# 2B) Перенести только ОДИН нужный коммит в main (без полного merge)
git checkout main
git pull
git log --oneline nvim-0.11
# выбери нужный SHA, например abc1234
git cherry-pick abc1234
git push
```

```bash
# 3) Создать новый стабильный snapshot-тег в ветке поддержки
# (старый тег nvim-0.11.6 НЕ трогаем)
git checkout nvim-0.11
git pull
git tag -a nvim-0.11.6-r1 -m "maintenance release for Neovim 0.11.6"
git push origin nvim-0.11.6-r1
```

Почему `--no-ff` полезен: даже когда Git может просто "подвинуть" указатель `main`, флаг заставляет создать явный merge-коммит, чтобы в истории было видно, что изменения пришли именно из ветки `nvim-0.11`.

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
