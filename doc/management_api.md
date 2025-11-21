# Postal Management API

The Management API provides full administrative control over Postal servers, domains, credentials, and webhooks via HTTP.

## Authentication

All requests require the `X-Management-API-Key` header.

```bash
curl -X GET https://postal.example.com/management/api/v1/servers \
  -H "X-Management-API-Key: your-secret-key"
```

### Configuration

Set the API key in one of two ways:

1. **Environment variable** (recommended):
   ```bash
   export POSTAL_MANAGEMENT_API_KEY="your-secret-key"
   ```

2. **postal.yml configuration**:
   ```yaml
   management_api:
     enabled: true
     key: "your-secret-key"
   ```

## Response Format

All responses are JSON with the following structure:

```json
{
  "status": "success",
  "time": 0.042,
  "data": { ... }
}
```

Error responses:
```json
{
  "status": "error",
  "time": 0.001,
  "data": {
    "code": "ValidationError",
    "message": "Name can't be blank",
    "errors": { "name": ["can't be blank"] }
  }
}
```

---

## Endpoints

### IP Pools

#### List IP Pools
```
GET /management/api/v1/ip_pools
```

Response:
```json
{
  "ip_pools": [
    {
      "id": 1,
      "uuid": "xxx",
      "name": "Default Pool",
      "default": true,
      "ip_addresses": [
        { "id": 1, "ip_address": "45.12.138.7", "hostname": "mail1.example.com" }
      ]
    }
  ]
}
```

#### Get IP Pools for Organization
```
GET /management/api/v1/organizations/:org/ip_pools
```

---

### Organizations

#### List Organizations
```
GET /management/api/v1/organizations
```

#### Get Organization
```
GET /management/api/v1/organizations/:permalink
```

#### Create Organization
```
POST /management/api/v1/organizations
```

Body:
```json
{
  "name": "My Company",
  "owner_email": "admin@example.com",
  "permalink": "my-company",
  "time_zone": "UTC"
}
```

---

### Servers

#### List Servers
```
GET /management/api/v1/servers
GET /management/api/v1/servers?organization=my-org
```

#### Get Server
```
GET /management/api/v1/servers/:id
GET /management/api/v1/servers/org-permalink/server-permalink
```

#### Create Server
```
POST /management/api/v1/servers
```

Body:
```json
{
  "organization": "my-org",
  "name": "Server1",
  "mode": "Live",
  "ip_pool_id": 1,
  "message_retention_days": 2,
  "raw_message_retention_days": 2,
  "raw_message_retention_size": 12048
}
```

Response:
```json
{
  "server": {
    "id": 1,
    "uuid": "xxx",
    "name": "Server1",
    "permalink": "server1",
    "full_permalink": "my-org/server1",
    "mode": "Live",
    "status": "Live",
    "token": "ABCDEF",
    "organization": "my-org",
    "ip_pool": { "id": 1, "name": "45.12.138.7" },
    "message_retention_days": 2,
    "raw_message_retention_days": 2,
    "raw_message_retention_size": 12048
  },
  "credentials": {
    "api_key": "auto-generated-api-key",
    "api_credential_uuid": "xxx"
  }
}
```

#### Update Server
```
PATCH /management/api/v1/servers/:id
```

Body:
```json
{
  "message_retention_days": 2,
  "raw_message_retention_days": 2,
  "raw_message_retention_size": 12048
}
```

#### Delete Server
```
DELETE /management/api/v1/servers/:id
```

#### Suspend/Unsuspend Server
```
POST /management/api/v1/servers/:id/suspend
POST /management/api/v1/servers/:id/unsuspend
```

---

### Domains

#### List Domains
```
GET /management/api/v1/servers/:server_id/domains
```

#### Get Domain
```
GET /management/api/v1/servers/:server_id/domains/:uuid
```

#### Add Domain
```
POST /management/api/v1/servers/:server_id/domains
```

Body:
```json
{
  "name": "example.com",
  "auto_verify": true
}
```

Response includes DNS records:
```json
{
  "domain": {
    "uuid": "xxx",
    "name": "example.com",
    "verified": true,
    "dns_status": {
      "spf": null,
      "dkim": null,
      "mx": null,
      "return_path": null,
      "ok": false
    },
    "dns_records": {
      "spf": {
        "type": "TXT",
        "name": "example.com",
        "value": "v=spf1 a mx include:spf.postal.example.com ~all"
      },
      "dkim": {
        "type": "TXT",
        "name": "postal-ABCDEF._domainkey.example.com",
        "value": "v=DKIM1; t=s; h=sha256; p=MIGf..."
      },
      "return_path": {
        "type": "CNAME",
        "name": "example.com",
        "value": "rp.postal.example.com"
      },
      "mx": {
        "type": "MX",
        "priority": 10,
        "values": ["mx.postal.example.com"]
      }
    }
  }
}
```

#### Verify Domain (via DNS)
```
POST /management/api/v1/servers/:server_id/domains/:uuid/verify
```

#### Check DNS Configuration
```
POST /management/api/v1/servers/:server_id/domains/:uuid/check_dns
```

#### Get DNS Records
```
GET /management/api/v1/servers/:server_id/domains/:uuid/dns_records
```

Returns all DNS records needed:
```json
{
  "domain": "example.com",
  "verified": true,
  "dns_ok": false,
  "records": [
    {
      "type": "TXT",
      "name": "example.com",
      "value": "v=spf1 a mx include:spf.postal.example.com ~all",
      "purpose": "spf",
      "required": true,
      "status": null
    },
    {
      "type": "TXT",
      "name": "postal-ABCDEF._domainkey.example.com",
      "value": "v=DKIM1; ...",
      "purpose": "dkim",
      "required": true
    },
    {
      "type": "CNAME",
      "name": "example.com",
      "value": "rp.postal.example.com",
      "purpose": "return_path",
      "required": false
    },
    {
      "type": "MX",
      "name": "example.com",
      "value": "mx.postal.example.com",
      "priority": 10,
      "purpose": "mx",
      "required": false
    }
  ]
}
```

#### Delete Domain
```
DELETE /management/api/v1/servers/:server_id/domains/:uuid
```

---

### Credentials

#### List Credentials
```
GET /management/api/v1/servers/:server_id/credentials
```

#### Create Credential
```
POST /management/api/v1/servers/:server_id/credentials
```

Body:
```json
{
  "name": "API Key",
  "type": "API",
  "hold": false
}
```

Types: `API`, `SMTP`, `SMTP-IP`

Response:
```json
{
  "credential": {
    "uuid": "xxx",
    "name": "API Key",
    "type": "API",
    "key": "generated-key-here",
    "hold": false,
    "usage_type": "Unused"
  }
}
```

#### Delete Credential
```
DELETE /management/api/v1/servers/:server_id/credentials/:uuid
```

---

### Webhooks

#### List Webhooks
```
GET /management/api/v1/servers/:server_id/webhooks
```

#### Create Webhook
```
POST /management/api/v1/servers/:server_id/webhooks
```

Body (for bounces only):
```json
{
  "name": "Bounce Handler",
  "url": "https://api.example.com/bounces",
  "events": ["MessageDeliveryFailed", "MessageBounced"],
  "all_events": false,
  "enabled": true,
  "sign": true
}
```

Available events:
- `MessageSent` - Email delivered successfully
- `MessageDelayed` - Delivery delayed, will retry
- `MessageDeliveryFailed` - Permanent delivery failure
- `MessageHeld` - Message held (limit reached or dev mode)
- `MessageBounced` - Bounce received for previously sent message
- `MessageLinkClicked` - Link in email clicked
- `MessageLoaded` - Email opened (tracking pixel)
- `DomainDNSError` - DNS configuration issue detected

#### Update Webhook
```
PATCH /management/api/v1/servers/:server_id/webhooks/:uuid
```

#### Delete Webhook
```
DELETE /management/api/v1/servers/:server_id/webhooks/:uuid
```

---

## Complete Setup Example

Here's a complete workflow to set up a new mail server:

```bash
# Configuration
export POSTAL_URL="https://postal.example.com"
export POSTAL_MANAGEMENT_API_KEY="your-secret-key"

# 1. Get available IP pools
curl -s -X GET "${POSTAL_URL}/management/api/v1/ip_pools" \
  -H "X-Management-API-Key: ${POSTAL_MANAGEMENT_API_KEY}" | jq '.data.ip_pools[] | {id, name}'

# 2. Create server with IP pool
curl -s -X POST "${POSTAL_URL}/management/api/v1/servers" \
  -H "X-Management-API-Key: ${POSTAL_MANAGEMENT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "organization": "my-org",
    "name": "Server1",
    "ip_pool_id": 1,
    "mode": "Live",
    "message_retention_days": 2,
    "raw_message_retention_days": 2,
    "raw_message_retention_size": 12048
  }' | jq .

# Save the server_id and api_key from response

# 3. Add domain
curl -s -X POST "${POSTAL_URL}/management/api/v1/servers/1/domains" \
  -H "X-Management-API-Key: ${POSTAL_MANAGEMENT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"name": "mydomain.com", "auto_verify": true}' | jq .

# Save the domain uuid and configure DNS records from response

# 4. Check DNS (after configuring records)
curl -s -X POST "${POSTAL_URL}/management/api/v1/servers/1/domains/DOMAIN_UUID/check_dns" \
  -H "X-Management-API-Key: ${POSTAL_MANAGEMENT_API_KEY}" | jq .

# 5. Create bounce webhook
curl -s -X POST "${POSTAL_URL}/management/api/v1/servers/1/webhooks" \
  -H "X-Management-API-Key: ${POSTAL_MANAGEMENT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mydomain.com",
    "url": "https://mysite.com/postal/bounces",
    "events": ["MessageDeliveryFailed", "MessageBounced"],
    "enabled": true
  }' | jq .
```

---

## Python Client

A full-featured Python client is available at `examples/postal_management_client.py`:

```python
from postal_management_client import PostalManagementClient

client = PostalManagementClient(
    base_url="https://postal.example.com",
    api_key="your-management-api-key"
)

# Full automated setup
result = client.full_setup(
    organization="my-org",
    server_name="Server1",
    domain_name="example.com",
    ip_pool_id=1,
    webhook_url="https://api.example.com/bounces"
)

# Print DNS records to configure
client.print_dns_records(result["dns_records"])

# Use the API key for sending emails
print(f"API Key: {result['credentials']['api_key']}")
```

---

## Bash Functions

Shell functions for common operations are available at `examples/api_examples.sh`:

```bash
source examples/api_examples.sh

# Get IP pools
get_ip_pools

# Full setup
full_setup "my-org" "Server1" "example.com" 1 "https://mysite.com/bounces"
```
