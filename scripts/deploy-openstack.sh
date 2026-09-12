#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OPENSTACK_DIR="${PROJECT_ROOT}/openstack"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

TERRAFORM_OUTPUT_FILE="${OPENSTACK_DIR}/terraform-output.json"
ANSIBLE_INVENTORY="${ANSIBLE_DIR}/inventory/inventory.ini"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <users.csv>"
    exit 1
fi

CSV_PATH="$1"

if [ ! -f "${CSV_PATH}" ]; then
    echo "ERROR: CSV file does not exist: ${CSV_PATH}"
    exit 1
fi

if [ -z "${MOODLE_DB_PASSWORD:-}" ]; then
    echo "ERROR: MOODLE_DB_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${MOODLE_ADMIN_PASSWORD:-}" ]; then
    echo "ERROR: MOODLE_ADMIN_PASSWORD environment variable is not set."
    exit 1
fi

if [ -z "${TF_VAR_admin_source_cidr:-}" ]; then
    echo "ERROR: TF_VAR_admin_source_cidr is not set."
    echo "Set it to your real administrator IP range before deployment:"
    echo 'export TF_VAR_admin_source_cidr="203.0.113.10/32"'
    exit 1
fi

CSV_PATH="$(realpath "${CSV_PATH}")"

echo "=========================================="
echo " TechSprint OpenStack deployment"
echo "=========================================="
echo
echo "Users CSV:"
echo "${CSV_PATH}"
echo

echo "[1/6] Validating OpenStack credentials..."

if [ -z "${OS_AUTH_URL:-}" ]; then
    echo "ERROR: OpenStack credentials are not loaded."
    echo "Run the appropriate OpenStack RC file first."
    echo
    echo "Example:"
    echo "source ~/developer1-finance-rc"
    exit 1
fi

echo "OpenStack credentials detected."
echo

echo "[2/6] Initializing Terraform..."

cd "${OPENSTACK_DIR}"

terraform init

echo
echo "[3/6] Validating Terraform configuration..."

terraform validate

echo
echo "[4/6] Deploying OpenStack infrastructure..."

terraform apply \
    -var="users_csv_path=${CSV_PATH}" \
    -auto-approve

echo
echo "[5/6] Generating Ansible inventory..."

terraform output -json > "${TERRAFORM_OUTPUT_FILE}"

python3 "${SCRIPT_DIR}/generate-ansible-inventory.py" \
    "${TERRAFORM_OUTPUT_FILE}" \
    "${ANSIBLE_INVENTORY}"

echo
echo "Generated inventory:"
echo "------------------------------------------"
cat "${ANSIBLE_INVENTORY}"
echo "------------------------------------------"
echo

echo "[6/6] Configuring Moodle servers..."

cd "${ANSIBLE_DIR}"

ansible-playbook \
    -i "${ANSIBLE_INVENTORY}" \
    playbooks/configure-moodle.yml

echo
echo "Configuring shared file storage..."

ansible-playbook \
    -i "${ANSIBLE_INVENTORY}" \
    playbooks/configure-file-storage.yml

echo
echo "Configuring object storage (Swift auto-mount)..."

ansible-playbook \
    -i "${ANSIBLE_INVENTORY}" \
    --extra-vars "os_auth_url=${OS_AUTH_URL} os_region_name=${OS_REGION_NAME:-regionOne}" \
    playbooks/configure-object-storage.yml

echo
echo "=========================================="
echo " TechSprint deployment completed"
echo "=========================================="