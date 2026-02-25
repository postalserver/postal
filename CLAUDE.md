# CLAUDE.md

This file provides guidance for AI assistants working with the Postal codebase.

## Project Overview

Postal is a fully featured, open-source mail server (comparable to Sendgrid/Mailgun/Postmark). It provides SMTP sending/receiving, a web UI for management, webhook delivery, message tracking, and a legacy REST API. Built with Ruby on Rails 7.1 and backed by MySQL/MariaDB.

## Tech Stack

- **Ruby** 3.4.6 (see `.ruby-version`)
- **Rails** 7.1.5.2 (pinned in Gemfile)
- **Database**: MySQL/MariaDB via `mysql2` gem
- **Web Server**: Puma
- **Views**: HAML templates with Sprockets asset pipeline (SCSS, CoffeeScript, jQuery)
- **Auth**: Authie for session management, optional OIDC via `omniauth_openid_connect`
- **Config**: Konfig (`konfig-config` gem) with YAML files or environment variables
- **Testing**: RSpec, FactoryBot, Shoulda Matchers, Timecop, WebMock, DatabaseCleaner
- **Linting**: RuboCop + RuboCop Rails
- **Container**: Docker (Ruby 3.4.6 slim-bookworm base)
- **CI**: GitHub Actions (Docker-based build and test)

## Repository Structure

```
app/
  controllers/       # Rails controllers (web UI + legacy API)
  controllers/legacy_api/  # Legacy REST API (v1)
  models/            # ActiveRecord models
  models/concerns/   # Shared model concerns (HasUUID, HasSoftDestroy, etc.)
  lib/               # Domain logic (message dequeuer, SMTP client/server, workers)
  views/             # HAML templates
  helpers/           # View helpers
  mailers/           # ActionMailer classes
  senders/           # Message delivery (SmtpSender, HttpSender, BaseSender, SendResult)
  services/          # Service objects (WebhookDeliveryService)
  scheduled_tasks/   # Periodic tasks run by the worker
  assets/            # Stylesheets (SCSS), JavaScript (CoffeeScript), images
  util/              # Utility classes
config/
  routes.rb          # All route definitions
  database.yml       # DB config (reads from Postal::Config)
  puma.rb            # Puma server configuration
  initializers/      # Rails initializers
  examples/          # Example config files for dev/test
  environments/      # Per-environment Rails config
db/
  schema.rb          # Database schema (source of truth)
  migrate/           # ActiveRecord migrations
lib/
  postal/            # Core Postal library code
  postal/config.rb   # Configuration loading (Konfig)
  postal/config_schema.rb  # Configuration schema definition
  postal/message_db/ # Per-server message database management and migrations
  postal/message_inspectors/  # Spam/virus scanning (ClamAV, Rspamd, SpamAssassin)
  tasks/             # Rake tasks (postal.rake)
  tracking_middleware.rb  # Rack middleware for click/open tracking
spec/
  models/            # Model specs
  lib/               # Library/service specs
  apis/              # API integration specs (legacy API)
  factories/         # FactoryBot factory definitions
  helpers/           # Test helpers (GeneralHelpers, MessageDbMocking, etc.)
  senders/           # Sender specs
  services/          # Service specs
  scheduled_tasks/   # Scheduled task specs
script/              # Standalone scripts (SMTP server, worker, user creation, etc.)
bin/
  postal             # Main CLI entry point (bash)
  dev                # Development runner (foreman)
  rspec              # RSpec binstub
docker/              # Docker support files (wait-for.sh, CI config)
```

## Build & Run Commands

```bash
# Install dependencies
bundle install

# Run all development components (web, worker, SMTP) via Foreman
bin/dev

# Run individual components
bin/postal web-server      # Puma web server
bin/postal smtp-server     # SMTP server
bin/postal worker          # Background worker

# Database
bin/postal initialize      # Create DB + load schema (first time)
bin/postal update          # Run pending migrations

# Rails console
bin/postal console

# Asset precompilation
RAILS_GROUPS=assets bundle exec rake assets:precompile
```

## Testing

```bash
# Run the full test suite
bundle exec rspec

# Run a specific spec file
bundle exec rspec spec/models/server_spec.rb

# Run a specific test by line number
bundle exec rspec spec/models/server_spec.rb:42
```

**Test configuration**: Tests expect a config file at `config/postal/postal.test.yml` (see `config/examples/test.yml`) or environment variables loaded from `.env.test`. The test environment uses `POSTAL_CONFIG_FILE_PATH` env var.

**Key test conventions**:
- Uses `FactoryBot` for test data (factories in `spec/factories/`)
- `DatabaseCleaner` for database state management
- `FactoryBot.lint` runs before the suite to validate all factories
- `WebMock` is enabled (external HTTP calls are blocked by default)
- Request specs set host to `Postal::Config.postal.web_hostname` automatically
- Helper `GeneralHelpers` is included in all specs
- Message DB interactions are mocked via `spec/helpers/message_db_mocking.rb`

## Linting

```bash
# Run RuboCop
bundle exec rubocop

# Auto-correct fixable offenses
bundle exec rubocop -a
```

## Code Conventions

### Ruby Style (from .rubocop.yml)

- **Strings**: Always use double quotes (`"hello"` not `'hello'`)
- **Frozen string literal**: Required (`# frozen_string_literal: true` at top of every Ruby file)
- **Symbol arrays**: Use bracket notation (`[:one, :two]` not `%i[one two]`)
- **Line length**: Max 200 characters (goal is to reduce to 120)
- **Trailing commas**: Required in multiline arrays (consistent_comma style)
- **Empty lines around class body**: Required (empty lines after `class` and before `end`)
- **Empty lines around block body**: Not required
- **Lambda spacing**: Space required after `->` (e.g., `-> (var) { block }`)
- **Empty methods**: Use expanded style (not single-line)
- **Accessor grouping**: Disabled (separate `attr_*` on individual lines)
- **Documentation**: Not required (Style/Documentation disabled)
- **Various metrics**: AbcSize, CyclomaticComplexity, MethodLength, BlockLength, ClassLength disabled

### Application Patterns

- **ApplicationRecord**: Uses `nilify_blanks` and custom STI column (`sti_type` instead of `type`)
- **Soft deletes**: Via `HasSoftDestroy` concern (uses `deleted_at` column)
- **UUIDs**: Models use `HasUUID` concern for UUID generation
- **Permalinks**: Resources identified by permalink in URLs (override `to_param`)
- **Two-database architecture**: Main database (ActiveRecord/schema.rb) for core models, plus per-server message databases managed by `Postal::MessageDB` with custom migrations in `lib/postal/message_db/migrations/`
- **Configuration**: All config accessed via `Postal::Config.*` (Konfig gem). Supports YAML file (v1 legacy or v2) and environment variables. Config file path set via `POSTAL_CONFIG_FILE_PATH` env var.
- **Schema annotations**: Models and factories include schema annotations generated by the `annotate` gem
- **Controllers**: Use `Authie` for authentication. Organization-scoped routes use `WithinOrganization` concern. Respond to both HTML and JSON.

### Key Domain Concepts

- **Organization**: Top-level entity that owns servers, domains, and users
- **Server**: A mail server within an organization; each server gets its own message database
- **Domain**: A sending/receiving domain, owned by either a Server or Organization
- **Credential**: API keys/SMTP credentials for a server
- **Route**: Maps incoming email addresses to endpoints
- **Endpoints**: Address, SMTP, or HTTP endpoints for routing incoming mail
- **QueuedMessage**: Messages waiting to be sent
- **MessageDB**: Per-server database storing messages, deliveries, clicks, loads, stats, suppressions
- **Webhook**: Server-level webhooks for event notifications
- **WorkerRole**: Distributed locking for background worker roles
- **ScheduledTask**: Periodic maintenance tasks (cleanup, DNS checks, retention, etc.)

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`):
1. **Build**: Docker image build (CI target, no asset compilation)
2. **Test**: `bundle exec rspec` inside Docker container with MariaDB
3. **Release**: Docker image published to `ghcr.io/postalserver/postal` on branch pushes and releases
4. **Release Please**: Automated versioning/changelogs on main branch

## Configuration

Configuration is managed via `Postal::Config` (Konfig gem). Two approaches:
1. **YAML file**: Place at `config/postal/postal.yml` (or set `POSTAL_CONFIG_FILE_PATH`). Supports version 1 (legacy) and version 2 formats.
2. **Environment variables**: Loaded from `.env` files or system env. Env vars override YAML values.

Example configs are in `config/examples/` (development.yml, test.yml).

A signing key is required: `openssl genrsa -out config/postal/signing.key 2048`

## Docker

```bash
# Build the image
docker build -t postal .

# Run with docker-compose (for CI/testing)
docker compose run postal sh -c 'bundle exec rspec'
```

The Dockerfile has two targets:
- `ci`: Base image without precompiled assets
- `full`: Production image with precompiled assets
