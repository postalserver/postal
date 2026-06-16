# Plan: upstream re-baseline (3.3.7) → re-qualify mods → domains API

- **Date:** 2026-06-16
- **Repo:** `EdifyPress/edify-postal` (fork of `postalserver/postal`, runs at e1)
- **Issues:** [#1](https://github.com/EdifyPress/edify-postal/issues/1) (required), [#2](https://github.com/EdifyPress/edify-postal/issues/2) (optional)
- **Consumer:** Edify-LM sending-domain auth wizard (`EdifyPress/edify-lm#173`, client `internal/postal/domains.go` PR #203)

## Decisions (locked)

| Topic | Decision |
|---|---|
| Merge target | Upstream **release tag `3.3.7`** (not `main` HEAD) |
| Strategy | **Merge** upstream into fork `main` (not rebase) |
| Sequencing | **Security baseline first**, ship to e1, then features in a follow-up |
| Artifact home | Plans under `doc/ai/`; standing guardrails in root `CLAUDE.md` |
| Qualify bar | **CI green + manual smoke** of high-risk Edify mods |
| API foundation | Reuse `LegacyAPI::BaseController` (`X-Server-API-Key`, `{status,time,flags,data}`) |

## Why this matters (the re-baseline is security-driven)

The fork's `main` (`3.3.4-edify.10`) is **27 commits behind** upstream and is
**missing patched vulnerabilities** currently live at e1:

- `fix(message-db): prevent SQL injection via condition keys (GHSA-x2hq-rfpg-3xr5)`
- `fix(http): prevent SSRF in outbound webhook and HTTP endpoint requests`
- `fix(messages): sandbox rendered email HTML as extra XSS defence`
- `fix(deliveries): escape delivery details to prevent HTML injection`
- `refactor(auth): tighten return_to validation`
- plus releases `3.3.5 → 3.3.6 → 3.3.7` and dependency bumps (rails 7.1.6, rack).

This is why the merge lands and deploys **before** the new features.

---

## Phase 1 — Re-baseline onto upstream 3.3.7

Merge is small and tractable (validated by dry-run): **29 files, +1114/-65, only 3
conflicts**, all mechanical. `lib/tracking_middleware.rb` (the ampersand/IIS mod)
**auto-merges clean**.

Branch: `chore/merge-upstream-3.3.7`

Conflicts and resolution:
| File | Conflict | Resolution |
|---|---|---|
| `spec/rails_helper.rb` | helper glob | **Take upstream** — adds `.reject { _spec.rb }`, strictly safer |
| `Gemfile` | `rails 7.1.5.2` vs `7.1.6` | **Take upstream** `7.1.6` (patch/security) |
| `Gemfile.lock` | lockfile | **Regenerate** via `bundle install` after Gemfile resolved |

Steps:
1. `git fetch upstream --tags`
2. `git checkout -b chore/merge-upstream-3.3.7`
3. `git merge 3.3.7`
4. Resolve the 3 conflicts as above; `bundle install` to regenerate the lock.
5. Commit the merge (`edify(chore): merge upstream 3.3.7 (security baseline)`).

## Phase 2 — Qualify mods against the new baseline (regression)

Bar = **CI green + manual smoke**. The Edify mods to re-verify (highest merge risk):

- **Ampersand / IIS redirect handling** — `lib/tracking_middleware.rb`, message
  parser URL handling. Covered by `spec/lib/ampersand_fix_spec.rb`; also smoke a
  redirect with `&` in a tracked URL.
- **Webhook delivery** — `HashWithIndifferentAccess` YAML serialization fix
  (`WebhookRequest#payload`, `Credential#options`). Smoke an actual webhook delivery
  under Rails 7.1.6 / Psych 5.
- **Branding** — user-facing views/emails render "Edify", no `postalserver.io` links.
- **Queue fairness** — round-robin server selection in `ProcessQueuedMessagesJob`.

Steps:
1. `bundle exec rspec` → green (pay attention to `spec/apis/`, `spec/lib/`, `spec/services/webhook_delivery_service_spec.rb`).
2. Push branch; confirm `.github/workflows/ci.yml` green.
3. Manual smoke of the four areas above.
4. If a mod regressed: fix on the branch; add a regression spec if the gap was real.

## Phase 3 — Ship baseline to e1

- Version bump → `3.3.7-edify.1` (upstream base + fork suffix).
- Merge `chore/merge-upstream-3.3.7` → `main`; build/push image; deploy e1.
- **Gate:** features (Phase 4) start only after the baseline is green at e1.

## Execution log — Phases 1–2 (actuals, 2026-06-16)

Done on branch `chore/merge-upstream-3.3.7` → [PR #3](https://github.com/EdifyPress/edify-postal/pull/3):

1. `dee6131` docs (CLAUDE.md + this plan).
2. `1805924` merge upstream 3.3.7 — 3 conflicts, all resolved to upstream as planned.
3. `6ef1456` **CI registry fix** — inherited `ci.yml` pushed to `ghcr.io/postalserver/postal`
   (upstream namespace, `permission_denied`); CI had never passed on the fork and the
   Test Suite job never ran. Repointed to `ghcr.io/edifypress/edify-postal` + `packages: write`.
4. `a447a61` **qualify fixes** — pre-existing fork breakage surfaced once the suite ran:
   - `db/schema.rb` was stuck at `2024_03_11_205229` while 4 scan-cache migrations existed →
     `check_pending_migrations` aborted every spec. Regenerated via migrate+dump → version
     `2026_01_09_000000`, **zero structural diff** (the scan-cache migrations net to nothing).
   - Removed orphans from the incomplete scan-cache removal: `spec/models/scan_result_cache_spec.rb`
     (referenced deleted `ScanResultCache`), `lib/postal/cached_scan_result.rb` (dead, unreferenced).
5. `c566274` **CI tag fix** — `Release (branch)` job built an invalid Docker tag for `/`-containing
   branch names; sanitised `/`→`-`.

**Result: CI fully green** (CI Image Build + Test Suite + Release branch). Suite = 826 examples
passing on GitHub runners (2 IPv6 `DNSResolver#aaaa` tests fail only in local Docker for lack of
IPv6 egress).

**Still open in Phase 2:** manual smoke of high-risk Edify mods (logic is spec-covered:
ampersand_fix_spec + webhook_delivery_service_spec pass; smoke adds branding render + live redirect).

**Flagged, not done (out of this PR's scope):** two dead artifacts from the scan-cache removal
remain — `deploy_multi_hash_migration.sh` and `PERFORMANCE_FIX_PLAN.md` (the latter may hold
non-scan-cache notes; review before deleting).

## Phase 4 — Feature: JSON `api/v1/domains` controller (Issue #1, required)

**Additive — surfaces Postal's existing Domain state as JSON. Never re-derives.**
All reused methods verified present in core:
`Domain#{spf_record,dkim_record,dkim_record_name,return_path_domain,dkim_identifier,
verified?,verified_at,mark_as_verified,check_dns}` and the
`{spf,dkim,mx,return_path}_status` (`OK|Missing|Invalid`) + `dns_checked_at` from
`HasDNSChecks`.

Foundation: `LegacyAPI::DomainsController < LegacyAPI::BaseController` →
inherits `X-Server-API-Key` auth + `render_success`/`render_error` envelope.
Domains scoped to `@current_credential.server.domains`. Looked up by `name`.

Routes (`config/routes.rb`, alongside existing `/api/v1/...`):
| Method | Path | Action |
|---|---|---|
| POST | `/api/v1/domains` | create (`{name}`) → domain payload |
| GET  | `/api/v1/domains/:name` | show current state |
| POST | `/api/v1/domains/:name/check` | run `Domain#check_dns(:manual)`, return state |
| DELETE | `/api/v1/domains/:name` | destroy → `{status:success}` |

Response `data` shape (matches edify-lm `domains.go` / PR #203):
```json
{ "name", "dkim_record_name", "dkim_record", "spf_record", "return_path_domain",
  "dkim_status", "spf_status", "mx_status", "return_path_status",
  "verified", "verified_at", "dns_checked_at" }
```
Errors → error envelope with stable `code` (`DomainNotFound`, `ValidationError`).
A single private `domain_payload(domain)` serializer feeds create/show/check.

Tests: `spec/apis/legacy_api/domains_spec.rb` — auth required; create/show/check/delete;
error envelopes; field names + native statuses match the Go client.

## Phase 5 — Feature: `DomainVerified` webhook (Issue #2, optional)

**Trigger: on transition only, auto checks** (mirrors the existing `DomainDNSError`).

- Add `DomainVerified` to `WebhookEvent::EVENTS` (`app/models/webhook_event.rb`).
- In `HasDNSChecks#check_dns`, the `DomainDNSError` webhook already fires for
  `source == :auto && !dns_ok?`. Add the symmetric case: fire `DomainVerified`
  with `{domain, statuses, verified_at}` when an auto check **transitions** a domain
  into `dns_ok?` (was-not-ok → now-ok), so it does not re-fire hourly.
- Source of auto checks: `CheckAllDNSScheduledTask` (hourly).
- Edify-LM can still poll `GET /api/v1/domains/:name` until `verified_at` is set;
  this webhook just lets it flip the badge without polling. Ship only if cheap.

## Out of scope / explicitly not doing

- Not reimplementing DNS/DKIM logic. Not changing core verification behavior.
- Not pulling upstream `main` HEAD (tracking tagged releases only).
- Unrelated upstream issues (`postalserver/postal#3567` routes 500,
  `#3581` DKIM delegation) are **not** part of this work.
