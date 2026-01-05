"""
Команда для создания проектных листов для проекта Благоустройство(Крыльца)
Создает по 7 листов для каждого статуса типа 'sheet' с назначением ответственных отделов
"""
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from apps.projects.models import Project, Status, ProjectSheet
from apps.auth.models import Department


class Command(BaseCommand):
    help = 'Создает набор проектных листов для проекта Благоустройство(Крыльца)'

    def handle(self, *args, **options):
        # Поиск проекта
        project_name = 'Благоустройство(Крыльца)'
        try:
            project = Project.objects.get(name=project_name)
            self.stdout.write(
                self.style.SUCCESS(f'Найден проект: {project.name} (ID: {project.id})')
            )
        except Project.DoesNotExist:
            # Попробуем с пробелом
            try:
                project = Project.objects.get(name='Благоустройство (Крыльца)')
                self.stdout.write(
                    self.style.SUCCESS(f'Найден проект: {project.name} (ID: {project.id})')
                )
            except Project.DoesNotExist:
                self.stdout.write(
                    self.style.ERROR(f'Проект "{project_name}" не найден')
                )
                return
        except Project.MultipleObjectsReturned:
            projects = Project.objects.filter(name__icontains='Благоустройство')
            self.stdout.write(
                self.style.WARNING(f'Найдено несколько проектов:')
            )
            for p in projects:
                self.stdout.write(f'  - ID: {p.id}, Название: {p.name}, Код: {p.code}')
            self.stdout.write(
                self.style.ERROR('Пожалуйста, уточните проект')
            )
            return

        # Получение всех статусов типа 'sheet'
        statuses = Status.objects.filter(status_type='sheet')
        if not statuses.exists():
            self.stdout.write(
                self.style.ERROR('Не найдено статусов типа "sheet"')
            )
            return

        self.stdout.write(
            self.style.SUCCESS(f'Найдено статусов: {statuses.count()}')
        )

        # Получение всех отделов
        departments = list(Department.objects.all())
        if not departments:
            self.stdout.write(
                self.style.WARNING('Не найдено отделов. Листы будут созданы без ответственных отделов.')
            )
        else:
            self.stdout.write(
                self.style.SUCCESS(f'Найдено отделов: {len(departments)}')
            )

        # Получение первого пользователя для created_by (или None)
        first_user = User.objects.first()

        # Создание листов
        total_created = 0
        department_index = 0
        
        for status in statuses:
            self.stdout.write(f'\nСоздание листов для статуса: {status.name}')
            for i in range(1, 8):  # 7 листов
                # Назначение отдела циклически
                responsible_department = None
                if departments:
                    responsible_department = departments[department_index % len(departments)]
                    department_index += 1
                
                sheet = ProjectSheet.objects.create(
                    project=project,
                    status=status,
                    name=f'Лист {i} - {status.name}',
                    description=f'Проектный лист {i} для статуса {status.name}',
                    created_by=first_user,
                    responsible_department=responsible_department,
                )
                total_created += 1
                dept_info = f', Отдел: {responsible_department.name}' if responsible_department else ''
                self.stdout.write(
                    f'  ✓ Создан лист: {sheet.name} (ID: {sheet.id}{dept_info})'
                )

        self.stdout.write(
            self.style.SUCCESS(
                f'\nВсего создано листов: {total_created}'
            )
        )

