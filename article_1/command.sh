#!/bin/bash

# Путь к файлу .env в папке docker
ENV_FILE="docker/.env"

# Путь к директории и лог-файлу
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/command.log"

# Функция для добавления времени к каждому лог-сообщению
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Проверка наличия директории logs
if [ ! -d "$LOG_DIR" ]; then
    log "Директория $LOG_DIR не найдена. Создаю..."
    mkdir -p "$LOG_DIR"
fi

# Проверка наличия файла .env
if [ ! -f "$ENV_FILE" ]; then
    log "Ошибка: файл $ENV_FILE не найден. Пожалуйста, проверьте наличие и расположение файла."
    exit 1
fi

# Загрузка переменных окружения из файла .env
source "$ENV_FILE"

# Названия папок для volumes берутся из .env
VOLUMES=("$OLLAMA_DATA_DIR" "$OPEN_WEBUI_DATA_DIR")

# Название стека (проекта), используемое для Docker Compose
PROJECT_NAME=${PROJECT_NAME:-"llm_stack"}

# Функция для создания папок, если их нет
create_volumes() {
    log "Проверка и создание папок для volumes, если их нет..."
    for volume in "${VOLUMES[@]}"; do
        if [ ! -d "$volume" ]; then
            log "Создание директории: $volume"
            mkdir -p "$volume"
        else
            log "Директория $volume уже существует"
        fi
    done
}

# Функция для запуска контейнеров Docker Compose
start_containers() {
    log "Запуск контейнеров через Docker Compose с проектом $PROJECT_NAME..."

    if [ ! -f "docker/docker-compose.yml" ]; then
        log "Ошибка: файл docker/docker-compose.yml не найден."
        exit 1
    fi

    docker compose -f docker/docker-compose.yml --env-file "$ENV_FILE" -p $PROJECT_NAME up -d | tee -a "$LOG_FILE"

    if [ $? -eq 0 ]; then
        log "Контейнеры успешно запущены"
    else
        log "Ошибка при запуске контейнеров"
    fi
}

# Функция для остановки контейнеров Docker Compose
stop_containers() {
    log "Остановка всех контейнеров Docker Compose с проектом $PROJECT_NAME..."
    docker compose -p $PROJECT_NAME down | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        log "Все контейнеры успешно остановлены"
    else
        log "Ошибка при остановке контейнеров"
    fi
}

# Функция для рестарта одного контейнера по имени
restart_container() {
    container_name=$1
    if [ -z "$container_name" ]; then
        log "Ошибка: необходимо указать имя контейнера для рестарта"
        exit 1
    fi

    log "Рестарт контейнера $container_name..."
    docker compose --env-file "$ENV_FILE" -p $PROJECT_NAME restart $container_name | tee -a "$LOG_FILE"

    if [ $? -eq 0 ]; then
        log "Контейнер $container_name успешно перезапущен"
    else
        log "Ошибка при перезапуске контейнера $container_name"
    fi
}

# Функция для рестарта всех контейнеров
restart_all_containers() {
    log "Рестарт всех контейнеров для проекта $PROJECT_NAME..."
    docker compose --env-file "$ENV_FILE" -p $PROJECT_NAME restart | tee -a "$LOG_FILE"
    if [ $? -eq 0 ]; then
        log "Все контейнеры успешно перезапущены"
    else
        log "Ошибка при перезапуске всех контейнеров"
    fi
}

# Функция для вывода списка всех контейнеров и их статуса
list_containers() {
    log "Список контейнеров для проекта $PROJECT_NAME:"
    docker compose --env-file "$ENV_FILE" -p $PROJECT_NAME ps | tee -a "$LOG_FILE"
}

# Основной блок управления командой
if [ "$1" == "start" ]; then
    create_volumes
    start_containers
elif [ "$1" == "stop" ]; then
    stop_containers
elif [ "$1" == "restart" ]; then
    if [ -z "$2" ]; then
        restart_all_containers  # Если нет параметра, перезапустить все контейнеры
    else
        restart_container "$2"  # Если указан контейнер, перезапустить его
    fi
elif [ "$1" == "list" ]; then
    list_containers
else
    log "Неправильная команда! Используйте:"
    log "  ./command.sh start    - для запуска контейнеров"
    log "  ./command.sh stop     - для остановки контейнеров"
    log "  ./command.sh restart  - для рестарта всех контейнеров или одного по имени"
    log "  ./command.sh list     - для вывода списка контейнеров и их статуса"
    log "Пример использования: ./command.sh restart <container_name>"
fi
