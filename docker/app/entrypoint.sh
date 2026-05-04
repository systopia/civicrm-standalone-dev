#!/bin/bash
set -euo pipefail

APP_ROOT=/var/www/html
DB_HOST=${CIVICRM_DB_HOST:-db}
DB_NAME=${CIVICRM_DB_NAME:-civicrm}
DB_USER=${CIVICRM_DB_USER:-civicrm}
DB_PASS=${CIVICRM_DB_PASSWORD:-civicrm}
CIVICRM_VERSION=${CIVICRM_VERSION:-6.13.1}
CIVICRM_BASE_URL=${CIVICRM_BASE_URL:-http://localhost:8080/}

log() { printf '==> %s\n' "$*"; }

wait_for_db() {
  for _ in $(seq 1 60); do
    if php -r "exit(@mysqli_connect('$DB_HOST', '$DB_USER', '$DB_PASS', '$DB_NAME') ? 0 : 1);" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "DB $DB_HOST not reachable" >&2
  exit 1
}

is_installed() {
  [ -f "$APP_ROOT/civicrm.standalone.php" ] && [ -d "$APP_ROOT/core" ]
}

fetch_standalone() {
  log "Downloading civicrm $CIVICRM_VERSION standalone tarball"
  rm -rf /tmp/civicrm-install
  mkdir -p /tmp/civicrm-install
  curl -sSL "https://download.civicrm.org/civicrm-${CIVICRM_VERSION}-standalone.tar.gz" \
    | tar -xz -C /tmp/civicrm-install --strip-components=1

  # Move everything except ext/ into the doc root — the ext bind mount must
  # not be overwritten by tarball defaults.
  find /tmp/civicrm-install -mindepth 1 -maxdepth 1 -not -name ext \
    -exec mv {} "$APP_ROOT/" \;
  rm -rf /tmp/civicrm-install
  mkdir -p "$APP_ROOT/ext"
}

reset_db() {
  log "Resetting DB $DB_NAME on $DB_HOST"
  php <<PHPEOF
<?php
\$pdo = new PDO("mysql:host=$DB_HOST", "$DB_USER", "$DB_PASS");
\$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
\$pdo->exec("DROP DATABASE IF EXISTS \`$DB_NAME\`");
\$pdo->exec("CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4");
PHPEOF
}

install_civicrm() {
  fetch_standalone
  reset_db

  log "Running Civi\\Setup against $DB_HOST/$DB_NAME"
  php /usr/local/bin/civicrm-install.php \
    "$APP_ROOT" "$DB_HOST" "$DB_USER" "$DB_PASS" "$DB_NAME" "$CIVICRM_BASE_URL"

  # private/ subdirs that CiviCRM writes to at runtime — pre-create so the
  # subsequent chown -R covers them, otherwise lazy-mkdir as www-data hits a
  # parent that's still owned by root from the install.
  mkdir -p "$APP_ROOT/private/tmp" "$APP_ROOT/private/cache" "$APP_ROOT/private/log"

  # private/ and public/ must be owned by www-data, otherwise php-fpm cannot
  # write to private/cache and uploads have nowhere to land.
  chown -R www-data:www-data "$APP_ROOT/private" "$APP_ROOT/public"

  # Dev convenience: pin the admin password to 'admin'. Civi\Setup generates
  # a random one — fine for prod, painful in a dev loop.
  log "Pinning admin password to 'admin' (dev mode)"
  ( cd "$APP_ROOT" && cv api4 User.update +w 'id=1' +v 'password=admin' >/dev/null )
}

ensure_base_url() {
  local f="$APP_ROOT/private/civicrm.settings.php"
  [ -f "$f" ] || return 0
  local before after base
  before=$(md5sum "$f" | cut -d' ' -f1)
  base="${CIVICRM_BASE_URL%/}"
  # Replace scheme://host[:port] prefix in every $civicrm_paths[...]['url']
  # entry — covers cms.root, civicrm.files, civicrm.root, civicrm.vendor,
  # civicrm.bower, civicrm.packages and any future siblings. The path part
  # (e.g. /public, /core/vendor) is preserved.
  sed -i -E "s|(\\\$civicrm_paths\\[[^]]+\\]\\['url'\\]\\s*=\\s*')https?://[^/']+|\\1$base|g" "$f"
  sed -i -E "s|(define\\('CIVICRM_UF_BASEURL',\\s*)'[^']*'|\\1'$CIVICRM_BASE_URL'|" "$f"
  after=$(md5sum "$f" | cut -d' ' -f1)
  if [ "$before" != "$after" ]; then
    log "Base URL changed — flushing CiviCRM caches"
    rm -f "$APP_ROOT/public/persist/"crm-* 2>/dev/null || true
    ( cd "$APP_ROOT" && cv flush ) 2>/dev/null || log "cv flush failed (non-fatal)"
  fi
}

start_web() {
  mkdir -p /run/php
  exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
}

wait_for_db
is_installed || install_civicrm
ensure_base_url
log "civicrm app ready at $CIVICRM_BASE_URL"
start_web
