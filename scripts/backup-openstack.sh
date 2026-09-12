#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
INVENTORY="${ANSIBLE_DIR}/inventory/inventory.ini"

if [ -z "${OS_AUTH_URL:-}" ]; then
    echo "ERROR: OpenStack credentials are not loaded."
    echo "Source the OpenStack RC file first."
    exit 1
fi

if [ ! -f "${INVENTORY}" ]; then
    echo "ERROR: Ansible inventory not found: ${INVENTORY}"
    exit 1
fi

BACKUP_DIR="${PROJECT_ROOT}/backups"
mkdir -p "${BACKUP_DIR}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo " TechSprint Moodle backup"
echo "=========================================="

while read -r DEV; do

    [ -z "${DEV}" ] && continue

    USERNAME="${DEV%-moodle-1}"

    ARCHIVE="${USERNAME}-moodle-${TIMESTAMP}.tar.gz"
    REMOTE_WORKDIR="/tmp/techsprint-backup-${USERNAME}-${TIMESTAMP}"
    REMOTE_ARCHIVE="/tmp/${ARCHIVE}"
    LOCAL_FILE="${BACKUP_DIR}/${ARCHIVE}"
    CONTAINER="techsprint-${USERNAME}-moodle-backups"

    echo
    echo "Backing up ${USERNAME}..."

    echo "Creating temporary backup directory..."

    ansible "${DEV}" \
        -i "${INVENTORY}" \
        -b \
        -m ansible.builtin.file \
        -a "path=${REMOTE_WORKDIR} state=directory mode=0700"

    echo "Dumping Moodle database..."

    ansible "${DEV}" \
        -i "${INVENTORY}" \
        -b \
        -m ansible.builtin.shell \
        -a "mysqldump --single-transaction --routines --triggers moodle > ${REMOTE_WORKDIR}/moodle.sql"

    echo "Creating Moodle archive..."

    ansible "${DEV}" \
        -i "${INVENTORY}" \
        -b \
        -m ansible.builtin.shell \
        -a "tar -czf ${REMOTE_ARCHIVE} ${REMOTE_WORKDIR}/moodle.sql /data/moodledata /var/www/html/moodle"

    echo "Downloading archive..."

    ansible "${DEV}" \
        -i "${INVENTORY}" \
        -b \
        -m ansible.builtin.fetch \
        -a "src=${REMOTE_ARCHIVE} dest=${LOCAL_FILE} flat=yes"

    echo "Uploading ${ARCHIVE} to Swift container ${CONTAINER}..."

    openstack object create \
        "${CONTAINER}" \
        "${LOCAL_FILE}" \
        --name "${ARCHIVE}"

    echo "Cleaning temporary files..."

    ansible "${DEV}" \
        -i "${INVENTORY}" \
        -b \
        -m ansible.builtin.file \
        -a "path=${REMOTE_ARCHIVE} state=absent"

    ansible "${DEV}" \
        -i "${INVENTORY}" \
        -b \
        -m ansible.builtin.file \
        -a "path=${REMOTE_WORKDIR} state=absent"

    echo "Backup completed for ${USERNAME}."

done < <(
    awk '
        /^\[moodle_primary\]/ {flag=1; next}
        /^\[/ {flag=0}
        flag && NF {print}
    ' "${INVENTORY}"
)

echo
echo "=========================================="
echo " All Moodle backups completed"
echo "=========================================="