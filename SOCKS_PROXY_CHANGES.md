# Изменения для поддержки SOCKS Proxy в Postal

## Краткое описание

Добавлена нативная поддержка SOCKS5 proxy для исходящих SMTP соединений в Postal. Это позволяет отправлять почту через другой сервер, используя его IP адрес вместо IP адреса сервера с Postal.

## Зачем это нужно?

**Проблема:** Вы хотите отправлять почту с IP адреса сервера2 (IP2), но Postal работает на сервере1 (IP1).

**Решение:** SOCKS proxy на сервере2 позволяет всему SMTP трафику проходить через IP2. Получатели видят только IP2, IP1 остается скрыт.

```
Postal (IP1) → SOCKS5 (IP2) → Gmail/Outlook/etc
                       ↑
                Получатели видят только этот IP
```

## Файлы изменены

### 1. `/home/user/postal/Gemfile`
- Добавлен гем `socksify` для поддержки SOCKS5 proxy

### 2. `/home/user/postal/lib/postal/config_schema.rb`
- Добавлены новые опции конфигурации в секцию `smtp_client`:
  - `socks_proxy_host` - хост SOCKS proxy сервера
  - `socks_proxy_port` - порт SOCKS proxy (по умолчанию 1080)
  - `socks_proxy_username` - имя пользователя (опционально)
  - `socks_proxy_password` - пароль (опционально)

### 3. `/home/user/postal/app/lib/smtp_client/endpoint.rb`
- Модифицирован метод `start_smtp_session` для поддержки SOCKS proxy
- Добавлены методы:
  - `setup_smtp_with_socks_proxy` - настройка соединения через SOCKS
  - `setup_smtp_direct` - прямое соединение (оригинальное поведение)
  - `configure_ssl` - вынесена конфигурация SSL в отдельный метод

## Новые файлы

### 1. `SOCKS_PROXY_SETUP.md`
Подробное руководство по настройке SOCKS proxy на втором сервере с примерами:
- SSH Dynamic Forward
- Dante SOCKS Server
- WireGuard + SSH
- Policy-based routing
- Настройка DNS (PTR, SPF, DKIM)
- Troubleshooting

### 2. `script/test_socks_connection.rb`
Тестовый скрипт для проверки работоспособности SOCKS соединения:
- Проверка доступности SOCKS proxy
- Определение IP через proxy
- Тестирование SMTP соединения через SOCKS
- DNS резолюция

## Как использовать

### 1. Установить зависимости

```bash
cd /home/user/postal
bundle install
```

### 2. Настроить SOCKS proxy на сервере2

Простейший вариант (SSH туннель):
```bash
ssh -D 1080 -N -f user@IP2
```

Или установить Dante SOCKS Server (рекомендуется для продакшена).
Подробности в `SOCKS_PROXY_SETUP.md`.

### 3. Обновить конфигурацию Postal

Отредактировать `postal.yml`:

```yaml
smtp_client:
  open_timeout: 30
  read_timeout: 30
  socks_proxy_host: "127.0.0.1"
  socks_proxy_port: 1080
```

### 4. Тестировать

```bash
# Проверить SOCKS соединение
ruby script/test_socks_connection.rb

# Перезапустить Postal
postal restart

# Отправить тестовое письмо
```

## Проверка работоспособности

### Проверить через какой IP идет трафик:

```bash
# Через SOCKS proxy
curl --socks5 127.0.0.1:1080 https://ifconfig.me

# Должен вернуть IP2, а не IP1
```

### Проверить заголовки письма:

Отправьте тестовое письмо себе и проверьте заголовки:
- `Received:` должен показывать IP2
- Сервисы типа mail-tester.com должны видеть IP2

## Безопасность

⚠️ **Важно:**

1. **Firewall:** Разрешите доступ к SOCKS порту только с IP1
   ```bash
   ufw allow from IP1 to any port 1080
   ```

2. **PTR запись:** Убедитесь что для IP2 настроен reverse DNS
   ```bash
   dig -x IP2
   ```

3. **SPF запись:** Добавьте IP2 в SPF запись вашего домена
   ```
   v=spf1 ip4:IP2 ~all
   ```

## Производительность

- SOCKS proxy добавляет минимальную задержку (обычно 10-50ms)
- Для продакшена рекомендуется использовать Dante SOCKS Server
- SSH туннель хорош для тестирования, но может быть нестабилен

## Совместимость

- ✅ Работает с IPv4
- ✅ Работает с IPv6 (если SOCKS proxy поддерживает)
- ✅ Поддерживает TLS/STARTTLS
- ✅ Обратная совместимость: если `socks_proxy_host` не указан, Postal работает как раньше

## Откат изменений

Если нужно вернуться к прямым соединениям:

1. Закомментировать или удалить настройки SOCKS в `postal.yml`:
   ```yaml
   smtp_client:
     # socks_proxy_host: "127.0.0.1"
     # socks_proxy_port: 1080
   ```

2. Перезапустить Postal

Код автоматически определит отсутствие конфигурации и будет использовать прямые соединения.

## Дальнейшие улучшения (опционально)

Возможные доработки:

1. **Per-server SOCKS settings** - разные SOCKS proxy для разных серверов/организаций
2. **SOCKS proxy pool** - ротация между несколькими SOCKS proxy
3. **Health checks** - автоматическая проверка доступности SOCKS proxy
4. **Metrics** - статистика использования SOCKS соединений
5. **HTTP CONNECT proxy** - поддержка альтернативного типа proxy

## Поддержка

Документация:
- Полное руководство: `SOCKS_PROXY_SETUP.md`
- Тестовый скрипт: `script/test_socks_connection.rb`

При проблемах проверьте:
1. Логи Postal: `/opt/postal/log/smtp.log`
2. Логи SOCKS сервера: `/var/log/syslog` (для Dante)
3. Сетевую доступность: `telnet 127.0.0.1 1080`
