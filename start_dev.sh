#!/bin/bash

# Скрипт запуска dev окружения
set -e

echo "Запуск dev окружения..."

# Проверка наличия .env.dev
if [ ! -f .env.dev ]; then
    echo "Создание .env.dev из примера..."
    cp .env.dev .env.dev 2>/dev/null || true
fi

# Остановка существующих контейнеров
echo "Остановка существующих контейнеров..."
docker-compose -f docker-compose.dev.yml down

# Запуск контейнеров
echo "Запуск контейнеров..."
docker-compose -f docker-compose.dev.yml up --build

