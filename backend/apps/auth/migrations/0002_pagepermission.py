# Generated manually

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('user_auth', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='PagePermission',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('page_name', models.CharField(choices=[('home', 'Главная'), ('tasks', 'Задачи'), ('settings', 'Настройки'), ('users_list', 'Список пользователей'), ('departments_list', 'Список отделов')], max_length=50, verbose_name='Страница')),
                ('has_access', models.BooleanField(default=False, verbose_name='Есть доступ')),
                ('department', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='page_permissions', to='user_auth.department', verbose_name='Отдел')),
            ],
            options={
                'verbose_name': 'Право доступа к странице',
                'verbose_name_plural': 'Права доступа к страницам',
                'unique_together': {('page_name', 'department')},
            },
        ),
    ]

