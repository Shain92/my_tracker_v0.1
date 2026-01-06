"""
API views для авторизации
"""
from rest_framework import status, generics, viewsets
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser, BasePermission
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from rest_framework.filters import SearchFilter
from django.contrib.auth.models import User
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from .models import Department, UserProfile, PagePermission


class HasPagePermission(BasePermission):
    """Проверка доступа к странице через PagePermission"""
    
    def __init__(self, page_name):
        self.page_name = page_name
        super().__init__()
    
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        # Суперпользователь имеет доступ ко всему
        if request.user.is_superuser:
            return True
        
        # Получаем отдел пользователя
        department = None
        if hasattr(request.user, 'profile') and request.user.profile.department:
            department = request.user.profile.department
        
        # Если у пользователя нет отдела, доступ только к главной
        if not department:
            return self.page_name == 'home'
        
        # Проверяем права доступа через PagePermission
        has_access = PagePermission.objects.filter(
            page_name=self.page_name,
            department=department,
            has_access=True
        ).exists()
        
        return has_access


@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    """Регистрация нового пользователя"""
    username = request.data.get('username')
    password = request.data.get('password')
    
    if not username or not password:
        return Response(
            {'error': 'Username и password обязательны'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    if User.objects.filter(username=username).exists():
        return Response(
            {'error': 'Пользователь с таким username уже существует'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user = User.objects.create_user(username=username, password=password)
    refresh = RefreshToken.for_user(user)
    
    return Response({
        'refresh': str(refresh),
        'access': str(refresh.access_token),
        'user': {
            'id': user.id,
            'username': user.username,
            'is_superuser': user.is_superuser,
        }
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    """Вход пользователя"""
    username = request.data.get('username')
    password = request.data.get('password')
    
    if not username or not password:
        return Response(
            {'error': 'Username и password обязательны'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    user = authenticate(username=username, password=password)
    
    if user is None:
        return Response(
            {'error': 'Неверные учетные данные'},
            status=status.HTTP_401_UNAUTHORIZED
        )
    
    refresh = RefreshToken.for_user(user)
    
    return Response({
        'refresh': str(refresh),
        'access': str(refresh.access_token),
        'user': {
            'id': user.id,
            'username': user.username,
            'is_superuser': user.is_superuser,
        }
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def current_user(request):
    """Получение информации о текущем пользователе"""
    user = request.user
    response_data = {
        'id': user.id,
        'username': user.username,
        'is_superuser': user.is_superuser,
    }
    
    # Добавляем информацию об отделе, если есть профиль
    if hasattr(user, 'profile') and user.profile.department:
        department = user.profile.department
        response_data['department_id'] = department.id
        response_data['department'] = {
            'id': department.id,
            'name': department.name,
            'color': department.color,
        }
    else:
        response_data['department_id'] = None
        response_data['department'] = None
    
    return Response(response_data, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def users_list(request):
    """Получение списка пользователей"""
    users = User.objects.all()
    return Response([
        {
            'id': user.id,
            'username': user.username,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'email': user.email,
        }
        for user in users
    ], status=status.HTTP_200_OK)


class UserPagination(PageNumberPagination):
    """Пагинация для списка пользователей"""
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class UserViewSet(viewsets.ModelViewSet):
    """ViewSet для управления пользователями"""
    queryset = User.objects.all().order_by('id')
    pagination_class = UserPagination
    permission_classes = [IsAuthenticated]
    filter_backends = [SearchFilter]
    search_fields = ['username', 'first_name', 'last_name', 'email']
    
    def get_permissions(self):
        """Возвращает permissions в зависимости от действия"""
        # Для чтения (list, retrieve) - доступ для всех авторизованных пользователей
        # Это необходимо для назначения начальника участка при создании Строительного Участка
        if self.action in ['list', 'retrieve']:
            return [IsAuthenticated()]
        # Для создания, обновления, удаления - проверяем доступ к странице users_list
        # Суперпользователи всегда имеют доступ
        return [IsAuthenticated(), HasPagePermission('users_list')]
    
    def get_serializer_class(self):
        """Возвращает сериализатор в зависимости от действия"""
        # Используем простой сериализатор, так как Django User модель
        return None
    
    def _get_user_data(self, user):
        """Вспомогательный метод для получения данных пользователя"""
        department_data = None
        if hasattr(user, 'profile') and user.profile.department:
            department_data = {
                'id': user.profile.department.id,
                'name': user.profile.department.name,
                'color': user.profile.department.color,
            }
        
        return {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'is_superuser': user.is_superuser,
            'is_active': user.is_active,
            'date_joined': user.date_joined.isoformat() if user.date_joined else None,
            'department': department_data,
        }
    
    def list(self, request, *args, **kwargs):
        """Получение списка пользователей с пагинацией"""
        page = self.paginate_queryset(self.queryset)
        if page is not None:
            users_data = [self._get_user_data(user) for user in page]
            return self.get_paginated_response(users_data)
        
        users_data = [self._get_user_data(user) for user in self.queryset]
        return Response(users_data)
    
    def retrieve(self, request, *args, **kwargs):
        """Получение одного пользователя"""
        user = self.get_object()
        return Response(self._get_user_data(user))
    
    def create(self, request, *args, **kwargs):
        """Создание нового пользователя"""
        username = request.data.get('username')
        password = request.data.get('password')
        email = request.data.get('email', '')
        first_name = request.data.get('first_name', '')
        last_name = request.data.get('last_name', '')
        is_superuser = request.data.get('is_superuser', False)
        is_active = request.data.get('is_active', True)
        department_id = request.data.get('department_id')
        
        if not username or not password:
            return Response(
                {'error': 'Username и password обязательны'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if User.objects.filter(username=username).exists():
            return Response(
                {'error': 'Пользователь с таким username уже существует'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = User.objects.create_user(
                username=username,
                password=password,
                email=email,
                first_name=first_name,
                last_name=last_name,
                is_superuser=is_superuser,
                is_active=is_active
            )
            
            # Назначение отдела, если указан
            if department_id:
                try:
                    department = Department.objects.get(id=department_id)
                    if hasattr(user, 'profile'):
                        user.profile.department = department
                        user.profile.save()
                except Department.DoesNotExist:
                    pass
            
            department_data = None
            if hasattr(user, 'profile') and user.profile.department:
                department_data = {
                    'id': user.profile.department.id,
                    'name': user.profile.department.name,
                }
            
            return Response({
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'is_superuser': user.is_superuser,
                'is_active': user.is_active,
                'date_joined': user.date_joined.isoformat() if user.date_joined else None,
                'department': department_data,
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    def update(self, request, *args, **kwargs):
        """Обновление пользователя (PUT)"""
        user = self.get_object()
        return self._update_user(request, user, request.data, partial=False)
    
    def partial_update(self, request, *args, **kwargs):
        """Частичное обновление пользователя (PATCH)"""
        user = self.get_object()
        return self._update_user(request, user, request.data, partial=True)
    
    def _update_user(self, request, user, data, partial=False):
        """Вспомогательный метод для обновления пользователя"""
        if 'username' in data:
            new_username = data['username']
            if new_username != user.username and User.objects.filter(username=new_username).exists():
                return Response(
                    {'error': 'Пользователь с таким username уже существует'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            user.username = new_username
        
        if 'email' in data:
            user.email = data['email']
        if 'first_name' in data:
            user.first_name = data['first_name']
        if 'last_name' in data:
            user.last_name = data['last_name']
        if 'is_superuser' in data:
            user.is_superuser = data['is_superuser']
        if 'is_active' in data:
            user.is_active = data['is_active']
        
        if 'password' in data and data['password']:
            user.set_password(data['password'])
        
        # Обновление отдела
        if 'department_id' in data:
            department_id = data['department_id']
            if not hasattr(user, 'profile'):
                UserProfile.objects.create(user=user)
            
            if department_id is None:
                user.profile.department = None
            else:
                try:
                    department = Department.objects.get(id=department_id)
                    user.profile.department = department
                except Department.DoesNotExist:
                    return Response(
                        {'error': 'Отдел не найден'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            user.profile.save()
        
        try:
            user.save()
            return Response(self._get_user_data(user))
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    def destroy(self, request, *args, **kwargs):
        """Удаление пользователя"""
        user = self.get_object()
        # Не позволяем удалять самого себя
        if user == request.user:
            return Response(
                {'error': 'Нельзя удалить самого себя'},
                status=status.HTTP_400_BAD_REQUEST
            )
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
    @action(detail=True, methods=['post'])
    def change_password(self, request, pk=None):
        """Смена пароля пользователя"""
        user = self.get_object()
        new_password = request.data.get('password')
        
        if not new_password:
            return Response(
                {'error': 'Пароль обязателен'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if len(new_password) < 8:
            return Response(
                {'error': 'Пароль должен содержать минимум 8 символов'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user.set_password(new_password)
            user.save()
            return Response({'message': 'Пароль успешно изменен'})
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )


class DepartmentViewSet(viewsets.ModelViewSet):
    """ViewSet для управления отделами"""
    queryset = Department.objects.all().order_by('name')
    permission_classes = [IsAuthenticated]
    
    def get_permissions(self):
        """Возвращает permissions в зависимости от действия"""
        # Для чтения списка (list) - все авторизованные пользователи (нужно для выбора отдела при редактировании пользователя)
        if self.action == 'list':
            return [IsAuthenticated()]
        # Для просмотра одного отдела (retrieve) проверяем через PagePermission
        if self.action == 'retrieve':
            return [IsAuthenticated(), HasPagePermission('departments_list')]
        # Для создания, обновления, удаления - только суперпользователи
        return [IsAuthenticated(), IsAdminUser()]
    
    def get_serializer_class(self):
        return None
    
    def retrieve(self, request, *args, **kwargs):
        """Получение одного отдела"""
        try:
            department = self.get_object()
            return Response({
                'id': department.id,
                'name': department.name,
                'description': department.description,
                'color': department.color,
            })
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    def list(self, request, *args, **kwargs):
        """Получение списка отделов"""
        # Принудительно обновляем queryset, чтобы получить свежие данные
        departments = Department.objects.all().order_by('name')
        departments_data = [
            {
                'id': dept.id,
                'name': dept.name,
                'description': dept.description,
                'color': dept.color,
            }
            for dept in departments
        ]
        return Response(departments_data)
    
    def create(self, request, *args, **kwargs):
        """Создание нового отдела"""
        name = request.data.get('name')
        description = request.data.get('description', '')
        color = request.data.get('color', '#000000')
        
        if not name:
            return Response(
                {'error': 'Название отдела обязательно'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            department = Department.objects.create(
                name=name,
                description=description,
                color=color
            )
            return Response({
                'id': department.id,
                'name': department.name,
                'description': department.description,
                'color': department.color,
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    def update(self, request, *args, **kwargs):
        """Обновление отдела"""
        department = self.get_object()
        name = request.data.get('name')
        description = request.data.get('description')
        color = request.data.get('color')
        
        if not name:
            return Response(
                {'error': 'Название отдела обязательно'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            department.name = name
            if description is not None:
                department.description = description
            if color is not None:
                department.color = color
            department.save()
            
            return Response({
                'id': department.id,
                'name': department.name,
                'description': department.description,
                'color': department.color,
            })
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    def destroy(self, request, *args, **kwargs):
        """Удаление отдела"""
        try:
            department = self.get_object()
            # Удаляем связанные PagePermission перед удалением отдела
            department.page_permissions.all().delete()
            department.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def page_permissions(request):
    """Получение матрицы прав доступа"""
    try:
        departments = Department.objects.all().order_by('name')
        pages = [choice[0] for choice in PagePermission.PAGE_CHOICES]
        
        # Получаем все права доступа
        permissions = PagePermission.objects.select_related('department').all()
        
        # Создаем словарь для быстрого доступа: page_name -> department_id -> has_access
        permissions_map = {}
        for perm in permissions:
            if perm.department:
                if perm.page_name not in permissions_map:
                    permissions_map[perm.page_name] = {}
                permissions_map[perm.page_name][perm.department.id] = perm.has_access
        
        # Формируем структуру данных - показываем ВСЕ отделы для ВСЕХ страниц
        pages_data = []
        for page_name, page_label in PagePermission.PAGE_CHOICES:
            departments_data = []
            for dept in departments:
                # Получаем значение has_access из permissions_map, если нет - False
                has_access = permissions_map.get(page_name, {}).get(dept.id, False)
                departments_data.append({
                    'department_id': dept.id,
                    'department_name': dept.name or '',
                    'has_access': has_access,
                })
            pages_data.append({
                'page_name': page_name,
                'page_label': page_label,
                'departments': departments_data,
            })
        
        departments_data = [
            {
                'id': dept.id,
                'name': dept.name,
            }
            for dept in departments
        ]
        
        return Response({
            'pages': pages_data,
            'departments': departments_data,
        })
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_page_permissions(request):
    """Обновление прав доступа"""
    try:
        permissions_data = request.data.get('permissions', [])
        
        for perm_data in permissions_data:
            page_name = perm_data.get('page_name')
            department_id = perm_data.get('department_id')
            has_access = perm_data.get('has_access', False)
            
            if not page_name or not department_id:
                continue
            
            try:
                department = Department.objects.get(id=department_id)
                PagePermission.objects.update_or_create(
                    page_name=page_name,
                    department=department,
                    defaults={'has_access': has_access}
                )
            except Department.DoesNotExist:
                continue
        
        return Response({'message': 'Права доступа обновлены'})
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_permissions(request):
    """Получение доступных страниц для текущего пользователя"""
    try:
        user = request.user
        
        # Суперпользователь видит все страницы
        if user.is_superuser:
            pages = [choice[0] for choice in PagePermission.PAGE_CHOICES]
            return Response({'pages': pages})
        
        # Получаем отдел пользователя
        department = None
        if hasattr(user, 'profile') and user.profile.department:
            department = user.profile.department
        
        # Если у пользователя нет отдела, видит только главную
        if not department:
            return Response({'pages': ['home']})
        
        # Получаем права доступа для отдела
        permissions = PagePermission.objects.filter(
            department=department,
            has_access=True
        ).values_list('page_name', flat=True)
        
        # Главная страница всегда доступна
        pages = ['home'] + list(permissions)
        
        return Response({'pages': pages})
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )

