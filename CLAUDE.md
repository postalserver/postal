# CLAUDE.md — Edify Postal fork guardrails

Standing rules for any AI agent (or human) working in this repository. Plans and
specs live in [`doc/ai/`](doc/ai/); this file holds the durable guardrails.

## What this repo is

`EdifyPress/edify-postal` is a **fork of [`postalserver/postal`](https://github.com/postalserver/postal)**.
It runs in production at **e1**. It carries Edify-specific modifications on top of
upstream and is consumed by **Edify-LM** (`EdifyPress/edify-lm`).

- `origin`   → `EdifyPress/edify-postal` (this fork)
- `upstream` → `postalserver/postal`

## Core design rule: additive, upgrade-safe, one source of truth

**Surface Postal's existing state; never re-derive or fork its logic.**
Postal already generates DKIM keypairs, derives DNS records, and runs
SPF/DKIM/MX/Return-Path verification. Edify features expose that as JSON/webhooks —
they do not reimplement it. This keeps the fork mergeable with upstream and keeps
Postal's verdict the single source of truth.

When adding a feature, prefer in this order:
1. Reuse an existing model method / concern (e.g. `Domain#check_dns`, `dkim_record`).
2. Add a thin new controller/serializer that calls into existing code.
3. Only if unavoidable, modify core — and document why in `doc/ai/`.

## Fork hygiene

- **Tag every Edify commit** with an `edify(...)` or `postal(...)` prefix so the
  fork's changes are greppable against upstream history.
- **Keep backend identifiers (`Postal::`, `Postal.method`) unchanged.** Only
  user-facing strings/branding are rebranded to "Edify" (see
  `doc/REBRANDING_GUIDE.md`).
- **Merge upstream, don't rebase** — preserves the 40+ Edify commits and resolves
  conflicts once. Track to upstream **release tags** (e.g. `3.3.7`), not `main` HEAD.
- After any upstream merge, **re-qualify the Edify mods** (CI green + manual smoke
  of: ampersand/IIS redirect handling, webhook delivery, branding render) before
  deploying to e1.

## API conventions

New HTTP API surface reuses the **Legacy API** foundation
(`app/controllers/legacy_api/base_controller.rb`):
- Auth: `X-Server-API-Key` header (server-scoped `Credential` of type `API`).
- Envelope: `{ "status": "success"|"error"|"parameter-error", "time", "flags", "data" }`
  via `render_success` / `render_error` / `render_parameter_error`.
- Errors carry a stable `code` (e.g. `DomainNotFound`, `ValidationError`).
- Specs live under `spec/apis/legacy_api/`.

## Before you ship

- `bundle exec rspec` green and CI (`.github/workflows/ci.yml`) green.
- No new upstream-divergence in core unless documented in `doc/ai/`.
- Version bump follows the `3.x.y-edify.N` scheme (upstream base + fork suffix).
