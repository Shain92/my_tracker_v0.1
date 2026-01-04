import json
import traceback
from rest_framework import serializers
from django.contrib.auth.models import User
from django.utils import timezone
from apps.auth.models import Department
from .models import (
    Status, ConstructionSite, Project, ProjectSheet,
    ProjectStage, ProjectSheetNote
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
        try:
            fallback_path = BASE_DIR / 'backend' / 'debug_fallback.log'
            with open(fallback_path, 'a', encoding='utf-8') as f:
                f.write(f"LOG ERROR at {location}: {log_err}\n")
        except:
            pass
# #endregion


class UserSerializer(serializers.ModelSerializer):
    """Сериализатор пользователя"""
    class Meta:
        model = User
        fields = ['id', 'username', 'first_name', 'last_name', 'email']


class StatusSerializer(serializers.ModelSerializer):
    """Сериализатор статуса"""
    class Meta:
        model = Status
        fields = ['id', 'name', 'color', 'status_type', 'created_at']


class DepartmentSerializer(serializers.ModelSerializer):
    """Сериализатор отдела"""
    class Meta:
        model = Department
        fields = ['id', 'name', 'description', 'color']


class ConstructionSiteSerializer(serializers.ModelSerializer):
    """Сериализатор строительного участка"""
    manager = UserSerializer(read_only=True)
    manager_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(),
        source='manager',
        write_only=True,
        required=False,
        allow_null=True
    )
    completion_percentage = serializers.ReadOnlyField()
    
    class Meta:
        model = ConstructionSite
        fields = [
            'id', 'name', 'description', 'manager', 'manager_id',
            'completion_percentage', 'created_at', 'updated_at'
        ]
    
    def to_representation(self, instance):
        # #region agent log
        _log('B', 'ConstructionSiteSerializer.to_representation:entry', 'Serializing ConstructionSite', {'instance_id': instance.id, 'has_manager': instance.manager_id is not None})
        # #endregion
        try:
            # #region agent log
            _log('B', 'ConstructionSiteSerializer.to_representation:before_super', 'Before calling super().to_representation()')
            # #endregion
            data = super().to_representation(instance)
            # #region agent log
            _log('B', 'ConstructionSiteSerializer.to_representation:after_super', 'After calling super().to_representation()', {'has_manager_field': 'manager' in data})
            # #endregion
            return data
        except Exception as e:
            # #region agent log
            _log('B', 'ConstructionSiteSerializer.to_representation:error', 'Exception in to_representation', {'error': str(e), 'traceback': traceback.format_exc()})
            # #endregion
            raise


class ProjectSerializer(serializers.ModelSerializer):
    """Сериализатор проекта"""
    construction_site = ConstructionSiteSerializer(read_only=True)
    construction_site_id = serializers.PrimaryKeyRelatedField(
        queryset=ConstructionSite.objects.all(),
        source='construction_site',
        write_only=True
    )
    completion_percentage = serializers.ReadOnlyField()
    
    class Meta:
        model = Project
        fields = [
            'id', 'name', 'description', 'code', 'cipher',
            'construction_site', 'construction_site_id',
            'completion_percentage', 'created_at', 'updated_at'
        ]


class ProjectSheetSerializer(serializers.ModelSerializer):
    """Сериализатор проектного листа"""
    project = ProjectSerializer(read_only=True)
    project_id = serializers.PrimaryKeyRelatedField(
        queryset=Project.objects.all(),
        source='project',
        write_only=True
    )
    status = StatusSerializer(read_only=True)
    status_id = serializers.PrimaryKeyRelatedField(
        queryset=Status.objects.filter(status_type='sheet'),
        source='status',
        write_only=True,
        required=False,
        allow_null=True
    )
    executors = UserSerializer(many=True, read_only=True)
    executor_ids = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(),
        source='executors',
        many=True,
        write_only=True,
        required=False
    )
    responsible_department = DepartmentSerializer(read_only=True)
    responsible_department_id = serializers.PrimaryKeyRelatedField(
        queryset=Department.objects.all(),
        source='responsible_department',
        write_only=True,
        required=False,
        allow_null=True
    )
    created_by = UserSerializer(read_only=True)
    created_by_id = serializers.SerializerMethodField()
    created_by_id_write = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(),
        source='created_by',
        write_only=True,
        required=False,
        allow_null=True
    )
    file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = ProjectSheet
        fields = [
            'id', 'name', 'description', 'project', 'project_id',
            'status', 'status_id', 'is_completed', 'completed_at',
            'file', 'file_url', 'executors', 'executor_ids',
            'responsible_department', 'responsible_department_id',
            'created_by', 'created_by_id', 'created_by_id_write', 'created_at', 'updated_at'
        ]
        read_only_fields = ['completed_at']
    
    def get_created_by_id(self, obj):
        """Возвращает ID инициатора"""
        return obj.created_by.id if obj.created_by else None
    
    def get_file_url(self, obj):
        """Возвращает URL файла"""
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None


class ProjectStageSerializer(serializers.ModelSerializer):
    """Сериализатор этапа проекта"""
    project = ProjectSerializer(read_only=True)
    project_id = serializers.PrimaryKeyRelatedField(
        queryset=Project.objects.all(),
        source='project',
        write_only=True
    )
    status = StatusSerializer(read_only=True)
    status_id = serializers.PrimaryKeyRelatedField(
        queryset=Status.objects.filter(status_type='stage'),
        source='status',
        write_only=True,
        required=False,
        allow_null=True
    )
    author = UserSerializer(read_only=True)
    author_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(),
        source='author',
        write_only=True,
        required=False,
        allow_null=True
    )
    responsible_users = UserSerializer(many=True, read_only=True)
    responsible_user_ids = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(),
        source='responsible_users',
        many=True,
        write_only=True,
        required=False
    )
    file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = ProjectStage
        fields = [
            'id', 'project', 'project_id', 'status', 'status_id',
            'datetime', 'author', 'author_id', 'responsible_users',
            'responsible_user_ids', 'description', 'file', 'file_url',
            'created_at'
        ]
    
    def get_file_url(self, obj):
        """Возвращает URL файла"""
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None


class ProjectSheetNoteSerializer(serializers.ModelSerializer):
    """Сериализатор заметки проектного листа"""
    project_sheet = ProjectSheetSerializer(read_only=True)
    project_sheet_id = serializers.PrimaryKeyRelatedField(
        queryset=ProjectSheet.objects.all(),
        source='project_sheet',
        write_only=True
    )
    author = UserSerializer(read_only=True)
    author_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(),
        source='author',
        write_only=True,
        required=False,
        allow_null=True
    )
    file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = ProjectSheetNote
        fields = [
            'id', 'name', 'note', 'file', 'file_url',
            'author', 'author_id', 'project_sheet', 'project_sheet_id',
            'created_at', 'updated_at'
        ]
    
    def get_file_url(self, obj):
        """Возвращает URL файла"""
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None


class DashboardDataSerializer(serializers.Serializer):
    """Сериализатор данных для дашборда"""
    construction_sites = ConstructionSiteSerializer(many=True)
    projects = ProjectSerializer(many=True)
    overall_completion = serializers.FloatField()
    chart_data = serializers.ListField(
        child=serializers.DictField(),
        help_text="Данные для диаграммы интенсивности"
    )

