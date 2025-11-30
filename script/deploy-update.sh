#!/bin/bash
# Скрипт для быстрого обновления Postal на сервере
# Использование: ./script/deploy-update.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_step() {
    echo -e "${BLUE}==>${NC} $1"
}

# Определение текущего пользователя
CURRENT_USER=$(whoami)
USE_SUDO=""

# Если не запущено от пользователя postal, используем sudo
if [ "$CURRENT_USER" != "postal" ]; then
    USE_SUDO="sudo -u postal"
    echo_warn "Скрипт запущен от пользователя $CURRENT_USER, будет использоваться sudo для выполнения команд от имени postal"
fi

# Определение рабочей директории
if [ -f "./bin/postal" ]; then
    POSTAL_DIR=$(pwd)
elif [ -f "/opt/postal/app/bin/postal" ]; then
    POSTAL_DIR="/opt/postal/app"
else
    echo_error "Не удалось найти директорию Postal"
    echo_error "Запустите скрипт из директории /opt/postal/app или укажите правильный путь"
    exit 1
fi

echo_info "=== Обновление Postal ==="
echo_info "Директория: $POSTAL_DIR"
echo ""

cd "$POSTAL_DIR"

# Проверка изменений
echo_step "Проверка текущего состояния..."
$USE_SUDO git status

# Сохранение текущей ветки
CURRENT_BRANCH=$(git branch --show-current)
echo_info "Текущая ветка: $CURRENT_BRANCH"

# Запрос подтверждения
read -p "Продолжить обновление? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo_warn "Обновление отменено"
    exit 0
fi

# Сохранение текущего коммита для возможности отката
PREVIOUS_COMMIT=$(git rev-parse HEAD)
echo_info "Текущий коммит: $PREVIOUS_COMMIT"

# Обновление кода
echo_step "Получение обновлений из репозитория..."
$USE_SUDO git fetch origin

echo_step "Применение обновлений..."
$USE_SUDO git pull origin "$CURRENT_BRANCH"

# Проверка, были ли изменения
NEW_COMMIT=$(git rev-parse HEAD)
if [ "$PREVIOUS_COMMIT" = "$NEW_COMMIT" ]; then
    echo_info "Новых изменений нет"
else
    echo_info "Обновлено с $PREVIOUS_COMMIT на $NEW_COMMIT"
    echo ""
    echo_info "Изменения:"
    git log --oneline --graph --decorate "$PREVIOUS_COMMIT..$NEW_COMMIT"
    echo ""
fi

# Обновление зависимостей
echo_step "Проверка и обновление зависимостей Ruby..."
if $USE_SUDO bundle check > /dev/null 2>&1; then
    echo_info "Все зависимости установлены"
else
    echo_warn "Обнаружены изменения в зависимостях, выполняется bundle install..."
    $USE_SUDO bundle install
fi

# Выполнение миграций базы данных
echo_step "Выполнение миграций базы данных..."
export POSTAL_CONFIG_FILE_PATH=${POSTAL_CONFIG_FILE_PATH:-/opt/postal/config/postal.yml}

if [ -f "$POSTAL_CONFIG_FILE_PATH" ]; then
    $USE_SUDO -E ./bin/postal upgrade
else
    echo_warn "Конфигурационный файл не найден: $POSTAL_CONFIG_FILE_PATH"
    echo_warn "Пропускаем миграции"
fi

# Компиляция ассетов (если изменились)
if [ -d "app/assets" ]; then
    echo_step "Проверка необходимости компиляции ассетов..."
    if git diff --name-only "$PREVIOUS_COMMIT..$NEW_COMMIT" | grep -q "app/assets"; then
        echo_info "Обнаружены изменения в ассетах, выполняется прекомпиляция..."
        $USE_SUDO RAILS_ENV=production bundle exec rake assets:precompile
    else
        echo_info "Изменений в ассетах нет, пропускаем компиляцию"
    fi
fi

# Перезапуск сервисов
echo_step "Перезапуск сервисов Postal..."
if [ "$CURRENT_USER" = "postal" ]; then
    echo_warn "Для перезапуска сервисов требуются права root"
    echo_info "Выполните вручную:"
    echo_info "  sudo systemctl restart postal-web postal-smtp postal-worker"
else
    sudo systemctl restart postal-web postal-smtp postal-worker
    echo_info "Сервисы перезапущены"
fi

# Проверка статуса сервисов
echo_step "Проверка статуса сервисов..."
sleep 3

if [ "$CURRENT_USER" != "postal" ]; then
    if sudo systemctl is-active --quiet postal-web && \
       sudo systemctl is-active --quiet postal-smtp && \
       sudo systemctl is-active --quiet postal-worker; then
        echo_info "✓ Все сервисы запущены успешно"
    else
        echo_error "✗ Некоторые сервисы не запустились"
        echo_error "Проверьте логи: sudo journalctl -u postal-* -n 50"
        exit 1
    fi
else
    echo_info "Проверьте статус сервисов вручную:"
    echo_info "  sudo systemctl status postal-*"
fi

echo ""
echo_info "=== Обновление завершено успешно! ==="
echo ""
echo_info "Версия Postal:"
$USE_SUDO ./bin/postal version
echo ""
echo_info "Полезные команды:"
echo_info "  Просмотр логов:     sudo journalctl -u postal-web -f"
echo_info "  Статус сервисов:    sudo systemctl status postal-*"
echo_info "  Откат к предыдущей версии:"
echo_info "    git checkout $PREVIOUS_COMMIT"
echo_info "    ./script/deploy-update.sh"
echo ""
