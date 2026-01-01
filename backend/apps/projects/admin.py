from django.contrib import admin
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
    list_display = ['name', 'color', 'status_type', 'created_at']
    list_filter = ['status_type', 'created_at']
    search_fields = ['name']


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
    list_display = ['name', 'project', 'status', 'is_completed', 'completed_at', 'created_at']
    list_filter = ['status', 'is_completed', 'created_at', 'project']
    search_fields = ['name', 'description']
    raw_id_fields = ['project', 'status']
    filter_horizontal = ['executors']


@admin.register(ProjectStage)
class ProjectStageAdmin(admin.ModelAdmin):
    list_display = ['project', 'status', 'datetime', 'author', 'created_at']
    list_filter = ['status', 'datetime', 'created_at', 'project']
    search_fields = ['description']
    raw_id_fields = ['project', 'status', 'author']


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

