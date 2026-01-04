#!/bin/bash

# Скрипт управления разработкой
set -e

COMPOSE_FILE="docker-compose.dev.yml"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция вывода меню
show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Управление разработкой My Tracker   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} Пересобрать контейнеры"
    echo -e "${GREEN}2.${NC} Остановить контейнеры"
    echo -e "${GREEN}3.${NC} Запустить с пересборкой (--build)"
    echo -e "${GREEN}4.${NC} Запустить без пересборки"
    echo -e "${GREEN}5.${NC} Запуск фронтенда (Flutter)"
    echo -e "${GREEN}6.${NC} Просмотр логов"
    echo -e "${GREEN}7.${NC} Статус контейнеров"
    echo -e "${GREEN}8.${NC} Создать миграции"
    echo -e "${GREEN}9.${NC} Выполнить миграции"
    echo -e "${GREEN}10.${NC} Создать суперпользователя"
    echo -e "${GREEN}11.${NC} Очистить volumes и остановить"
    echo -e "${GREEN}12.${NC} Перезапустить контейнеры"
    echo -e "${GREEN}13.${NC} Войти в контейнер backend"
    echo -e "${GREEN}14.${NC} Создать видео истории Git (Gource)"
    echo -e "${YELLOW}0.${NC} Выход"
    echo ""
    echo -n "Выберите опцию: "
}

# Функция пересборки контейнеров
rebuild_containers() {
    echo -e "${YELLOW}Пересборка контейнеров...${NC}"
    docker-compose -f $COMPOSE_FILE down
    docker-compose -f $COMPOSE_FILE build --no-cache
    echo -e "${GREEN}Контейнеры пересобраны!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция остановки контейнеров
stop_containers() {
    echo -e "${YELLOW}Остановка контейнеров...${NC}"
    docker-compose -f $COMPOSE_FILE down
    echo -e "${GREEN}Контейнеры остановлены!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция запуска с пересборкой
start_with_build() {
    echo -e "${YELLOW}Запуск контейнеров с пересборкой...${NC}"
    docker-compose -f $COMPOSE_FILE up --build -d
    echo -e "${GREEN}Контейнеры запущены!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция запуска без пересборки
start_without_build() {
    echo -e "${YELLOW}Запуск контейнеров...${NC}"
    docker-compose -f $COMPOSE_FILE up -d
    echo -e "${GREEN}Контейнеры запущены!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция запуска фронтенда
start_frontend() {
    echo -e "${YELLOW}Запуск Flutter фронтенда...${NC}"
    cd frontend
    if command -v flutter &> /dev/null; then
        flutter run -d chrome --web-port=3000
    else
        echo -e "${RED}Flutter не найден! Установите Flutter SDK.${NC}"
    fi
    cd ..
    read -p "Нажмите Enter для продолжения..."
}

# Функция просмотра логов
view_logs() {
    echo -e "${YELLOW}Выберите сервис для просмотра логов:${NC}"
    echo "1. Все сервисы"
    echo "2. Backend"
    echo "3. Database"
    echo -n "Выбор: "
    read log_choice
    
    case $log_choice in
        1)
            docker-compose -f $COMPOSE_FILE logs -f
            ;;
        2)
            docker-compose -f $COMPOSE_FILE logs -f backend
            ;;
        3)
            docker-compose -f $COMPOSE_FILE logs -f db
            ;;
        *)
            echo -e "${RED}Неверный выбор${NC}"
            ;;
    esac
    read -p "Нажмите Enter для продолжения..."
}

# Функция статуса контейнеров
show_status() {
    echo -e "${YELLOW}Статус контейнеров:${NC}"
    docker-compose -f $COMPOSE_FILE ps
    echo ""
    echo -e "${YELLOW}Использование ресурсов:${NC}"
    docker stats --no-stream $(docker-compose -f $COMPOSE_FILE ps -q) 2>/dev/null || echo "Контейнеры не запущены"
    read -p "Нажмите Enter для продолжения..."
}

# Функция создания миграций
make_migrations() {
    echo -e "${YELLOW}Создание миграций...${NC}"
    echo -n "Введите имя приложения (или оставьте пустым для всех): "
    read app_name
    if [ -z "$app_name" ]; then
        docker-compose -f $COMPOSE_FILE exec backend python manage.py makemigrations
    else
        docker-compose -f $COMPOSE_FILE exec backend python manage.py makemigrations $app_name
    fi
    echo -e "${GREEN}Миграции созданы!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция выполнения миграций
run_migrations() {
    echo -e "${YELLOW}Выполнение миграций...${NC}"
    docker-compose -f $COMPOSE_FILE exec backend python manage.py migrate
    echo -e "${GREEN}Миграции выполнены!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция создания суперпользователя
create_superuser() {
    echo -e "${YELLOW}Создание суперпользователя...${NC}"
    docker-compose -f $COMPOSE_FILE exec backend python manage.py createsuperuser
    echo -e "${GREEN}Суперпользователь создан!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция очистки
clean_containers() {
    echo -e "${RED}ВНИМАНИЕ: Это удалит все volumes и данные!${NC}"
    read -p "Вы уверены? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo -e "${YELLOW}Очистка контейнеров и volumes...${NC}"
        docker-compose -f $COMPOSE_FILE down -v
        echo -e "${GREEN}Очистка завершена!${NC}"
    else
        echo -e "${YELLOW}Операция отменена${NC}"
    fi
    read -p "Нажмите Enter для продолжения..."
}

# Функция перезапуска
restart_containers() {
    echo -e "${YELLOW}Перезапуск контейнеров...${NC}"
    docker-compose -f $COMPOSE_FILE restart
    echo -e "${GREEN}Контейнеры перезапущены!${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция входа в контейнер
enter_backend() {
    echo -e "${YELLOW}Вход в контейнер backend...${NC}"
    docker-compose -f $COMPOSE_FILE exec backend /bin/bash || docker-compose -f $COMPOSE_FILE exec backend /bin/sh
}

# Функция создания видео истории Git
create_gource_video() {
    echo -e "${YELLOW}Создание видео истории Git...${NC}"
    GOURCE_PATH="/c/Program Files/Gource/gource.exe"
    if [ -f "$GOURCE_PATH" ]; then
        "$GOURCE_PATH" -5120x1440 -f --title "My video" --seconds-per-day 30 --auto-skip-seconds 3 --highlight-all-users --multi-sampling .
    else
        echo -e "${RED}Gource не найден по пути: $GOURCE_PATH${NC}"
        echo -e "${YELLOW}Убедитесь, что Gource установлен.${NC}"
    fi
    read -p "Нажмите Enter для продолжения..."
}

# Главный цикл
while true; do
    show_menu
    read choice
    
    case $choice in
        1)
            rebuild_containers
            ;;
        2)
            stop_containers
            ;;
        3)
            start_with_build
            ;;
        4)
            start_without_build
            ;;
        5)
            start_frontend
            ;;
        6)
            view_logs
            ;;
        7)
            show_status
            ;;
        8)
            make_migrations
            ;;
        9)
            run_migrations
            ;;
        10)
            create_superuser
            ;;
        11)
            clean_containers
            ;;
        12)
            restart_containers
            ;;
        13)
            enter_backend
            ;;
        14)
            create_gource_video
            ;;
        0)
            echo -e "${GREEN}Выход...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор!${NC}"
            sleep 1
            ;;
    esac
done

