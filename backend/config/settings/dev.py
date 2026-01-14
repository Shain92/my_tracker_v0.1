"""
Настройки для разработки
"""
from .base import *

DEBUG = True

# Разрешаем все хосты для разработки (включая IP адреса локальной сети)
ALLOWED_HOSTS = ['*']

CORS_ALLOW_ALL_ORIGINS = True


