import json
import traceback
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from django.utils import timezone

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

try:
    _log('D', 'urls.py:module_import', 'urls.py module imported')
except:
    pass
# #endregion

try:
    from .views import (
        StatusViewSet, ConstructionSiteViewSet, ProjectViewSet,
        ProjectSheetViewSet, ProjectStageViewSet, ProjectSheetNoteViewSet,
        DashboardViewSet
    )
    # #region agent log
    _log('D', 'urls.py:views_imported', 'Views imported successfully')
    # #endregion
except Exception as e:
    # #region agent log
    _log('D', 'urls.py:views_import_error', 'Error importing views', {'error': str(e), 'traceback': traceback.format_exc()})
    # #endregion
    raise

router = DefaultRouter()
router.register(r'statuses', StatusViewSet, basename='status')
router.register(r'construction-sites', ConstructionSiteViewSet, basename='construction-site')
router.register(r'projects', ProjectViewSet, basename='project')
router.register(r'project-sheets', ProjectSheetViewSet, basename='project-sheet')
router.register(r'project-stages', ProjectStageViewSet, basename='project-stage')
router.register(r'project-sheet-notes', ProjectSheetNoteViewSet, basename='project-sheet-note')
router.register(r'dashboard', DashboardViewSet, basename='dashboard')

urlpatterns = [
    path('', include(router.urls)),
]

