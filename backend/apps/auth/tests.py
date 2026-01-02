"""
Тесты для проверки доступа по отделам
"""
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from .models import Department, UserProfile, PagePermission


class DepartmentPagePermissionsTest(TestCase):
    """Тесты для проверки доступа по отделам"""
    
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
        
        # Создаем пользователей (профиль создается автоматически через сигнал)
        self.it_user = User.objects.create_user(
            username='it_user',
            password='testpass123'
        )
        # Обновляем существующий профиль, устанавливая отдел
        self.it_user.profile.department = self.it_department
        self.it_user.profile.save()
        
        self.hr_user = User.objects.create_user(
            username='hr_user',
            password='testpass123'
        )
        # Обновляем существующий профиль, устанавливая отдел
        self.hr_user.profile.department = self.hr_department
        self.hr_user.profile.save()
        
        self.user_no_department = User.objects.create_user(
            username='no_dept_user',
            password='testpass123'
        )
        # Профиль создается автоматически через сигнал, но без отдела
        
        self.superuser = User.objects.create_superuser(
            username='admin',
            password='adminpass123'
        )
        
        # Устанавливаем права доступа для IT отдела
        PagePermission.objects.create(
            page_name='tasks',
            department=self.it_department,
            has_access=True
        )
        PagePermission.objects.create(
            page_name='settings',
            department=self.it_department,
            has_access=True
        )
        PagePermission.objects.create(
            page_name='users_list',
            department=self.it_department,
            has_access=False  # Нет доступа
        )
        
        # Устанавливаем права доступа для HR отдела
        PagePermission.objects.create(
            page_name='users_list',
            department=self.hr_department,
            has_access=True
        )
        PagePermission.objects.create(
            page_name='tasks',
            department=self.hr_department,
            has_access=False  # Нет доступа
        )
    
    def _get_auth_token(self, user):
        """Получить токен для пользователя"""
        refresh = RefreshToken.for_user(user)
        return str(refresh.access_token)
    
    def test_it_user_sees_only_allowed_pages(self):
        """Проверка: пользователь IT отдела видит только страницы с has_access=True"""
        token = self._get_auth_token(self.it_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/auth/user-permissions/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        pages = response.data['pages']
        
        # Должен видеть home (всегда доступна), tasks и settings
        self.assertIn('home', pages)
        self.assertIn('tasks', pages)
        self.assertIn('settings', pages)
        
        # НЕ должен видеть users_list (has_access=False)
        self.assertNotIn('users_list', pages)
        
        # Проверяем, что нет других страниц
        expected_pages = {'home', 'tasks', 'settings'}
        self.assertEqual(set(pages), expected_pages)
    
    def test_hr_user_sees_only_allowed_pages(self):
        """Проверка: пользователь HR отдела видит только страницы с has_access=True"""
        token = self._get_auth_token(self.hr_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/auth/user-permissions/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        pages = response.data['pages']
        
        # Должен видеть home (всегда доступна) и users_list
        self.assertIn('home', pages)
        self.assertIn('users_list', pages)
        
        # НЕ должен видеть tasks (has_access=False)
        self.assertNotIn('tasks', pages)
        
        # Проверяем, что нет других страниц
        expected_pages = {'home', 'users_list'}
        self.assertEqual(set(pages), expected_pages)
    
    def test_user_without_department_sees_only_home(self):
        """Проверка: пользователь без отдела видит только главную страницу"""
        token = self._get_auth_token(self.user_no_department)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/auth/user-permissions/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        pages = response.data['pages']
        
        # Должен видеть только home
        self.assertEqual(pages, ['home'])
    
    def test_superuser_sees_all_pages(self):
        """Проверка: суперпользователь видит все страницы независимо от настроек"""
        token = self._get_auth_token(self.superuser)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        
        response = self.client.get('/api/auth/user-permissions/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        pages = response.data['pages']
        
        # Должен видеть все страницы
        expected_pages = {'home', 'tasks', 'settings', 'users_list', 'departments_list'}
        self.assertEqual(set(pages), expected_pages)
    
    def test_permission_checkbox_controls_access(self):
        """Проверка: доступ контролируется чекбоксом has_access"""
        # Создаем новый отдел и пользователя
        sales_department = Department.objects.create(
            name='Sales',
            description='Отдел продаж',
            color='#FF0000'
        )
        sales_user = User.objects.create_user(
            username='sales_user',
            password='testpass123'
        )
        # Обновляем существующий профиль, устанавливая отдел
        sales_user.profile.department = sales_department
        sales_user.profile.save()
        
        # Изначально нет доступа ни к одной странице (кроме home)
        token = self._get_auth_token(sales_user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        response = self.client.get('/api/auth/user-permissions/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(set(response.data['pages']), {'home'})
        
        # Устанавливаем доступ к tasks (has_access=True)
        PagePermission.objects.create(
            page_name='tasks',
            department=sales_department,
            has_access=True
        )
        
        # Теперь должен видеть tasks
        response = self.client.get('/api/auth/user-permissions/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        pages = response.data['pages']
        self.assertIn('tasks', pages)
        self.assertEqual(set(pages), {'home', 'tasks'})
        
        # Убираем доступ (has_access=False)
        permission = PagePermission.objects.get(
            page_name='tasks',
            department=sales_department
        )
        permission.has_access = False
        permission.save()
        
        # Теперь НЕ должен видеть tasks
        response = self.client.get('/api/auth/user-permissions/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        pages = response.data['pages']
        self.assertNotIn('tasks', pages)
        self.assertEqual(set(pages), {'home'})

