# Postal Management API v2

Полноценный RESTful API для автоматизации управления Postal. Позволяет программно управлять организациями, серверами, доменами, пользователями и всеми другими сущностями Postal.

## Содержание

- [Установка и применение изменений](#установка-и-применение-изменений)
- [Аутентификация](#аутентификация)
- [Создание API ключа](#создание-api-ключа)
- [Формат ответов](#формат-ответов)
- [Пагинация](#пагинация)
- [Эндпоинты API](#эндпоинты-api)
  - [Система](#система)
  - [Организации](#организации)
  - [Серверы](#серверы)
  - [Домены](#домены)
  - [Учетные данные (Credentials)](#учетные-данные-credentials)
  - [Маршруты (Routes)](#маршруты-routes)
  - [Вебхуки (Webhooks)](#вебхуки-webhooks)
  - [Сообщения](#сообщения)
  - [Пользователи](#пользователи)
- [Примеры использования](#примеры-использования)
- [Коды ошибок](#коды-ошибок)

---

## Установка и применение изменений

### Шаг 1: Обновление кода

Если вы используете стандартную установку через postal-install:

```bash
# Остановить Postal
postal stop

# Обновить код (предполагая, что вы уже склонировали обновленный репозиторий)
cd /opt/postal/app
git fetch origin
git checkout main
git pull origin main

# Или если используете ветку с Management API:
git fetch origin claude/postal-management-api-0135npiyxajSAqsmNwQe6eVg
git checkout claude/postal-management-api-0135npiyxajSAqsmNwQe6eVg
```

### Шаг 2: Применение миграции базы данных

```bash
# Выполнить миграцию для создания таблицы management_api_keys
postal upgrade
```

Или через Docker:

```bash
docker compose exec postal postal upgrade
```

### Шаг 3: Создание API ключа

```bash
# Создать супер-админ ключ (доступ ко всем организациям)
postal console
```

В консоли Rails:

```ruby
key = ManagementApiKey.create!(
  name: "My Management Key",
  super_admin: true,
  description: "Main automation key"
)
puts "API Key: #{key.key}"
```

Или используйте rake task:

```bash
# Через postal CLI
postal rake management_api:create_key["My Management Key"]

# Или напрямую через docker
docker compose exec postal bundle exec rake management_api:create_key["My Management Key"]
```

### Шаг 4: Запуск Postal

```bash
postal start
```

### Шаг 5: Проверка работоспособности

```bash
# Проверить health endpoint (не требует аутентификации)
curl https://postal.yourdomain.com/api/v2/management/system/health

# Проверить статус с аутентификацией
curl -H "X-Management-API-Key: mgmt_YOUR_KEY_HERE" \
     https://postal.yourdomain.com/api/v2/management/system/status
```

---

## Аутентификация

Все запросы к API (кроме `/system/health`) требуют аутентификации через заголовок:

```
X-Management-API-Key: mgmt_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Или через Bearer токен:

```
Authorization: Bearer mgmt_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Типы ключей

1. **Super Admin** - полный доступ ко всем организациям и операциям
2. **Organization-scoped** - доступ только к определенной организации

---

## Создание API ключа

### Через консоль Rails

```bash
postal console
```

```ruby
# Супер-админ ключ
key = ManagementApiKey.create!(
  name: "Automation Key",
  super_admin: true
)
puts key.key

# Ключ для конкретной организации
org = Organization.find_by(permalink: "my-org")
key = ManagementApiKey.create!(
  name: "Org API Key",
  organization: org,
  super_admin: false
)
puts key.key
```

### Через Rake tasks

```bash
# Список всех ключей
postal rake management_api:list_keys

# Создать супер-админ ключ
postal rake management_api:create_key["My Key Name"]

# Создать ключ для организации
postal rake management_api:create_org_key["Key Name","org-permalink"]

# Отключить ключ
postal rake management_api:disable_key[uuid]

# Включить ключ
postal rake management_api:enable_key[uuid]

# Удалить ключ
postal rake management_api:delete_key[uuid]
```

### Через API (только для super admin)

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/system/api_keys \
  -H "X-Management-API-Key: mgmt_YOUR_SUPER_ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "New API Key",
    "super_admin": false,
    "organization_permalink": "my-org"
  }'
```

---

## Формат ответов

### Успешный ответ

```json
{
  "status": "success",
  "time": 0.0234,
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 25,
    "total": 100,
    "total_pages": 4
  }
}
```

### Ответ с ошибкой

```json
{
  "status": "error",
  "time": 0.0012,
  "error": {
    "code": "NotFound",
    "message": "Resource not found"
  }
}
```

### Ошибка валидации

```json
{
  "status": "error",
  "time": 0.0045,
  "error": {
    "code": "ValidationError",
    "message": "Validation failed",
    "details": {
      "name": ["can't be blank"],
      "permalink": ["has already been taken"]
    }
  }
}
```

---

## Пагинация

Для списков используйте параметры:

- `page` - номер страницы (по умолчанию: 1)
- `per_page` - элементов на странице (по умолчанию: 25, максимум: 100)

```bash
curl "https://postal.yourdomain.com/api/v2/management/organizations?page=2&per_page=50" \
  -H "X-Management-API-Key: mgmt_xxx"
```

---

## Эндпоинты API

### Система

#### Health Check (без аутентификации)

```
GET /api/v2/management/system/health
```

```bash
curl https://postal.yourdomain.com/api/v2/management/system/health
```

Ответ:
```json
{
  "status": "healthy",
  "time": "2025-01-15T10:30:00Z",
  "version": "3.0.0"
}
```

#### Статус системы

```
GET /api/v2/management/system/status
```

#### Статистика системы (super admin)

```
GET /api/v2/management/system/stats
```

#### Управление API ключами (super admin)

```
GET    /api/v2/management/system/api_keys
POST   /api/v2/management/system/api_keys
DELETE /api/v2/management/system/api_keys/:uuid
```

---

### Организации

#### Список организаций

```
GET /api/v2/management/organizations
```

Параметры фильтрации:
- `name` - поиск по имени
- `permalink` - точное совпадение permalink

```bash
curl "https://postal.yourdomain.com/api/v2/management/organizations?name=test" \
  -H "X-Management-API-Key: mgmt_xxx"
```

#### Получить организацию

```
GET /api/v2/management/organizations/:permalink
```

#### Создать организацию

```
POST /api/v2/management/organizations
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/organizations \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Company",
    "permalink": "my-company",
    "time_zone": "Europe/Moscow",
    "owner_email": "admin@example.com"
  }'
```

#### Обновить организацию

```
PATCH /api/v2/management/organizations/:permalink
```

```bash
curl -X PATCH https://postal.yourdomain.com/api/v2/management/organizations/my-company \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Company Updated"
  }'
```

#### Удалить организацию

```
DELETE /api/v2/management/organizations/:permalink
```

#### Приостановить организацию

```
POST /api/v2/management/organizations/:permalink/suspend
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/organizations/my-company/suspend \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{"reason": "Payment overdue"}'
```

#### Возобновить организацию

```
POST /api/v2/management/organizations/:permalink/unsuspend
```

---

### Серверы

#### Список серверов

```
GET /api/v2/management/servers
GET /api/v2/management/organizations/:org_permalink/servers
```

Параметры фильтрации:
- `name` - поиск по имени
- `mode` - Live или Development

#### Получить сервер

```
GET /api/v2/management/servers/:uuid
```

#### Создать сервер

```
POST /api/v2/management/organizations/:org_permalink/servers
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/organizations/my-company/servers \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Mail",
    "mode": "Live",
    "send_limit": 10000,
    "create_api_credential": true
  }'
```

Ответ включает автоматически созданный API ключ:
```json
{
  "status": "success",
  "data": {
    "uuid": "xxx",
    "name": "Production Mail",
    "token": "ABCDEF",
    "credentials": [
      {
        "uuid": "yyy",
        "name": "Default API Key",
        "type": "API",
        "key": "abc123..."
      }
    ]
  }
}
```

#### Обновить сервер

```
PATCH /api/v2/management/servers/:uuid
```

#### Удалить сервер

```
DELETE /api/v2/management/servers/:uuid
```

#### Приостановить/возобновить сервер

```
POST /api/v2/management/servers/:uuid/suspend
POST /api/v2/management/servers/:uuid/unsuspend
```

#### Статистика сервера

```
GET /api/v2/management/servers/:uuid/stats
```

```json
{
  "status": "success",
  "data": {
    "uuid": "xxx",
    "name": "Production Mail",
    "message_rate": 12.5,
    "queue_size": 150,
    "held_messages": 3,
    "throughput": {
      "incoming": 450,
      "outgoing": 1200,
      "outgoing_usage": 12.0
    },
    "bounce_rate": 2.3,
    "domain_stats": {
      "total": 5,
      "unverified": 1,
      "bad_dns": 0
    },
    "send_limit": 10000,
    "send_limit_approaching": false,
    "send_limit_exceeded": false
  }
}
```

---

### Домены

#### Список доменов сервера

```
GET /api/v2/management/servers/:server_uuid/domains
```

Параметры:
- `name` - поиск по имени
- `verified` - true/false

#### Получить домен

```
GET /api/v2/management/servers/:server_uuid/domains/:uuid
```

#### Создать домен

```
POST /api/v2/management/servers/:server_uuid/domains
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/domains \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "example.com",
    "verification_method": "DNS"
  }'
```

Ответ с DNS записями для настройки:
```json
{
  "status": "success",
  "data": {
    "uuid": "xxx",
    "name": "example.com",
    "verified": false,
    "verification_method": "DNS",
    "verification_token": "abc123...",
    "dns_verification_string": "postal-verification abc123...",
    "dkim_record_name": "postal-ABCDEF._domainkey",
    "dkim_record": "v=DKIM1; t=s; h=sha256; p=...",
    "spf_record": "v=spf1 a mx include:spf.postal.example.com ~all",
    "return_path_domain": "rp.example.com"
  }
}
```

#### Верифицировать домен

```
POST /api/v2/management/servers/:server_uuid/domains/:uuid/verify
```

#### Проверить DNS записи

```
POST /api/v2/management/servers/:server_uuid/domains/:uuid/check_dns
```

#### Удалить домен

```
DELETE /api/v2/management/servers/:server_uuid/domains/:uuid
```

---

### Учетные данные (Credentials)

#### Список credentials

```
GET /api/v2/management/servers/:server_uuid/credentials
```

#### Создать credential

```
POST /api/v2/management/servers/:server_uuid/credentials
```

```bash
# API ключ
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/credentials \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "API Key for Service X",
    "type": "API"
  }'

# SMTP credential
curl -X POST ... -d '{
    "name": "SMTP Credential",
    "type": "SMTP"
  }'

# IP-based SMTP
curl -X POST ... -d '{
    "name": "Office IP",
    "type": "SMTP-IP",
    "ip_address": "203.0.113.50"
  }'
```

#### Удалить credential

```
DELETE /api/v2/management/servers/:server_uuid/credentials/:uuid
```

---

### Маршруты (Routes)

#### Список маршрутов

```
GET /api/v2/management/servers/:server_uuid/routes
```

#### Создать маршрут

```
POST /api/v2/management/servers/:server_uuid/routes
```

```bash
# HTTP endpoint
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/routes \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Incoming to Webhook",
    "domain_name": "example.com",
    "spam_mode": "Mark",
    "endpoint": {
      "type": "http",
      "name": "My Webhook",
      "url": "https://myapp.com/webhook/email",
      "encoding": "BodyAsJSON",
      "include_attachments": true
    }
  }'

# SMTP endpoint
curl -X POST ... -d '{
    "name": "Forward to Gmail",
    "domain_name": "example.com",
    "endpoint": {
      "type": "smtp",
      "hostname": "smtp.gmail.com",
      "port": 587,
      "ssl_mode": "STARTTLS"
    }
  }'

# Address endpoint
curl -X POST ... -d '{
    "name": "Forward to Admin",
    "domain_name": "example.com",
    "endpoint": {
      "type": "address",
      "address": "admin@gmail.com"
    }
  }'
```

---

### Вебхуки (Webhooks)

#### Список вебхуков

```
GET /api/v2/management/servers/:server_uuid/webhooks
```

#### Создать вебхук

```
POST /api/v2/management/servers/:server_uuid/webhooks
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/webhooks \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Delivery Status Webhook",
    "url": "https://myapp.com/postal/webhook",
    "enabled": true,
    "all_events": true,
    "sign": true
  }'
```

#### Тестировать вебхук

```
POST /api/v2/management/servers/:server_uuid/webhooks/:uuid/test
```

---

### Сообщения

#### Список сообщений

```
GET /api/v2/management/servers/:server_uuid/messages
```

Параметры:
- `direction` - incoming/outgoing
- `to` - адрес получателя
- `from` - адрес отправителя
- `status` - статус сообщения
- `scope` - all/held

#### Получить сообщение

```
GET /api/v2/management/servers/:server_uuid/messages/:id
```

#### Deliveries сообщения

```
GET /api/v2/management/servers/:server_uuid/messages/:id/deliveries
```

#### Повторить отправку

```
POST /api/v2/management/servers/:server_uuid/messages/:id/retry
```

#### Снять hold

```
POST /api/v2/management/servers/:server_uuid/messages/:id/cancel_hold
```

#### Очередь сообщений

```
GET /api/v2/management/servers/:server_uuid/queue
```

---

### Пользователи (super admin)

#### Список пользователей

```
GET /api/v2/management/users
```

#### Создать пользователя

```
POST /api/v2/management/users
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/users \
  -H "X-Management-API-Key: mgmt_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "John",
    "last_name": "Doe",
    "email_address": "john@example.com",
    "password": "SecurePassword123!",
    "admin": false
  }'
```

---

## Примеры использования

### Полный workflow: создание организации, сервера и домена

```bash
#!/bin/bash

API_KEY="mgmt_your_key_here"
BASE_URL="https://postal.yourdomain.com/api/v2/management"

# 1. Создать организацию
ORG_RESPONSE=$(curl -s -X POST "$BASE_URL/organizations" \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ACME Corp",
    "permalink": "acme",
    "owner_email": "admin@acme.com"
  }')

echo "Organization created: $ORG_RESPONSE"

# 2. Создать сервер
SERVER_RESPONSE=$(curl -s -X POST "$BASE_URL/organizations/acme/servers" \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production",
    "mode": "Live",
    "send_limit": 50000
  }')

SERVER_UUID=$(echo $SERVER_RESPONSE | jq -r '.data.uuid')
SMTP_KEY=$(echo $SERVER_RESPONSE | jq -r '.data.credentials[0].key')

echo "Server created: $SERVER_UUID"
echo "SMTP Key: $SMTP_KEY"

# 3. Добавить домен
DOMAIN_RESPONSE=$(curl -s -X POST "$BASE_URL/servers/$SERVER_UUID/domains" \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mail.acme.com",
    "verification_method": "DNS"
  }')

echo "Domain created: $DOMAIN_RESPONSE"

# 4. Получить DNS записи для настройки
DOMAIN_UUID=$(echo $DOMAIN_RESPONSE | jq -r '.data.uuid')
DNS_INFO=$(curl -s "$BASE_URL/servers/$SERVER_UUID/domains/$DOMAIN_UUID" \
  -H "X-Management-API-Key: $API_KEY")

echo "Configure these DNS records:"
echo $DNS_INFO | jq '.data | {dkim_record_name, dkim_record, spf_record, dns_verification_string}'

# 5. После настройки DNS - верифицировать
curl -X POST "$BASE_URL/servers/$SERVER_UUID/domains/$DOMAIN_UUID/verify" \
  -H "X-Management-API-Key: $API_KEY"
```

### Python пример

```python
import requests

class PostalManagementAPI:
    def __init__(self, base_url, api_key):
        self.base_url = base_url.rstrip('/')
        self.headers = {
            'X-Management-API-Key': api_key,
            'Content-Type': 'application/json'
        }

    def _request(self, method, endpoint, data=None):
        url = f"{self.base_url}{endpoint}"
        response = requests.request(method, url, headers=self.headers, json=data)
        return response.json()

    def list_organizations(self, **params):
        return self._request('GET', f'/organizations?{urlencode(params)}')

    def create_organization(self, name, owner_email, permalink=None, time_zone='UTC'):
        return self._request('POST', '/organizations', {
            'name': name,
            'permalink': permalink,
            'owner_email': owner_email,
            'time_zone': time_zone
        })

    def create_server(self, org_permalink, name, mode='Live', send_limit=None):
        return self._request('POST', f'/organizations/{org_permalink}/servers', {
            'name': name,
            'mode': mode,
            'send_limit': send_limit
        })

    def add_domain(self, server_uuid, domain_name):
        return self._request('POST', f'/servers/{server_uuid}/domains', {
            'name': domain_name,
            'verification_method': 'DNS'
        })

    def verify_domain(self, server_uuid, domain_uuid):
        return self._request('POST', f'/servers/{server_uuid}/domains/{domain_uuid}/verify')

    def get_server_stats(self, server_uuid):
        return self._request('GET', f'/servers/{server_uuid}/stats')


# Использование
api = PostalManagementAPI(
    'https://postal.example.com/api/v2/management',
    'mgmt_your_key_here'
)

# Создать организацию
org = api.create_organization('ACME Corp', 'admin@acme.com')
print(f"Organization: {org}")

# Создать сервер
server = api.create_server('acme', 'Production', send_limit=50000)
print(f"Server UUID: {server['data']['uuid']}")
print(f"SMTP Key: {server['data']['credentials'][0]['key']}")

# Добавить домен
domain = api.add_domain(server['data']['uuid'], 'mail.acme.com')
print(f"Domain DNS records: {domain['data']}")
```

---

## Коды ошибок

| Код | HTTP Status | Описание |
|-----|-------------|----------|
| `AuthenticationRequired` | 401 | API ключ не предоставлен |
| `InvalidApiKey` | 401 | Неверный или истекший API ключ |
| `Forbidden` | 403 | Недостаточно прав для операции |
| `NotFound` | 404 | Ресурс не найден |
| `ValidationError` | 422 | Ошибка валидации данных |
| `ParameterMissing` | 400 | Отсутствует обязательный параметр |
| `OwnerNotFound` | 404 | Владелец организации не найден |
| `OwnerRequired` | 400 | Не указан владелец при создании организации |
| `VerificationFailed` | 400 | Не удалось верифицировать домен |
| `NotQueued` | 400 | Сообщение не в очереди |
| `NotHeld` | 400 | Сообщение не заблокировано |
| `CannotDeleteSelf` | 400 | Нельзя удалить текущий API ключ |

---

## Безопасность

1. **Храните API ключи безопасно** - используйте переменные окружения или secret managers
2. **Используйте HTTPS** - никогда не отправляйте API ключи по HTTP
3. **Ограничивайте права** - создавайте organization-scoped ключи когда не нужен полный доступ
4. **Используйте срок действия** - устанавливайте `expires_at` для временных ключей
5. **Мониторьте использование** - проверяйте `request_count` и `last_used_at`

---

## Версионирование

API использует версионирование в URL: `/api/v2/management/...`

Текущая версия: **v2**

Legacy API v1 (`/api/v1/...`) остается доступным для обратной совместимости.
