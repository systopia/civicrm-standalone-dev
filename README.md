# civicrm-standalone-dev

Local Docker setup: Nginx + PHP 8.1-FPM, MariaDB 11.4.

```bash
docker compose up -d --build
docker compose exec -u www-data app php /var/www/html/docker/install.php
```

The installer ([docker/install.php](docker/install.php)) runs `Civi\Setup`
(`init` → `installFiles` → `installDatabase`) with DB credentials from
[docker-compose.yml](docker-compose.yml) — same flow as the web installer,
just scripted.

App: **https://civicrm.systopia.local** (via Traefik, `proxy` network).

## Admin login

| | |
|---|---|
| URL      | https://civicrm.systopia.local/civicrm/login |
| User     | `admin` |
| Password | `admin` |

## Extensions

- [core/ext/](core/ext/) — bundled with the tarball, overwritten on update. **Don't touch.**
- [ext/](ext/) — own and third-party extensions. Survives updates.

The `civicrm_extensions` volume in [docker-compose.yml](docker-compose.yml)
bind-mounts `~/projects/systopia/civicrm-extensions` — adjust the `device:`
path if your checkout lives elsewhere.

## Dev helpers — `./civi`

Wrapper around the `app-test` container. Extra args are passed through to
composer, e.g. `./civi phpunit de.systopia.eventmessages -- --filter SomeTest`.

### PHPUnit

```bash
./civi phpunit de.systopia.eventmessages
```

### PHPStan

```bash
./civi phpstan de.systopia.eventmessages
```

### PHPCS

```bash
./civi phpcs de.systopia.eventmessages
```
