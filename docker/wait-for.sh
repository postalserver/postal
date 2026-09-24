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

if [ -n "$JEMALLOC_PROFILE" ]; then
  jemalloc_eval="$(ruby -r/opt/postal/app/lib/postal/jemalloc.rb -e '
begin
  # Validate the profile first: nothing is written anywhere unless both the
  # library and the profile check out.
  conf = Postal::Jemalloc.malloc_conf_for(ENV.fetch("JEMALLOC_PROFILE", nil))
  lib = Postal::Jemalloc.lib_path
  abort "JEMALLOC_PROFILE is set but libjemalloc.so.2 is not installed" if lib.nil?
  # LD_PRELOAD is exported as well so that non-capped children (shell
  # utilities, node for assets) also use jemalloc, but the mechanism that
  # reaches the setcap-capped ruby binary is /etc/ld.so.preload -- glibc
  # ignores LD_PRELOAD for file-capped binaries (AT_SECURE) while honouring
  # the preload file. The image hands that file to the app user only in the
  # jemalloc variant; nowhere else does this run.
  File.write("/etc/ld.so.preload", "#{lib}\n")
  puts "LD_PRELOAD=#{lib}"
  puts "MALLOC_CONF=#{conf}"
rescue ArgumentError => e
  abort e.message
end
' 2>&1)" || { echo "jemalloc: ${jemalloc_eval}" >&2; exit 2; }
  # shellcheck disable=SC2163
  while IFS= read -r line; do export "$line"; done <<EOF
$jemalloc_eval
EOF
fi

exec "$@"
