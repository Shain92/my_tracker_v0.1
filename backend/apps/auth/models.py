from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver


class Department(models.Model):
    """Отдел"""
    name = models.CharField('Название', max_length=200)
    description = models.TextField('Описание', blank=True, null=True)
    color = models.CharField('Цвет', max_length=7, default='#000000')  # HEX цвет
    
    class Meta:
        verbose_name = 'Отдел'
        verbose_name_plural = 'Отделы'
    
    def __str__(self):
        return self.name


class UserProfile(models.Model):
    """Профиль пользователя"""
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile',
        verbose_name='Пользователь'
    )
    department = models.ForeignKey(
        Department,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='users',
        verbose_name='Отдел'
    )
    
    class Meta:
        verbose_name = 'Профиль пользователя'
        verbose_name_plural = 'Профили пользователей'
    
    def __str__(self):
        return f"{self.user.username} - {self.department.name if self.department else 'Без отдела'}"


@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Автоматически создает профиль при создании пользователя"""
    if created:
        UserProfile.objects.get_or_create(user=instance)


@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    """Сохраняет профиль при сохранении пользователя"""
    if hasattr(instance, 'profile'):
        instance.profile.save()


class PagePermission(models.Model):
    """Право доступа к странице для отдела"""
    PAGE_CHOICES = [
        ('home', 'Главная'),
        ('tasks', 'Задачи'),
        ('projects', 'Проекты'),
        ('settings', 'Настройки'),
        ('users_list', 'Список пользователей'),
        ('departments_list', 'Список отделов'),
        ('project_id', 'Строительные участки'),
        ('statuses_list', 'Статусы'),
    ]
    
    page_name = models.CharField(
        'Страница',
        max_length=50,
        choices=PAGE_CHOICES
    )
    has_access = models.BooleanField(
        'Есть доступ',
        default=False
    )
    department = models.ForeignKey(
        Department,
        on_delete=models.CASCADE,
        related_name='page_permissions',
        verbose_name='Отдел'
    )
    
    class Meta:
        verbose_name = 'Право доступа к странице'
        verbose_name_plural = 'Права доступа к страницам'
        unique_together = [['page_name', 'department']]
    
    def __str__(self):
        return f"{self.department.name} - {self.get_page_name_display()}"
