#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Installs the goabonga.vps collection in ./collections, where ansible.cfg
# looks for collections:
#   - `local` (default): the collection of the working tree;
#   - `<env>`: the release pinned in inventories/<env>/requirements.yml. The
#     repository is private: with GH_TOKEN set, git authenticates with it for
#     this command only (nothing is written to any git config).
#
# Usage: scripts/install-collection.sh [local|<env>]

set -euo pipefail

target=${1:-local}

if [ "$target" = "local" ]; then
  uv run --no-sync ansible-galaxy collection install . --force -p collections
  exit 0
fi

requirements="inventories/${target}/requirements.yml"
if [ ! -f "$requirements" ]; then
  echo "${requirements} does not exist" >&2
  exit 1
fi

if [ -n "${GH_TOKEN:-}" ]; then
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0="url.https://x-access-token:${GH_TOKEN}@github.com/.insteadOf"
  export GIT_CONFIG_VALUE_0="https://github.com/"
fi

uv run --no-sync ansible-galaxy collection install -r "$requirements" --force -p collections
