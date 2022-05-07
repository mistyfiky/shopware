ARG SHOPWARE_VERSION=6.4.11.1
ARG JQ_VERSION=1.5
ARG PHP_VERSION=7.4.29
ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG COMPOSER_VERSION=2.3.5
ARG NODE_VERSION=16.15.0
ARG NGINX_VERSION=1.21.6
FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} as php-ext-installer
FROM composer:${COMPOSER_VERSION} as composer
FROM node:${NODE_VERSION} as node

FROM bash as production
ARG SHOPWARE_VERSION
RUN mkdir /app && \
    wget -O /tmp/production.tar.gz https://github.com/shopware/production/archive/refs/tags/v${SHOPWARE_VERSION}.tar.gz && \
    tar -xvzf /tmp/production.tar.gz -C /app \
     --exclude */.github \
     --exclude */.gitlab-ci \
     --exclude */.dockerignore \
     --exclude */.gitlab-ci.yml \
     --exclude */Dockerfile \
     --strip-components 1 && \
    rm -f /tmp/production.tar.gz


FROM bash as jq
RUN apk add gpg gpg-agent
ARG JQ_VERSION
RUN wget --no-check-certificate https://raw.githubusercontent.com/stedolan/jq/master/sig/jq-release.key -O /tmp/jq-release.key && \
    wget --no-check-certificate https://raw.githubusercontent.com/stedolan/jq/master/sig/v${JQ_VERSION}/jq-linux64.asc -O /tmp/jq-linux64.asc && \
    wget --no-check-certificate https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /tmp/jq-linux64 && \
    gpg --import /tmp/jq-release.key && \
    gpg --verify /tmp/jq-linux64.asc /tmp/jq-linux64 && \
    cp /tmp/jq-linux64 /usr/bin/jq && \
    chmod +x /usr/bin/jq && \
    rm -f /tmp/jq-release.key && \
    rm -f /tmp/jq-linux64.asc && \
    rm -f /tmp/jq-linux64


FROM php:${PHP_VERSION}-cli as php-cli
# FIXME DRY
COPY --from=php-ext-installer /usr/bin/install-php-extensions /usr/local/bin
RUN install-php-extensions curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib


FROM php:${PHP_VERSION}-fpm as php-fpm
# FIXME DRY
COPY --from=php-ext-installer /usr/bin/install-php-extensions /usr/local/bin
RUN install-php-extensions curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib


FROM php-cli as php-cli-composer
COPY --from=composer /usr/bin/composer /usr/bin/composer


FROM php-cli as php-cli-node
COPY --from=jq /usr/bin/jq /usr/bin/jq
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/share /usr/local/share
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin


FROM nginx:${NGINX_VERSION} as nginx
COPY etc/nginx /etc/nginx


FROM php-cli-composer as dependencies
COPY --from=production /app /app
WORKDIR /app
RUN composer install --no-interaction --optimize-autoloader --no-suggest --ignore-platform-reqs && \
    composer install -d vendor/shopware/recovery --no-interaction --optimize-autoloader --no-suggest --ignore-platform-reqs


FROM php-cli-node as assets
COPY --from=dependencies /app /app
WORKDIR /app
# FIXME build.sh
RUN CI=1 bin/build-administration.sh


FROM bash as app
# FIXME assets only
COPY --from=assets --chown=1000:1000 /app /app
COPY --chown=1000:1000 app /app
WORKDIR /app


FROM php-fpm as sw
COPY etc/php /usr/local/etc/php
COPY --from=app /app /app
WORKDIR /app
USER 1000:1000


FROM nginx as web
COPY --from=app --chown=nginx:nginx /app /app
WORKDIR /app


FROM php-cli as cli
COPY etc/php /usr/local/etc/php
COPY --from=app /app /app
WORKDIR /app
USER 1000:1000
CMD bash
