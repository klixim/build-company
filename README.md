# Construction Company Management System

Полнофункциональная система управления строительной компанией: Go backend + PostgreSQL + веб-сайт с админ-панелью и клиентской зоной.

## Структура проекта

- `docker-compose.yml` - сервисы PostgreSQL и Go API
- `app/` - Go-приложение
  - `main.go` - основной код сервера
  - `templates/` - HTML-шаблоны для веб-сайта
    - `index.html` - главная страница
    - `login.html` - страница входа
    - `admin.html` - админ-панель
    - `client.html` - клиентская панель
  - `static/` - статические файлы
    - `css/bootstrap.min.css` - стили Bootstrap
    - `js/bootstrap.bundle.min.js` - скрипты Bootstrap
    - `uploads/` - папка для загруженных файлов
- `database/init/01-schema.sql` - схема БД, таблицы, триггеры и процедуры
- `database/init/02-data.sql` - начальные данные (более 50 записей)
- `app/Dockerfile` - инструкции для сборки Docker-образа

## Запуск

1. Перейдите в корневую папку проекта:
   ```bash
   cd /home/klixim/build-company
   ```
2. Запустите контейнеры:
   ```bash
   docker compose up --build
   ```
3. Веб-сайт будет доступен на `http://localhost:8080`

## Веб-сайт

### Главная страница (`/`)
- Приветствие и ссылки на вход для клиентов и администраторов.

### Страница входа (`/login`)
- Форма авторизации.
- После входа перенаправляет в админ-панель или клиентскую зону в зависимости от роли.

### Админ-панель (`/admin`)
- Просмотр и управление проектами, клиентами, подрядчиками и задачами.
- Создание проектов и задач через модальные окна.
- Использует API для загрузки и отправки данных.

### Клиентская панель (`/client`)
- Просмотр проектов (своих), счетов и задач (назначенных пользователю).

## API точки

### Аутентификация
- `POST /login` — авторизация, возвращает JWT и данные пользователя

### Защищенные API (требуют `Authorization: Bearer <token>`)
- `GET /api/projects` — список проектов
- `GET /api/projects/{id}` — проект по ID
- `POST /api/projects` — создание проекта
- `PUT /api/projects/{id}` — обновление проекта
- `DELETE /api/projects/{id}` — удаление проекта
- `GET /api/clients` — список клиентов
- `GET /api/contractors` — список подрядчиков
- `GET /api/tasks` — список задач, поддержка поиска `?search=`
- `POST /api/tasks` — создание задачи
- `POST /api/tasks/{id}/assign` — назначение задачи пользователю
- `POST /api/invoices` — создание счета через процедуру
- `GET /api/invoices` — список счетов
- `POST /api/upload` — загрузка файла

## Аутентификация

Запросы к `/api/*` требуют заголовок:
```http
Authorization: Bearer <token>
```

Токен получается при входе через `/login`.

## Тестовые учетные записи

- **Администратор**: admin / admin123
- **Менеджер**: mgr1 / manager123
- **Инженер**: eng1 / engineer123
- **Клиент**: client1 / client123

## База данных

- **Имя**: construction
- **Пользователь**: postgres
- **Пароль**: 14231423
- **Порт на хосте**: 5435

Подключение из контейнера:
```bash
docker exec -it build-company-db-1 psql -U postgres -d construction
```
  
Подключение извне:
```bash
psql -h localhost -p 5435 -U postgres -d construction
```

## Технологии

- **Backend**: Go (Gorilla Mux, JWT, PostgreSQL)
- **Frontend**: HTML, CSS (Bootstrap), JavaScript (Fetch API)
- **База данных**: PostgreSQL
- **Контейнеризация**: Docker, Docker Compose
# build-company
# build-company
