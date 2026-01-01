import json
import traceback
from rest_framework.views import exception_handler
from rest_framework.response import Response
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
# #endregion


def custom_exception_handler(exc, context):
    """Кастомный обработчик исключений для логирования"""
    # #region agent log
    _log('C', 'custom_exception_handler:entry', 'Exception handler called', {
        'exception_type': type(exc).__name__,
        'exception_message': str(exc),
        'view': context.get('view', {}).__class__.__name__ if context.get('view') else None,
        'request_method': context.get('request', {}).method if context.get('request') else None,
        'request_path': str(context.get('request', {}).path) if context.get('request') else None,
    })
    # #endregion
    
    # Вызываем стандартный обработчик исключений
    response = exception_handler(exc, context)
    
    # #region agent log
    if response:
        _log('C', 'custom_exception_handler:response', 'Exception handler response', {
            'status_code': response.status_code,
            'response_data': response.data if hasattr(response, 'data') else None,
        })
    else:
        _log('C', 'custom_exception_handler:no_response', 'Exception handler returned None', {
            'traceback': traceback.format_exc()
        })
    # #endregion
    
    return response

