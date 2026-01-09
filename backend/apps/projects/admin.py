from django.contrib import admin
from django.utils.html import format_html
from django.db import connection
from pathlib import Path
import json
import os
from .models import (
    Status, ConstructionSite, Project, ProjectSheet,
    ProjectStage, ProjectSheetNote
)

# #region agent log
def _log(hypothesis_id, location, message, data=None):
    log_path = r"r:\dev\my-tracker\my_tracker_v0.1\.cursor\debug.log"
    try:
        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps({
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": hypothesis_id,
                "location": location,
                "message": message,
                "data": data or {},
                "timestamp": os.times().elapsed if hasattr(os.times(), 'elapsed') else 0
            }, ensure_ascii=False) + '\n')
    except:
        pass
# #endregion


@admin.register(Status)
class StatusAdmin(admin.ModelAdmin):
    list_display = ['name', 'color_display', 'status_type', 'created_at']
    list_filter = ['status_type', 'created_at']
    search_fields = ['name']
    fields = ['name', 'color', 'status_type', 'created_at']
    readonly_fields = ['created_at']
    
    def color_display(self, obj):
        """Отображение цвета с визуальным индикатором"""
        if obj.color:
            return format_html(
                '<span style="display: inline-block; width: 20px; height: 20px; '
                'background-color: {}; border: 1px solid #ccc; border-radius: 3px; '
                'vertical-align: middle; margin-right: 8px;"></span>{}',
                obj.color,
                obj.color
            )
        return '-'
    color_display.short_description = 'Цвет'


@admin.register(ConstructionSite)
class ConstructionSiteAdmin(admin.ModelAdmin):
    list_display = ['name', 'manager', 'created_at']
    list_filter = ['created_at']
    search_fields = ['name', 'description']


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ['name', 'code', 'cipher', 'construction_site', 'created_at']
    list_filter = ['construction_site', 'created_at']
    search_fields = ['name', 'code', 'cipher', 'description']
    raw_id_fields = ['construction_site']


@admin.register(ProjectSheet)
class ProjectSheetAdmin(admin.ModelAdmin):
    list_display = ['name', 'project', 'status', 'responsible_department', 'is_completed', 'completed_at', 'created_at']
    list_filter = ['status', 'is_completed', 'created_at', 'project', 'responsible_department']
    search_fields = ['name', 'description']
    raw_id_fields = ['project', 'status', 'responsible_department']
    fields = [
        'name', 'description', 'project', 'status', 
        'responsible_department', 'file', 'is_completed', 
        'completed_at', 'created_by', 'created_at', 'updated_at'
    ]
    readonly_fields = ['completed_at', 'created_at', 'updated_at']


@admin.register(ProjectStage)
class ProjectStageAdmin(admin.ModelAdmin):
    """Админка этапа проекта с автодополнением для связей"""
    list_display = ['project', 'status', 'datetime', 'author', 'created_at']
    list_filter = ['status', 'datetime', 'created_at', 'project']
    search_fields = ['description']
    autocomplete_fields = ['project', 'status', 'author', 'responsible_users']
    fields = [
        'project', 'status', 'datetime', 'author', 'responsible_users',
        'description', 'file', 'created_at'
    ]
    readonly_fields = ['created_at']


@admin.register(ProjectSheetNote)
class ProjectSheetNoteAdmin(admin.ModelAdmin):
    list_display = ['name', 'project_sheet', 'author', 'created_at']
    list_filter = ['created_at', 'project_sheet']
    search_fields = ['name', 'note']
    raw_id_fields = ['project_sheet', 'author']
    
    def changelist_view(self, request, extra_context=None):
        # #region agent log
        _log("post-fix", "admin.py:changelist_view", "ProjectSheetNoteAdmin.changelist_view called", {
            "path": request.path
        })
        # #endregion
        
        # #region agent log
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'projects_%'")
                tables = [row[0] for row in cursor.fetchall()]
                _log("post-fix", "admin.py:changelist_view", "Checking database tables after fix", {
                    "projects_tables": tables,
                    "projectsheet_exists": "projects_projectsheet" in tables
                })
        except Exception as e:
            _log("post-fix", "admin.py:changelist_view", "Error checking database tables", {
                "error": str(e)
            })
        # #endregion
        
        return super().changelist_view(request, extra_context)

