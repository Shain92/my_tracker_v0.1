"""
Тесты для проверки фильтрации этапов и листов на странице задач
"""
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from apps.auth.models import Department, UserProfile
from .models import (
    Status, ConstructionSite, Project, ProjectSheet, ProjectStage
)


class TasksScreenFilteringTest(TestCase):
    """Тесты для проверки фильтрации этапов и листов на странице задач"""
    
    def setUp(self):
        """Настройка тестовых данных"""
        self.client = APIClient()
        
        # Создаем отделы
        self.it_department = Department.objects.create(
            name='IT',
            description='IT отдел',
            color='#0000FF'
        )
        self.hr_department = Department.objects.create(
            name='HR',
            description='HR отдел',
            color='#00FF00'
        )
        
        # Создаем пользователей
        self.user1 = User.objects.create_user(
            username='user1',
            password='testpass123'
        )
        self.user1.profile.department = self.it_department
        self.user1.profile.save()
        
        self.user2 = User.objects.create_user(
            username='user2',
            password='testpass123'
        )
        self.user2.profile.department = self.hr_department
        self.user2.profile.save()
        
        self.user3 = User.objects.create_user(
            username='user3',
            password='testpass123'
        )
        self.user3.profile.department = self.it_department
        self.user3.profile.save()
        
        # Создаем строительные участки
        self.site1 = ConstructionSite.objects.create(
            name='Участок 1',
            description='Описание участка 1'
        )
        self.site2 = ConstructionSite.objects.create(
            name='Участок 2',
            description='Описание участка 2'
        )
        
        # Создаем проекты
        self.project1 = Project.objects.create(
            name='Проект 1',
            code='P1',
            cipher='C1',
            construction_site=self.site1
        )
        self.project2 = Project.objects.create(
            name='Проект 2',
            code='P2',
            cipher='C2',
            construction_site=self.site1
        )
        self.project3 = Project.objects.create(
            name='Проект 3',
            code='P3',
            cipher='C3',
            construction_site=self.site2
        )
        
        # Создаем статусы
        self.stage_status = Status.objects.create(
            name='В работе',
            color='#FF0000',
            status_type='stage'
        )
        self.sheet_status = Status.objects.create(
            name='Активный',
            color='#00FF00',
            status_type='sheet'
        )
        
        # Создаем этапы
        # Этап 1: user1 - ответственный
        self.stage1 = ProjectStage.objects.create(
            project=self.project1,
            datetime=timezone.now(),
            author=self.user1,
            description='Этап 1',
            status=self.stage_status
        )
        self.stage1.responsible_users.add(self.user1)
        
        # Этап 2: user2 - ответственный
        self.stage2 = ProjectStage.objects.create(
            project=self.project1,
            datetime=timezone.now(),
            author=self.user2,
            description='Этап 2',
            status=self.stage_status
        )
        self.stage2.responsible_users.add(self.user2)
        
        # Этап 3: user1 - автор, но не ответственный
        self.stage3 = ProjectStage.objects.create(
            project=self.project2,
            datetime=timezone.now(),
            author=self.user1,
            description='Этап 3',
            status=self.stage_status
        )
        
        # Этап 4: user3 - ответственный
        self.stage4 = ProjectStage.objects.create(
            project=self.project3,
            datetime=timezone.now(),
            author=self.user3,
            description='Этап 4',
            status=self.stage_status
        )
        self.stage4.responsible_users.add(self.user3)
        
        # Создаем листы
        # Лист 1: IT отдел
        self.sheet1 = ProjectSheet.objects.create(
            name='Лист 1',
            project=self.project1,
            responsible_department=self.it_department,
            status=self.sheet_status,
            is_completed=False
        )
        
        # Лист 2: HR отдел
        self.sheet2 = ProjectSheet.objects.create(
            name='Лист 2',
            project=self.project1,
            responsible_department=self.hr_department,
            status=self.sheet_status,
            is_completed=False
        )
        
        # Лист 3: IT отдел, выполнен
        self.sheet3 = ProjectSheet.objects.create(
            name='Лист 3',
            project=self.project2,
            responsible_department=self.it_department,
            status=self.sheet_status,
            is_completed=True
        )
        
        # Лист 4: IT отдел, другой участок
        self.sheet4 = ProjectSheet.objects.create(
            name='Лист 4',
            project=self.project3,
            responsible_department=self.it_department,
            status=self.sheet_status,
            is_completed=False
        )
    
    def _get_auth_token(self, user):
        """Получить токен для пользователя"""
        refresh = RefreshToken.for_user(user)
        return str(refresh.access_token)
    
    # Тесты для фильтрации этапов
    
    def test_user_sees_only_their_stages(self):
        """Проверка: пользователь видит только этапы, где он ответственный или автор, или этапы своего отдела"""
        token = self._get_auth_token(self.user1)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/projects/project-stages/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # user1 должен видеть:
        # - stage1 (user1 - ответственный, IT отдел)
        # - stage3 (user1 - автор, IT отдел)
        # - stage4 (user3 - ответственный, но тоже IT отдел, поэтому виден)
        # НЕ должен видеть stage2 (user2 - ответственный, HR отдел)
        stage_ids = [stage['id'] for stage in results]
        self.assertIn(self.stage1.id, stage_ids)
        self.assertIn(self.stage3.id, stage_ids)
        self.assertIn(self.stage4.id, stage_ids)  # user3 в том же отделе (IT)
        self.assertNotIn(self.stage2.id, stage_ids)  # user2 - ответственный, но другой отдел (HR)
    
    def test_user_does_not_see_other_users_stages(self):
        """Проверка: пользователь не видит этапы других отделов"""
        token = self._get_auth_token(self.user2)  # user2 в HR отделе
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/projects/project-stages/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # user2 (HR отдел) должен видеть только stage2 (ответственный, HR отдел)
        # Не должен видеть этапы IT отдела (stage1, stage3, stage4)
        stage_ids = [stage['id'] for stage in results]
        self.assertIn(self.stage2.id, stage_ids)
        self.assertNotIn(self.stage1.id, stage_ids)  # IT отдел
        self.assertNotIn(self.stage3.id, stage_ids)  # IT отдел
        self.assertNotIn(self.stage4.id, stage_ids)  # IT отдел
    
    def test_user_sees_stages_from_same_department(self):
        """Проверка: пользователь видит этапы других пользователей из своего отдела"""
        token = self._get_auth_token(self.user1)  # user1 в IT отделе
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/projects/project-stages/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # user1 (IT отдел) должен видеть:
        # - stage1 (user1 - ответственный, IT)
        # - stage3 (user1 - автор, IT)
        # - stage4 (user3 - ответственный, но тоже IT отдел)
        stage_ids = [stage['id'] for stage in results]
        self.assertIn(self.stage1.id, stage_ids)
        self.assertIn(self.stage3.id, stage_ids)
        self.assertIn(self.stage4.id, stage_ids)  # user3 в том же отделе
    
    def test_stage_filtering_by_construction_site(self):
        """Проверка: фильтрация этапов по строительному участку"""
        token = self._get_auth_token(self.user1)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        # Фильтруем по site1
        response = self.client.get(
            f'/api/projects/project-stages/?construction_site_id={self.site1.id}'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # user1 должен видеть только этапы из site1 (stage1, stage3)
        stage_ids = [stage['id'] for stage in results]
        self.assertIn(self.stage1.id, stage_ids)
        self.assertIn(self.stage3.id, stage_ids)
        self.assertNotIn(self.stage4.id, stage_ids)  # stage4 в site2
    
    def test_stage_filtering_by_project(self):
        """Проверка: фильтрация этапов по проекту"""
        token = self._get_auth_token(self.user1)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        # Фильтруем по project1
        response = self.client.get(
            f'/api/projects/project-stages/?project_id={self.project1.id}'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # user1 должен видеть только stage1 из project1
        stage_ids = [stage['id'] for stage in results]
        self.assertIn(self.stage1.id, stage_ids)
        self.assertNotIn(self.stage3.id, stage_ids)  # stage3 в project2
    
    # Тесты для фильтрации листов
    
    def test_user_sees_only_department_sheets(self):
        """Проверка: пользователь видит только листы своего отдела"""
        token = self._get_auth_token(self.user1)  # user1 в IT отделе
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        # Получаем ID отдела пользователя
        department_id = self.user1.profile.department.id
        
        response = self.client.get(
            f'/api/projects/project-sheets/?department_id={department_id}'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # user1 должен видеть только листы IT отдела
        sheet_ids = [sheet['id'] for sheet in results]
        self.assertIn(self.sheet1.id, sheet_ids)  # IT отдел
        self.assertIn(self.sheet3.id, sheet_ids)  # IT отдел
        self.assertIn(self.sheet4.id, sheet_ids)  # IT отдел
        self.assertNotIn(self.sheet2.id, sheet_ids)  # HR отдел
    
    def test_user_does_not_see_other_department_sheets(self):
        """Проверка: пользователь не видит листы других отделов"""
        token = self._get_auth_token(self.user2)  # user2 в HR отделе
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        # Получаем ID отдела пользователя
        department_id = self.user2.profile.department.id
        
        response = self.client.get(
            f'/api/projects/project-sheets/?department_id={department_id}'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # user2 должен видеть только листы HR отдела
        sheet_ids = [sheet['id'] for sheet in results]
        self.assertIn(self.sheet2.id, sheet_ids)  # HR отдел
        self.assertNotIn(self.sheet1.id, sheet_ids)  # IT отдел
        self.assertNotIn(self.sheet3.id, sheet_ids)  # IT отдел
        self.assertNotIn(self.sheet4.id, sheet_ids)  # IT отдел
    
    def test_sheet_filtering_by_construction_site(self):
        """Проверка: фильтрация листов по строительному участку"""
        token = self._get_auth_token(self.user1)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        department_id = self.user1.profile.department.id
        
        # Фильтруем по site1
        response = self.client.get(
            f'/api/projects/project-sheets/?department_id={department_id}&construction_site_id={self.site1.id}'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # Должны быть только листы IT отдела из site1
        sheet_ids = [sheet['id'] for sheet in results]
        self.assertIn(self.sheet1.id, sheet_ids)  # IT, site1
        self.assertIn(self.sheet3.id, sheet_ids)  # IT, site1 (project2 в site1)
        self.assertNotIn(self.sheet4.id, sheet_ids)  # IT, но site2
    
    def test_sheet_filtering_by_project(self):
        """Проверка: фильтрация листов по проекту"""
        token = self._get_auth_token(self.user1)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        department_id = self.user1.profile.department.id
        
        # Фильтруем по project1
        response = self.client.get(
            f'/api/projects/project-sheets/?department_id={department_id}&project_id={self.project1.id}'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # Должен быть только sheet1 (IT отдел, project1)
        sheet_ids = [sheet['id'] for sheet in results]
        self.assertIn(self.sheet1.id, sheet_ids)
        self.assertNotIn(self.sheet3.id, sheet_ids)  # project2
        self.assertNotIn(self.sheet4.id, sheet_ids)  # project3
    
    def test_sheet_filtering_by_completion_status(self):
        """Проверка: фильтрация листов по статусу выполнения"""
        token = self._get_auth_token(self.user1)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        department_id = self.user1.profile.department.id
        
        # Фильтруем только выполненные
        response = self.client.get(
            f'/api/projects/project-sheets/?department_id={department_id}&is_completed=true'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # Должен быть только sheet3 (выполнен)
        sheet_ids = [sheet['id'] for sheet in results]
        self.assertIn(self.sheet3.id, sheet_ids)
        self.assertNotIn(self.sheet1.id, sheet_ids)  # не выполнен
        self.assertNotIn(self.sheet4.id, sheet_ids)  # не выполнен
        
        # Фильтруем только невыполненные
        response = self.client.get(
            f'/api/projects/project-sheets/?department_id={department_id}&is_completed=false'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        results = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        
        # Должны быть sheet1 и sheet4 (не выполнены)
        sheet_ids = [sheet['id'] for sheet in results]
        self.assertIn(self.sheet1.id, sheet_ids)
        self.assertIn(self.sheet4.id, sheet_ids)
        self.assertNotIn(self.sheet3.id, sheet_ids)  # выполнен
