#!/usr/bin/env bash
# provision/dvwa.sh
#
# Installs Damn Vulnerable Web Application (DVWA) on Apache + PHP + MariaDB.
# DVWA is intentionally vulnerable; flags on this box are "derived" (values you
# extract by exploiting it), so nothing is planted from flags.env here.
#
# Reachable at http://192.168.56.21/  (default creds admin / password).
set -uo pipefail
log() { echo "[provision:dvwa] $*"; }
export DEBIAN_FRONTEND=noninteractive

log "installing LAMP stack..."
apt-get update -y >/dev/null 2>&1
apt-get install -y apache2 mariadb-server php php-mysqli php-gd libapache2-mod-php git \
  >/dev/null 2>&1 || { log "ERROR: package install failed"; exit 0; }

# --- fetch DVWA ------------------------------------------------------------
if [ ! -d /var/www/html/DVWA ]; then
  git clone --depth 1 https://github.com/digininja/DVWA.git /var/www/html/DVWA \
    >/dev/null 2>&1 || log "WARNING: DVWA clone failed (needs build-time internet)"
fi

if [ -d /var/www/html/DVWA ]; then
  # config
  cp -n /var/www/html/DVWA/config/config.inc.php.dist \
        /var/www/html/DVWA/config/config.inc.php 2>/dev/null || true
  sed -i "s/'db_password' ] = 'p@ssw0rd'/'db_password' ] = 'dvwa'/" \
        /var/www/html/DVWA/config/config.inc.php 2>/dev/null || true

  # writable dirs DVWA expects
  chown -R www-data:www-data /var/www/html/DVWA
  chmod -R 777 /var/www/html/DVWA/hackable/uploads 2>/dev/null || true
  chmod 777 /var/www/html/DVWA/external/phpids/0.6/lib/IDS/tmp/phpids_log.txt 2>/dev/null || true

  # relax PHP for the classic DVWA experience (intentionally insecure)
  PHPINI=$(ls /etc/php/*/apache2/php.ini 2>/dev/null | head -n1)
  if [ -n "${PHPINI:-}" ]; then
    sed -i 's/^allow_url_include = .*/allow_url_include = On/' "$PHPINI"
    sed -i 's/^allow_url_fopen = .*/allow_url_fopen = On/' "$PHPINI"
    sed -i 's/^;\?display_errors = .*/display_errors = On/' "$PHPINI"
  fi

  # redirect site root to DVWA
  echo '<?php header("Location: /DVWA/"); ?>' > /var/www/html/index.php
  rm -f /var/www/html/index.html 2>/dev/null || true
fi

# --- database --------------------------------------------------------------
systemctl enable --now mariadb >/dev/null 2>&1 || true
mysql <<'SQL' 2>/dev/null || log "WARNING: DB setup failed"
CREATE DATABASE IF NOT EXISTS dvwa;
CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'dvwa';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';
FLUSH PRIVILEGES;
SQL

systemctl enable --now apache2 >/dev/null 2>&1 || true
log "DVWA ready. Visit http://192.168.56.21/ and click 'Create / Reset Database' (admin/password)."
