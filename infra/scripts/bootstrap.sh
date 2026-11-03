#!/usr/bin/env bash
# Creates the state storage (and the OAuth2 service account for the other
# units) with Terraform, then moves its own state into the bucket.
#
#   1. apply bootstrap/ (project, user, S3 credentials, policy, bucket,
#      OAuth2 client and its IAM policies)
#   2. write the new credentials into .env: AWS_ACCESS_KEY_ID,
#      AWS_SECRET_ACCESS_KEY and, if an OAuth2 client is configured,
#      OVH_CLIENT_ID, OVH_CLIENT_SECRET
#   3. migrate the local state into the bucket it just created
#   4. remove the local state files
#
# Needs ONE admin credential, in the environment or in .env (see README):
# OVH_ACCESS_TOKEN, or OVH_CLIENT_ID + OVH_CLIENT_SECRET, or
# OVH_APPLICATION_KEY + OVH_APPLICATION_SECRET + OVH_CONSUMER_KEY.
#
# Usage: scripts/bootstrap.sh [--yes] [--remote] [--migrate-only] [--write-env]
#   --yes           do not ask for confirmation before applying
#   --remote        the state is already in the bucket (bootstrap done once):
#                   apply against it, no migration. Needs the AWS_* variables.
#   --migrate-only  skip steps 1-2 (resume after an interrupted migration)
#   --write-env     only rewrite the credentials in .env from the bootstrap
#                   outputs, then exit. Reads the remote state when S3
#                   credentials are already available, the local one otherwise.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$root/.env"
unit="$root/bootstrap"

auto_approve=()
remote=0
migrate_only=0
write_env=0
for arg in "$@"; do
  case "$arg" in
    --yes) auto_approve=(-auto-approve) ;;
    --remote) remote=1 ;;
    --migrate-only) migrate_only=1 ;;
    --write-env) write_env=1 ;;
    -h | --help) sed -n '2,${/^#/!q;p}' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "bootstrap.sh: unknown option: $arg" >&2; exit 2 ;;
  esac
done

log() { echo "bootstrap.sh: $*" >&2; }

load_env() {
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
  fi
}

require() {
  local missing=0 v
  for v in "$@"; do
    if [ -z "${!v:-}" ]; then
      log "$v is not set"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || exit 1
}

# One admin credential is enough, whatever the method.
require_ovh_auth() {
  if [ -n "${OVH_ACCESS_TOKEN:-}" ]; then return 0; fi
  if [ -n "${OVH_CLIENT_ID:-}" ] && [ -n "${OVH_CLIENT_SECRET:-}" ]; then return 0; fi
  if [ -n "${OVH_APPLICATION_KEY:-}" ] && [ -n "${OVH_APPLICATION_SECRET:-}" ] && [ -n "${OVH_CONSUMER_KEY:-}" ]; then return 0; fi
  log "no OVHcloud credential: set OVH_ACCESS_TOKEN, or OVH_CLIENT_ID + OVH_CLIENT_SECRET,"
  log "or OVH_APPLICATION_KEY + OVH_APPLICATION_SECRET + OVH_CONSUMER_KEY"
  exit 1
}

# set_env_var NAME VALUE: replaces or appends NAME=VALUE in .env without
# putting the value on a command line.
set_env_var() {
  local name="$1" value="$2" tmp
  tmp="$(umask 077 && mktemp "$env_file.XXXXXX")"
  if [ -f "$env_file" ]; then
    grep -v "^${name}=" "$env_file" >"$tmp" || true
  fi
  printf '%s=%s\n' "$name" "$value" >>"$tmp"
  mv "$tmp" "$env_file"
  chmod 600 "$env_file"
}

tg() { (cd "$unit" && terragrunt "$@"); }

# write_credentials BACKEND: copies the credentials from the bootstrap
# outputs (read through BACKEND: local or s3) into .env.
write_credentials() {
  local backend="$1" access_key secret_key client_id client_secret
  access_key="$(BOOTSTRAP_BACKEND=$backend tg output -raw access_key_id)"
  secret_key="$(BOOTSTRAP_BACKEND=$backend tg output -raw secret_access_key)"
  [ -n "$access_key" ] && [ -n "$secret_key" ] || { log "empty S3 credentials in the outputs"; exit 1; }
  set_env_var AWS_ACCESS_KEY_ID "$access_key"
  set_env_var AWS_SECRET_ACCESS_KEY "$secret_key"

  # Null outputs (no OAuth2 client configured) make `output -raw` fail.
  client_id="$(BOOTSTRAP_BACKEND=$backend tg output -raw oauth2_client_id 2>/dev/null || true)"
  client_secret="$(BOOTSTRAP_BACKEND=$backend tg output -raw oauth2_client_secret 2>/dev/null || true)"
  if [ -n "$client_id" ] && [ -n "$client_secret" ]; then
    set_env_var OVH_CLIENT_ID "$client_id"
    set_env_var OVH_CLIENT_SECRET "$client_secret"
    log "OAuth2 client written to .env (OVH_CLIENT_ID, OVH_CLIENT_SECRET)"
  fi
}

load_env
require_ovh_auth

if [ "$write_env" -eq 1 ]; then
  if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    backend=s3
  elif [ -f "$unit/terraform.tfstate" ]; then
    backend=local
  else
    log "no S3 credentials to read the remote state and no local state: nothing to read from"
    exit 1
  fi
  log "writing credentials to .env from the $backend state"
  write_credentials "$backend"
  exit 0
fi

if [ "$remote" -eq 1 ]; then
  require AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  log "applying bootstrap/ against the remote state"
  BOOTSTRAP_BACKEND=s3 tg apply "${auto_approve[@]}"
  write_credentials s3
  log "done"
  exit 0
fi

if [ "$migrate_only" -eq 0 ]; then
  log "step 1/4: applying bootstrap/ with a local state"
  BOOTSTRAP_BACKEND=local tg apply "${auto_approve[@]}"

  log "step 2/4: writing credentials to .env"
  write_credentials local
  load_env
fi

require AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

log "step 3/4: migrating the state into the bucket"
# The S3 policy and credentials can take a moment to become effective.
attempts=12
for ((i = 1; i <= attempts; i++)); do
  if BOOTSTRAP_BACKEND=s3 tg init -migrate-state -force-copy -input=false; then
    break
  fi
  if [ "$i" -eq "$attempts" ]; then
    log "migration failed after $attempts attempts; fix the error and rerun with --migrate-only"
    exit 1
  fi
  log "migration failed (attempt $i/$attempts), retrying in 10s"
  sleep 10
done

log "step 4/4: checking the remote state, then removing the local one"
bucket="$(BOOTSTRAP_BACKEND=s3 tg output -raw bucket_name)"
if [ -z "$bucket" ]; then
  log "cannot read the bootstrap outputs from the bucket; keeping the local state"
  exit 1
fi
rm -f "$unit/terraform.tfstate" "$unit/terraform.tfstate.backup"

log "done: state of bootstrap/ is in s3://$bucket"
log "run further bootstrap commands with --remote (or BOOTSTRAP_BACKEND=s3)"
