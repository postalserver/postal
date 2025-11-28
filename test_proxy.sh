#!/bin/bash
# Скрипт для тестирования установленного прокси

echo "=== Тест SOCKS прокси ==="
echo ""

# Проверка 1: Слушает ли порт 1080
echo "1. Проверка что порт 1080 открыт:"
netstat -tulpn | grep 1080 || ss -tulpn | grep 1080
echo ""

# Проверка 2: Статус сервиса
echo "2. Статус сервиса danted:"
systemctl status danted --no-pager || service danted status
echo ""

# Проверка 3: Логи сервиса
echo "3. Последние логи danted:"
journalctl -u danted -n 20 --no-pager || tail -20 /var/log/syslog | grep danted
echo ""

# Проверка 4: Конфигурация
echo "4. Текущая конфигурация /etc/danted.conf:"
cat /etc/danted.conf
echo ""

# Проверка 5: Тест подключения через прокси (если установлен curl)
if command -v curl &> /dev/null; then
    echo "5. Тест подключения через прокси:"
    echo "Пытаюсь подключиться к ifconfig.me через прокси..."
    curl -x socks5://127.0.0.1:1080 ifconfig.me -v --connect-timeout 5 || echo "ОШИБКА: Не удалось подключиться через прокси"
else
    echo "5. curl не установлен, пропускаем тест подключения"
fi

echo ""
echo "=== Тест завершен ==="
