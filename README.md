# vps

Ansible automation for OVH infrastructure.

## Prerequisites

### VPS installation

When installing (or reinstalling) the VPS from the OVH control panel,
select the **Ubuntu 26.04** image.

### SSH key for the `ubuntu` user

The image creates a default `ubuntu` user. Ansible connects with it
using an SSH key, which OVH injects at install time.

1. Generate a dedicated key pair on your workstation:

   ```sh
   ssh-keygen -t ed25519 -C "ovh-vps" -f ~/.ssh/ovh_vps
   ```

2. Register the public key (`~/.ssh/ovh_vps.pub`) in the OVH control
   panel, in the SSH keys section of your account.
3. Install or reinstall the VPS with Ubuntu 26.04 and select that key
   in the installation form.
4. Check the connection:

   ```sh
   ssh -i ~/.ssh/ovh_vps ubuntu@<vps-ip>
   ```

If the VPS was installed without a key, either reinstall it with one, or
copy the key using the password OVH sent by email:

```sh
ssh-copy-id -i ~/.ssh/ovh_vps.pub ubuntu@<vps-ip>
```

## Roles

The `goabonga.vps` collection ships the roles, which the `goabonga.vps.site`
playbook applies to every host.

| Role | Description | Variables |
| --- | --- | --- |
| `version` | echoes the version being deployed on the host | `deployment_version`, set by the environment or passed with `-e` |

## Usage

The repository follows the standard Ansible layout:

```
ansible.cfg
inventories/<env>/hosts.yml           # hosts of the environment
inventories/<env>/group_vars/all/     # variables (main.yml, ansible.yml)
inventories/<env>/requirements.yml    # collection release pinned for the environment
inventories/<env>/CHANGELOG.md        # what each deployment shipped
playbooks/site.yml                    # entry point
roles/                                # reusable roles (version for now)
```

The `production` inventory targets the VPS as the `ubuntu` user and reads
its connection settings from environment variables:

| Variable | Description | Default |
| --- | --- | --- |
| `VPS_HOST` | IP address or hostname of the VPS | required |
| `VPS_SSH_KEY` | path to the SSH private key | `~/.ssh/ovh_vps` |

Roles are used through the collection (`goabonga.vps.version`). Install the
one of the working tree in `./collections`, then check that the VPS is
reachable (the `version` role echoes the version being deployed on the host):

```sh
scripts/install-collection.sh local
export VPS_HOST=<vps-ip>
uv run ansible-playbook -i inventories/production goabonga.vps.site
```

## Development environment

`inventories/development` targets a VM on local KVM, created from the same
Ubuntu 26.04 cloud image as the VPS, with the same `ubuntu` user. It needs
libvirt (system connection, your user in the `libvirt` group), a `default`
network, a storage pool named `images`, `qemu-img` and `xorriso`.

```sh
scripts/dev-vm.sh up        # create (first time), start, wait for SSH
scripts/install-collection.sh local
uv run ansible-playbook -i inventories/development goabonga.vps.site
scripts/dev-vm.sh ssh       # shell on the VM
scripts/dev-vm.sh down      # shut it down (destroy deletes it)
```

The VM always answers at `192.168.122.61` (a DHCP reservation on the
`default` network), so no variable is needed. The SSH key pair and the
downloaded image are generated once in `.dev/` (not committed) and reused
when the VM is recreated. This environment uses the collection of the working
tree, not a pinned release, to try roles before they are released, so it has
no `requirements.yml`. The collection installed in `./collections` is shared
with the pinned installs (`scripts/install-collection.sh <env>`): the last one
installed wins.

## Releases and deployment

Components are versioned by [multicz](https://goabonga.github.io/multicz/)
from Conventional Commits (see `multicz.toml`):

- `collection` (roles, playbooks, plugins, `galaxy.yml`) is released on
  every push to `main`, tagged `collection-v<version>`;
- `ansible-<env>` tracks what is applied on an environment
  (`inventories/<env>/`) and is bumped only after a successful apply. Its
  version is the `deployment_version` variable of
  `inventories/<env>/group_vars/all/ansible.yml`: the pipelines compute the
  next one (`scripts/next-ansible-version.sh`) and pass it to the playbooks
  with `-e deployment_version=...`, so roles and templates can use it while
  deploying; multicz records the same value after a successful apply, with
  the changelog of what was shipped in `inventories/<env>/CHANGELOG.md`
  (cleaned by `scripts/format-changelog.sh`, a multicz `post_bump` hook).

A deployment never runs the working tree. Each environment pins a release of
the collection in `inventories/<env>/requirements.yml` (a git tag such as
`collection-v0.2.0`), and the plan and the apply install it
(`scripts/install-collection.sh <env>`) and run its playbook
`goabonga.vps.site`. Each release of the collection rewrites the pinned tag
(a multicz mirror), so the next plan sees a pending deployment; remove the
mirror of an environment to pin it by hand, for instance to let staging
follow the releases while production waits. Only one version of the
collection can be used in a run.

Deployment follows a plan, pull request, apply flow:

1. once **ci** and **release** succeeded on `main`, `goabonga.vps.site` is
   run in check mode (**ansible-plan** workflow, `ansible-<env>-plan` GitHub
   environment), so the dry run never runs alongside ci and always sees
   the released `main`;
2. if the dry run reports changes, or if `main` differs from
   `ansible/<env>` on the deployed paths, a tracking issue and a pull
   request from `plan/ansible-<env>` (the last non-release commit of `main`) into
   `ansible/<env>` are opened (both assigned to
   the `DEPLOY_ASSIGNEE` user). The issue only lists what is pending (check
   mode and commits not deployed yet); the pull request starts with a
   reference to the issue, repeats it, adds the version to deploy, lists the
   changed files and shows the diff and the full check output (the complete output is also a workflow
   artifact);
3. merging that pull request is the go signal: the **ansible-apply**
   workflow (`ansible-<env>-apply` GitHub environment) realigns `ansible/<env>` on `main`,
   computes the version, runs the playbook for real, bumps `ansible-<env>`
   with a signed release commit, fast-forwards `main` onto it (so the
   release commit and tag come back onto `main`), moves `ansible/<env>` to
   the same commit, publishes the GitHub release `ansible-<env>-v<version>`
   (its notes list what the deployment shipped) and closes the issue.

Use any merge method for the deploy pull request. GitHub recreates the
commits of a *rebase and merge* (unsigned, with new hashes), but the apply
throws them away: `ansible/<env>` is always rebuilt from `main`, so both
branches only hold the original signed commits, no duplicate, plus one
signed release commit per deployment. Nothing needs re-signing.

### One-time setup

- Secret `GH_PAT` (repository): a personal access token with write access
  to contents, pull requests, issues and workflows.
- Variable `DEPLOY_ASSIGNEE` (repository): the GitHub user the deploy pull
  requests and issues are assigned to (defaults to the owner of `GH_PAT`):
  `gh variable set DEPLOY_ASSIGNEE --body goabonga`.
- Variable `DEPLOY_REVIEWER` (repository): the GitHub user asked to review
  the deploy pull requests (defaults to the assignee). GitHub refuses a
  review request addressed to the pull request's author, so this only works
  when the pull requests are not opened by that same user.
- Secrets `VPS_HOST`, `VPS_SSH_KEY` and `VPS_KNOWN_HOSTS` in both the
  `ansible-production-apply` and `ansible-production-plan` environments. `VPS_KNOWN_HOSTS` is the
  `known_hosts` line of the VPS (`ssh-keyscan -t ed25519 <vps-ip>`), whose
  fingerprint must be checked against the one shown on the VPS
  (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`). The pipelines refuse
  any other host key, so update it after reinstalling the VPS.
- Optional secrets `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` to sign release
  commits and tags. The committer then takes the identity of the key (its
  e-mail must be one of its uids and the public key added to your GitHub
  account for the commits to show as verified).
- Create the deployment branch once at the root commit, so the first
  deployment shows up as a pending pull request:
  `git push origin "$(git rev-list --max-parents=0 main)":refs/heads/ansible/production`,
  and protect it so only the owner can trigger an apply.
- Environment `ansible-production-apply` is restricted to the `ansible/*` branches and
  `ansible-production-plan` to `main`. On a plan that supports it, also add the
  owner as *Required reviewer* of `ansible-production-apply`.

Add an environment by creating `inventories/<env>/` with a
`requirements.yml` pinning the collection (see `multicz.toml`). The pipelines
only deploy the inventories that have this file.

## Branch protection and signed commits

Only signed commits should reach `main`. The rulesets in
`.github/rulesets/` protect `main` (pull request, the `lint`, `syntax`, `collection`,
`workflows`, `audit`, `multicz` and `signatures` checks, signed commits, no
force push or deletion) and the
`ansible/*` branches (pull request, signed commits, no force push or
deletion). Repository admins bypass them, so the pipelines can push
releases with the personal access token.

Apply them (idempotent) with `gh`; this needs a plan that supports rulesets
on private repositories, or a public repository:

```sh
scripts/apply-rulesets.sh
```

The `signatures` check fails on a pull request containing a commit that
GitHub does not show as verified. Add the `resign` label to the pull
request (owner only) to run the **resign** workflow: it rebases the branch
on `main`, re-signs every commit with the GPG key and pushes the result
back, so the commits that get merged are signed. It needs the `GH_PAT`,
`GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` secrets.

GitHub's *Rebase and merge* recreates the commits of a pull request and does
not sign them. When commits without any signature land on `main`, the
**resign-main** workflow replays them on the previous head, re-signs them
with the GPG key and moves `main` with an explicit lease (the hashes change,
so pull again). The rewritten head starts a new ci, release and plan chain,
and the release workflow waits for it: its gate refuses unsigned commits.
Only commits with no signature at all are rewritten, so the rewrite does
not loop.
