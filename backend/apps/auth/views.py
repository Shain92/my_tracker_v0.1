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
from .models import Department, UserProfile


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
            department.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )

