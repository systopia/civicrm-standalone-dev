FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_NO_INTERACTION=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https \
        git \
        unzip \
        default-mysql-client \
    && curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php8.4-cli \
        php8.4-mysql \
        php8.4-xml \
        php8.4-mbstring \
        php8.4-curl \
        php8.4-gd \
        php8.4-intl \
        php8.4-zip \
        php8.4-bcmath \
        php8.4-soap \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsS https://download.civicrm.org/cv/cv.phar -o /usr/local/bin/cv \
    && chmod +x /usr/local/bin/cv \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --quiet \
    && composer config --global allow-plugins.civicrm/composer-compile-plugin true \
    && composer config --global allow-plugins.civicrm/composer-downloads-plugin true \
    && composer config --global allow-plugins.composer/installers true \
    && composer config --global allow-plugins.cweagans/composer-patches true \
    && git config --global --add safe.directory '*'

COPY app-test/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY shared/install.php /usr/local/bin/civicrm-install.php
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /opt/civicrm-test

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["help"]
