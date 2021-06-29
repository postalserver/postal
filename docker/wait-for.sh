#!/bin/sh
[ -n "$DEBUG" ] && set -x

check_http() {
  wget -T 1 -S -q -O - "$1" 2>&1 | head -1 |
    head -1 | grep -E 'HTTP.+\s2\d{2}' >/dev/null 2>&1
  return $?
}

check_tcp() {
  host="$(echo "$1" | cut -d: -f1)"
  port="$(echo "$1" | cut -d: -f2)"
  if [ -z "${host}" ] || [ -z "${port}" ]; then
    echo "TCP target ${1} is not in \"<host>:<port>\" format" >&2
    exit 2
  fi

  nc -z -w1 "$host" "$port" >/dev/null 2>&1
  return $?
}

wait_for() {
  type="$1"
  uri="$2"
  timeout="${3:-30}"

  seconds=0
  while [ "$seconds" -lt "$timeout" ] && ! "check_${type}" "$uri"; do
    if [ "$seconds" -lt "1" ]; then
      printf "Waiting for %s  ." "$uri"
    else
      printf .
    fi
    seconds=$((seconds + 1))
    sleep 1
  done

  if [ "$seconds" -lt "$timeout" ]; then
    if [ "$seconds" -gt "0" ]; then
      echo "  up!"
    fi
  else
    echo "  FAIL"
    echo "ERROR: unable to connect to: $uri" >&2
    exit 1
  fi
}

if [ -n "$WAIT_FOR_TARGETS" ]; then
  uris="$(echo "$WAIT_FOR_TARGETS" | sed -e 's/\s+/\n/g' | uniq)"
  for uri in $uris; do
    if echo "$uri" | grep -E '^https?://.*' >/dev/null 2>&1; then
      wait_for "http" "$uri" "$WAIT_FOR_TIMEOUT"
    else
      wait_for "tcp" "$uri" "$WAIT_FOR_TIMEOUT"
    fi
  done
fi

exec "$@"
