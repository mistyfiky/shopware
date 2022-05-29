ARG PROJECT_REPO=https://github.com/mistyfiky/shopware
ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG COMPOSER_VERSION=2.3.5
ARG JQ_VERSION=1.5
ARG PHP_VERSION=8.1.5
ARG APP_ENV=dev
ARG NODE_VERSION=16.15.0
ARG USER_ID=1000
ARG GROUP_ID=1000


FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} as php-ext-installer


FROM composer:${COMPOSER_VERSION} as composer


FROM bash as jq
ARG JQ_VERSION
ADD https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 /usr/bin/jq
RUN chmod 755 /usr/bin/jq


FROM scratch as stage
WORKDIR /srv


FROM bash as catalyst
WORKDIR /tmp/app


FROM php:${PHP_VERSION}-fpm-alpine as php-base
COPY --from=php-ext-installer /usr/bin/install-php-extensions /usr/bin/install-php-extensions
RUN IPE_GD_WITHOUTAVIF=1 install-php-extensions \
     curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib \
     apcu \
     redis && \
    IPE_DONT_ENABLE=1 install-php-extensions \
     opcache \
     xdebug


FROM php-base as php-prod
RUN docker-php-ext-enable-opcache
# TODO separate base config files
COPY etc/php /usr/local/etc/php


FROM php-base as php-dev
# TODO add xdebug config
RUN docker-php-ext-enable-xdebug
# TODO separate base config files
COPY etc/php /usr/local/etc/php


FROM php-${APP_ENV} as php
RUN apk add --no-cache bash
WORKDIR /srv
ARG APP_ENV
ENV APP_ENV=${APP_ENV}


FROM stage as stage1
ADD production.tar.gz .


FROM php as vendor-base
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=stage1 /srv .
RUN composer remove --no-update --no-scripts shopware/recovery && \
    composer require --no-install --no-scripts enqueue/amqp-bunny


FROM catalyst as plugins-composer-files
COPY app/custom/static-plugins /tmp/app/custom/static-plugins
RUN [ -z "$(ls custom/static-plugins)" ] || cp -r --parents custom/static-plugins/*/composer.json /srv


FROM vendor-base as vendor-plugins
COPY --from=jq /usr/bin/jq /usr/bin/jq
COPY --from=plugins-composer-files /srv .
RUN [ -z "$(ls custom/static-plugins)" ] || for plugin in custom/static-plugins/*; do \
     composer require --no-install --no-scripts $(jq -r '.name' "$plugin/composer.json"); \
    done


FROM vendor-plugins as vendor-prod
RUN composer install --no-interaction --optimize-autoloader --no-scripts --no-dev


FROM vendor-plugins as vendor-dev
RUN composer install --no-interaction --optimize-autoloader --no-scripts


FROM vendor-${APP_ENV} as vendor


FROM php as bundle-dump
COPY --from=stage1 /srv .
COPY --from=vendor /srv .
COPY app/custom/static-plugins /srv/custom/static-plugins
RUN bin/ci bundle:dump


FROM stage as stage2
COPY --from=stage1 /srv .
COPY --from=vendor /srv .
COPY --from=bundle-dump /srv/var/plugins.json ./var/plugins.json


# TODO separate prod and dev assets?
FROM node:${NODE_VERSION} as node
WORKDIR /srv


FROM catalyst as plugins-resources
COPY app/custom/static-plugins /srv/custom/static-plugins
RUN [ -z "$(ls custom/static-plugins)" ] || cp -r --parents custom/static-plugins/*/src/Resources/app /srv


FROM node as compile-plugins-assets
COPY --from=jq /usr/bin/jq /usr/bin/jq
COPY --from=stage2 /srv .
COPY --from=plugins-resources /srv .
ENV CI=1 \
    SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1 \
    SHOPWARE_SKIP_BUNDLE_DUMP=1 \
    SHOPWARE_SKIP_ASSET_COPY=1
RUN bin/build-administration.sh


FROM catalyst as plugins-assets
COPY --from=compile-plugins-assets /srv/custom/static-plugins /tmp/app/custom/static-plugins
RUN [ -z "$(ls custom/static-plugins)" ] || cp -r --parents custom/static-plugins/*/src/Resources/public /srv


FROM stage as stage3
COPY --from=stage2 /srv .
COPY --from=plugins-assets /srv .
COPY app .


FROM php
ARG USER_ID
ARG GROUP_ID
RUN addgroup -Sg ${GROUP_ID} app && adduser -Su ${USER_ID} app -G app
USER ${USER_ID}:${GROUP_ID}
WORKDIR /app
COPY --from=stage3 --chown=${USER_ID}:${GROUP_ID} /srv .
ENV APP_DEBUG="0" \
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
