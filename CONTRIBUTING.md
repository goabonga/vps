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
trailer. A scope is a module listed in "Commit scopes" below; `feat`, `fix`, `docs` and
`ci` commits carry one. Keep each commit to one logical change that can be
reverted on its own.

## Commit scopes

A scope is a module, in kebab-case. Only these exist, and `feat`, `fix`, `docs` and
`ci` commits carry one; `chore` and the others usually omit it.

### General

- `project`: the project files themselves (`README.md`, `CONTRIBUTING.md`,
  `SECURITY.md`): creating them or changing how they are organized.
  Documenting a module carries the scope of that module.
- `collection`: what else the `goabonga.vps` collection ships
  (`playbooks/`, `galaxy.yml`, `meta/`, `plugins/`).
- `release`: versioning and releases (`multicz.toml`, the release
  workflow, the changelogs).
- `signatures`: signed commits and their checks (the `signatures`,
  `resign` and `resign-main` workflows).

### Environments

- `inventory`: `ansible.cfg` and what every environment shares.
- `production`: `inventories/production/` (hosts, variables, the
  collection it pins).
- `development`: `inventories/development/` and the script creating its
  local VM.

### Roles

- `version`: the `version` role (`roles/version/` and its line in
  `playbooks/site.yml`).

## Checking a change

Run the checks on the working tree, then try the change on the development VM
(see "Development environment" in the [README](README.md)) before proposing it:

```sh
uv run ansible-lint
scripts/install-collection.sh local
uv run ansible-playbook -i inventories/development --syntax-check goabonga.vps.site
uv tool run multicz validate --strict
scripts/dev-vm.sh up
uv run ansible-playbook -i inventories/development goabonga.vps.site
```

## Releases and deployments

Versions, tags, changelogs and releases are produced by the pipelines with
[multicz](https://goabonga.github.io/multicz/) from the commit messages: do
not bump a version or edit a changelog by hand. See "Releases and
deployment" in the [README](README.md).

## Pull requests

Every commit that reaches `main` must be signed. If a pull request fails the
`signatures` check, ask the owner to add the `resign` label: the pipeline
re-signs the commits. See "Branch protection and signed
commits" in the [README](README.md).

## Reporting bugs and asking for features

Please open a GitHub issue. For anything security-sensitive, follow
[SECURITY.md](SECURITY.md) instead of the public tracker.
