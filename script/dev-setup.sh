#!/bin/bash
# Скрипт для быстрой настройки локального окружения разработки
# Использование: ./script/dev-setup.sh

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

echo_info "=== Настройка окружения для разработки Postal ==="
echo ""

# Проверка Ruby
echo_step "Проверка версии Ruby..."
if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby -v | awk '{print $2}')
    echo_info "Ruby версия: $RUBY_VERSION"

    # Проверка соответствия версии
    if [[ ! "$RUBY_VERSION" =~ ^3\.4 ]]; then
        echo_warn "Рекомендуется Ruby 3.4.x, у вас установлена версия $RUBY_VERSION"
        echo_warn "Для установки правильной версии:"
        echo_warn "  rvm install 3.4.6"
        echo_warn "  rvm use 3.4.6"
    fi
else
    echo_error "Ruby не установлен"
    echo_error "Установите Ruby 3.4.6:"
    echo_error "  curl -sSL https://get.rvm.io | bash -s stable"
    echo_error "  rvm install 3.4.6"
    exit 1
fi

# Проверка Bundler
echo_step "Проверка Bundler..."
if command -v bundle &> /dev/null; then
    BUNDLER_VERSION=$(bundle -v | awk '{print $3}')
    echo_info "Bundler версия: $BUNDLER_VERSION"
else
    echo_warn "Bundler не установлен, устанавливаем..."
    gem install bundler -v 2.7.2
fi

# Установка зависимостей
echo_step "Установка зависимостей Ruby..."
bundle install

# Проверка Node.js
echo_step "Проверка Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo_info "Node.js версия: $NODE_VERSION"
else
    echo_warn "Node.js не установлен"
    echo_warn "Установите Node.js 20.x:"
    echo_warn "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    echo_warn "  sudo apt-get install -y nodejs"
fi

# Проверка базы данных
echo_step "Проверка базы данных..."
if command -v mysql &> /dev/null; then
    echo_info "MySQL/MariaDB найден"
else
    echo_warn "MySQL/MariaDB не найден"
    echo_warn "Установите MariaDB:"
    echo_warn "  sudo apt-get install -y mariadb-server mariadb-client"
fi

# Создание директории для конфигурации
echo_step "Создание конфигурационных директорий..."
mkdir -p config/postal
mkdir -p log
mkdir -p tmp

# Создание примера конфигурации для разработки
if [ ! -f "config/postal/postal.yml" ]; then
    echo_step "Создание примера конфигурации..."
    cat > config/postal/postal.yml << 'EOF'
version: 2
postal:
  web_server:
    bind_address: 127.0.0.1
    port: 5000
  smtp_server:
    port: 2525  # Используем порт > 1024 для разработки без sudo
    tls_enabled: false
  use_ip_pools: false

main_db:
  host: localhost
  username: root
  password: ""
  database: postal_dev

message_db:
  host: localhost
  username: root
  password: ""
  prefix: postal_dev

logging:
  stdout: true
  level: debug

web:
  host: localhost:5000
  protocol: http
EOF
    echo_info "Создан config/postal/postal.yml"
    echo_warn "Отредактируйте файл config/postal/postal.yml для настройки базы данных"
else
    echo_info "Конфигурация уже существует: config/postal/postal.yml"
fi

# Создание .env для переменных окружения
if [ ! -f ".env" ]; then
    echo_step "Создание .env файла..."
    cat > .env << 'EOF'
# Переменные окружения для разработки Postal
POSTAL_CONFIG_FILE_PATH=config/postal/postal.yml
RAILS_ENV=development
PORT=5000

# Раскомментируйте для дебага
# LOGGING_LEVEL=debug
EOF
    echo_info "Создан .env файл"
else
    echo_info ".env файл уже существует"
fi

# Создание базы данных
echo_step "Хотите создать базу данных и выполнить миграции? (y/n)"
read -p "> " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo_info "Создание базы данных..."
    export POSTAL_CONFIG_FILE_PATH=config/postal/postal.yml
    ./bin/postal initialize || echo_warn "База данных уже существует или произошла ошибка"
fi

# Установка foreman для удобного запуска процессов
echo_step "Проверка foreman..."
if command -v foreman &> /dev/null; then
    echo_info "Foreman установлен"
else
    echo_warn "Foreman не установлен"
    read -p "Установить foreman для удобного запуска процессов? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        gem install foreman
    fi
fi

echo ""
echo_info "=== Настройка завершена! ==="
echo ""
echo_info "Быстрый старт:"
echo_info ""
echo_info "1. Отредактируйте config/postal/postal.yml (настройки БД)"
echo_info ""
echo_info "2. Создайте администратора:"
echo_info "   ./bin/postal make-user"
echo_info ""
echo_info "3. Запустите все процессы разработки:"
echo_info "   foreman start -f Procfile.dev"
echo_info ""
echo_info "   Или запустите процессы отдельно:"
echo_info "   ./bin/postal web-server    # Web интерфейс на http://localhost:5000"
echo_info "   ./bin/postal smtp-server   # SMTP сервер на порту 2525"
echo_info "   ./bin/postal worker        # Обработчик очереди"
echo_info ""
echo_info "4. Запустите тесты:"
echo_info "   bundle exec rspec"
echo_info ""
echo_info "5. Откройте консоль Rails:"
echo_info "   ./bin/postal console"
echo_info ""
echo_warn "Примечание: Для разработки SMTP работает на порту 2525 (не требует sudo)"
echo_warn "Для использования порта 25 нужны права root или setcap"
echo ""
