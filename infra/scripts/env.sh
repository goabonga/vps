# shellcheck shell=bash
# To be sourced (bash/zsh): `source scripts/env.sh`
# Loads infra/.env and checks that the credentials are set:
# the S3 keys, and one OVHcloud method (OAuth2 client, access token or API
# keys).

_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

if [ ! -f "$_root/.env" ]; then
  echo "env.sh: $_root/.env not found (cp .env.example .env)" >&2
  unset _root
  return 1
fi

set -a
# shellcheck source=/dev/null
. "$_root/.env"
set +a
unset _root

_missing=0
for _v in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  eval "_val=\${$_v:-}"
  if [ -z "$_val" ]; then
    echo "env.sh: $_v is not set" >&2
    _missing=1
  fi
done
unset _v _val

if [ -n "${OVH_ACCESS_TOKEN:-}" ]; then
  _auth="access token"
elif [ -n "${OVH_CLIENT_ID:-}" ] && [ -n "${OVH_CLIENT_SECRET:-}" ]; then
  _auth="OAuth2 client"
elif [ -n "${OVH_APPLICATION_KEY:-}" ] && [ -n "${OVH_APPLICATION_SECRET:-}" ] && [ -n "${OVH_CONSUMER_KEY:-}" ]; then
  _auth="API keys"
else
  echo "env.sh: no OVHcloud credential: set OVH_CLIENT_ID + OVH_CLIENT_SECRET, OVH_ACCESS_TOKEN," >&2
  echo "env.sh: or OVH_APPLICATION_KEY + OVH_APPLICATION_SECRET + OVH_CONSUMER_KEY" >&2
  _missing=1
fi

if [ "$_missing" -eq 1 ]; then
  unset _missing _auth
  return 1
fi
echo "env.sh: S3 and OVHcloud ($_auth) variables loaded"
unset _missing _auth
