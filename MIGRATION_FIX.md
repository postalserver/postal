# Fix for IP Address Page Error

## Problem
После добавления функционала прокси, страница добавления IP адреса выдает ошибку 500:
```
undefined method 'use_proxy' for an instance of IPAddress
```

## Причина
Миграция базы данных для добавления полей прокси не могла быть применена из-за **бага в названии класса миграции**.

Rails ожидал класс `AddProxyFieldsToIPAddresses` (с заглавными IP), но в файле миграции был указан класс `AddProxyFieldsToIpAddresses` (с Ip). Это вызывало ошибку:
```
NameError: uninitialized constant AddProxyFieldsToIPAddresses
Did you mean?  AddProxyFieldsToIpAddresses
```

**Баг исправлен!** Теперь миграция работает корректно.

## Решение

### ✅ Обновите код и запустите миграцию

1. **Получите исправленную версию миграции:**
```bash
cd /home/user/postal  # или где находится ваш клон репозитория
git pull origin main  # или ваша ветка с исправлением
```

2. **Примените миграцию:**
```bash
postal upgrade
```

Эта команда теперь должна успешно применить миграцию без ошибки `NameError`.

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
