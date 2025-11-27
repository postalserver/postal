# Настройка SOCKS Proxy для Postal

Это руководство объясняет как настроить Postal для отправки почты через SOCKS5 proxy, что позволяет использовать IP адрес с другого сервера.

## Архитектура

```
Postal (IP1) → SOCKS5 Proxy (IP2) → Интернет
```

Получатели видят только IP2, IP1 полностью скрыт.

## Шаг 1: Установить зависимости

```bash
cd /home/user/postal
bundle install
```

## Шаг 2: Настроить SOCKS proxy на сервере2 (с IP2)

### Вариант A: SSH Dynamic Forward (простой, для тестирования)

На сервере с Postal:
```bash
# Создать SSH туннель с SOCKS5 proxy
ssh -D 1080 -N -f user@IP2

# Проверить что порт 1080 слушает
netstat -tlnp | grep 1080
```

### Вариант B: Dante SOCKS Server (продакшен)

На сервере2 (Ubuntu 22):
```bash
# Установить Dante
apt-get update
apt-get install dante-server

# Конфигурация /etc/danted.conf
cat > /etc/danted.conf << 'EOF'
logoutput: syslog

# Внутренний интерфейс (слушать соединения от Postal)
internal: eth0 port = 1080

# Внешний интерфейс (для исходящих соединений)
external: eth0

# Метод аутентификации
clientmethod: none
socksmethod: none

# Правила доступа
client pass {
    from: IP1/32 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: IP1/32 to: 0.0.0.0/0
    protocol: tcp
    command: connect
    log: connect disconnect error
}
EOF

# Запустить Dante
systemctl enable danted
systemctl start danted
systemctl status danted

# Проверить firewall
ufw allow from IP1 to any port 1080
```

### Вариант C: WireGuard + SSH (максимальная безопасность)

**На обоих серверах:**
```bash
apt install wireguard
```

**На сервере с Postal:**
```bash
# Генерировать ключи
wg genkey | tee privatekey | wg pubkey > publickey

# /etc/wireguard/wg0.conf
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = <privatekey_сервера1>
Address = 10.0.0.1/24

[Peer]
PublicKey = <publickey_сервера2>
Endpoint = IP2:51820
AllowedIPs = 10.0.0.2/32
PersistentKeepalive = 25
EOF

# Запустить
wg-quick up wg0
systemctl enable wg-quick@wg0
```

**На сервере2:**
```bash
# Генерировать ключи
wg genkey | tee privatekey | wg pubkey > publickey

# /etc/wireguard/wg0.conf
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = <privatekey_сервера2>
Address = 10.0.0.2/24
ListenPort = 51820

[Peer]
PublicKey = <publickey_сервера1>
AllowedIPs = 10.0.0.1/32
EOF

# Запустить
wg-quick up wg0
systemctl enable wg-quick@wg0

# Настроить SSH SOCKS на WireGuard интерфейсе
# Теперь SSH туннель будет защищен WireGuard
```

Затем создать SSH туннель через WireGuard:
```bash
# На сервере с Postal
ssh -D 1080 -N -f user@10.0.0.2
```

## Шаг 3: Настроить Postal конфигурацию

Отредактируйте конфигурационный файл Postal (обычно `/opt/postal/config/postal.yml`):

```yaml
smtp_client:
  open_timeout: 30
  read_timeout: 30
  # SOCKS5 proxy настройки
  socks_proxy_host: "127.0.0.1"  # или 10.0.0.2 для WireGuard
  socks_proxy_port: 1080
  # socks_proxy_username: "user"  # опционально
  # socks_proxy_password: "pass"  # опционально
```

## Шаг 4: Перезапустить Postal

```bash
# Используйте вашу команду для перезапуска Postal, например:
postal stop
postal start

# Или если используется Docker:
docker-compose restart postal
```

## Шаг 5: Проверка

### Проверить SOCKS соединение:

```bash
# Установить curl с SOCKS поддержкой
apt install curl

# Проверить через SOCKS proxy
curl --socks5 127.0.0.1:1080 https://ifconfig.me

# Должен показать IP2, а не IP1
```

### Отправить тестовое письмо:

```bash
# Через Postal CLI или API отправьте тестовое письмо
# Проверьте заголовки полученного письма - должны показывать IP2
```

### Проверить логи:

```bash
# Логи Postal
tail -f /opt/postal/log/smtp.log

# Логи Dante (если используется)
tail -f /var/log/syslog | grep danted
```

## Важные замечания

### DNS записи для IP2:

Убедитесь что для IP2 настроены:

```bash
# PTR запись (reverse DNS)
dig -x IP2

# SPF запись
dig TXT yourdomain.com

# Пример SPF:
# v=spf1 ip4:IP2 ~all
```

### Производительность:

- SOCKS proxy добавляет небольшую задержку (~10-50ms в зависимости от расстояния между серверами)
- Для продакшена рекомендуется WireGuard + Dante
- SSH туннель хорош для тестирования, но может быть нестабилен

### Безопасность:

1. **Firewall на сервере2:**
   ```bash
   # Разрешить только от IP1
   ufw allow from IP1 to any port 1080
   ufw deny 1080
   ```

2. **Аутентификация Dante:**
   ```
   # В /etc/danted.conf использовать username auth
   socksmethod: username

   # Создать пользователя
   useradd -r -s /bin/false socksuser
   passwd socksuser
   ```

3. **Мониторинг:**
   ```bash
   # Установить fail2ban для защиты от атак
   apt install fail2ban
   ```

## Альтернативные варианты

### 1. Policy-based routing (без SOCKS)

Если серверы в одной сети, можно настроить маршрутизацию:

```bash
# На сервере с Postal
ip route add default via IP2 table 100
ip rule add fwmark 25 table 100
iptables -t mangle -A OUTPUT -p tcp --dport 25 -j MARK --set-mark 25
```

### 2. HAProxy в TCP режиме

На сервере2:
```bash
# /etc/haproxy/haproxy.cfg
frontend smtp_front
    bind *:2525
    mode tcp
    default_backend smtp_back

backend smtp_back
    mode tcp
    source 0.0.0.0 usesrc clientip
    server smtp 0.0.0.0:25
```

## Troubleshooting

### SOCKS соединение не работает:

```bash
# Проверить доступность SOCKS proxy
telnet 127.0.0.1 1080

# Проверить firewall
iptables -L -n -v | grep 1080

# Проверить что процесс слушает
lsof -i :1080
```

### Письма не отправляются:

```bash
# Проверить логи Postal
tail -f /opt/postal/log/smtp.log

# Включить debug в Ruby (временно)
# В config/environments/production.rb
config.log_level = :debug
```

### Получатели все еще видят IP1:

- Проверьте что трафик действительно идет через proxy
- Проверьте NAT на сервере2
- Используйте tcpdump для анализа трафика

## Поддержка

Если возникли проблемы:
1. Проверьте логи Postal
2. Проверьте логи SOCKS сервера
3. Используйте tcpdump для отладки: `tcpdump -i any port 1080 or port 25`
