from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MinValueValidator, MaxValueValidator
from apps.auth.models import Department


class Status(models.Model):
    """Модель статусов для проектных листов и этапов проекта"""
    STATUS_TYPES = [
        ('sheet', 'Проектный лист'),
        ('stage', 'Этап проекта'),
    ]
    
    name = models.CharField('Название', max_length=100)
    color = models.CharField('Цвет', max_length=7, default='#000000')  # HEX цвет
    status_type = models.CharField('Тип', max_length=10, choices=STATUS_TYPES)
    created_at = models.DateTimeField('Создан', auto_now_add=True)
    
    class Meta:
        verbose_name = 'Статус'
        verbose_name_plural = 'Статусы'
        unique_together = ['name', 'status_type']
    
    def __str__(self):
        return f"{self.name} ({self.get_status_type_display()})"


class ConstructionSite(models.Model):
    """Строительный участок"""
    name = models.CharField('Название', max_length=200)
    description = models.TextField('Описание', blank=True, null=True)
    manager = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='managed_sites',
        verbose_name='Начальник участка'
    )
    created_at = models.DateTimeField('Создан', auto_now_add=True)
    updated_at = models.DateTimeField('Обновлен', auto_now=True)
    
    class Meta:
        verbose_name = 'Строительный участок'
        verbose_name_plural = 'Строительные участки'
    
    def __str__(self):
        return self.name
    
    @property
    def completion_percentage(self):
        """Процент выполнения участка (средний процент всех проектов)"""
        projects = self.projects.all()
        if not projects.exists():
            return 0.0
        total_percentage = sum(project.completion_percentage for project in projects)
        return round(total_percentage / projects.count(), 2)


class Project(models.Model):
    """Проект"""
    name = models.CharField('Название', max_length=200)
    description = models.TextField('Описание', blank=True, null=True)
    code = models.CharField('Код', max_length=50)
    cipher = models.CharField('Шифр', max_length=50)
    construction_site = models.ForeignKey(
        ConstructionSite,
        on_delete=models.CASCADE,
        related_name='projects',
        verbose_name='Строительный участок'
    )
    created_at = models.DateTimeField('Создан', auto_now_add=True)
    updated_at = models.DateTimeField('Обновлен', auto_now=True)
    
    class Meta:
        verbose_name = 'Проект'
        verbose_name_plural = 'Проекты'
        unique_together = ['code', 'cipher']
    
    def __str__(self):
        return f"{self.name} ({self.code})"
    
    @property
    def completion_percentage(self):
        """Процент выполнения проекта (выполненные листы / все листы)"""
        sheets = self.sheets.all()
        if not sheets.exists():
            return 0.0
        completed = sheets.filter(is_completed=True).count()
        return round((completed / sheets.count()) * 100, 2)
    
    @property
    def last_stage_status(self):
        """Статус последнего этапа проекта (по дате datetime)"""
        last_stage = self.stages.order_by('-datetime').first()
        if last_stage and last_stage.status:
            return last_stage.status
        return None


class ProjectSheet(models.Model):
    """Проектный лист"""
    name = models.CharField('Название', max_length=200, blank=True, null=True)
    description = models.TextField('Описание', blank=True, null=True)
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name='sheets',
        verbose_name='Проект'
    )
    status = models.ForeignKey(
        Status,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        limit_choices_to={'status_type': 'sheet'},
        related_name='project_sheets',
        verbose_name='Статус'
    )
    is_completed = models.BooleanField('Выполнено', default=False)
    completed_at = models.DateTimeField('Дата выполнения', null=True, blank=True)
    file = models.FileField('Файл', upload_to='project_sheets/', blank=True, null=True)
    executors = models.ManyToManyField(
        User,
        related_name='project_sheets',
        blank=True,
        verbose_name='Исполнители'
    )
    responsible_department = models.ForeignKey(
        Department,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='project_sheets',
        verbose_name='Ответственный отдел'
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='initiated_sheets',
        verbose_name='Инициатор'
    )
    created_at = models.DateTimeField('Создан', auto_now_add=True)
    updated_at = models.DateTimeField('Обновлен', auto_now=True)
    
    class Meta:
        verbose_name = 'Проектный лист'
        verbose_name_plural = 'Проектные листы'
    
    def __str__(self):
        return f"{self.name or 'Без названия'} - {self.project.name}"
    
    def save(self, *args, **kwargs):
        """Автоматически устанавливает дату выполнения при установке чекбокса"""
        if self.is_completed and not self.completed_at:
            from django.utils import timezone
            self.completed_at = timezone.now()
        elif not self.is_completed:
            self.completed_at = None
        super().save(*args, **kwargs)


class ProjectStage(models.Model):
    """Этап проекта"""
    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name='stages',
        verbose_name='Проект'
    )
    status = models.ForeignKey(
        Status,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        limit_choices_to={'status_type': 'stage'},
        related_name='project_stages',
        verbose_name='Статус этапа'
    )
    datetime = models.DateTimeField('Дата-время')
    author = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_stages',
        verbose_name='Автор'
    )
    responsible_users = models.ManyToManyField(
        User,
        related_name='responsible_stages',
        blank=True,
        verbose_name='Ответственные лица'
    )
    description = models.TextField('Описание', blank=True, null=True)
    file = models.FileField('Файл', upload_to='project_stages/', blank=True, null=True)
    created_at = models.DateTimeField('Создан', auto_now_add=True)
    
    class Meta:
        verbose_name = 'Этап проекта'
        verbose_name_plural = 'Этапы проекта'
        ordering = ['-datetime']
    
    def __str__(self):
        return f"{self.project.name} - {self.datetime.strftime('%d.%m.%Y %H:%M')}"


class ProjectSheetNote(models.Model):
    """Заметка проектного листа"""
    name = models.CharField('Название', max_length=200)
    note = models.TextField('Заметка')
    file = models.FileField('Файл', upload_to='project_sheet_notes/', blank=True, null=True)
    author = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='project_sheet_notes',
        verbose_name='Автор'
    )
    project_sheet = models.ForeignKey(
        ProjectSheet,
        on_delete=models.CASCADE,
        related_name='notes',
        verbose_name='Проектный лист'
    )
    created_at = models.DateTimeField('Создан', auto_now_add=True)
    updated_at = models.DateTimeField('Обновлен', auto_now=True)
    
    class Meta:
        verbose_name = 'Заметка проектного листа'
        verbose_name_plural = 'Заметки проектных листов'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.name} - {self.project_sheet.name or 'Без названия'}"


