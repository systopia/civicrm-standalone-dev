#!/bin/bash
set -euo pipefail

CIVICRM_TEST_DIR=/opt/civicrm-test
DB_HOST=${DB_HOST:-db}
DB_NAME=${DB_NAME:-civicrm_test}
DB_USER=${DB_USER:-civicrm}
DB_PASS=${DB_PASS:-civicrm}
CIVICRM_VERSION=${CIVICRM_VERSION:-6.13.1}
# Dummy URL — only used by Civi\Setup to satisfy required field; the test
# container has no web server, the value is never resolved at runtime.
CIVICRM_BASE_URL=${CIVICRM_BASE_URL:-http://localhost/}

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
  [ -f "$CIVICRM_TEST_DIR/civicrm.standalone.php" ] && [ -d "$CIVICRM_TEST_DIR/core" ]
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

fetch_standalone() {
  log "Downloading civicrm $CIVICRM_VERSION standalone tarball"
  rm -rf /tmp/civicrm-install
  mkdir -p /tmp/civicrm-install
  curl -sSL "https://download.civicrm.org/civicrm-${CIVICRM_VERSION}-standalone.tar.gz" \
    | tar -xz -C /tmp/civicrm-install --strip-components=1

  # Move everything except ext/ into the doc root — the ext bind mount must
  # not be overwritten by tarball defaults.
  find /tmp/civicrm-install -mindepth 1 -maxdepth 1 -not -name ext \
    -exec mv {} "$CIVICRM_TEST_DIR/" \;
  rm -rf /tmp/civicrm-install
  mkdir -p "$CIVICRM_TEST_DIR/ext"
}

fetch_test_fixtures() {
  log "Fetching test-only SQL fixtures from civicrm-core $CIVICRM_VERSION"
  local base="https://raw.githubusercontent.com/civicrm/civicrm-core/${CIVICRM_VERSION}/sql"
  for f in test_data.mysql test_data_second_domain.mysql; do
    curl -sSLo "$CIVICRM_TEST_DIR/core/sql/$f" "$base/$f"
  done
}

install_civicrm() {
  fetch_standalone
  fetch_test_fixtures
  reset_db

  log "Running Civi\\Setup against $DB_HOST/$DB_NAME"
  php /usr/local/bin/civicrm-install.php \
    "$CIVICRM_TEST_DIR" "$DB_HOST" "$DB_USER" "$DB_PASS" "$DB_NAME" "$CIVICRM_BASE_URL"

  mkdir -p "$CIVICRM_TEST_DIR/private/tmp" "$CIVICRM_TEST_DIR/private/cache" "$CIVICRM_TEST_DIR/private/log"
}

ensure_test_db_dsn() {
  cd "$CIVICRM_TEST_DIR"
  [ -f /root/.cv.json ] || cv vars:fill >/dev/null 2>&1 || true
  sed -i "s|mysql://dbUser:dbPass@dbHost/dbName|mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:3306/${DB_NAME}|" /root/.cv.json 2>/dev/null || true
}

wait_for_db
is_installed || install_civicrm
ensure_test_db_dsn

log "app-test ready — attach with 'docker compose exec app-test bash'"
exec sleep infinity
