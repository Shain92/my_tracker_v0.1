# Generated manually

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0002_add_created_by_to_project_sheet'),
        ('user_auth', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='projectsheet',
            name='responsible_department',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='project_sheets',
                to='user_auth.department',
                verbose_name='Ответственный отдел'
            ),
        ),
    ]

