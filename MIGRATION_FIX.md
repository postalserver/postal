# Fix for IP Address Page Error

## Problem
После добавления функционала прокси, страница добавления IP адреса выдает ошибку 500:
```
undefined method 'use_proxy' for an instance of IPAddress
```

## Причина
Миграция базы данных для добавления полей прокси не была применена. Модель и форма уже обновлены, но в базе данных отсутствуют необходимые колонки.

## Решение

### Вариант 1: Использование Rails миграций (Рекомендуется)

Выполните миграцию через Rails:

```bash
docker compose exec web bash -c "cd /opt/postal/app && bundle exec rails db:migrate"
```

Или если вы используете `postal` CLI:

```bash
postal db migrate
```

### Вариант 2: Прямое выполнение SQL

Если первый вариант не работает, выполните SQL скрипт напрямую в базе данных:

```bash
docker compose exec db mysql -u root -ppassword postal-production < db/migrate/fix_proxy_fields.sql
```

### Вариант 3: Через MySQL CLI вручную

```bash
docker compose exec db mysql -u root -ppassword postal-production
```

Затем скопируйте и выполните SQL команды из файла `db/migrate/fix_proxy_fields.sql`.

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
