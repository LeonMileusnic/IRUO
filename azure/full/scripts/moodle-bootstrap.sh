#!/bin/bash
set -e

# Adapted for Rocky Linux (dnf/httpd/apache user) after the VM image was changed
# from Ubuntu to Rocky Linux to satisfy the task's OS requirement.

dnf -y install epel-release
dnf -y makecache

dnf -y install \
  httpd \
  mariadb-server \
  php \
  php-cli \
  php-common \
  php-mysqlnd \
  php-gd \
  php-xml \
  php-mbstring \
  php-intl \
  php-json \
  php-opcache \
  php-soap \
  php-zip \
  unzip \
  curl \
  git \
  fuse3 \
  cifs-utils \
  policycoreutils-python-utils

# Install BlobFuse2 (and azfilesauth) from Microsoft's RHEL/Rocky repository
rpm -Uvh --force https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
dnf -y makecache
dnf -y install blobfuse2 azfilesauth

# Configure Azure Files authentication using the VM system-assigned Managed Identity.
# Azure RBAC assignments may need some time to propagate after the VM is created,
# so retry the authentication setup before failing the bootstrap.

AZFILES_MAX_ATTEMPTS=20
AZFILES_RETRY_SECONDS=15
AZFILES_ATTEMPT=1

until azfilesauthmanager set \
  "https://${storage_account_name}.file.core.windows.net" \
  --system
do
  if [ "$AZFILES_ATTEMPT" -ge "$AZFILES_MAX_ATTEMPTS" ]; then
    echo "Azure Files authentication failed after $${AZFILES_MAX_ATTEMPTS} attempts."
    exit 1
  fi

  echo "Azure Files authentication not ready yet. Retrying in $${AZFILES_RETRY_SECONDS} seconds..."

  AZFILES_ATTEMPT=$((AZFILES_ATTEMPT + 1))
  sleep "$AZFILES_RETRY_SECONDS"
done

# Verify that the authentication ticket was created
azfilesauthmanager list

# Allow httpd to read/write mounted CIFS and FUSE (blobfuse2) filesystems under SELinux
setsebool -P httpd_use_cifs on
setsebool -P httpd_use_fusefs on

# Mount Azure Files share using Managed Identity authentication
FILE_MOUNT="/mnt/moodle-shared"

mkdir -p "$FILE_MOUNT"

CREDENTIAL_ID=$(grep "credential-id:" /etc/azfilesauth/config.yaml | awk '{print $2}')

mount -t cifs \
  "//${storage_account_name}.file.core.windows.net/${file_share_name}" \
  "$FILE_MOUNT" \
  -o "sec=krb5,cruid=$CREDENTIAL_ID,dir_mode=0755,file_mode=0755,serverino,nosharesock,mfsymlinks,actimeo=30"

# Enable automatic refresh of Managed Identity credentials
systemctl enable --now azfilesrefresh

# Configure and mount Azure Blob Storage using Managed Identity.
# RBAC assignments can also take some time to propagate,
# so retry the BlobFuse2 mount before failing the bootstrap.

BLOB_MOUNT="/mnt/moodle-backups"
BLOB_CONFIG="/etc/blobfuse2-moodle.yaml"

mkdir -p "$BLOB_MOUNT"

cat > "$BLOB_CONFIG" <<EOF
allow_other: true

components:
  - libfuse
  - block_cache
  - attr_cache
  - azstorage

block_cache:
  block-size-mb: 16

azstorage:
  type: block
  account-name: ${storage_account_name}
  container: ${blob_container_name}
  endpoint: blob.core.windows.net
  mode: msi
EOF

chmod 600 "$BLOB_CONFIG"

BLOB_MAX_ATTEMPTS=20
BLOB_RETRY_SECONDS=15
BLOB_ATTEMPT=1

until blobfuse2 mount "$BLOB_MOUNT" \
  --config-file="$BLOB_CONFIG"
do
  if [ "$BLOB_ATTEMPT" -ge "$BLOB_MAX_ATTEMPTS" ]; then
    echo "BlobFuse2 mount failed after $${BLOB_MAX_ATTEMPTS} attempts."
    exit 1
  fi

  echo "Blob Storage access not ready yet. Retrying in $${BLOB_RETRY_SECONDS} seconds..."

  BLOB_ATTEMPT=$((BLOB_ATTEMPT + 1))
  sleep "$BLOB_RETRY_SECONDS"
done

systemctl enable httpd
systemctl enable mariadb

systemctl start httpd
systemctl start mariadb

# Rocky cloud images ship firewalld enabled with only SSH open by default;
# the Ubuntu image this replaced did not have this restriction.
if systemctl is-active --quiet firewalld || systemctl list-unit-files firewalld.service >/dev/null 2>&1; then
  systemctl enable --now firewalld
  firewall-cmd --permanent --add-service=http
  firewall-cmd --reload
fi

# Prepare and mount the additional managed data disk
DATA_DISK="/dev/disk/azure/scsi1/lun0"
DATA_MOUNT="/mnt/moodledata"

mkdir -p "$DATA_MOUNT"

if [ -b "$DATA_DISK" ]; then
  if ! blkid "$DATA_DISK" >/dev/null 2>&1; then
    mkfs.ext4 "$DATA_DISK"
  fi

  if ! grep -q "$DATA_DISK" /etc/fstab; then
    echo "$DATA_DISK $DATA_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
  fi

  mount -a
fi

# Prepare Moodle database
mysql -e "CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'moodle'@'localhost' IDENTIFIED BY '${moodle_db_password}';"
mysql -e "GRANT ALL PRIVILEGES ON moodle.* TO 'moodle'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

rm -f /var/www/html/index.html

# Download Moodle
if [ ! -d /var/www/html/moodle ]; then
  git clone --depth 1 -b MOODLE_405_STABLE \
    https://github.com/moodle/moodle.git \
    /var/www/html/moodle
fi

# Prepare Moodle data directory on the managed disk
mkdir -p /mnt/moodledata/moodledata

if [ ! -L /var/moodledata ]; then
  rm -rf /var/moodledata
  ln -s /mnt/moodledata/moodledata /var/moodledata
fi

chown -R apache:apache /var/www/html/moodle
chown -R apache:apache /mnt/moodledata/moodledata

chmod -R 755 /var/www/html/moodle
chmod -R 770 /mnt/moodledata/moodledata

semanage fcontext -a -t httpd_sys_rw_content_t "/mnt/moodledata(/.*)?" 2>/dev/null || true
semanage fcontext -a -t httpd_sys_rw_content_t "/var/moodledata(/.*)?" 2>/dev/null || true
restorecon -R /mnt/moodledata /var/moodledata 2>/dev/null || true

# Complete Moodle installation if it has not been installed yet
if [ ! -f /var/www/html/moodle/config.php ]; then
  sudo -u apache php /var/www/html/moodle/admin/cli/install.php \
    --non-interactive \
    --agree-license \
    --wwwroot="${moodle_url}" \
    --dataroot="/var/moodledata" \
    --dbtype="mariadb" \
    --dbhost="localhost" \
    --dbname="moodle" \
    --dbuser="moodle" \
    --dbpass="${moodle_db_password}" \
    --fullname="TechSprint Moodle" \
    --shortname="TechSprint" \
    --adminuser="admin" \
    --adminpass="${moodle_db_password}" \
    --adminemail="admin@example.com"
fi

# Configure Apache for Moodle
cat > /etc/httpd/conf.d/moodle.conf <<'APACHE'
<VirtualHost *:80>
    DocumentRoot /var/www/html/moodle

    <Directory /var/www/html/moodle>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog logs/moodle-error.log
    CustomLog logs/moodle-access.log combined
</VirtualHost>
APACHE

systemctl restart httpd

# Create simple health-check endpoint for Azure Load Balancer
cat > /var/www/html/moodle/moodle-health.html <<'HTML'
<!DOCTYPE html>
<html>
<head>
  <title>TechSprint Moodle</title>
</head>
<body>
  <h1>TechSprint Moodle node is running</h1>
</body>
</html>
HTML

chown apache:apache /var/www/html/moodle/moodle-health.html
