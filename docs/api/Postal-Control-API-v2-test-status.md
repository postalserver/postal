# Postal Control API v2 — Test Status

Last verified: 2026-09-01 (Asia/Kolkata)

## Test evidence

- Local end-to-end collection lifecycle: `spec/requests/api/v2/collection_lifecycle_spec.rb`
- Full V2 request suite: `bundle exec rspec spec/requests/api/v2`
- Result: **23 examples, 0 failures**.

The lifecycle test provisions a real message database in the project’s MariaDB test container, executes every request represented by the Postman collection, and removes the created organization, server, domain, credential, and webhook afterwards. DNS verification and DNS checking are stubbed in that test so it does not depend on public DNS propagation; webhook hostname safety validation is exercised with a safe test address.

## Endpoint status

| # | Collection request | Method | Expected status | Local status |
|---:|---|---|---:|---|
| 1 | Control API health | `GET` | 200 | Pass |
| 2 | Create organization | `POST` | 201 | Pass |
| 3 | List organizations | `GET` | 200 | Pass |
| 4 | Get organization | `GET` | 200 | Pass |
| 5 | Update organization quota | `PATCH` | 200 | Pass |
| 6 | Suspend organization | `POST` | 200 | Pass |
| 7 | Unsuspend organization | `POST` | 200 | Pass |
| 8 | Create server | `POST` | 201 | Pass |
| 9 | List servers | `GET` | 200 | Pass |
| 10 | Get server | `GET` | 200 | Pass |
| 11 | Update server | `PATCH` | 200 | Pass |
| 12 | Suspend server | `POST` | 200 | Pass |
| 13 | Unsuspend server | `POST` | 200 | Pass |
| 14 | Add sending domain | `POST` | 201 | Pass |
| 15 | List domains | `GET` | 200 | Pass |
| 16 | Get domain DNS instructions | `GET` | 200 | Pass |
| 17 | Verify domain ownership | `POST` | 200 | Pass |
| 18 | Check domain DNS | `POST` | 200 | Pass |
| 19 | Create SMTP credential | `POST` | 201 | Pass |
| 20 | List credentials (secrets masked) | `GET` | 200 | Pass |
| 21 | Rotate credential | `POST` | 201 | Pass |
| 22 | Create webhook | `POST` | 201 | Pass |
| 23 | List webhooks | `GET` | 200 | Pass |
| 24 | Get webhook | `GET` | 200 | Pass |
| 25 | Update webhook | `PATCH` | 200 | Pass |
| 26 | Organization usage | `GET` | 200 | Pass |
| 27 | Server usage | `GET` | 200 | Pass |
| 28 | Server health | `GET` | 200 | Pass |
| 29 | Revoke rotated credential | `DELETE` | 204 | Pass |
| 30 | Delete webhook | `DELETE` | 204 | Pass |
| 31 | Delete domain | `DELETE` | 204 | Pass |
| 32 | Delete server | `DELETE` | 204 | Pass |
| 33 | Delete organization | `DELETE` | 204 | Pass |

## Deployed environment status

The last collection run against `https://v2postal.t4gc.in` reached the health and organization endpoints successfully, but **Create server** returned `422 provisioning_failed`. That is a deployment configuration issue: the message-database account must be permitted to create, drop, alter, and manage tables/indexes for the configured server-database prefix. Because server creation failed, the remaining server-scoped calls could not run against that deployed target.

The source now logs and retains the underlying provisioning exception in `ControlPlane::ProvisionServer`; deploy that source change and correct the database grants before re-running the live collection.
