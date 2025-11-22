# Postal Management API Documentation

The Management API provides full administrative control over Postal without using the web interface. All operations available in the web UI can be performed programmatically through this API.

## Base URL

```
https://your-postal-server.com/management/api/v1
```

## Authentication

All requests require the `X-Management-API-Key` header:

```bash
curl -X GET https://postal.example.com/management/api/v1/organizations \
  -H "X-Management-API-Key: your-secret-key" \
  -H "Content-Type: application/json"
```

### Configuration

Set your API key via environment variable or in `postal.yml`:

```yaml
# postal.yml
management_api:
  enabled: true
  key: "your-secret-api-key"
```

Or via environment variable:
```bash
export POSTAL_MANAGEMENT_API_KEY="your-secret-api-key"
```

## Response Format

All responses follow this structure:

```json
{
  "status": "success|error",
  "time": 0.123,
  "data": { ... }
}
```

### Error Response

```json
{
  "status": "error",
  "time": 0.123,
  "data": {
    "code": "ErrorCode",
    "message": "Human readable error message",
    "errors": { "field": ["error message"] }
  }
}
```

---

## Users API

Manage global users.

### List Users

```http
GET /management/api/v1/users
```

**Query Parameters:**
- `admin` (optional): Filter by admin status (`true`/`false`)

**Response:**
```json
{
  "status": "success",
  "data": {
    "users": [
      {
        "uuid": "abc123",
        "email_address": "user@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "name": "John Doe",
        "admin": false,
        "time_zone": "UTC",
        "oidc": false,
        "email_verified": true,
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z"
      }
    ]
  }
}
```

### Get User

```http
GET /management/api/v1/users/:uuid
```

### Create User

```http
POST /management/api/v1/users
```

**Body:**
```json
{
  "email_address": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "password": "securepassword123",
  "admin": false,
  "time_zone": "UTC"
}
```

### Update User

```http
PATCH /management/api/v1/users/:uuid
```

**Body:**
```json
{
  "first_name": "Jane",
  "admin": true,
  "password": "newpassword123"
}
```

### Delete User

```http
DELETE /management/api/v1/users/:uuid
```

### Reset Password

```http
POST /management/api/v1/users/:uuid/reset_password
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "message": "Password reset token generated",
    "reset_token": "abc123xyz",
    "valid_until": "2024-01-01T01:00:00Z"
  }
}
```

---

## Organizations API

Manage organizations and their settings.

### List Organizations

```http
GET /management/api/v1/organizations
```

### Get Organization

```http
GET /management/api/v1/organizations/:permalink
```

### Create Organization

```http
POST /management/api/v1/organizations
```

**Body:**
```json
{
  "name": "My Company",
  "permalink": "my-company",
  "owner_email": "owner@example.com",
  "time_zone": "America/New_York"
}
```

### Update Organization

```http
PATCH /management/api/v1/organizations/:permalink
```

### Delete Organization

```http
DELETE /management/api/v1/organizations/:permalink
```

### Suspend Organization

```http
POST /management/api/v1/organizations/:permalink/suspend
```

**Body:**
```json
{
  "reason": "Violation of terms of service"
}
```

### Unsuspend Organization

```http
POST /management/api/v1/organizations/:permalink/unsuspend
```

---

## Organization Users API

Manage users within an organization.

### List Organization Users

```http
GET /management/api/v1/organizations/:permalink/users
```

### Add User to Organization

```http
POST /management/api/v1/organizations/:permalink/users
```

**Body:**
```json
{
  "user_uuid": "abc123",
  "admin": true,
  "all_servers": true
}
```

### Update User Role

```http
PATCH /management/api/v1/organizations/:permalink/users/:uuid
```

**Body:**
```json
{
  "admin": false,
  "all_servers": false
}
```

### Remove User from Organization

```http
DELETE /management/api/v1/organizations/:permalink/users/:uuid
```

### Transfer Ownership

```http
POST /management/api/v1/organizations/:permalink/users/:uuid/make_owner
```

---

## Servers API

Manage mail servers within organizations.

### List Servers

```http
GET /management/api/v1/servers
```

**Query Parameters:**
- `organization` (optional): Filter by organization permalink

### Get Server

```http
GET /management/api/v1/servers/:id
```

You can use either the numeric ID or the full permalink (e.g., `my-org/my-server`).

### Create Server

```http
POST /management/api/v1/servers
```

**Body:**
```json
{
  "organization": "my-org",
  "name": "Transactional",
  "mode": "Live",
  "ip_pool_id": 1,
  "message_retention_days": 30,
  "raw_message_retention_days": 7,
  "raw_message_retention_size": 2048
}
```

**Response includes auto-generated API credentials:**
```json
{
  "status": "success",
  "data": {
    "server": { ... },
    "credentials": {
      "api_key": "abc123xyz",
      "api_credential_uuid": "cred-uuid"
    }
  }
}
```

### Update Server

```http
PATCH /management/api/v1/servers/:id
```

### Delete Server

```http
DELETE /management/api/v1/servers/:id
```

### Suspend Server

```http
POST /management/api/v1/servers/:id/suspend
```

### Unsuspend Server

```http
POST /management/api/v1/servers/:id/unsuspend
```

---

## Domains API

Manage sending and receiving domains for servers.

### List Domains

```http
GET /management/api/v1/servers/:server_id/domains
```

### Create Domain

```http
POST /management/api/v1/servers/:server_id/domains
```

**Body:**
```json
{
  "name": "example.com",
  "verification_method": "DNS",
  "auto_verify": true
}
```

### Verify Domain

```http
POST /management/api/v1/servers/:server_id/domains/:uuid/verify
```

### Check DNS

```http
POST /management/api/v1/servers/:server_id/domains/:uuid/check_dns
```

### Get DNS Records

```http
GET /management/api/v1/servers/:server_id/domains/:uuid/dns_records
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "dns_records": {
      "spf": {
        "hostname": "example.com",
        "type": "TXT",
        "value": "v=spf1 a mx include:spf.postal.example.com ~all"
      },
      "dkim": {
        "hostname": "postal-abc123._domainkey.example.com",
        "type": "TXT",
        "value": "v=DKIM1; t=s; h=sha256; p=..."
      },
      "return_path": {
        "hostname": "psrp.example.com",
        "type": "CNAME",
        "value": "rp.postal.example.com"
      },
      "mx": {
        "hostname": "example.com",
        "type": "MX",
        "priority": 10,
        "value": "mx.postal.example.com"
      }
    }
  }
}
```

### Delete Domain

```http
DELETE /management/api/v1/servers/:server_id/domains/:uuid
```

---

## Credentials API

Manage API keys and SMTP credentials for servers.

### List Credentials

```http
GET /management/api/v1/servers/:server_id/credentials
```

### Create Credential

```http
POST /management/api/v1/servers/:server_id/credentials
```

**Body:**
```json
{
  "name": "Production API Key",
  "type": "API",
  "hold": false
}
```

Types: `API`, `SMTP`, `SMTP-IP`

### Update Credential

```http
PATCH /management/api/v1/servers/:server_id/credentials/:uuid
```

### Delete Credential

```http
DELETE /management/api/v1/servers/:server_id/credentials/:uuid
```

---

## Webhooks API

Manage webhooks for event notifications.

### List Webhooks

```http
GET /management/api/v1/servers/:server_id/webhooks
```

### Create Webhook

```http
POST /management/api/v1/servers/:server_id/webhooks
```

**Body:**
```json
{
  "name": "My Webhook",
  "url": "https://example.com/webhook",
  "enabled": true,
  "sign": true,
  "all_events": false,
  "events": ["MessageSent", "MessageBounced", "MessageDeliveryFailed"]
}
```

**Available Events:**
- `MessageSent`
- `MessageDelayed`
- `MessageDeliveryFailed`
- `MessageHeld`
- `MessageBounced`
- `MessageLinkClicked`
- `MessageLoaded`
- `DomainDNSError`

### Update Webhook

```http
PATCH /management/api/v1/servers/:server_id/webhooks/:uuid
```

### Delete Webhook

```http
DELETE /management/api/v1/servers/:server_id/webhooks/:uuid
```

---

## Routes API

Configure mail routing for incoming messages.

### List Routes

```http
GET /management/api/v1/servers/:server_id/routes
```

### Create Route

```http
POST /management/api/v1/servers/:server_id/routes
```

**Body:**
```json
{
  "name": "*",
  "domain_uuid": "domain-uuid",
  "endpoint_type": "HTTPEndpoint",
  "endpoint_uuid": "endpoint-uuid",
  "spam_mode": "Mark",
  "additional_endpoints": [
    { "endpoint_type": "AddressEndpoint", "endpoint_uuid": "addr-uuid" }
  ]
}
```

**Modes:** `Endpoint`, `Accept`, `Hold`, `Bounce`, `Reject`
**Spam Modes:** `Mark`, `Quarantine`, `Fail`

### Update Route

```http
PATCH /management/api/v1/servers/:server_id/routes/:uuid
```

### Delete Route

```http
DELETE /management/api/v1/servers/:server_id/routes/:uuid
```

---

## HTTP Endpoints API

Manage HTTP endpoints for mail routing.

### List HTTP Endpoints

```http
GET /management/api/v1/servers/:server_id/http_endpoints
```

### Create HTTP Endpoint

```http
POST /management/api/v1/servers/:server_id/http_endpoints
```

**Body:**
```json
{
  "name": "Webhook Handler",
  "url": "https://example.com/incoming",
  "encoding": "BodyAsJSON",
  "format": "Hash",
  "strip_replies": false,
  "include_attachments": true,
  "timeout": 30
}
```

**Encodings:** `BodyAsJSON`, `FormData`
**Formats:** `Hash`, `RawMessage`

### Update HTTP Endpoint

```http
PATCH /management/api/v1/servers/:server_id/http_endpoints/:uuid
```

### Delete HTTP Endpoint

```http
DELETE /management/api/v1/servers/:server_id/http_endpoints/:uuid
```

---

## SMTP Endpoints API

Manage SMTP forwarding endpoints.

### List SMTP Endpoints

```http
GET /management/api/v1/servers/:server_id/smtp_endpoints
```

### Create SMTP Endpoint

```http
POST /management/api/v1/servers/:server_id/smtp_endpoints
```

**Body:**
```json
{
  "name": "External SMTP",
  "hostname": "smtp.example.com",
  "port": 25,
  "ssl_mode": "Auto"
}
```

**SSL Modes:** `None`, `Auto`, `STARTTLS`, `TLS`

### Update SMTP Endpoint

```http
PATCH /management/api/v1/servers/:server_id/smtp_endpoints/:uuid
```

### Delete SMTP Endpoint

```http
DELETE /management/api/v1/servers/:server_id/smtp_endpoints/:uuid
```

---

## Address Endpoints API

Manage email forwarding endpoints.

### List Address Endpoints

```http
GET /management/api/v1/servers/:server_id/address_endpoints
```

### Create Address Endpoint

```http
POST /management/api/v1/servers/:server_id/address_endpoints
```

**Body:**
```json
{
  "address": "forward@example.com"
}
```

### Update Address Endpoint

```http
PATCH /management/api/v1/servers/:server_id/address_endpoints/:uuid
```

### Delete Address Endpoint

```http
DELETE /management/api/v1/servers/:server_id/address_endpoints/:uuid
```

---

## Track Domains API

Manage click and open tracking domains.

### List Track Domains

```http
GET /management/api/v1/servers/:server_id/track_domains
```

### Create Track Domain

```http
POST /management/api/v1/servers/:server_id/track_domains
```

**Body:**
```json
{
  "name": "track",
  "domain_uuid": "domain-uuid",
  "ssl_enabled": true,
  "track_clicks": true,
  "track_loads": true,
  "excluded_click_domains": "unsubscribe.example.com\noptout.example.com"
}
```

### Update Track Domain

```http
PATCH /management/api/v1/servers/:server_id/track_domains/:uuid
```

### Check Track Domain DNS

```http
POST /management/api/v1/servers/:server_id/track_domains/:uuid/check_dns
```

### Toggle SSL

```http
POST /management/api/v1/servers/:server_id/track_domains/:uuid/toggle_ssl
```

### Delete Track Domain

```http
DELETE /management/api/v1/servers/:server_id/track_domains/:uuid
```

---

## Messages API

Access and manage messages.

### List Messages

```http
GET /management/api/v1/servers/:server_id/messages
```

**Query Parameters:**
- `scope`: `incoming`, `outgoing`, `held` (default: `outgoing`)
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 50, max: 100)
- `start_date`: Filter by start date (ISO 8601)
- `end_date`: Filter by end date (ISO 8601)
- `status`: Filter by status
- `to`: Filter by recipient
- `from`: Filter by sender
- `tag`: Filter by tag

### Get Message

```http
GET /management/api/v1/servers/:server_id/messages/:id
```

**Query Parameters:**
- `expansions`: Comma-separated list of additional data:
  - `status` - Status details
  - `details` - Technical details
  - `inspection` - Inspection data
  - `plain_body` - Plain text body
  - `html_body` - HTML body
  - `attachments` - Attachment list
  - `headers` - Message headers
  - `deliveries` - Delivery attempts
  - `all` - All expansions

### Retry Message

```http
POST /management/api/v1/servers/:server_id/messages/:id/retry
```

### Cancel Hold

```http
POST /management/api/v1/servers/:server_id/messages/:id/cancel_hold
```

### Delete from Queue

```http
DELETE /management/api/v1/servers/:server_id/messages/:id
```

### Get Deliveries

```http
GET /management/api/v1/servers/:server_id/messages/:id/deliveries
```

### Get Activity (Opens/Clicks)

```http
GET /management/api/v1/servers/:server_id/messages/:id/activity
```

### Get Plain Body

```http
GET /management/api/v1/servers/:server_id/messages/:id/plain
```

### Get HTML Body

```http
GET /management/api/v1/servers/:server_id/messages/:id/html
```

### Get Headers

```http
GET /management/api/v1/servers/:server_id/messages/:id/headers
```

### Get Raw Message

```http
GET /management/api/v1/servers/:server_id/messages/:id/raw
```

Returns base64-encoded raw message data.

### Get Spam Checks

```http
GET /management/api/v1/servers/:server_id/messages/:id/spam_checks
```

---

## Statistics API

Get server statistics and metrics.

### Get Statistics

```http
GET /management/api/v1/servers/:server_id/statistics
```

**Query Parameters:**
- `period`: `hour`, `day`, `week`, `month` (default: `day`)

### Get Summary

```http
GET /management/api/v1/servers/:server_id/statistics/summary
```

### Get Statistics by Status

```http
GET /management/api/v1/servers/:server_id/statistics/by_status
```

**Query Parameters:**
- `scope`: `incoming`, `outgoing` (default: `outgoing`)

### Get Statistics by Domain

```http
GET /management/api/v1/servers/:server_id/statistics/by_domain
```

### Get Clicks and Opens Statistics

```http
GET /management/api/v1/servers/:server_id/statistics/clicks_and_opens
```

**Query Parameters:**
- `days`: Number of days (default: 7)

---

## Suppressions API

Manage email suppression lists.

### List Suppressions

```http
GET /management/api/v1/servers/:server_id/suppressions
```

**Query Parameters:**
- `type`: `bounce`, `complaint`, `manual`
- `page`: Page number
- `per_page`: Items per page

### Check Suppression

```http
GET /management/api/v1/servers/:server_id/suppressions/check?address=user@example.com
```

### Add Suppression

```http
POST /management/api/v1/servers/:server_id/suppressions
```

**Body:**
```json
{
  "address": "user@example.com",
  "reason": "User requested removal"
}
```

### Remove Suppression

```http
DELETE /management/api/v1/servers/:server_id/suppressions/:address
```

### Bulk Add Suppressions

```http
POST /management/api/v1/servers/:server_id/suppressions/bulk
```

**Body:**
```json
{
  "addresses": ["user1@example.com", "user2@example.com"],
  "reason": "Bulk import"
}
```

### Bulk Remove Suppressions

```http
DELETE /management/api/v1/servers/:server_id/suppressions/bulk
```

**Body:**
```json
{
  "addresses": ["user1@example.com", "user2@example.com"]
}
```

---

## Queue API

Manage the message delivery queue.

### List Queued Messages

```http
GET /management/api/v1/servers/:server_id/queue
```

### Get Queue Summary

```http
GET /management/api/v1/servers/:server_id/queue/summary
```

### Get Queued Message

```http
GET /management/api/v1/servers/:server_id/queue/:id
```

### Remove from Queue

```http
DELETE /management/api/v1/servers/:server_id/queue/:id
```

### Retry Queued Message

```http
POST /management/api/v1/servers/:server_id/queue/:id/retry
```

### Clear Queue

```http
DELETE /management/api/v1/servers/:server_id/queue/clear
```

### Retry All Queued

```http
POST /management/api/v1/servers/:server_id/queue/retry_all
```

---

## IP Pools API

Manage IP pools for outgoing mail.

### List IP Pools

```http
GET /management/api/v1/ip_pools
```

### Get IP Pool

```http
GET /management/api/v1/ip_pools/:id
```

### Create IP Pool

```http
POST /management/api/v1/ip_pools
```

**Body:**
```json
{
  "name": "Transactional Pool",
  "default": false
}
```

### Update IP Pool

```http
PATCH /management/api/v1/ip_pools/:id
```

### Delete IP Pool

```http
DELETE /management/api/v1/ip_pools/:id
```

### Get Organization IP Pools

```http
GET /management/api/v1/organizations/:permalink/ip_pools
```

### Assign IP Pools to Organization

```http
POST /management/api/v1/organizations/:permalink/ip_pools/assign
```

**Body:**
```json
{
  "ip_pool_ids": [1, 2, 3]
}
```

---

## IP Addresses API

Manage IP addresses within pools.

### List IP Addresses

```http
GET /management/api/v1/ip_pools/:ip_pool_id/ip_addresses
```

### Create IP Address

```http
POST /management/api/v1/ip_pools/:ip_pool_id/ip_addresses
```

**Body:**
```json
{
  "ipv4": "192.168.1.1",
  "ipv6": "2001:db8::1",
  "hostname": "mail1.example.com",
  "priority": 100
}
```

### Update IP Address

```http
PATCH /management/api/v1/ip_pools/:ip_pool_id/ip_addresses/:id
```

### Delete IP Address

```http
DELETE /management/api/v1/ip_pools/:ip_pool_id/ip_addresses/:id
```

---

## IP Pool Rules API

Configure conditional IP pool assignment.

### List IP Pool Rules (Server)

```http
GET /management/api/v1/servers/:server_id/ip_pool_rules
```

### List IP Pool Rules (Organization)

```http
GET /management/api/v1/organizations/:permalink/ip_pool_rules
```

### Create IP Pool Rule

```http
POST /management/api/v1/servers/:server_id/ip_pool_rules
```

**Body:**
```json
{
  "ip_pool_id": 1,
  "from_addresses": ["marketing@example.com", "example.com"],
  "to_addresses": ["@gmail.com", "@yahoo.com"]
}
```

### Update IP Pool Rule

```http
PATCH /management/api/v1/servers/:server_id/ip_pool_rules/:uuid
```

### Delete IP Pool Rule

```http
DELETE /management/api/v1/servers/:server_id/ip_pool_rules/:uuid
```

---

## Error Codes

| Code | Description |
|------|-------------|
| `AccessDenied` | Missing or invalid API key header |
| `Disabled` | Management API is disabled |
| `NotConfigured` | API key not configured |
| `InvalidAPIKey` | Invalid API key |
| `NotFound` | Resource not found |
| `ValidationError` | Validation failed |
| `AlreadyMember` | User already in organization |
| `CannotDemoteOwner` | Cannot demote organization owner |
| `CannotRemoveOwner` | Cannot remove organization owner |
| `LastAdmin` | Cannot delete last admin user |
| `OIDCUser` | Cannot reset password for OIDC users |
| `InUse` | Resource is in use |
| `CannotDeleteDefault` | Cannot delete default resource |
| `InvalidStatus` | Invalid status for operation |
| `NotQueued` | Message not in queue |
| `AlreadySuppressed` | Address already suppressed |
| `MissingParameter` | Required parameter missing |
| `InvalidParameter` | Invalid parameter value |

---

## Rate Limiting

The Management API does not implement rate limiting at the application level. Consider implementing rate limiting at your reverse proxy or load balancer.

---

## Examples

### Complete Server Setup

```bash
# 1. Create organization
curl -X POST https://postal.example.com/management/api/v1/organizations \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{"name": "My Company", "permalink": "my-company", "owner_email": "admin@example.com"}'

# 2. Create server
curl -X POST https://postal.example.com/management/api/v1/servers \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{"organization": "my-company", "name": "Transactional"}'

# 3. Add domain
curl -X POST https://postal.example.com/management/api/v1/servers/1/domains \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{"name": "example.com", "auto_verify": true}'

# 4. Create webhook
curl -X POST https://postal.example.com/management/api/v1/servers/1/webhooks \
  -H "X-Management-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{"name": "Events", "url": "https://example.com/webhook", "all_events": true}'
```

### Message Monitoring Script

```python
import requests

headers = {
    "X-Management-API-Key": "your-key",
    "Content-Type": "application/json"
}

# Get failed messages
response = requests.get(
    "https://postal.example.com/management/api/v1/servers/1/messages",
    headers=headers,
    params={"status": "HardFail", "per_page": 100}
)

messages = response.json()["data"]["messages"]
for msg in messages:
    print(f"Failed: {msg['rcpt_to']} - {msg['subject']}")

    # Retry the message
    requests.post(
        f"https://postal.example.com/management/api/v1/servers/1/messages/{msg['id']}/retry",
        headers=headers
    )
```
