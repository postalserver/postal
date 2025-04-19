# Servers API

The Servers API allows you to programmatically retrieve information about your Postal servers.

## Authentication

All API requests require authentication using a Server API key. This should be provided in the `X-Server-API-Key` header.

## Content Types

The API supports two content types:

1. `application/json` - Parameters should be provided as JSON in the request body.
2. `application/x-www-form-urlencoded` - Parameters should be provided as URL-encoded form data with a `params` parameter containing a JSON string.

## Endpoints

### List Servers

**URL:** `/api/v1/servers/list`  
**Method:** POST  

Returns a list of all servers in the organization that the authenticated server belongs to.

#### Parameters

None required.

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/list \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{}'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "servers": [
      {
        "uuid": "server-uuid-1",
        "name": "Marketing Server",
        "permalink": "marketing-server",
        "mode": "Live",
        "suspended": false,
        "privacy_mode": false,
        "domain_identifier": "mk",
        "ip_pool_id": "ip-pool-id",
        "created_at": "2023-01-01T12:00:00.000Z",
        "updated_at": "2023-01-01T12:00:00.000Z",
        "domains_count": 3,
        "credentials_count": 2,
        "webhooks_count": 1,
        "routes_count": 5
      },
      {
        "uuid": "server-uuid-2",
        "name": "Transactional Server",
        "permalink": "transactional-server",
        "mode": "Live",
        "suspended": false,
        "privacy_mode": false,
        "domain_identifier": "tx",
        "ip_pool_id": "ip-pool-id",
        "created_at": "2023-01-01T12:00:00.000Z",
        "updated_at": "2023-01-01T12:00:00.000Z",
        "domains_count": 5,
        "credentials_count": 3,
        "webhooks_count": 2,
        "routes_count": 8
      }
    ]
  }
}
```

### Show Server

**URL:** `/api/v1/servers/show`  
**Method:** POST  

Returns detailed information about a specific server.

#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
| server_id | String | Yes | The UUID of the server to retrieve |
| include_domains | Boolean | No | Set to `true` to include domains associated with the server |

#### Example Request

```bash
curl -X POST \
  https://postal.example.com/api/v1/servers/show \
  -H 'Content-Type: application/json' \
  -H 'X-Server-API-Key: YOUR_API_KEY' \
  -d '{
    "server_id": "server-uuid",
    "include_domains": true
  }'
```

#### Example Response

```json
{
  "status": "success",
  "time": 0.055,
  "flags": {},
  "data": {
    "server": {
      "uuid": "server-uuid",
      "name": "Transactional Server",
      "permalink": "transactional-server",
      "mode": "Live",
      "suspended": false,
      "suspension_reason": null,
      "privacy_mode": false,
      "domain_identifier": "tx",
      "ip_pool_id": "ip-pool-id",
      "created_at": "2023-01-01T12:00:00.000Z",
      "updated_at": "2023-01-01T12:00:00.000Z",
      "domains_count": 3,
      "credentials_count": 2,
      "webhooks_count": 1,
      "routes_count": 5,
      "organization": {
        "uuid": "org-uuid",
        "name": "ACME Inc",
        "permalink": "acme"
      },
      "stats": {
        "messages_sent_today": 1524,
        "messages_sent_this_month": 45789
      },
      "domains": [
        {
          "uuid": "domain-uuid-1",
          "name": "example.com",
          "verified": true,
          "verification_method": "DNS",
          "dns_checked_at": "2023-01-10T15:30:00.000Z",
          "created_at": "2023-01-01T12:00:00.000Z",
          "updated_at": "2023-01-10T15:30:00.000Z"
        },
        {
          "uuid": "domain-uuid-2",
          "name": "mail.example.org",
          "verified": true,
          "verification_method": "DNS",
          "dns_checked_at": "2023-01-10T15:30:00.000Z",
          "created_at": "2023-01-05T09:15:00.000Z",
          "updated_at": "2023-01-10T15:30:00.000Z"
        }
      ]
    }
  }
}
```

The `include_domains` parameter is optional. If set to `true`, the response will include an array of domains associated with the server.