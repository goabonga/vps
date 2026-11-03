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
