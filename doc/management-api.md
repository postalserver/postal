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

**Вариант A: Через конфигурационный файл (рекомендуется для начала)**

Добавьте в `postal.yml`:

```yaml
management_api:
  api_key: "your-secure-api-key-here"
```

**Вариант B: Через консоль Rails**

```bash
postal console
```

В консоли Rails:

```ruby
key = ManagementAPIKey.create!(
  name: "My Management Key",
  super_admin: true,
  description: "Main automation key"
)
puts "API Key: #{key.key}"
```

**Вариант C: Через rake task**

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
curl -H "X-Management-API-Key: your-api-key" \
     https://postal.yourdomain.com/api/v2/management/system/status
```

---

## Аутентификация

Все запросы к API (кроме `/system/health`) требуют аутентификации.

### Способы аутентификации

**1. Через заголовок X-Management-API-Key:**

```
X-Management-API-Key: mgmt_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**2. Через Bearer токен:**

```
Authorization: Bearer mgmt_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Источники ключей

**1. Конфигурационный файл (postal.yml)**

```yaml
management_api:
  api_key: "your-static-api-key"
```

Особенности:
- Всегда имеет права super admin
- Не требует миграции БД
- Идеален для CI/CD и автоматизации
- Проверяется первым

**2. База данных (ManagementAPIKey)**

```ruby
# Super admin ключ
ManagementAPIKey.create!(name: "Admin Key", super_admin: true)

# Ключ для конкретной организации
ManagementAPIKey.create!(
  name: "Org Key",
  organization: Organization.find_by(permalink: "my-org"),
  super_admin: false
)
```

### Типы ключей

| Тип | Описание |
|-----|----------|
| **Super Admin** | Полный доступ ко всем организациям и операциям |
| **Organization-scoped** | Доступ только к определенной организации |
| **Config-based** | Статический ключ из postal.yml (всегда super admin) |

---

## Создание API ключа

### Через консоль Rails

```bash
postal console
```

```ruby
# Супер-админ ключ
key = ManagementAPIKey.create!(
  name: "Automation Key",
  super_admin: true
)
puts key.key

# Ключ для конкретной организации
org = Organization.find_by(permalink: "my-org")
key = ManagementAPIKey.create!(
  name: "Org API Key",
  organization: org,
  super_admin: false
)
puts key.key

# Ключ с истечением срока действия
key = ManagementAPIKey.create!(
  name: "Temporary Key",
  super_admin: true,
  expires_at: 30.days.from_now
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

# Показать детали ключа
postal rake management_api:show_key[uuid]

# Отключить ключ
postal rake management_api:disable_key[uuid]

# Включить ключ
postal rake management_api:enable_key[uuid]

# Удалить ключ
postal rake management_api:delete_key[uuid]

# Очистить истекшие ключи
postal rake management_api:cleanup_expired
```

### Через API (только для super admin)

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/system/api_keys \
  -H "X-Management-API-Key: your-super-admin-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "New API Key",
    "super_admin": false,
    "organization_permalink": "my-org",
    "description": "Key for automation",
    "expires_at": "2025-12-31T23:59:59Z"
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

| Параметр | Описание | По умолчанию | Максимум |
|----------|----------|--------------|----------|
| `page` | Номер страницы | 1 | - |
| `per_page` | Элементов на странице | 25 | 100 |

```bash
curl "https://postal.yourdomain.com/api/v2/management/organizations?page=2&per_page=50" \
  -H "X-Management-API-Key: your-key"
```

Ответ содержит метаданные пагинации:

```json
{
  "status": "success",
  "data": [...],
  "meta": {
    "page": 2,
    "per_page": 50,
    "total": 150,
    "total_pages": 3
  }
}
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

Ответ:
```json
{
  "status": "success",
  "data": {
    "version": "3.0.0",
    "hostname": "postal-server",
    "authenticated_as": {
      "uuid": "abc123",
      "name": "My API Key",
      "super_admin": true
    },
    "database_connected": true,
    "time": "2025-01-15T10:30:00Z"
  }
}
```

#### Статистика системы (super admin)

```
GET /api/v2/management/system/stats
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "organizations": {
      "total": 15,
      "suspended": 2
    },
    "servers": {
      "total": 45,
      "suspended": 3,
      "by_mode": {
        "Live": 40,
        "Development": 5
      }
    },
    "users": {
      "total": 120,
      "admins": 5
    },
    "messages": {
      "queued": 1500,
      "held": 23
    },
    "management_api_keys": {
      "total": 10,
      "enabled": 8,
      "super_admin": 3
    }
  }
}
```

#### Управление API ключами (super admin)

**Список ключей:**
```
GET /api/v2/management/system/api_keys
```

**Создать ключ:**
```
POST /api/v2/management/system/api_keys
```

```json
{
  "name": "New API Key",
  "super_admin": false,
  "organization_permalink": "my-org",
  "description": "Optional description",
  "expires_at": "2025-12-31T23:59:59Z"
}
```

**Удалить ключ:**
```
DELETE /api/v2/management/system/api_keys/:uuid
```

---

### Организации

#### Список организаций

```
GET /api/v2/management/organizations
```

Параметры фильтрации:
| Параметр | Описание |
|----------|----------|
| `name` | Поиск по имени (частичное совпадение) |
| `permalink` | Точное совпадение permalink |

```bash
curl "https://postal.yourdomain.com/api/v2/management/organizations?name=test" \
  -H "X-Management-API-Key: your-key"
```

#### Получить организацию

```
GET /api/v2/management/organizations/:permalink
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "uuid": "abc123",
    "name": "My Company",
    "permalink": "my-company",
    "time_zone": "Europe/Moscow",
    "status": "Active",
    "suspended": false,
    "suspension_reason": null,
    "owner": {
      "uuid": "user123",
      "email": "admin@example.com",
      "name": "John Doe"
    },
    "stats": {
      "servers": 5,
      "users": 10,
      "domains": 3
    },
    "ip_pools": [
      {"uuid": "pool1", "name": "Default"}
    ],
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  }
}
```

#### Создать организацию

```
POST /api/v2/management/organizations
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/organizations \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Company",
    "permalink": "my-company",
    "time_zone": "Europe/Moscow",
    "owner_email": "admin@example.com"
  }'
```

| Параметр | Обязательный | Описание |
|----------|--------------|----------|
| `name` | Да | Название организации |
| `owner_email` | Да | Email существующего пользователя |
| `permalink` | Нет | URL-slug (генерируется автоматически) |
| `time_zone` | Нет | Часовой пояс (по умолчанию UTC) |

#### Обновить организацию

```
PATCH /api/v2/management/organizations/:permalink
```

```bash
curl -X PATCH https://postal.yourdomain.com/api/v2/management/organizations/my-company \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Company Updated",
    "time_zone": "America/New_York"
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
  -H "X-Management-API-Key: your-key" \
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
| Параметр | Описание |
|----------|----------|
| `name` | Поиск по имени |
| `mode` | `Live` или `Development` |

#### Получить сервер

```
GET /api/v2/management/servers/:uuid
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "uuid": "server123",
    "name": "Production Mail",
    "permalink": "production-mail",
    "token": "ABCDEF",
    "mode": "Live",
    "status": "Live",
    "suspended": false,
    "suspension_reason": null,
    "organization": {
      "uuid": "org123",
      "permalink": "my-company",
      "name": "My Company"
    },
    "send_limit": 10000,
    "settings": {
      "message_retention_days": 60,
      "raw_message_retention_days": 30,
      "raw_message_retention_size": 2048,
      "allow_sender": false,
      "spam_threshold": 5.0,
      "spam_failure_threshold": 20.0,
      "outbound_spam_threshold": null,
      "postmaster_address": null,
      "log_smtp_data": false
    },
    "stats": {
      "domains": 3,
      "credentials": 5,
      "routes": 2,
      "webhooks": 1
    },
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  }
}
```

#### Создать сервер

```
POST /api/v2/management/organizations/:org_permalink/servers
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/organizations/my-company/servers \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Mail",
    "mode": "Live",
    "send_limit": 10000,
    "create_api_credential": true
  }'
```

| Параметр | Обязательный | Описание |
|----------|--------------|----------|
| `name` | Да | Название сервера |
| `mode` | Нет | `Live` (по умолчанию) или `Development` |
| `send_limit` | Нет | Лимит отправки за период |
| `create_api_credential` | Нет | Создать API ключ автоматически |

Ответ включает автоматически созданный API ключ:
```json
{
  "status": "success",
  "data": {
    "uuid": "server123",
    "name": "Production Mail",
    "token": "ABCDEF",
    "credentials": [
      {
        "uuid": "cred123",
        "name": "Default API Key",
        "type": "API",
        "key": "abc123def456..."
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

Ответ:
```json
{
  "status": "success",
  "data": {
    "uuid": "server123",
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
| Параметр | Описание |
|----------|----------|
| `name` | Поиск по имени |
| `verified` | `true` или `false` |

#### Получить домен

```
GET /api/v2/management/servers/:server_uuid/domains/:uuid
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "uuid": "domain123",
    "name": "example.com",
    "verified": true,
    "verified_at": "2025-01-10T12:00:00Z",
    "verification_method": "DNS",
    "verification_token": "abc123...",
    "dns_verification_string": "postal-verification abc123...",
    "dkim_record_name": "postal-ABCDEF._domainkey",
    "dkim_record": "v=DKIM1; t=s; h=sha256; p=...",
    "spf_record": "v=spf1 a mx include:spf.postal.example.com ~all",
    "return_path_domain": "psrp.example.com",
    "outgoing": true,
    "incoming": true,
    "use_for_any": false,
    "dns_ok": true,
    "dns_checked_at": "2025-01-15T08:00:00Z",
    "dns_status": {
      "spf": {"status": "OK", "error": null},
      "dkim": {"status": "OK", "error": null},
      "mx": {"status": "OK", "error": null},
      "return_path": {"status": "OK", "error": null}
    },
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  }
}
```

#### Создать домен

```
POST /api/v2/management/servers/:server_uuid/domains
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/domains \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "example.com",
    "verification_method": "DNS",
    "outgoing": true,
    "incoming": true
  }'
```

| Параметр | Обязательный | Описание |
|----------|--------------|----------|
| `name` | Да | Имя домена |
| `verification_method` | Нет | `DNS` (по умолчанию) или `Email` |
| `outgoing` | Нет | Разрешить исходящую почту (по умолчанию true) |
| `incoming` | Нет | Разрешить входящую почту (по умолчанию true) |
| `use_for_any` | Нет | Использовать для любого домена |

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

Параметры:
| Параметр | Описание |
|----------|----------|
| `name` | Поиск по имени |
| `type` | `API`, `SMTP` или `SMTP-IP` |

#### Получить credential

```
GET /api/v2/management/servers/:server_uuid/credentials/:uuid
```

#### Создать credential

```
POST /api/v2/management/servers/:server_uuid/credentials
```

**API ключ:**
```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/credentials \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "API Key for Service X",
    "type": "API"
  }'
```

**SMTP credential:**
```json
{
  "name": "SMTP Credential",
  "type": "SMTP"
}
```

**IP-based SMTP:**
```json
{
  "name": "Office IP",
  "type": "SMTP-IP",
  "ip_address": "203.0.113.50"
}
```

Ответ (ключ показывается только при создании):
```json
{
  "status": "success",
  "data": {
    "uuid": "cred123",
    "name": "API Key for Service X",
    "type": "API",
    "key": "abc123def456ghi789...",
    "hold": false,
    "last_used_at": null,
    "usage_type": "Unused",
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

#### Обновить credential

```
PATCH /api/v2/management/servers/:server_uuid/credentials/:uuid
```

```json
{
  "name": "Updated Name",
  "hold": true
}
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

#### Получить маршрут

```
GET /api/v2/management/servers/:server_uuid/routes/:uuid
```

#### Создать маршрут

```
POST /api/v2/management/servers/:server_uuid/routes
```

**HTTP endpoint:**
```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/routes \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "*",
    "domain_name": "example.com",
    "spam_mode": "Mark",
    "endpoint": {
      "type": "http",
      "name": "My Webhook",
      "url": "https://myapp.com/webhook/email",
      "encoding": "BodyAsJSON",
      "format": "Hash",
      "include_attachments": true,
      "timeout": 10
    }
  }'
```

**SMTP endpoint:**
```json
{
  "name": "*",
  "domain_name": "example.com",
  "spam_mode": "Quarantine",
  "endpoint": {
    "type": "smtp",
    "name": "Forward to Gmail",
    "hostname": "smtp.gmail.com",
    "port": 587,
    "ssl_mode": "STARTTLS"
  }
}
```

**Address endpoint:**
```json
{
  "name": "support",
  "domain_name": "example.com",
  "spam_mode": "Mark",
  "endpoint": {
    "type": "address",
    "address": "support@gmail.com"
  }
}
```

**Использование существующего endpoint:**
```json
{
  "name": "*",
  "domain_name": "example.com",
  "endpoint": {
    "type": "existing",
    "endpoint_type": "http",
    "uuid": "endpoint-uuid-here"
  }
}
```

**Без endpoint (режимы Accept, Hold, Bounce, Reject):**
```json
{
  "name": "*",
  "domain_name": "example.com",
  "mode": "Accept",
  "spam_mode": "Mark"
}
```

| Параметр | Описание |
|----------|----------|
| `name` | Имя маршрута (`*` для wildcard, `__returnpath__` для return path) |
| `domain_name` | Имя верифицированного домена |
| `spam_mode` | `Mark`, `Quarantine` или `Fail` |
| `mode` | `Endpoint`, `Accept`, `Hold`, `Bounce`, `Reject` |
| `endpoint` | Объект с описанием endpoint |

#### Обновить маршрут

```
PATCH /api/v2/management/servers/:server_uuid/routes/:uuid
```

#### Удалить маршрут

```
DELETE /api/v2/management/servers/:server_uuid/routes/:uuid
```

---

### Вебхуки (Webhooks)

#### Список вебхуков

```
GET /api/v2/management/servers/:server_uuid/webhooks
```

Параметры:
| Параметр | Описание |
|----------|----------|
| `name` | Поиск по имени |
| `enabled` | `true` или `false` |

#### Получить вебхук

```
GET /api/v2/management/servers/:server_uuid/webhooks/:uuid
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "uuid": "webhook123",
    "name": "Delivery Status Webhook",
    "url": "https://myapp.com/postal/webhook",
    "enabled": true,
    "all_events": false,
    "sign": true,
    "events": ["MessageSent", "MessageBounced", "MessageDeliveryFailed"],
    "available_events": [
      "MessageSent",
      "MessageDelayed",
      "MessageDeliveryFailed",
      "MessageHeld",
      "MessageBounced",
      "MessageLinkClicked",
      "MessageLoaded",
      "DomainDNSError"
    ],
    "recent_requests": [
      {
        "uuid": "req123",
        "event": "MessageSent",
        "attempts": 1,
        "created_at": "2025-01-15T10:00:00Z"
      }
    ],
    "last_used_at": "2025-01-15T10:00:00Z",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  }
}
```

#### Создать вебхук

```
POST /api/v2/management/servers/:server_uuid/webhooks
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/webhooks \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Delivery Status Webhook",
    "url": "https://myapp.com/postal/webhook",
    "enabled": true,
    "all_events": false,
    "events": ["MessageSent", "MessageBounced"],
    "sign": true
  }'
```

| Параметр | Описание |
|----------|----------|
| `name` | Название вебхука |
| `url` | URL для отправки событий |
| `enabled` | Включен ли вебхук |
| `all_events` | Отправлять все события |
| `events` | Массив событий (если `all_events: false`) |
| `sign` | Подписывать запросы |

#### Обновить вебхук

```
PATCH /api/v2/management/servers/:server_uuid/webhooks/:uuid
```

#### Удалить вебхук

```
DELETE /api/v2/management/servers/:server_uuid/webhooks/:uuid
```

#### Тестировать вебхук

```
POST /api/v2/management/servers/:server_uuid/webhooks/:uuid/test
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/servers/xxx/webhooks/yyy/test \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{"event": "MessageSent"}'
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "success": true,
    "event": "MessageSent",
    "url": "https://myapp.com/postal/webhook",
    "response_code": 200,
    "response_time_ms": 125.5,
    "response_body": "{\"received\": true}"
  }
}
```

---

### Сообщения

#### Список сообщений

```
GET /api/v2/management/servers/:server_uuid/messages
```

Параметры:
| Параметр | Описание |
|----------|----------|
| `direction` | `incoming` или `outgoing` |
| `to` | Адрес получателя |
| `from` | Адрес отправителя |
| `status` | Статус сообщения |
| `scope` | `held` для заблокированных сообщений |
| `tag` | Тег сообщения |

#### Получить сообщение

```
GET /api/v2/management/servers/:server_uuid/messages/:id
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "id": 12345,
    "token": "abc123xyz",
    "direction": "outgoing",
    "status": "Sent",
    "held": false,
    "from": "sender@example.com",
    "to": "recipient@example.com",
    "subject": "Test Email",
    "message_id": "<123@example.com>",
    "tag": "transactional",
    "timestamp": "2025-01-15T10:00:00Z",
    "size": 2048,
    "spam_status": "NotSpam",
    "spam_score": 1.5,
    "domain": {"uuid": "dom123", "name": "example.com"},
    "credential": {"uuid": "cred123", "name": "API Key"},
    "route": null,
    "tracking": {
      "loaded": "2025-01-15T10:05:00Z",
      "clicked": "2025-01-15T10:06:00Z",
      "tracked_links": 3,
      "tracked_images": 1
    },
    "hold_expiry": null,
    "queue": null,
    "last_delivery": {
      "status": "Sent",
      "details": "Message sent successfully",
      "timestamp": "2025-01-15T10:00:05Z"
    }
  }
}
```

#### Deliveries сообщения

```
GET /api/v2/management/servers/:server_uuid/messages/:id/deliveries
```

Ответ:
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "status": "Sent",
      "details": "Message sent to mx.example.com",
      "output": "250 OK",
      "sent_with_ssl": true,
      "log_id": "log123",
      "timestamp": "2025-01-15T10:00:05Z"
    }
  ]
}
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

Параметры:
| Параметр | Описание |
|----------|----------|
| `domain` | Фильтр по домену |
| `locked` | `true` или `false` |

Ответ:
```json
{
  "status": "success",
  "data": [
    {
      "id": 123,
      "message_id": 12345,
      "domain": "example.com",
      "locked": false,
      "locked_by": null,
      "locked_at": null,
      "retry_after": "2025-01-15T10:10:00Z",
      "attempts": 2,
      "manual": false,
      "ip_address": "192.168.1.1",
      "created_at": "2025-01-15T10:00:00Z"
    }
  ],
  "meta": {...}
}
```

---

### Пользователи (super admin)

#### Список пользователей

```
GET /api/v2/management/users
```

Параметры:
| Параметр | Описание |
|----------|----------|
| `email` | Поиск по email |
| `name` | Поиск по имени |
| `admin` | `true` или `false` |

#### Получить пользователя

```
GET /api/v2/management/users/:uuid
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "uuid": "user123",
    "email_address": "john@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "name": "John Doe",
    "admin": false,
    "time_zone": "UTC",
    "has_password": true,
    "oidc_enabled": false,
    "organizations": [
      {
        "uuid": "org123",
        "permalink": "my-company",
        "name": "My Company",
        "admin": true,
        "all_servers": true
      }
    ],
    "owned_organizations": [
      {
        "uuid": "org123",
        "permalink": "my-company",
        "name": "My Company"
      }
    ],
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  }
}
```

#### Создать пользователя

```
POST /api/v2/management/users
```

```bash
curl -X POST https://postal.yourdomain.com/api/v2/management/users \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "John",
    "last_name": "Doe",
    "email_address": "john@example.com",
    "password": "SecurePassword123!",
    "admin": false,
    "time_zone": "Europe/London"
  }'
```

| Параметр | Обязательный | Описание |
|----------|--------------|----------|
| `first_name` | Да | Имя |
| `last_name` | Да | Фамилия |
| `email_address` | Да | Email адрес |
| `password` | Да* | Пароль (*если OIDC отключен) |
| `admin` | Нет | Системный администратор |
| `time_zone` | Нет | Часовой пояс |

#### Обновить пользователя

```
PATCH /api/v2/management/users/:uuid
```

#### Удалить пользователя

```
DELETE /api/v2/management/users/:uuid
```

> **Примечание:** Нельзя удалить пользователя, который является владельцем организации. Сначала передайте владение.

---

## Примеры использования

### Полный workflow: создание организации, сервера и домена

```bash
#!/bin/bash

API_KEY="your-api-key"
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

# 2. Создать сервер с автоматическим API ключом
SERVER_RESPONSE=$(curl -s -X POST "$BASE_URL/organizations/acme/servers" \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production",
    "mode": "Live",
    "send_limit": 50000,
    "create_api_credential": true
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

# 6. Проверить DNS
curl -X POST "$BASE_URL/servers/$SERVER_UUID/domains/$DOMAIN_UUID/check_dns" \
  -H "X-Management-API-Key: $API_KEY"
```

### Python клиент

```python
import requests
from urllib.parse import urlencode

class PostalManagementAPI:
    def __init__(self, base_url, api_key):
        self.base_url = base_url.rstrip('/')
        self.headers = {
            'X-Management-API-Key': api_key,
            'Content-Type': 'application/json'
        }

    def _request(self, method, endpoint, data=None, params=None):
        url = f"{self.base_url}{endpoint}"
        if params:
            url += f"?{urlencode(params)}"
        response = requests.request(method, url, headers=self.headers, json=data)
        return response.json()

    # System
    def health(self):
        return self._request('GET', '/system/health')

    def status(self):
        return self._request('GET', '/system/status')

    def stats(self):
        return self._request('GET', '/system/stats')

    # Organizations
    def list_organizations(self, **params):
        return self._request('GET', '/organizations', params=params)

    def get_organization(self, permalink):
        return self._request('GET', f'/organizations/{permalink}')

    def create_organization(self, name, owner_email, permalink=None, time_zone='UTC'):
        return self._request('POST', '/organizations', {
            'name': name,
            'permalink': permalink,
            'owner_email': owner_email,
            'time_zone': time_zone
        })

    def update_organization(self, permalink, **data):
        return self._request('PATCH', f'/organizations/{permalink}', data)

    def delete_organization(self, permalink):
        return self._request('DELETE', f'/organizations/{permalink}')

    def suspend_organization(self, permalink, reason=None):
        return self._request('POST', f'/organizations/{permalink}/suspend', {'reason': reason})

    def unsuspend_organization(self, permalink):
        return self._request('POST', f'/organizations/{permalink}/unsuspend')

    # Servers
    def list_servers(self, org_permalink=None, **params):
        if org_permalink:
            return self._request('GET', f'/organizations/{org_permalink}/servers', params=params)
        return self._request('GET', '/servers', params=params)

    def get_server(self, uuid):
        return self._request('GET', f'/servers/{uuid}')

    def create_server(self, org_permalink, name, mode='Live', send_limit=None, create_api_credential=False):
        return self._request('POST', f'/organizations/{org_permalink}/servers', {
            'name': name,
            'mode': mode,
            'send_limit': send_limit,
            'create_api_credential': create_api_credential
        })

    def update_server(self, uuid, **data):
        return self._request('PATCH', f'/servers/{uuid}', data)

    def delete_server(self, uuid):
        return self._request('DELETE', f'/servers/{uuid}')

    def server_stats(self, uuid):
        return self._request('GET', f'/servers/{uuid}/stats')

    # Domains
    def list_domains(self, server_uuid, **params):
        return self._request('GET', f'/servers/{server_uuid}/domains', params=params)

    def get_domain(self, server_uuid, domain_uuid):
        return self._request('GET', f'/servers/{server_uuid}/domains/{domain_uuid}')

    def add_domain(self, server_uuid, domain_name, verification_method='DNS'):
        return self._request('POST', f'/servers/{server_uuid}/domains', {
            'name': domain_name,
            'verification_method': verification_method
        })

    def verify_domain(self, server_uuid, domain_uuid):
        return self._request('POST', f'/servers/{server_uuid}/domains/{domain_uuid}/verify')

    def check_domain_dns(self, server_uuid, domain_uuid):
        return self._request('POST', f'/servers/{server_uuid}/domains/{domain_uuid}/check_dns')

    def delete_domain(self, server_uuid, domain_uuid):
        return self._request('DELETE', f'/servers/{server_uuid}/domains/{domain_uuid}')

    # Credentials
    def list_credentials(self, server_uuid, **params):
        return self._request('GET', f'/servers/{server_uuid}/credentials', params=params)

    def create_credential(self, server_uuid, name, cred_type='API', ip_address=None):
        data = {'name': name, 'type': cred_type}
        if ip_address:
            data['ip_address'] = ip_address
        return self._request('POST', f'/servers/{server_uuid}/credentials', data)

    def delete_credential(self, server_uuid, cred_uuid):
        return self._request('DELETE', f'/servers/{server_uuid}/credentials/{cred_uuid}')

    # Webhooks
    def list_webhooks(self, server_uuid, **params):
        return self._request('GET', f'/servers/{server_uuid}/webhooks', params=params)

    def create_webhook(self, server_uuid, name, url, all_events=True, events=None, sign=True):
        return self._request('POST', f'/servers/{server_uuid}/webhooks', {
            'name': name,
            'url': url,
            'all_events': all_events,
            'events': events or [],
            'sign': sign,
            'enabled': True
        })

    def test_webhook(self, server_uuid, webhook_uuid, event='MessageSent'):
        return self._request('POST', f'/servers/{server_uuid}/webhooks/{webhook_uuid}/test', {
            'event': event
        })

    # Messages
    def list_messages(self, server_uuid, **params):
        return self._request('GET', f'/servers/{server_uuid}/messages', params=params)

    def get_message(self, server_uuid, message_id):
        return self._request('GET', f'/servers/{server_uuid}/messages/{message_id}')

    def retry_message(self, server_uuid, message_id):
        return self._request('POST', f'/servers/{server_uuid}/messages/{message_id}/retry')

    def get_queue(self, server_uuid, **params):
        return self._request('GET', f'/servers/{server_uuid}/queue', params=params)


# Использование
api = PostalManagementAPI(
    'https://postal.example.com/api/v2/management',
    'your-api-key'
)

# Проверить статус
print(api.status())

# Создать организацию
org = api.create_organization('ACME Corp', 'admin@acme.com')
print(f"Organization: {org}")

# Создать сервер
server = api.create_server('acme', 'Production', send_limit=50000, create_api_credential=True)
print(f"Server UUID: {server['data']['uuid']}")
print(f"SMTP Key: {server['data']['credentials'][0]['key']}")

# Добавить домен
domain = api.add_domain(server['data']['uuid'], 'mail.acme.com')
print(f"Domain DNS records: {domain['data']}")

# Верифицировать домен после настройки DNS
api.verify_domain(server['data']['uuid'], domain['data']['uuid'])

# Проверить статистику
stats = api.server_stats(server['data']['uuid'])
print(f"Server stats: {stats['data']}")
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
| `AlreadySuspended` | 400 | Ресурс уже приостановлен |
| `NotSuspended` | 400 | Ресурс не приостановлен |
| `AlreadyVerified` | 400 | Домен уже верифицирован |
| `VerificationFailed` | 400 | Не удалось верифицировать домен |
| `NotQueued` | 400 | Сообщение не в очереди |
| `NotHeld` | 400 | Сообщение не заблокировано |
| `CannotDeleteSelf` | 400 | Нельзя удалить текущий API ключ |
| `CannotDelete` | 400 | Невозможно удалить ресурс (например, пользователь - владелец организаций) |
| `EventNotEnabled` | 400 | Событие не включено для вебхука |
| `InvalidEndpointType` | 400 | Неверный тип endpoint |
| `DomainNotFound` | 404 | Домен не найден |
| `EndpointNotFound` | 404 | Endpoint не найден |
| `EndpointValidationError` | 422 | Ошибка валидации endpoint |

---

## Безопасность

### Рекомендации

1. **Храните API ключи безопасно** - используйте переменные окружения или secret managers
2. **Используйте HTTPS** - никогда не отправляйте API ключи по HTTP
3. **Ограничивайте права** - создавайте organization-scoped ключи когда не нужен полный доступ
4. **Используйте срок действия** - устанавливайте `expires_at` для временных ключей
5. **Мониторьте использование** - проверяйте `request_count` и `last_used_at`
6. **Ротируйте ключи** - периодически создавайте новые ключи и удаляйте старые

### Пример безопасного использования

```bash
# Храните ключ в переменной окружения
export POSTAL_API_KEY="mgmt_xxx..."

# Используйте в скриптах
curl -H "X-Management-API-Key: $POSTAL_API_KEY" \
  https://postal.example.com/api/v2/management/system/status
```

```python
import os

api_key = os.environ.get('POSTAL_API_KEY')
if not api_key:
    raise ValueError("POSTAL_API_KEY environment variable not set")

api = PostalManagementAPI('https://postal.example.com/api/v2/management', api_key)
```

---

## Версионирование

API использует версионирование в URL: `/api/v2/management/...`

Текущая версия: **v2**

Legacy API v1 (`/api/v1/...`) остается доступным для обратной совместимости и используется для отправки сообщений через API.

---

## Rate Limiting

В текущей версии rate limiting не реализован. Рекомендуется:

- Не превышать 100 запросов в секунду
- Использовать пагинацию для больших списков
- Кэшировать результаты где возможно

---

## Поддержка

При возникновении проблем:

1. Проверьте health endpoint: `GET /api/v2/management/system/health`
2. Проверьте статус аутентификации: `GET /api/v2/management/system/status`
3. Проверьте логи Postal
4. Создайте issue в репозитории проекта
