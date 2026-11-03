#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Creates and drives the VM of the development environment on local KVM
# (libvirt, system connection): the same Ubuntu cloud image as the VPS, at the
# fixed address of inventories/development/hosts.yml.
#
# Everything generated lives in .dev/ (not committed): the SSH key pair used by
# Ansible, created once, and the downloaded image, so neither is recreated
# when the VM is. The disks are volumes of the libvirt storage pool below.
#
# Usage: scripts/dev-vm.sh up|down|destroy|status|ssh [command...]
#   up       create the VM if needed, start it and wait for SSH
#   down     shut the VM down (its disk is kept)
#   destroy  delete the VM and its disks (the key and the image are kept)
#   status   state of the VM
#   ssh      open a shell (or run a command) on the VM

set -euo pipefail

NAME=vps-dev-01
IP=192.168.122.61
MAC=52:54:00:00:00:61
CPUS=2
MEMORY_MIB=2048
DISK_SIZE=20G
NETWORK=default
POOL=images
IMAGE_URL=https://cloud-images.ubuntu.com/releases/resolute/release
IMAGE_FILE=ubuntu-26.04-server-cloudimg-amd64.img

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE="${ROOT}/.dev"
KEY="${STATE}/ssh/id_ed25519"
SYSTEM_VOLUME="${NAME}-system.qcow2"
SEED_VOLUME="${NAME}-seed.iso"

virsh() { command virsh -c qemu:///system "$@"; }

SSH_EXTRA=()

ssh_vm() {
  ssh -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=3 \
    ${SSH_EXTRA[@]+"${SSH_EXTRA[@]}"} "ubuntu@${IP}" "$@"
}

domain_exists() { virsh dominfo "$NAME" > /dev/null 2>&1; }
domain_running() { [ "$(virsh domstate "$NAME" 2> /dev/null)" = "running" ]; }
volume_exists() { virsh vol-info --pool "$POOL" "$1" > /dev/null 2>&1; }

ensure_key() {
  if [ ! -f "$KEY" ]; then
    mkdir -p "${STATE}/ssh"
    chmod 700 "${STATE}/ssh"
    ssh-keygen -q -t ed25519 -N "" -C "${NAME}" -f "$KEY"
    echo "generated ${KEY}"
  fi
}

ensure_image() {
  local image="${STATE}/${IMAGE_FILE}"
  if [ ! -f "$image" ]; then
    mkdir -p "$STATE"
    echo "downloading ${IMAGE_FILE}"
    curl -fL --progress-bar -o "${image}.part" "${IMAGE_URL}/${IMAGE_FILE}"
    local expected actual
    expected=$(curl -fsSL "${IMAGE_URL}/SHA256SUMS" | awk -v f="*${IMAGE_FILE}" '$2 == f { print $1 }')
    actual=$(sha256sum "${image}.part" | awk '{ print $1 }')
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
      rm -f "${image}.part"
      echo "checksum of ${IMAGE_FILE} does not match" >&2
      exit 1
    fi
    mv "${image}.part" "$image"
  fi
}

ensure_network_lease() {
  if ! virsh net-dumpxml "$NETWORK" | grep -q "mac='${MAC}'"; then
    virsh net-update "$NETWORK" add-last ip-dhcp-host \
      "<host mac='${MAC}' name='${NAME}' ip='${IP}'/>" --live --config > /dev/null
    echo "reserved ${IP} on the ${NETWORK} network"
  fi
}

# Uploads a file into a new volume of the pool.
create_volume() {
  local volume=$1 format=$2 capacity=$3 file=$4
  virsh vol-create-as "$POOL" "$volume" "$capacity" --format "$format" > /dev/null
  virsh vol-upload --pool "$POOL" "$volume" "$file" > /dev/null
}

ensure_volumes() {
  if ! volume_exists "$SYSTEM_VOLUME"; then
    create_volume "$SYSTEM_VOLUME" qcow2 "$(stat -c %s "${STATE}/${IMAGE_FILE}")B" "${STATE}/${IMAGE_FILE}"
    virsh vol-resize --pool "$POOL" "$SYSTEM_VOLUME" "$DISK_SIZE" > /dev/null
  fi
  if ! volume_exists "$SEED_VOLUME"; then
    local seed="${STATE}/seed"
    rm -rf "$seed"
    mkdir -p "$seed"
    printf 'instance-id: %s\nlocal-hostname: %s\n' "$NAME" "$NAME" > "${seed}/meta-data"
    printf '#cloud-config\nssh_authorized_keys:\n  - %s\n' "$(cat "${KEY}.pub")" > "${seed}/user-data"
    xorriso -as genisoimage -quiet -output "${seed}.iso" -volid cidata -joliet -rock \
      "${seed}/user-data" "${seed}/meta-data"
    create_volume "$SEED_VOLUME" raw "$(stat -c %s "${seed}.iso")B" "${seed}.iso"
  fi
}

define_domain() {
  virsh define /dev/stdin > /dev/null << XML
<domain type='kvm'>
  <name>${NAME}</name>
  <memory unit='MiB'>${MEMORY_MIB}</memory>
  <vcpu>${CPUS}</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features><acpi/><apic/></features>
  <cpu mode='host-passthrough'/>
  <devices>
    <disk type='volume' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source pool='${POOL}' volume='${SYSTEM_VOLUME}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='volume' device='disk'>
      <driver name='qemu' type='raw'/>
      <source pool='${POOL}' volume='${SEED_VOLUME}'/>
      <target dev='vdc' bus='virtio'/>
      <readonly/>
    </disk>
    <interface type='network'>
      <source network='${NETWORK}'/>
      <mac address='${MAC}'/>
      <model type='virtio'/>
    </interface>
    <serial type='pty'/>
    <console type='pty'/>
  </devices>
</domain>
XML
}

wait_for_ssh() {
  for _ in $(seq 1 60); do
    if ssh_vm true 2> /dev/null; then
      echo "${NAME} is ready: ubuntu@${IP}"
      return 0
    fi
    sleep 3
  done
  echo "${NAME} did not answer on SSH within 3 minutes" >&2
  return 1
}

cmd_up() {
  ensure_key
  ensure_image
  ensure_network_lease
  ensure_volumes
  domain_exists || define_domain
  domain_running || virsh start "$NAME" > /dev/null
  wait_for_ssh
}

cmd_down() {
  if domain_running; then virsh shutdown "$NAME" > /dev/null; fi
}

cmd_destroy() {
  if domain_running; then virsh destroy "$NAME" > /dev/null; fi
  if domain_exists; then virsh undefine "$NAME" > /dev/null; fi
  for volume in "$SYSTEM_VOLUME" "$SEED_VOLUME"; do
    if volume_exists "$volume"; then virsh vol-delete --pool "$POOL" "$volume" > /dev/null; fi
  done
  rm -rf "${STATE}/seed" "${STATE}/seed.iso"
}

cmd_status() {
  if domain_exists; then
    echo "${NAME}: $(virsh domstate "$NAME") (${IP})"
  else
    echo "${NAME}: not created"
  fi
}

case "${1:-}" in
  up) cmd_up ;;
  down) cmd_down ;;
  destroy) cmd_destroy ;;
  status) cmd_status ;;
  ssh) shift; SSH_EXTRA=(-t); ssh_vm "$@" ;;
  *) sed -n '/^# Usage/,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
