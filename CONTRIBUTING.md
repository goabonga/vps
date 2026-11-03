# Contributing to vps

Thanks for taking the time to contribute. This is the short version of how to
propose a change.

## Development setup

```sh
git clone git@github.com:goabonga/vps.git
cd vps
uv sync
```

## Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
and are limited to a subject: no body, no footer, no `Co-Authored-By`
trailer. A scope is a module listed in "Commit scopes" below; `feat`, `fix` and
`docs` commits carry one. Keep each commit to one logical change that can be
reverted on its own.

## Commit scopes

A scope is a module, in kebab-case. Only these exist, and `feat`, `fix` and
`docs` commits carry one; `chore`, `ci` and the others usually omit it.

### General

- `project`: the project files themselves (`README.md`, `CONTRIBUTING.md`,
  `SECURITY.md`): creating them or changing how they are organized.
  Documenting a module carries the scope of that module.
- `collection`: what else the `goabonga.vps` collection ships
  (`playbooks/`, `galaxy.yml`, `meta/`, `plugins/`).

### Environments

- `inventory`: `ansible.cfg` and what every environment shares.
- `production`: `inventories/production/` (hosts, variables, the
  collection it pins).

- `development`: `inventories/development/` and the script creating its
  local VM.

### Roles

- `version`: the `version` role (`roles/version/` and its line in
  `playbooks/site.yml`).

## Reporting bugs and asking for features

Please open a GitHub issue. For anything security-sensitive, follow
[SECURITY.md](SECURITY.md) instead of the public tracker.
