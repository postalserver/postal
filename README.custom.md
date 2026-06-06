# Postal Custom — Priority Subjects & Configurable Send Limit Retry

This is a custom build of [Postal](https://github.com/postalserver/postal) v3.3.6 with two additional features aimed at high-volume transactional email deployments.

---

## New Features

### 1. Priority Subject Keywords

**Problem:** When a mail server hits its hourly send limit, all outbound emails are held — including time-sensitive transactional emails like password resets and OTPs.

**Solution:** Admins can configure a list of subject keywords. Any outgoing email whose subject contains one of these keywords will bypass the hourly send limit and be delivered immediately, regardless of current volume.

**How it works:**
- Keywords are matched case-insensitively and as substrings (e.g. keyword `reset` matches subject `Password Reset Request`)
- Non-matching emails continue to follow the normal send limit behavior
- Only server admins can manage keywords

**Configuration (Admin UI):**
1. Log in to Postal as an admin
2. Go to **Mail Server → Settings → Advanced**
3. Scroll to the **Priority Subject Keywords** section
4. Use the **Add Keyword** form to add keywords one at a time
5. Click **Remove** next to any keyword to delete it

---

### 2. Configurable Send Limit Retry Interval

**Problem:** When the hourly send limit is reached, all queued messages are placed in a "Held" state and require manual intervention to release — even if the limit resets within an hour.

**Solution:** Admins can set a retry interval (in minutes). When the send limit is exceeded, messages stay in the queue and are automatically retried after the configured interval instead of being held indefinitely.

**How it works:**
- If **Send Limit Retry Interval** is set (e.g. `60`): messages are re-queued with a `retry_after` timestamp set that many minutes in the future. When the limit resets, they are delivered automatically.
- If left **blank**: original Postal behavior is preserved — messages are held until manually released.

**Configuration (Admin UI):**
1. Log in to Postal as an admin
2. Go to **Mail Server → Settings → Advanced**
3. Set the **Send Limit Retry Interval** field to the number of minutes between retries (e.g. `60` for hourly retry)
4. Click **Save server**

---

## Installation

### Prerequisites

- Docker and Docker Compose
- An existing Postal v3.3.6 installation, **or** a fresh install using the official Postal setup guide

### Option A — Use the Pre-built Docker Image

Replace the official image in your `docker-compose.yml`:

```yaml
# Before:
image: ghcr.io/postalserver/postal:3.3.6

# After:
image: <your-dockerhub-username>/postal-custom:3.3.6
```

Then run migrations:

```bash
docker compose run --rm runner postal upgrade
```

### Option B — Build from Source

```bash
git clone https://github.com/<your-github-username>/postal-custom.git
cd postal-custom
docker build -t postal-custom:3.3.6 .
```

Update your `docker-compose.yml` to use `postal-custom:3.3.6`, then:

```bash
docker compose up -d
docker compose run --rm runner postal upgrade
```

---

## Database Migrations

Two migrations are included:

| Migration | Description |
|---|---|
| `20260514000000_add_priority_subjects_to_servers` | Adds `priority_subjects` (text) column to `servers` table |
| `20260514000001_add_send_limit_retry_interval_to_servers` | Adds `send_limit_retry_interval` (integer, minutes) column to `servers` table |

Run them with:

```bash
docker compose run --rm runner postal upgrade
```

---

## Files Changed from Upstream

| File | Change |
|---|---|
| `db/migrate/20260514000000_add_priority_subjects_to_servers.rb` | New migration |
| `db/migrate/20260514000001_add_send_limit_retry_interval_to_servers.rb` | New migration |
| `app/models/server.rb` | Added `priority_subject_keywords`, `priority_subject_bypass?` methods |
| `app/lib/message_dequeuer/outgoing_message_processor.rb` | Modified `check_send_limits` to support both features |
| `app/controllers/servers_controller.rb` | Added `add_priority_subject`, `remove_priority_subject` actions and permitted params |
| `config/routes.rb` | Added `add_priority_subject` and `remove_priority_subject` member routes |
| `app/views/servers/advanced.html.haml` | Added UI for both features in the Admin → Advanced settings page |

---

## Upgrading

When a new upstream Postal version is released:

1. Fetch upstream changes: `git fetch upstream && git merge upstream/main`
2. Resolve any conflicts in the files listed above
3. Rebuild: `docker build -t postal-custom:<new-version> .`
4. Deploy and migrate

---

## License

MIT — same as the upstream [Postal](https://github.com/postalserver/postal) project.
