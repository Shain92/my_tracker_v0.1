# Generated manually

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('user_auth', '0002_pagepermission'),
    ]

    operations = [
        # Изменение PAGE_CHOICES не требует миграции БД,
        # так как это только валидация на уровне приложения.
        # Новые страницы: 'projects' (Проекты), 'project_id' (Строительные участки) 
        # и 'statuses_list' (Статусы) добавлены в модель PagePermission.PAGE_CHOICES
    ]

