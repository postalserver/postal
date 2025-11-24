# Bug Fix: API Domain Creation Missing DNS Verification Records

## Problem

When creating a domain via the Management API (`POST /api/v2/management/servers/:server_id/domains`), the domain was created without a `verification_token`, causing:

1. No DNS verification records displayed in the web UI
2. DNS verification failing with error: "DNS verification failed. Ensure TXT record is configured."
3. Missing `dns_verification_string`, `dkim_identifier`, and other DNS-related fields

## Root Cause

The issue was in `/app/controllers/management_api/domains_controller.rb`:

**Before:**
```ruby
def create
  domain = @server.domains.new(domain_params)
  domain.owner = @server
  domain.verification_method = api_params[:verification_method] || "DNS"  # Set AFTER .new()
  domain.save
end

def domain_params
  {
    name: api_params[:name],
    # verification_method was NOT included here
    outgoing: api_params[:outgoing],
    incoming: api_params[:incoming],
    use_for_any: api_params[:use_for_any]
  }.compact
end
```

The `verification_method` was set **after** the domain object was instantiated with `.new(domain_params)`. The Domain model has a `before_save` callback (`update_verification_token_on_method_change`) that generates the `verification_token` only when `verification_method_changed?` returns true. 

Setting `verification_method` separately after `.new()` can cause ActiveRecord's change tracking to not properly detect this as a change in some contexts, preventing the token from being generated.

## Solution

Include `verification_method` in the `domain_params` hash so it's part of the initial attributes when building the domain, matching the pattern used by the web UI:

**After:**
```ruby
def create
  domain = @server.domains.new(domain_params)  # verification_method now included in params
  domain.owner = @server
  domain.save
end

def domain_params
  {
    name: api_params[:name],
    verification_method: api_params[:verification_method] || "DNS",  # ✅ Now included
    outgoing: api_params[:outgoing],
    incoming: api_params[:incoming],
    use_for_any: api_params[:use_for_any]
  }.compact
end
```

This ensures:
1. `verification_method` is set as part of the initial domain attributes
2. The `before_save :update_verification_token_on_method_change` callback properly detects the change from `nil` → `"DNS"`
3. A `verification_token` is generated (32-char alphanumeric for DNS, 6-digit for Email)
4. All DNS-related methods work correctly (`dns_verification_string`, `dkim_identifier`, etc.)

## Files Changed

- `/app/controllers/management_api/domains_controller.rb`: Updated `create` action and `domain_params` method
- `/spec/apis/management_api/domains_controller_spec.rb`: Added comprehensive test coverage

## Testing

The fix includes new RSpec tests that verify:
1. Creating a domain via API generates the verification token
2. DNS verification method defaults to "DNS" when not specified
3. Email verification method generates a 6-digit numeric token
4. All DNS-related fields are properly populated

Run tests:
```bash
bundle exec rspec spec/apis/management_api/domains_controller_spec.rb
```

## Impact

This fix resolves the issue where domains created via the Management API couldn't be verified and didn't display DNS records in the web interface. The behavior now matches the web UI domain creation flow.
