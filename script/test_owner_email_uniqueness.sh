#!/usr/bin/env bash

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run this test." >&2
  exit 1
fi

image="${POSTAL_IMAGE:-postal-control-api-ci}"

POSTAL_IMAGE="$image" docker compose run --rm postal \
  bundle exec rspec spec/requests/api/v2/organizations_spec.rb
