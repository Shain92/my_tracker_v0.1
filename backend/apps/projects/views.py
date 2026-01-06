import json
import traceback
import os
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q, Count, F
from django.utils import timezone
from django.http import FileResponse, Http404
from datetime import datetime, timedelta
from django.contrib.auth.models import User

from apps.auth.views import HasPagePermission

from .models import (
    Status, ConstructionSite, Project, ProjectSheet,
    ProjectStage, ProjectSheetNote
)
from .serializers import (
    StatusSerializer, ConstructionSiteSerializer, ProjectSerializer,
    ProjectSheetSerializer, ProjectStageSerializer, ProjectSheetNoteSerializer,
    DashboardDataSerializer
)

# #region agent log
import os
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
LOG_PATH = BASE_DIR / '.cursor' / 'debug.log'
def _log(hypothesis_id, location, message, data=None):
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_PATH, 'a', encoding='utf-8') as f:
            f.write(json.dumps({
                'sessionId': 'debug-session',
                'runId': 'run1',
                'hypothesisId': hypothesis_id,
                'location': location,
                'message': message,
                'data': data or {},
                'timestamp': int(timezone.now().timestamp() * 1000)
            }) + '\n')
    except Exception as log_err:
        # Fallback: try to write to a simpler location
        try:
            fallback_path = BASE_DIR / 'backend' / 'debug_fallback.log'
            with open(fallback_path, 'a', encoding='utf-8') as f:
                f.write(f"LOG ERROR at {location}: {log_err}\n")
        except:
            pass

# Log module import
try:
    _log('D', 'views.py:module_import', 'views.py module imported', {'models_imported': True})
except:
    pass
# #endregion


class StatusViewSet(viewsets.ModelViewSet):
    """ViewSet для статусов"""
    queryset = Status.objects.all()
    serializer_class = StatusSerializer
    
    def __init__(self, *args, **kwargs):
        # #region agent log
        try:
            _log('D', 'StatusViewSet.__init__', 'StatusViewSet initialized')
        except:
            pass
        # #endregion
        super().__init__(*args, **kwargs)
    
    def list(self, request, *args, **kwargs):
        # #region agent log
        _log('A', 'StatusViewSet.list:entry', 'StatusViewSet.list called', {'user': str(request.user), 'authenticated': request.user.is_authenticated})
        # #endregion
        try:
            # #region agent log
            _log('A', 'StatusViewSet.list:before_query', 'Before querying Status.objects.all()')
            # #endregion
            from django.db import connection
            # #region agent log
            _log('A', 'StatusViewSet.list:check_table', 'Checking if table exists', {'table_name': Status._meta.db_table})
            try:
                with connection.cursor() as cursor:
                    cursor.execute(f"SELECT COUNT(*) FROM {Status._meta.db_table}")
                    count = cursor.fetchone()[0]
                    _log('A', 'StatusViewSet.list:table_check', 'Table exists and accessible', {'count': count})
            except Exception as table_error:
                _log('A', 'StatusViewSet.list:table_error', 'Table check failed', {'error': str(table_error)})
            # #endregion
            queryset = self.get_queryset()
            
            # Фильтрация по status_type
            status_type = request.query_params.get('status_type')
            if status_type:
                queryset = queryset.filter(status_type=status_type)
            
            # #region agent log
            _log('A', 'StatusViewSet.list:after_query', 'After querying', {'count': queryset.count(), 'status_type': status_type})
            # #endregion
            serializer = self.get_serializer(queryset, many=True)
            # #region agent log
            _log('A', 'StatusViewSet.list:after_serialize', 'After serialization', {'data_count': len(serializer.data)})
            # #endregion
            return Response(serializer.data)
        except Exception as e:
            # #region agent log
            _log('A', 'StatusViewSet.list:error', 'Exception in StatusViewSet.list', {'error': str(e), 'error_type': type(e).__name__, 'traceback': traceback.format_exc()})
            # #endregion
            raise


class ConstructionSiteViewSet(viewsets.ModelViewSet):
    """ViewSet для строительных участков"""
    queryset = ConstructionSite.objects.all()
    serializer_class = ConstructionSiteSerializer
    permission_classes = [IsAuthenticated]
    
    def get_permissions(self):
        """Возвращает permissions в зависимости от действия"""
        # Для чтения (list, retrieve) - доступ для всех авторизованных пользователей
        if self.action in ['list', 'retrieve']:
            return [IsAuthenticated()]
        # Для создания, обновления, удаления - проверяем доступ к странице project_id
        return [IsAuthenticated(), HasPagePermission('project_id')]
    
    def __init__(self, *args, **kwargs):
        # #region agent log
        try:
            _log('D', 'ConstructionSiteViewSet.__init__', 'ConstructionSiteViewSet initialized')
        except:
            pass
        # #endregion
        super().__init__(*args, **kwargs)
    
    def list(self, request, *args, **kwargs):
        # #region agent log
        _log('A', 'ConstructionSiteViewSet.list:entry', 'ConstructionSiteViewSet.list called', {'user': str(request.user), 'authenticated': request.user.is_authenticated})
        # #endregion
        try:
            # #region agent log
            _log('A', 'ConstructionSiteViewSet.list:before_query', 'Before querying ConstructionSite.objects.all()')
            # #endregion
            from django.db import connection
            # #region agent log
            _log('A', 'ConstructionSiteViewSet.list:check_table', 'Checking if table exists', {'table_name': ConstructionSite._meta.db_table})
            try:
                with connection.cursor() as cursor:
                    cursor.execute(f"SELECT COUNT(*) FROM {ConstructionSite._meta.db_table}")
                    count = cursor.fetchone()[0]
                    _log('A', 'ConstructionSiteViewSet.list:table_check', 'Table exists and accessible', {'count': count})
            except Exception as table_error:
                _log('A', 'ConstructionSiteViewSet.list:table_error', 'Table check failed', {'error': str(table_error), 'error_type': type(table_error).__name__})
            # #endregion
            queryset = self.get_queryset()
            # #region agent log
            _log('A', 'ConstructionSiteViewSet.list:after_query', 'After querying', {'count': queryset.count()})
            # #endregion
            serializer = self.get_serializer(queryset, many=True, context={'request': request})
            # #region agent log
            _log('A', 'ConstructionSiteViewSet.list:after_serialize', 'After serialization', {'data_count': len(serializer.data)})
            # #endregion
            return Response(serializer.data)
        except Exception as e:
            # #region agent log
            _log('A', 'ConstructionSiteViewSet.list:error', 'Exception in ConstructionSiteViewSet.list', {'error': str(e), 'error_type': type(e).__name__, 'traceback': traceback.format_exc()})
            # #endregion
            raise


class ProjectViewSet(viewsets.ModelViewSet):
    """ViewSet для проектов"""
    queryset = Project.objects.all()
    serializer_class = ProjectSerializer
    permission_classes = [IsAuthenticated]
    
    def get_permissions(self):
        """Возвращает permissions в зависимости от действия"""
        # Для чтения (list, retrieve) - доступ для всех авторизованных пользователей
        if self.action in ['list', 'retrieve']:
            return [IsAuthenticated()]
        # Для создания, обновления, удаления - проверяем доступ к странице projects
        return [IsAuthenticated(), HasPagePermission('projects')]
    
    def get_queryset(self):
        """Фильтрация по строительному участку"""
        queryset = super().get_queryset()
        site_id = self.request.query_params.get('construction_site_id')
        if site_id:
            queryset = queryset.filter(construction_site_id=site_id)
        return queryset


class ProjectSheetViewSet(viewsets.ModelViewSet):
    """ViewSet для проектных листов"""
    queryset = ProjectSheet.objects.all()
    serializer_class = ProjectSheetSerializer
    
    def get_queryset(self):
        """Фильтрация по проекту и сортировка"""
        queryset = super().get_queryset()
        project_id = self.request.query_params.get('project_id')
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        
        # Сортировка: 1. Выполненные внизу, 2. По отделам, 3. По алфавиту
        queryset = queryset.order_by(
            'is_completed',  # False сначала, True потом (выполненные внизу)
            'responsible_department__name',  # По отделам
            'name'  # По алфавиту
        )
        return queryset
    
    def perform_create(self, serializer):
        """Автоматически устанавливает created_by при создании"""
        serializer.save(created_by=self.request.user)
    
    def perform_update(self, serializer):
        """Проверка прав на изменение is_completed"""
        instance = self.get_object()
        # Если пытаются изменить is_completed, проверяем права
        if 'is_completed' in serializer.validated_data:
            if instance.created_by and instance.created_by != self.request.user:
                from rest_framework.exceptions import PermissionDenied
                raise PermissionDenied("Только инициатор листа может изменить статус выполнения")
        serializer.save()
    
    @action(detail=True, methods=['get'])
    def download_file(self, request, pk=None):
        """Скачивание файла проектного листа"""
        sheet = self.get_object()
        if not sheet.file:
            return Response(
                {'error': 'Файл не прикреплен'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        try:
            file_path = sheet.file.path
            if not os.path.exists(file_path):
                return Response(
                    {'error': 'Файл не найден на сервере'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            file_handle = open(file_path, 'rb')
            response = FileResponse(
                file_handle,
                content_type='application/octet-stream'
            )
            response['Content-Disposition'] = f'attachment; filename="{os.path.basename(file_path)}"'
            return response
        except Exception as e:
            return Response(
                {'error': f'Ошибка при скачивании файла: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ProjectStageViewSet(viewsets.ModelViewSet):
    """ViewSet для этапов проекта"""
    queryset = ProjectStage.objects.all()
    serializer_class = ProjectStageSerializer
    
    def get_queryset(self):
        """Фильтрация по проекту"""
        queryset = super().get_queryset()
        project_id = self.request.query_params.get('project_id')
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        return queryset
    
    @action(detail=True, methods=['get'])
    def download_file(self, request, pk=None):
        """Скачивание файла этапа проекта"""
        stage = self.get_object()
        if not stage.file:
            return Response(
                {'error': 'Файл не прикреплен'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        try:
            file_path = stage.file.path
            if not os.path.exists(file_path):
                return Response(
                    {'error': 'Файл не найден на сервере'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            file_handle = open(file_path, 'rb')
            response = FileResponse(
                file_handle,
                content_type='application/octet-stream'
            )
            response['Content-Disposition'] = f'attachment; filename="{os.path.basename(file_path)}"'
            return response
        except Exception as e:
            return Response(
                {'error': f'Ошибка при скачивании файла: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ProjectSheetNoteViewSet(viewsets.ModelViewSet):
    """ViewSet для заметок проектного листа"""
    queryset = ProjectSheetNote.objects.all()
    serializer_class = ProjectSheetNoteSerializer
    
    def get_queryset(self):
        """Фильтрация по проектному листу"""
        queryset = super().get_queryset()
        sheet_id = self.request.query_params.get('project_sheet_id')
        if sheet_id:
            queryset = queryset.filter(project_sheet_id=sheet_id)
        return queryset


class DashboardViewSet(viewsets.ViewSet):
    """ViewSet для дашборда"""
    
    @action(detail=False, methods=['get'])
    def data(self, request):
        """Получение данных для дашборда с фильтрами"""
        # Получение параметров фильтров
        construction_site_ids_raw = request.query_params.getlist('construction_site_ids[]')
        project_ids_raw = request.query_params.getlist('project_ids[]')
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        status_ids_raw = request.query_params.getlist('status_ids[]')
        executor_ids_raw = request.query_params.getlist('executor_ids[]')
        granularity = request.query_params.get('granularity', 'month')  # year, quarter, month, day
        
        # Преобразование строковых ID в int
        construction_site_ids = [int(id) for id in construction_site_ids_raw if id.isdigit()]
        project_ids = [int(id) for id in project_ids_raw if id.isdigit()]
        status_ids = [int(id) for id in status_ids_raw if id.isdigit()]
        executor_ids = [int(id) for id in executor_ids_raw if id.isdigit()]
        
        # Базовый queryset для проектных листов
        sheets_qs = ProjectSheet.objects.all()
        
        # Применение фильтров
        if construction_site_ids:
            sheets_qs = sheets_qs.filter(project__construction_site_id__in=construction_site_ids)
        
        if project_ids:
            sheets_qs = sheets_qs.filter(project_id__in=project_ids)
        
        if date_from:
            try:
                date_from_obj = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
                sheets_qs = sheets_qs.filter(completed_at__gte=date_from_obj)
            except ValueError:
                pass
        
        if date_to:
            try:
                date_to_obj = datetime.fromisoformat(date_to.replace('Z', '+00:00'))
                sheets_qs = sheets_qs.filter(completed_at__lte=date_to_obj)
            except ValueError:
                pass
        
        if status_ids:
            sheets_qs = sheets_qs.filter(status_id__in=status_ids)
        
        if executor_ids:
            sheets_qs = sheets_qs.filter(executors__id__in=executor_ids).distinct()
        
        # Получение строительных участков и проектов с учетом фильтров
        if construction_site_ids:
            sites_qs = ConstructionSite.objects.filter(id__in=construction_site_ids)
        else:
            sites_qs = ConstructionSite.objects.all()
        
        if project_ids:
            projects_qs = Project.objects.filter(id__in=project_ids)
        elif construction_site_ids:
            projects_qs = Project.objects.filter(construction_site_id__in=construction_site_ids)
        else:
            projects_qs = Project.objects.all()
        
        # Вычисление общего процента выполнения
        all_sheets = sheets_qs
        total_sheets = all_sheets.count()
        completed_sheets = all_sheets.filter(is_completed=True).count()
        overall_completion = (completed_sheets / total_sheets * 100) if total_sheets > 0 else 0.0
        
        # Подготовка данных для диаграммы
        chart_data = self._prepare_chart_data(sheets_qs, projects_qs, granularity)
        
        # Сериализация данных
        sites_serializer = ConstructionSiteSerializer(sites_qs, many=True, context={'request': request})
        projects_serializer = ProjectSerializer(projects_qs, many=True, context={'request': request})
        
        data = {
            'construction_sites': sites_serializer.data,
            'projects': projects_serializer.data,
            'overall_completion': round(overall_completion, 2),
            'chart_data': chart_data
        }
        
        serializer = DashboardDataSerializer(data)
        return Response(serializer.data)
    
    def _prepare_chart_data(self, sheets_qs, projects_qs, granularity):
        """Подготовка данных для диаграммы интенсивности"""
        # Получаем выполненные листы с датами
        completed_sheets = sheets_qs.filter(
            is_completed=True,
            completed_at__isnull=False
        ).select_related('project')
        
        # Группируем по проектам и датам в зависимости от детализации
        chart_data = []
        
        for project in projects_qs:
            project_sheets = completed_sheets.filter(project=project)
            
            if not project_sheets.exists():
                continue
            
            # Группировка данных по датам
            grouped_data = {}
            
            for sheet in project_sheets:
                date_key = self._get_date_key(sheet.completed_at, granularity)
                if date_key not in grouped_data:
                    grouped_data[date_key] = 0
                grouped_data[date_key] += 1
            
            # Преобразование в формат для диаграммы
            project_data = {
                'project_id': project.id,
                'project_name': project.name,
                'data': [
                    {
                        'date': key,
                        'count': count
                    }
                    for key, count in sorted(grouped_data.items())
                ]
            }
            chart_data.append(project_data)
        
        return chart_data
    
    def _get_date_key(self, dt, granularity):
        """Получение ключа даты в зависимости от детализации"""
        if granularity == 'year':
            return dt.strftime('%Y')
        elif granularity == 'quarter':
            quarter = (dt.month - 1) // 3 + 1
            return f"{dt.year}-Q{quarter}"
        elif granularity == 'month':
            return dt.strftime('%Y-%m')
        elif granularity == 'day':
            return dt.strftime('%Y-%m-%d')
        else:
            return dt.strftime('%Y-%m')

