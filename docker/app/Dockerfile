FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV CIVICRM_SETTINGS=/var/www/html/private/civicrm.settings.php

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https \
    && curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        php8.4-fpm \
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
        php8.4-opcache \
        php8.4-xdebug \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsS https://download.civicrm.org/cv/cv.phar -o /usr/local/bin/cv \
    && chmod +x /usr/local/bin/cv

COPY app/nginx.conf /etc/nginx/sites-available/default
COPY app/php.ini /etc/php/8.4/fpm/conf.d/99-civicrm.ini
COPY app/xdebug.ini /etc/php/8.4/fpm/conf.d/99-xdebug.ini
COPY app/supervisord.conf /etc/supervisor/conf.d/civicrm.conf
COPY app/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY shared/install.php /usr/local/bin/civicrm-install.php
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

CMD ["/usr/local/bin/entrypoint.sh"]
