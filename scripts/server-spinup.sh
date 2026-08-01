#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

HOST=$1 # e.g. vps-1
TARGET=$2 # e.g. root@example.com
SSH_ED25519_HOSTKEY_PATH=$3 # e.g. ./tmpdir/host_key
# ssh-keygen -q -N "" -t ed25519 -f host_key
# nix-shell -p ssh-to-age --run 'cat host_key.pub | ssh-to-age'

TMPDIR=$(mktemp -d)

cleanup() {
    rm -rf "${TMPDIR}"
}
trap cleanup EXIT

install -d -m755 "${TMPDIR}/etc/ssh"
cp "${SSH_ED25519_HOSTKEY_PATH}" "${TMPDIR}/etc/ssh/ssh_host_ed25519_key"
chmod 600 "${TMPDIR}/etc/ssh/ssh_host_ed25519_key"

nix run github:nix-community/nixos-anywhere \
    -- \
    --flake "${SCRIPT_DIR}/..#${HOST}" \
    --generate-hardware-config nixos-generate-config "./hosts/${HOST}/hardware-configuration.nix" \
    --target-host "${TARGET}" \
    --extra-files "${TMPDIR}"

# --disk-encryption-keys <remote_path> <local_path>
#  copy the contents of the file or pipe in local_path to remote_path in the installer environment,
#  after kexec but before installation. Can be repeated.
