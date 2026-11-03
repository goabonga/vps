#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Prints the version the next deployment of an environment will get: the
# bump multicz plans for the ansible-<env> component, or a patch bump of its
# current version when none is pending (an apply is always recorded). The
# pipelines pass it to Ansible as `-e deployment_version=...` before the apply;
# multicz writes the same value back after a successful apply.
#
# Usage: scripts/next-ansible-version.sh <env>

set -euo pipefail

env=${1:?environment}
component="ansible-${env}"

next=$(uv tool run multicz plan --output json \
  | jq -r --arg c "$component" 'select(.bumps != null) | .bumps[$c].next_version // empty')

if [ -z "$next" ]; then
  current=$(uv tool run multicz get "$component")
  IFS=. read -r major minor patch <<<"${current%%[-+]*}"
  next="${major}.${minor}.$((patch + 1))"
fi

echo "$next"
