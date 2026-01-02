"""
Скрипт для создания суперпользователя
Использование: python manage.py shell < create_superuser.py
Или: docker-compose exec backend python manage.py shell < create_superuser.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.dev')
django.setup()

from django.contrib.auth.models import User

username = os.environ.get('SUPERUSER_USERNAME', 'admin')
email = os.environ.get('SUPERUSER_EMAIL', 'admin@example.com')
password = os.environ.get('SUPERUSER_PASSWORD', 'admin123')

if User.objects.filter(username=username).exists():
    print(f'Пользователь {username} уже существует')
else:
    User.objects.create_superuser(username=username, email=email, password=password)
    print(f'Суперпользователь {username} создан успешно')


