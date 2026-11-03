#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Cleans the changelogs written by multicz: the upstream-notes plugin prefixes
# the commit subjects of an upstream component with a bullet that the
# changelog already renders, which gave "- - feat: ...". Idempotent.
#
# Usage: scripts/format-changelog.sh <changelog.md>...

set -euo pipefail

for file in "$@"; do
  sed -i 's/^\(\s*\)- - /\1- /' "$file"
done
