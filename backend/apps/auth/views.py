"""
API views для авторизации
"""
from rest_framework import status, generics, viewsets
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from django.contrib.auth.models import User
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from .models import Department, UserProfile, PagePermission


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
    return Response({
        'id': user.id,
        'username': user.username,
        'is_superuser': user.is_superuser,
    }, status=status.HTTP_200_OK)


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
    """ViewSet для управления пользователями (только для суперпользователей)"""
    queryset = User.objects.all().order_by('id')
    pagination_class = UserPagination
    permission_classes = [IsAuthenticated, IsAdminUser]
    
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
        return self._update_user(user, request.data, partial=False)
    
    def partial_update(self, request, *args, **kwargs):
        """Частичное обновление пользователя (PATCH)"""
        user = self.get_object()
        return self._update_user(user, request.data, partial=True)
    
    def _update_user(self, user, data, partial=False):
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
    # #region agent log
    import json
    log_path = r'r:\dev\my-tracker\my_tracker_v0.1\.cursor\debug.log'
    try:
        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps({
                'sessionId': 'debug-session',
                'runId': 'run1',
                'hypothesisId': 'A',
                'location': 'views.py:457',
                'message': 'page_permissions called',
                'data': {'user': request.user.username if request.user.is_authenticated else None},
                'timestamp': int(__import__('time').time() * 1000)
            }) + '\n')
    except: pass
    # #endregion
    try:
        departments = Department.objects.all().order_by('name')
        pages = [choice[0] for choice in PagePermission.PAGE_CHOICES]
        
        # Получаем все права доступа
        permissions = PagePermission.objects.select_related('department').all()
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'A',
                    'location': 'views.py:475',
                    'message': 'departments and permissions loaded',
                    'data': {
                        'departments_count': departments.count(),
                        'permissions_count': permissions.count(),
                        'department_names': [d.name for d in departments]
                    },
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
        # Создаем словарь для быстрого доступа: page_name -> department_id -> has_access
        permissions_map = {}
        for perm in permissions:
            if perm.department:
                if perm.page_name not in permissions_map:
                    permissions_map[perm.page_name] = {}
                permissions_map[perm.page_name][perm.department.id] = perm.has_access
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'A',
                    'location': 'views.py:492',
                    'message': 'permissions_map created',
                    'data': {'map_keys': list(permissions_map.keys()), 'map_size': len(permissions_map)},
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
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
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'A',
                    'location': 'views.py:515',
                    'message': 'pages_data created',
                    'data': {
                        'pages_count': len(pages_data),
                        'first_page_departments_count': len(pages_data[0]['departments']) if pages_data else 0
                    },
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
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
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'A',
                    'location': 'views.py:535',
                    'message': 'page_permissions error',
                    'data': {'error': str(e)},
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_page_permissions(request):
    """Обновление прав доступа"""
    # #region agent log
    import json
    log_path = r'r:\dev\my-tracker\my_tracker_v0.1\.cursor\debug.log'
    try:
        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps({
                'sessionId': 'debug-session',
                'runId': 'run1',
                'hypothesisId': 'B',
                'location': 'views.py:505',
                'message': 'update_page_permissions called',
                'data': {
                    'user': request.user.username if request.user.is_authenticated else None,
                    'permissions_count': len(request.data.get('permissions', []))
                },
                'timestamp': int(__import__('time').time() * 1000)
            }) + '\n')
    except: pass
    # #endregion
    try:
        permissions_data = request.data.get('permissions', [])
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'B',
                    'location': 'views.py:520',
                    'message': 'permissions_data received',
                    'data': {'permissions': permissions_data[:5]},  # Первые 5 для примера
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
        updated_count = 0
        for perm_data in permissions_data:
            page_name = perm_data.get('page_name')
            department_id = perm_data.get('department_id')
            has_access = perm_data.get('has_access', False)
            
            if not page_name or not department_id:
                continue
            
            try:
                department = Department.objects.get(id=department_id)
                perm, created = PagePermission.objects.update_or_create(
                    page_name=page_name,
                    department=department,
                    defaults={'has_access': has_access}
                )
                updated_count += 1
                # #region agent log
                try:
                    with open(log_path, 'a', encoding='utf-8') as f:
                        f.write(json.dumps({
                            'sessionId': 'debug-session',
                            'runId': 'run1',
                            'hypothesisId': 'B',
                            'location': 'views.py:545',
                            'message': 'permission updated',
                            'data': {
                                'page_name': page_name,
                                'department_id': department_id,
                                'department_name': department.name,
                                'has_access': has_access,
                                'created': created
                            },
                            'timestamp': int(__import__('time').time() * 1000)
                        }) + '\n')
                except: pass
                # #endregion
            except Department.DoesNotExist:
                continue
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'B',
                    'location': 'views.py:565',
                    'message': 'update_page_permissions completed',
                    'data': {'updated_count': updated_count},
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
        return Response({'message': 'Права доступа обновлены'})
    except Exception as e:
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'B',
                    'location': 'views.py:575',
                    'message': 'update_page_permissions error',
                    'data': {'error': str(e)},
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_permissions(request):
    """Получение доступных страниц для текущего пользователя"""
    # #region agent log
    import json
    log_path = r'r:\dev\my-tracker\my_tracker_v0.1\.cursor\debug.log'
    try:
        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps({
                'sessionId': 'debug-session',
                'runId': 'run1',
                'hypothesisId': 'C',
                'location': 'views.py:590',
                'message': 'user_permissions called',
                'data': {
                    'user': request.user.username,
                    'is_superuser': request.user.is_superuser
                },
                'timestamp': int(__import__('time').time() * 1000)
            }) + '\n')
    except: pass
    # #endregion
    try:
        user = request.user
        
        # Суперпользователь видит все страницы
        if user.is_superuser:
            pages = [choice[0] for choice in PagePermission.PAGE_CHOICES]
            # #region agent log
            try:
                with open(log_path, 'a', encoding='utf-8') as f:
                    f.write(json.dumps({
                        'sessionId': 'debug-session',
                        'runId': 'run1',
                        'hypothesisId': 'C',
                        'location': 'views.py:605',
                        'message': 'superuser - all pages',
                        'data': {'pages': pages},
                        'timestamp': int(__import__('time').time() * 1000)
                    }) + '\n')
            except: pass
            # #endregion
            return Response({'pages': pages})
        
        # Получаем отдел пользователя
        department = None
        if hasattr(user, 'profile') and user.profile.department:
            department = user.profile.department
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'C',
                    'location': 'views.py:620',
                    'message': 'user department check',
                    'data': {
                        'has_profile': hasattr(user, 'profile'),
                        'department_id': department.id if department else None,
                        'department_name': department.name if department else None
                    },
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
        # Если у пользователя нет отдела, видит только главную
        if not department:
            # #region agent log
            try:
                with open(log_path, 'a', encoding='utf-8') as f:
                    f.write(json.dumps({
                        'sessionId': 'debug-session',
                        'runId': 'run1',
                        'hypothesisId': 'C',
                        'location': 'views.py:635',
                        'message': 'no department - only home',
                        'data': {},
                        'timestamp': int(__import__('time').time() * 1000)
                    }) + '\n')
            except: pass
            # #endregion
            return Response({'pages': ['home']})
        
        # Получаем права доступа для отдела
        permissions = PagePermission.objects.filter(
            department=department,
            has_access=True
        ).values_list('page_name', flat=True)
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'C',
                    'location': 'views.py:650',
                    'message': 'permissions queried',
                    'data': {
                        'permissions_count': permissions.count(),
                        'permissions': list(permissions)
                    },
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
        # Главная страница всегда доступна
        pages = ['home'] + list(permissions)
        
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'C',
                    'location': 'views.py:665',
                    'message': 'user_permissions result',
                    'data': {'pages': pages},
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        
        return Response({'pages': pages})
    except Exception as e:
        # #region agent log
        try:
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps({
                    'sessionId': 'debug-session',
                    'runId': 'run1',
                    'hypothesisId': 'C',
                    'location': 'views.py:675',
                    'message': 'user_permissions error',
                    'data': {'error': str(e)},
                    'timestamp': int(__import__('time').time() * 1000)
                }) + '\n')
        except: pass
        # #endregion
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )

