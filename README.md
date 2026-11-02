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
