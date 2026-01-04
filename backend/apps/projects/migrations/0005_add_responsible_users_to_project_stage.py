# Generated manually

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0004_alter_projectsheet_responsible_department'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name='projectstage',
            name='responsible_users',
            field=models.ManyToManyField(
                blank=True,
                related_name='responsible_stages',
                to=settings.AUTH_USER_MODEL,
                verbose_name='Ответственные лица'
            ),
        ),
    ]

