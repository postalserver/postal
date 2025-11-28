# Fix for IP Address Page Error

## Problem
После добавления функционала прокси, страница добавления IP адреса выдает ошибку 500:
```
undefined method 'use_proxy' for an instance of IPAddress
```

## Причина
Миграция базы данных для добавления полей прокси не была применена. Модель и форма уже обновлены, но в базе данных отсутствуют необходимые колонки.

**Это произошло потому, что после обновления кода не была запущена команда `postal upgrade`.**

## Решение

### ✅ Правильный способ (Рекомендуется)

После любого обновления кода Postal из Git **ВСЕГДА** нужно запускать:

```bash
postal upgrade
```

Эта команда автоматически применит все новые миграции базы данных.

Для текущей проблемы:

```bash
# Остановите Postal
postal stop

# Примените миграции
postal upgrade

# Запустите Postal
postal start
```

### Вариант 2: Через Docker (если postal запущен в контейнерах)

```bash
docker compose exec web bash -c "cd /opt/postal/app && bundle exec rake postal:update"
docker compose restart web
```

### Вариант 3: Прямое выполнение SQL (только если предыдущие способы не работают)

```bash
docker compose exec db mysql -u root -ppassword postal-production < db/migrate/fix_proxy_fields.sql
docker compose restart web
```

## Проверка

После применения миграции, проверьте, что поля добавлены:

```bash
docker compose exec db mysql -u root -ppassword postal-production -e "DESCRIBE ip_addresses;"
```

Вы должны увидеть новые поля:
- use_proxy
- proxy_type
- proxy_host
- proxy_port
- proxy_username
- proxy_password
- proxy_auto_install
- proxy_ssh_host
- proxy_ssh_port
- proxy_ssh_username
- proxy_ssh_password
- proxy_status
- proxy_last_tested_at
- proxy_last_test_result

## Перезапуск

После применения миграции, возможно потребуется перезапустить контейнер web:

```bash
docker compose restart web
```

Теперь страница https://web.bspin.ru/ip_pools/702dcf02-b97b-40c9-81cb-69b4238c6d2e/ip_addresses/new должна работать корректно.
