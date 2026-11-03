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
- `ansible`: the plan and apply workflows of the Ansible deployment and what they need to run.
- `terragrunt`: the plan and apply workflows of the Terragrunt deployment and
  what they need to run.
- `github`: the GitHub repository settings and the ci workflow
  (`.github/rulesets/`, branch protection, `ci.yml`, `scripts/summary.sh`).

### Environments

- `inventory`: `ansible.cfg` and what every environment shares.
- `production`: `inventories/production/` (hosts, variables, the
  collection it pins) and `infra/configs/production/` (the settings of its
  infrastructure).
- `development`: `inventories/development/` and the script creating its
  local VM.

### Infrastructure

- `infra`: the `infra/` directory: the Terragrunt wiring (`infra/ovh/`), the
  Terraform modules (`infra/modules/`) and the tooling around them. The settings
  of an environment (`infra/configs/<env>/`) carry the scope of that
  environment.
- `vps`: the `vps` Terraform module (`infra/modules/vps/`, its tests and its
  documentation).
- `bootstrap`: the state storage created before everything else
  (`infra/bootstrap/`, `infra/modules/bootstrap/` and its script).

### Roles

- `version`: the `version` role (`roles/version/` and its line in
  `playbooks/site.yml`).
- `sysctl`: the `sysctl` role (`roles/sysctl/` and its line in
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

## Adding a role

A role is its own scope, named after it (`feat(version): ...`). Each step is a
commit of its own, in this order:

1. `feat(<role>): add role <what it does>`: `roles/<role>/` only, with a
   default in `defaults/main.yml` for every variable the role owns. The
   commit also adds the scope to the "Roles" list of "Commit scopes".
2. `feat(<role>): apply role in the site playbook`.
3. `docs(<role>): document the role`, in the README.
4. `feat(development): configure the <role> role`: the values in
   `inventories/development/group_vars/all/<role>.yml`. Try the role on the
   development VM (see "Checking a change") before going further.
5. `feat(production): configure the <role> role`: the same in
   `inventories/production/group_vars/all/<role>.yml`.

An environment file is only added when the defaults of the role do not fit.
Versions, changelogs and the pinned collection are never edited by hand.

## Releases and deployments

Versions, tags, changelogs and releases are produced by the pipelines with
[multicz](https://goabonga.github.io/multicz/) from the commit messages: do
not bump a version or edit a changelog by hand. A change reaches the VPS only
through the deployment pull request the plan workflow opens; see "Releases and
deployment" in the [README](README.md).

## Pull requests

Every commit that reaches `main` must be signed. If a pull request fails the
`signatures` check, ask the owner to add the `resign` label: the pipeline
re-signs the commits. The `lint`, `syntax`, `collection`, `workflows`,
`audit` and `multicz` checks must pass too (see "Branch protection and signed
commits" in the [README](README.md)).

## Reporting bugs and asking for features

Please open a GitHub issue. For anything security-sensitive, follow
[SECURITY.md](SECURITY.md) instead of the public tracker.
