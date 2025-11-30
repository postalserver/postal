# Упрощенное развертывание Postal на Ubuntu 22.04

Этот гайд описывает простой способ разработки и развертывания Postal напрямую на Ubuntu без необходимости каждый раз пересобирать Docker образы.

## Преимущества этого подхода

- ✅ Быстрое обновление: просто `git pull` и перезапуск сервисов
- ✅ Легкое тестирование изменений локально
- ✅ Не нужно мерджить, пересобирать образы и переустанавливать
- ✅ Простая отладка и просмотр логов
- ✅ Возможность быстро откатиться к предыдущей версии

## Установка на сервере (первый раз)

### 1. Установка зависимостей

```bash
# Обновление системы
sudo apt-get update
sudo apt-get upgrade -y

# Установка необходимых пакетов
sudo apt-get install -y \
  build-essential \
  git \
  libmariadb-dev \
  libcap2-bin \
  libyaml-dev \
  curl \
  gnupg2

# Установка MariaDB
sudo apt-get install -y mariadb-server mariadb-client
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Установка RabbitMQ (если используется)
sudo apt-get install -y rabbitmq-server
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server

# Установка Ruby (версия 3.4.6)
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install 3.4.6
rvm use 3.4.6 --default

# Установка Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Создание пользователя для Postal

```bash
sudo useradd -r -d /opt/postal -m -s /bin/bash postal
sudo usermod -aG sudo postal  # опционально, для административных задач
```

### 3. Клонирование и настройка проекта

```bash
# Переключиться на пользователя postal
sudo su - postal

# Клонировать репозиторий
cd /opt/postal
git clone https://github.com/postalserver/postal.git app
# Или ваш форк:
# git clone https://github.com/YOUR_USERNAME/postal.git app

cd app

# Установка bundler
gem install bundler -v 2.7.2

# Установка зависимостей
bundle install

# Дать Ruby возможность использовать порты < 1024
sudo setcap 'cap_net_bind_service=+ep' $(which ruby)
```

### 4. Конфигурация

```bash
# Создать директорию для конфигурации
mkdir -p /opt/postal/config

# Создать конфигурационный файл
nano /opt/postal/config/postal.yml
```

Пример минимальной конфигурации:

```yaml
version: 2
postal:
  web_server:
    bind_address: 0.0.0.0
    port: 5000
  smtp_server:
    port: 25
    tls_enabled: true
    tls_certificate_path: /opt/postal/config/postal.cert
    tls_private_key_path: /opt/postal/config/postal.key

main_db:
  host: localhost
  username: postal
  password: YOUR_DB_PASSWORD
  database: postal

message_db:
  host: localhost
  username: postal
  password: YOUR_DB_PASSWORD
  prefix: postal
```

### 5. Инициализация базы данных

```bash
# Создать базу данных и пользователя в MariaDB
sudo mysql -u root << EOF
CREATE DATABASE postal;
CREATE USER 'postal'@'localhost' IDENTIFIED BY 'YOUR_DB_PASSWORD';
GRANT ALL PRIVILEGES ON postal.* TO 'postal'@'localhost';
GRANT ALL PRIVILEGES ON \`postal-%\`.* TO 'postal'@'localhost';
FLUSH PRIVILEGES;
EOF

# Инициализировать схему
cd /opt/postal/app
export POSTAL_CONFIG_FILE_PATH=/opt/postal/config/postal.yml
./bin/postal initialize

# Создать администратора
./bin/postal make-user
```

### 6. Настройка systemd сервисов

Создайте файлы systemd для автозапуска:

```bash
# Web сервер
sudo tee /etc/systemd/system/postal-web.service << 'EOF'
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
sudo tee /etc/systemd/system/postal-smtp.service << 'EOF'
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
sudo tee /etc/systemd/system/postal-worker.service << 'EOF'
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

# Включить и запустить сервисы
sudo systemctl daemon-reload
sudo systemctl enable postal-web postal-smtp postal-worker
sudo systemctl start postal-web postal-smtp postal-worker
```

## Быстрое обновление (когда есть изменения в коде)

Используйте скрипт `./script/deploy-update.sh` (см. ниже):

```bash
cd /opt/postal/app
./script/deploy-update.sh
```

Этот скрипт автоматически:
1. Делает `git pull`
2. Обновляет зависимости
3. Выполняет миграции БД
4. Перезапускает сервисы

## Локальная разработка

### На вашей машине разработки:

```bash
# Установить зависимости (как на сервере, но проще)
bundle install

# Скопировать пример конфигурации
mkdir -p config/postal
cp doc/config/yaml.yml config/postal/postal.yml
# Отредактировать config/postal/postal.yml под локальные настройки

# Инициализировать БД
./bin/postal initialize

# Запустить все сервисы для разработки
# Установить foreman (если нет)
gem install foreman

# Запустить все процессы
foreman start -f Procfile.dev
```

### Тестирование изменений:

```bash
# Запустить тесты
bundle exec rspec

# Запустить отдельный компонент
./bin/postal web-server   # только web
./bin/postal smtp-server  # только SMTP
./bin/postal worker       # только worker
```

### Отправка изменений на сервер:

```bash
# Закоммитить изменения
git add .
git commit -m "Описание изменений"
git push

# На сервере - просто обновить
ssh postal@your-server.com
cd /opt/postal/app
./script/deploy-update.sh
```

## Просмотр логов

```bash
# Web сервер
sudo journalctl -u postal-web -f

# SMTP сервер
sudo journalctl -u postal-smtp -f

# Worker
sudo journalctl -u postal-worker -f

# Все сервисы вместе
sudo journalctl -u postal-* -f
```

## Откат к предыдущей версии

```bash
cd /opt/postal/app
git log --oneline -10  # посмотреть последние коммиты
git checkout COMMIT_HASH  # откатиться к нужному коммиту
./script/deploy-update.sh
```

## Полезные команды

```bash
# Консоль Rails
cd /opt/postal/app
./bin/postal console

# Проверить статус сервисов
sudo systemctl status postal-*

# Перезапустить все сервисы
sudo systemctl restart postal-web postal-smtp postal-worker

# Просмотреть версию
./bin/postal version
```

## Сравнение подходов

### Старый способ (Docker):
1. Claude делает изменения → коммит → push
2. Вы: merge изменений
3. Вы: пересборка Docker образа (долго!)
4. Вы: остановка контейнеров
5. Вы: запуск новых контейнеров
6. Проблемы с дебагом внутри контейнера

### Новый способ (Native):
1. Claude делает изменения → коммит → push
2. Вы: `./script/deploy-update.sh` (всё!)
3. Готово, сервис обновлен

## Безопасность

- Используйте firewall (ufw) для ограничения доступа к портам
- Настройте SSL/TLS сертификаты (Let's Encrypt)
- Регулярно обновляйте систему и зависимости
- Используйте strong пароли для БД
- Настройте бэкапы базы данных

```bash
# Пример настройки UFW
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5000/tcp  # Postal Web (или настройте nginx proxy)
sudo ufw enable
```
