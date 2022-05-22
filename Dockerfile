# syntax=docker/dockerfile:1.4

ARG SHOPWARE_VERSION=6.4.11.1
ARG JQ_VERSION=1.5
ARG PHP_VERSION=8.1.5
ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG COMPOSER_VERSION=2.3.5
ARG NODE_VERSION=16.15.0
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG APP_ENV
FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} as php-ext-installer
FROM composer:${COMPOSER_VERSION} as composer


FROM bash as production
ARG SHOPWARE_VERSION
ADD https://github.com/shopware/production/archive/refs/tags/v${SHOPWARE_VERSION}.tar.gz /tmp/production.tar.gz
WORKDIR /srv
RUN tar -xzf /tmp/production.tar.gz \
     --exclude */.github \
     --exclude */.gitlab-ci \
     --exclude */.dockerignore \
     --exclude */.gitlab-ci.yml \
     --exclude */Dockerfile \
     --strip-components 1


FROM php:${PHP_VERSION}-fpm as php-base
RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*
RUN --mount=target=/usr/bin/install-php-extensions,source=/usr/bin/install-php-extensions,from=php-ext-installer <<eol
    install-php-extensions curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib
    install-php-extensions apcu
    install-php-extensions redis
eol
# TODO separate base config files
COPY --link etc/php /usr/local/etc/php


FROM php-base as php-prod
RUN --mount=target=/usr/bin/install-php-extensions,source=/usr/bin/install-php-extensions,from=php-ext-installer \
    install-php-extensions opcache


FROM php-base as php-dev
# TODO add xdebug config
RUN --mount=target=/usr/bin/install-php-extensions,source=/usr/bin/install-php-extensions,from=php-ext-installer \
    install-php-extensions xdebug


FROM php-${APP_ENV} as php
WORKDIR /srv


FROM php as dependencies
COPY --from=production --link /srv/composer.json /srv/composer.lock ./
ENV COMPOSER_ALLOW_SUPERUSER=1
# TODO custom/static-plugins/*/composer.json
RUN --mount=target=/usr/bin/composer,source=/usr/bin/composer,from=composer <<eol
    mkdir -p custom/plugins custom/static-plugins
    composer remove --no-update --no-scripts shopware/recovery
    composer require --no-install --no-scripts enqueue/amqp-bunny
eol


FROM dependencies as vendor-prod
RUN --mount=target=/usr/bin/composer,source=/usr/bin/composer,from=composer \
    composer install --no-interaction --optimize-autoloader --no-scripts --no-dev


FROM dependencies as vendor-dev
RUN --mount=target=/usr/bin/composer,source=/usr/bin/composer,from=composer \
    composer install --no-interaction --optimize-autoloader --no-scripts


FROM vendor-${APP_ENV} as vendor


FROM scratch as jq
ARG JQ_VERSION
ADD --chmod=755 https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 /usr/bin/jq


# TODO separate prod and dev assets?
FROM node:${NODE_VERSION} as node
WORKDIR /srv


FROM node as assets
COPY --from=production --link /srv .
COPY --from=vendor --link /srv .
ENV CI=1 \
    SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1 \
    SHOPWARE_SKIP_BUNDLE_DUMP=1 \
    SHOPWARE_SKIP_ASSET_COPY=1
RUN --mount=target=/usr/bin/jq,source=/usr/bin/jq,from=jq \
    bin/build-administration.sh


FROM php as public
COPY --from=assets --link /srv .
ARG APP_ENV
ENV APP_ENV=${APP_ENV}
RUN bin/ci bundle:dump


FROM scratch as app
WORKDIR /srv
COPY --from=production --link /srv .
COPY --from=vendor --link /srv .
COPY --from=public --link /srv/public ./public
COPY app .


FROM php
ARG USER_ID
ARG GROUP_ID
USER ${USER_ID}:${GROUP_ID}
WORKDIR /app
COPY --from=app --chown=${USER_ID}:${GROUP_ID} --link /srv .
ARG APP_ENV
ENV APP_ENV=${APP_ENV} \
    APP_DEBUG="0" \
    SHOPWARE_ES_HOSTS="" \
    SHOPWARE_ES_ENABLED="0" \
    SHOPWARE_ES_INDEXING_ENABLED="0" \
    SHOPWARE_ES_INDEX_PREFIX="" \
    SHOPWARE_HTTP_CACHE_ENABLED="1" \
    SHOPWARE_HTTP_DEFAULT_TTL="7200" \
    SHOPWARE_CDN_STRATEGY_DEFAULT="id" \
    BLUE_GREEN_DEPLOYMENT="0" \
    COMPOSER_HOME="/app/var/cache/composer" \
    COMPOSER_PLUGIN_LOADER=1
