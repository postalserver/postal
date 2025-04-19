# Domain API

The Domain API allows you to programmatically add and verify domains in Postal.

## Authentication

All API requests require authentication using a Server API key. This should be provided in the `X-Server-API-Key` header.

## Content Types

The API supports two content types:

1. `application/json` - Parameters should be provided as JSON in the request body.
2. `application/x-www-form-urlencoded` - Parameters should be provided as URL-encoded form data with a `params` parameter containing a JSON string.

## Endpoints

### Create Domain

**URL:** `/api/v1/domains/create`  
**Method:** POST  

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| server_id | String | Yes | The UUID of the server to add the domain to |
| name | String | Yes | The domain name to add |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/create \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "server_id": "server-uuid",
    "name": "example.com"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "domain": {
      "uuid": "domain-uuid",
      "name": "example.com",
      "verification_method": "DNS",
      "verified": false,
      "verification_token": "verification-token",
      "dns_verification_string": "postal-verify verification-token",
      "created_at": "2023-01-01T12:00:00.000Z",
      "updated_at": "2023-01-01T12:00:00.000Z"
    }
  }
}
```

### Verify Domain

**URL:** `/api/v1/domains/verify`  
**Method:** POST  

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| domain_id | String | Yes | The UUID of the domain to verify |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/verify \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "domain_id": "domain-uuid"
  }'
```

#### Example Success Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "domain": {
      "uuid": "domain-uuid",
      "name": "example.com",
      "verified": true,
      "verified_at": "2023-01-01T12:00:00.000Z"
    }
  }
}
```

#### Example Error Response

```json
{
  "status": "error",
  "time": 0.055,
  "flags": {},
  "data": {
    "code": "VerificationFailed",
    "message": "We couldn't verify your domain. Please double check you've added the TXT record correctly.",
    "dns_verification_string": "postal-verify verification-token"
  }
}
```

### Get DNS Records

**URL:** `/api/v1/domains/dns_records`  
**Method:** POST  

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| domain_id | String | Yes | The UUID of the domain to get DNS records for |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/domains/dns_records \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "domain_id": "domain-uuid"
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "domain": {
      "uuid": "domain-uuid",
      "name": "example.com",
      "verified": true
    },
    "dns_records": [
      {
        "type": "TXT",
        "name": "example.com",
        "value": "v=spf1 a mx include:spf.postal.example.com ~all",
        "purpose": "spf"
      },
      {
        "type": "TXT",
        "name": "postal-abc123._domainkey.example.com",
        "short_name": "postal-abc123._domainkey",
        "value": "v=DKIM1; t=s; h=sha256; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCuGbIaO4c5rhYkHPMYMH/Cg8zRW...",
        "purpose": "dkim"
      },
      {
        "type": "CNAME",
        "name": "rp.example.com",
        "short_name": "rp",
        "value": "return.postal.example.com",
        "purpose": "return_path"
      },
      {
        "type": "MX",
        "name": "example.com",
        "priority": 10,
        "value": "mx.postal.example.com",
        "purpose": "mx"
      }
    ]
  }
}
```

## DNS Verification

To verify your domain via DNS, add a TXT record to your domain with the following content:

```
postal-verify YOUR_VERIFICATION_TOKEN
```

The verification token and full verification string are provided in the response when you create a domain.

## DNS Record Types

When setting up a domain with Postal, you'll need to configure several DNS records:

1. **Verification Record (TXT)** - Used to verify domain ownership
2. **SPF Record (TXT)** - Specifies which servers are allowed to send email for your domain
3. **DKIM Record (TXT)** - Enables cryptographic signing of messages
4. **Return Path Record (CNAME)** - Used for return path/bounce handling
5. **MX Records** - Required if you want to receive inbound email
6. **Tracking Domain Records (CNAME)** - For open/click tracking

The `dns_records` endpoint provides all the necessary records for proper configuration.