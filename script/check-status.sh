#!/bin/bash
# Скрипт для проверки состояния Postal
# Использование: ./script/check-status.sh

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo_error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Определение директории
if [ -f "./bin/postal" ]; then
    POSTAL_DIR=$(pwd)
elif [ -f "/opt/postal/app/bin/postal" ]; then
    POSTAL_DIR="/opt/postal/app"
else
    echo_error "Не удалось найти директорию Postal"
    exit 1
fi

cd "$POSTAL_DIR"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Проверка состояния Postal           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"

# Версия Postal
echo_section "Версия Postal"
if [ -f "./bin/postal" ]; then
    VERSION=$(./bin/postal version 2>/dev/null || echo "неизвестно")
    echo_info "Версия: $VERSION"
else
    echo_error "Не удалось определить версию"
fi

# Git информация
echo_section "Git репозиторий"
if [ -d ".git" ]; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "неизвестно")
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "неизвестно")
    echo_info "Ветка: $BRANCH"
    echo_info "Коммит: $COMMIT"

    # Проверка изменений
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        echo_info "Рабочая директория чистая"
    else
        echo_warn "Есть незакоммиченные изменения"
        git status --short
    fi

    # Проверка обновлений
    git fetch origin -q 2>/dev/null
    LOCAL=$(git rev-parse @ 2>/dev/null)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)
    if [ "$LOCAL" = "$REMOTE" ]; then
        echo_info "Код актуален"
    else
        echo_warn "Доступны обновления из origin"
        echo "  Запустите: ./script/deploy-update.sh"
    fi
else
    echo_warn "Не git репозиторий"
fi

# Статус systemd сервисов (если доступен systemctl)
if command -v systemctl &> /dev/null; then
    echo_section "Systemd сервисы"

    services=("postal-web" "postal-smtp" "postal-worker")
    all_running=true

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo_info "$service: работает"
        elif systemctl list-units --full -all | grep -q "$service.service"; then
            echo_error "$service: остановлен"
            all_running=false
        else
            echo_warn "$service: не настроен"
        fi
    done

    if [ "$all_running" = false ]; then
        echo ""
        echo_warn "Для перезапуска: sudo systemctl restart postal-*"
    fi
else
    echo_warn "systemctl не доступен (не на production сервере?)"
fi

# Конфигурация
echo_section "Конфигурация"
CONFIG_PATH=${POSTAL_CONFIG_FILE_PATH:-/opt/postal/config/postal.yml}
if [ -f "$CONFIG_PATH" ]; then
    echo_info "Файл конфигурации: $CONFIG_PATH"

    # Проверка прав доступа
    if [ -r "$CONFIG_PATH" ]; then
        echo_info "Файл доступен для чтения"
    else
        echo_error "Нет прав на чтение конфигурации"
    fi
else
    echo_error "Конфигурационный файл не найден: $CONFIG_PATH"
fi

# Проверка Ruby
echo_section "Зависимости"
if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby -v | awk '{print $2}')
    echo_info "Ruby: $RUBY_VERSION"
else
    echo_error "Ruby не установлен"
fi

if command -v bundle &> /dev/null; then
    BUNDLER_VERSION=$(bundle -v | awk '{print $3}')
    echo_info "Bundler: $BUNDLER_VERSION"

    # Проверка gems
    if bundle check > /dev/null 2>&1; then
        echo_info "Все Ruby gems установлены"
    else
        echo_warn "Некоторые gems отсутствуют, запустите: bundle install"
    fi
else
    echo_error "Bundler не установлен"
fi

# Проверка базы данных
echo_section "База данных"
if command -v mysql &> /dev/null; then
    echo_info "MySQL/MariaDB найден"

    # Попытка подключиться (если есть конфиг)
    if [ -f "$CONFIG_PATH" ]; then
        DB_HOST=$(grep -A 3 "main_db:" "$CONFIG_PATH" | grep "host:" | awk '{print $2}')
        DB_NAME=$(grep -A 3 "main_db:" "$CONFIG_PATH" | grep "database:" | awk '{print $2}')

        if [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ]; then
            echo_info "База данных: $DB_NAME @ $DB_HOST"
        fi
    fi
else
    echo_error "MySQL/MariaDB не найден"
fi

# Проверка портов (если доступен ss или netstat)
echo_section "Сетевые порты"
if command -v ss &> /dev/null; then
    # Web сервер (обычно 5000)
    if ss -tuln | grep -q ":5000"; then
        echo_info "Web сервер слушает на порту 5000"
    else
        echo_warn "Web сервер не слушает на порту 5000"
    fi

    # SMTP (обычно 25)
    if ss -tuln | grep -q ":25"; then
        echo_info "SMTP сервер слушает на порту 25"
    else
        echo_warn "SMTP сервер не слушает на порту 25"
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":5000"; then
        echo_info "Web сервер слушает на порту 5000"
    else
        echo_warn "Web сервер не слушает на порту 5000"
    fi

    if netstat -tuln | grep -q ":25"; then
        echo_info "SMTP сервер слушает на порту 25"
    else
        echo_warn "SMTP сервер не слушает на порту 25"
    fi
else
    echo_warn "Невозможно проверить порты (ss/netstat не найдены)"
fi

# Проверка дискового пространства
echo_section "Дисковое пространство"
DISK_USAGE=$(df -h "$POSTAL_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_MOUNT=$(df -h "$POSTAL_DIR" | tail -1 | awk '{print $6}')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo_info "Использование диска: ${DISK_USAGE}% ($DISK_MOUNT)"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo_warn "Использование диска: ${DISK_USAGE}% ($DISK_MOUNT)"
else
    echo_error "Критическое использование диска: ${DISK_USAGE}% ($DISK_MOUNT)"
fi

# Проверка памяти
echo_section "Память"
if command -v free &> /dev/null; then
    MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    if [ "$MEM_USAGE" -lt 80 ]; then
        echo_info "Использование памяти: ${MEM_USAGE}%"
    elif [ "$MEM_USAGE" -lt 90 ]; then
        echo_warn "Использование памяти: ${MEM_USAGE}%"
    else
        echo_error "Критическое использование памяти: ${MEM_USAGE}%"
    fi
else
    echo_warn "Невозможно проверить память"
fi

# Проверка логов на ошибки (последние 50 строк)
if command -v journalctl &> /dev/null; then
    echo_section "Последние ошибки в логах"
    ERROR_COUNT=$(sudo journalctl -u postal-* --since "1 hour ago" -p err -q 2>/dev/null | wc -l)

    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo_info "Ошибок в логах за последний час не обнаружено"
    else
        echo_warn "Обнаружено ошибок за последний час: $ERROR_COUNT"
        echo "  Просмотреть: sudo journalctl -u postal-* -p err -n 50"
    fi
fi

# Итоговая сводка
echo_section "Итоговая сводка"
echo ""
echo_info "Полезные команды:"
echo "  Обновить Postal:      ./script/deploy-update.sh"
echo "  Перезапустить:        sudo systemctl restart postal-*"
echo "  Просмотр логов:       sudo journalctl -u postal-* -f"
echo "  Статус сервисов:      sudo systemctl status postal-*"
echo "  Консоль Rails:        ./bin/postal console"
echo ""
