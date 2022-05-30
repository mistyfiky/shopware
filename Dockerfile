ARG PROJECT_REPO=https://github.com/mistyfiky/shopware
ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG COMPOSER_VERSION=2.3.5
ARG JQ_VERSION=1.5
ARG PHP_VERSION=8.1.5
ARG APP_ENV=dev
ARG NODE_VERSION=16.15.0
ARG USER_ID=1000
ARG GROUP_ID=1000


FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} AS php-ext-installer-img
FROM scratch AS php-ext-installer
COPY --from=php-ext-installer-img /usr/bin/install-php-extensions /usr/bin/install-php-extensions


FROM composer:${COMPOSER_VERSION} AS composer-img
FROM scratch AS composer
COPY --from=composer-img /usr/bin/composer /usr/bin/composer


FROM node:${NODE_VERSION}-alpine AS node-img
FROM scratch AS node
COPY --from=node-img /usr/lib /usr/lib
COPY --from=node-img /usr/local/share /usr/local/share
COPY --from=node-img /usr/local/lib /usr/local/lib
COPY --from=node-img /usr/local/include /usr/local/include
COPY --from=node-img /usr/local/bin /usr/local/bin


FROM bash AS jq-img
ARG JQ_VERSION
ADD https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 /usr/bin/jq
RUN chmod 755 /usr/bin/jq
FROM scratch AS jq
COPY --from=jq-img /usr/bin/jq /usr/bin/jq


FROM scratch AS stage
WORKDIR /app


FROM php:${PHP_VERSION}-fpm-alpine AS base
COPY --from=php-ext-installer / /
RUN IPE_GD_WITHOUTAVIF=1 install-php-extensions curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib
RUN install-php-extensions apcu
RUN install-php-extensions redis


FROM base AS php-prod
RUN install-php-extensions opcache


FROM base AS php-dev
# TODO add xdebug config
RUN install-php-extensions xdebug


FROM php-${APP_ENV} AS php
RUN apk add --no-cache bash


FROM stage AS stage0
COPY --from=php / /
# TODO separate base config files
COPY stage0 /


FROM stage0 AS base


FROM stage AS stage1
COPY stage1 /


FROM base AS dependencies
COPY --from=composer / /
COPY --from=jq / /
COPY --from=stage1 / /
COPY stage2/app/custom/static-plugins /app/custom/static-plugins
ARG APP_ENV
ENV APP_ENV=${APP_ENV} \
    COMPOSER_ALLOW_SUPERUSER=1
ARG PHP_VERSION
RUN composer config platform.php "$PHP_VERSION" && \
    composer require --no-install --no-scripts php "$PHP_VERSION" && \
    composer remove --no-update --no-scripts shopware/recovery && \
    composer require --no-install --no-scripts enqueue/amqp-bunny && \
    for plugin in custom/static-plugins/*; do \
     composer require --no-install --no-scripts $(jq -r '.name' "$plugin/composer.json"); \
    done


FROM dependencies AS vendor-prod
RUN composer install --no-interaction --optimize-autoloader --no-scripts --no-dev


FROM dependencies AS vendor-dev
RUN composer install --no-interaction --optimize-autoloader --no-scripts


FROM vendor-${APP_ENV} AS vendor


FROM vendor AS bundle-dump
RUN bin/ci bundle:dump


FROM stage AS stage2
COPY stage2 /
COPY --from=dependencies /app/composer.json /app/composer.lock ./
COPY --from=vendor /app/vendor vendor
COPY --from=bundle-dump /app/var/plugins.json var/plugins.json


FROM base AS assets
COPY --from=node / /
COPY --from=jq / /
COPY --from=stage1 / /
COPY --from=stage2 / /
ENV CI=1 \
    SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1 \
    SHOPWARE_SKIP_BUNDLE_DUMP=1 \
    SHOPWARE_SKIP_ASSET_COPY=1 \
    PUPPETEER_SKIP_DOWNLOAD=1
RUN bin/build-administration.sh


FROM stage AS stage3
COPY stage3 /
# FIXME automate
COPY --from=assets /app/custom/static-plugins/FroshTools/src/Resources/public custom/static-plugins/FroshTools/src/Resources/public


FROM scratch as prod
COPY --from=stage0 / /


FROM prod as dev
COPY --from=composer / /
COPY --from=node / /


FROM ${APP_ENV}
COPY --from=stage1 --chown=www-data / /
COPY --from=stage2 --chown=www-data / /
COPY --from=stage3 --chown=www-data / /
ENV PHP_INI_DIR=/usr/local/etc/php
ENTRYPOINT ["docker-php-entrypoint"]
WORKDIR /app
STOPSIGNAL SIGQUIT
EXPOSE 9000
CMD ["php-fpm"]
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
    DISABLE_EXTENSIONS=1
LABEL org.opencontainers.image.source=$PROJECT_REPO
