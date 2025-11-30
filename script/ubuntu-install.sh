#!/bin/bash
# Скрипт для первоначальной установки Postal на Ubuntu 22.04
# Использование: sudo ./script/ubuntu-install.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Проверка, что скрипт запущен с правами root
if [ "$EUID" -ne 0 ]; then
    echo_error "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

echo_info "=== Установка Postal на Ubuntu 22.04 ==="
echo ""

# Запрос данных для конфигурации
read -p "Введите имя домена для Postal (например, mail.example.com): " DOMAIN
read -p "Введите пароль для базы данных Postal: " -s DB_PASSWORD
echo ""
read -p "Введите email администратора: " ADMIN_EMAIL
read -p "Введите имя администратора: " ADMIN_NAME
read -p "Введите пароль администратора: " -s ADMIN_PASSWORD
echo ""

echo_info "Обновление системы..."
apt-get update
apt-get upgrade -y

echo_info "Установка необходимых пакетов..."
apt-get install -y \
    build-essential \
    git \
    libmariadb-dev \
    libcap2-bin \
    libyaml-dev \
    curl \
    gnupg2 \
    software-properties-common \
    ca-certificates

echo_info "Установка MariaDB..."
apt-get install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb

echo_info "Установка RVM и Ruby 3.4.6..."
# Установка GPG ключей для RVM
gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB || true

# Установка RVM
curl -sSL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh

# Установка Ruby
rvm install 3.4.6
rvm use 3.4.6 --default

echo_info "Установка Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo_info "Создание пользователя postal..."
if id "postal" &>/dev/null; then
    echo_warn "Пользователь postal уже существует"
else
    useradd -r -d /opt/postal -m -s /bin/bash postal
fi

echo_info "Создание директорий..."
mkdir -p /opt/postal/app
mkdir -p /opt/postal/config
chown -R postal:postal /opt/postal

echo_info "Клонирование репозитория Postal..."
if [ -d "/opt/postal/app/.git" ]; then
    echo_warn "Репозиторий уже склонирован, пропускаем"
else
    sudo -u postal git clone https://github.com/postalserver/postal.git /opt/postal/app
fi

echo_info "Установка Bundler и зависимостей Ruby..."
cd /opt/postal/app
sudo -u postal gem install bundler -v 2.7.2
sudo -u postal bundle install

echo_info "Настройка прав для Ruby..."
setcap 'cap_net_bind_service=+ep' $(which ruby)

echo_info "Создание базы данных..."
mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS postal;
CREATE USER IF NOT EXISTS 'postal'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON postal.* TO 'postal'@'localhost';
GRANT ALL PRIVILEGES ON \`postal-%\`.* TO 'postal'@'localhost';
FLUSH PRIVILEGES;
EOF

echo_info "Создание конфигурационного файла..."
cat > /opt/postal/config/postal.yml << EOF
version: 2
postal:
  web_server:
    bind_address: 0.0.0.0
    port: 5000
  smtp_server:
    port: 25
    tls_enabled: false
  use_ip_pools: false

main_db:
  host: localhost
  username: postal
  password: ${DB_PASSWORD}
  database: postal

message_db:
  host: localhost
  username: postal
  password: ${DB_PASSWORD}
  prefix: postal

logging:
  stdout: true

web:
  host: ${DOMAIN}
  protocol: https
EOF

chown postal:postal /opt/postal/config/postal.yml
chmod 600 /opt/postal/config/postal.yml

echo_info "Инициализация базы данных..."
cd /opt/postal/app
export POSTAL_CONFIG_FILE_PATH=/opt/postal/config/postal.yml
sudo -u postal -E ./bin/postal initialize

echo_info "Создание администратора..."
sudo -u postal -E ./bin/postal make-user << EOF
${ADMIN_EMAIL}
${ADMIN_NAME}
${ADMIN_PASSWORD}
${ADMIN_PASSWORD}
EOF

echo_info "Создание systemd сервисов..."

# Web сервер
cat > /etc/systemd/system/postal-web.service << 'EOF'
[Unit]
Description=Postal Web Server
After=network.target mariadb.service

[Service]
Type=simple
User=postal
WorkingDirectory=/opt/postal/app
Environment="POSTAL_CONFIG_FILE_PATH=/opt/postal/config/postal.yml"
ExecStart=/opt/postal/app/bin/postal web-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# SMTP сервер
cat > /etc/systemd/system/postal-smtp.service << 'EOF'
[Unit]
Description=Postal SMTP Server
After=network.target mariadb.service

[Service]
Type=simple
User=postal
WorkingDirectory=/opt/postal/app
Environment="POSTAL_CONFIG_FILE_PATH=/opt/postal/config/postal.yml"
ExecStart=/opt/postal/app/bin/postal smtp-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Worker
cat > /etc/systemd/system/postal-worker.service << 'EOF'
[Unit]
Description=Postal Worker
After=network.target mariadb.service

[Service]
Type=simple
User=postal
WorkingDirectory=/opt/postal/app
Environment="POSTAL_CONFIG_FILE_PATH=/opt/postal/config/postal.yml"
ExecStart=/opt/postal/app/bin/postal worker
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo_info "Запуск сервисов..."
systemctl daemon-reload
systemctl enable postal-web postal-smtp postal-worker
systemctl start postal-web postal-smtp postal-worker

echo ""
echo_info "=== Установка завершена! ==="
echo ""
echo_info "Postal установлен и запущен!"
echo_info "Web интерфейс доступен на: http://$(hostname -I | awk '{print $1}'):5000"
echo_info ""
echo_info "Данные для входа:"
echo_info "  Email: ${ADMIN_EMAIL}"
echo_info "  Пароль: (тот, что вы указали)"
echo ""
echo_info "Проверить статус сервисов:"
echo_info "  sudo systemctl status postal-*"
echo ""
echo_info "Просмотр логов:"
echo_info "  sudo journalctl -u postal-web -f"
echo_info "  sudo journalctl -u postal-smtp -f"
echo_info "  sudo journalctl -u postal-worker -f"
echo ""
echo_warn "Не забудьте:"
echo_warn "  1. Настроить DNS записи для домена ${DOMAIN}"
echo_warn "  2. Настроить SSL/TLS сертификаты (например, Let's Encrypt)"
echo_warn "  3. Настроить firewall (UFW)"
echo_warn "  4. Настроить reverse proxy (nginx/apache) если нужно"
echo ""
