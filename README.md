# My Tracker

Проект на Django + Flutter с авторизацией через JWT токены.

## Структура проекта

```
my_tracker_v0.1/
├── backend/          # Django REST API
├── frontend/         # Flutter приложение
├── docker-compose.dev.yml
├── docker-compose.prod.yml
└── start_dev.sh
```

## Требования

- Docker и Docker Compose
- Flutter SDK (для локальной разработки Flutter)
- Python 3.11+ (для локальной разработки Django)

## Быстрый старт

### Разработка (Dev окружение)

1. Запустите dev окружение:
```bash
./start_dev.sh
```

Или вручную:
```bash
docker-compose -f docker-compose.dev.yml up --build
```

2. Backend будет доступен на `http://localhost:8000`
3. API endpoints:
   - `POST /api/auth/register/` - регистрация
   - `POST /api/auth/login/` - вход
   - `POST /api/auth/refresh/` - обновление токена

### Flutter приложение

Для запуска Flutter приложения локально:

1. Перейдите в директорию frontend:
```bash
cd frontend
```

2. Установите зависимости:
```bash
flutter pub get
```

3. Запустите приложение:
   - Android: `flutter run`
   - Windows: `flutter run -d windows`
   - Web: `flutter run -d chrome`

**Важно:** Для работы с Web убедитесь, что backend запущен и доступен на `http://localhost:8000`

## Настройка окружения

### Dev окружение

Файл `.env.dev` содержит настройки для разработки. По умолчанию:
- DEBUG=True
- База данных: PostgreSQL на localhost:5432
- CORS разрешен для всех источников

### Prod окружение

Файл `.env.prod` содержит настройки для продакшена. **Обязательно измените:**
- `SECRET_KEY` - на безопасный ключ
- `DB_PASSWORD` - на безопасный пароль
- `ALLOWED_HOSTS` - на ваш домен
- `CORS_ALLOWED_ORIGINS` - на ваш домен

## Запуск в продакшене

```bash
docker-compose -f docker-compose.prod.yml up --build -d
```

## Миграции базы данных

При первом запуске выполните миграции:

```bash
docker-compose -f docker-compose.dev.yml exec backend python manage.py migrate
```

## Создание суперпользователя

### Способ 1: Интерактивный (рекомендуется)
Выполните в терминале:
```bash
docker-compose -f docker-compose.dev.yml exec -it backend python manage.py createsuperuser
```

### Способ 2: Через Django shell
```bash
docker-compose -f docker-compose.dev.yml exec backend python manage.py shell
```
Затем в shell выполните:
```python
from django.contrib.auth.models import User
User.objects.create_superuser('admin', 'admin@example.com', 'your_password')
```

### Способ 3: Через переменные окружения
```bash
docker-compose -f docker-compose.dev.yml exec -e SUPERUSER_USERNAME=admin -e SUPERUSER_EMAIL=admin@example.com -e SUPERUSER_PASSWORD=admin123 backend python manage.py shell < backend/create_superuser.py
```

## API Endpoints

### Регистрация
```bash
POST /api/auth/register/
Content-Type: application/json

{
  "username": "user123",
  "password": "password123"
}
```

### Вход
```bash
POST /api/auth/login/
Content-Type: application/json

{
  "username": "user123",
  "password": "password123"
}
```

### Ответ содержит:
```json
{
  "access": "jwt_access_token",
  "refresh": "jwt_refresh_token",
  "user": {
    "id": 1,
    "username": "user123"
  }
}
```

## Платформы Flutter

Приложение поддерживает:
- Android
- Windows (Desktop)
- Web

## Разработка

### Backend

- Django 5.0.6
- Django REST Framework
- JWT авторизация (djangorestframework-simplejwt)
- PostgreSQL

### Frontend

- Flutter 3.x
- HTTP клиент для API
- SharedPreferences для хранения токенов

## Остановка

```bash
docker-compose -f docker-compose.dev.yml down
```

Или для продакшена:
```bash
docker-compose -f docker-compose.prod.yml down
```

