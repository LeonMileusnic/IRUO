#!/bin/bash
set -e

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path-to-users.csv>"
  exit 1
fi

CSV_PATH=$(realpath "$1")
TERRAFORM_DIR="$(cd "$(dirname "$0")/../azure/full" && pwd)"

if [ ! -f "$CSV_PATH" ]; then
  echo "ERROR: CSV file does not exist: $CSV_PATH"
  exit 1
fi

if [ -z "${TF_VAR_moodle_db_password:-}" ]; then
  echo "ERROR: TF_VAR_moodle_db_password is not set."
  echo "Set it before deployment:"
  echo 'export TF_VAR_moodle_db_password="your-password"'
  exit 1
fi

if [ -z "${TF_VAR_admin_source_cidr:-}" ]; then
  echo "ERROR: TF_VAR_admin_source_cidr is not set."
  echo "Set it to your real administrator IP range before deployment:"
  echo 'export TF_VAR_admin_source_cidr="203.0.113.10/32"'
  exit 1
fi

if [ -z "${TF_VAR_entra_domain:-}" ]; then
  echo "NOTE: TF_VAR_entra_domain is not set."
  echo "Developer/lead RBAC role assignments will be skipped unless"
  echo "developer_principal_ids/lead_principal_id are set explicitly."
  echo 'export TF_VAR_entra_domain="techsprint.onmicrosoft.com"'
fi

echo "======================================"
echo " TechSprint Azure deployment"
echo "======================================"
echo "Users CSV: $CSV_PATH"
echo "Terraform: $TERRAFORM_DIR"
echo

terraform -chdir="$TERRAFORM_DIR" init
terraform -chdir="$TERRAFORM_DIR" validate

terraform -chdir="$TERRAFORM_DIR" apply \
  -var="users_csv_path=$CSV_PATH"
