# syntax=docker/dockerfile:1.4

ARG PHP_VERSION=8.1.5
ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG APP_ENV
ARG COMPOSER_VERSION=2.3.5
ARG BASH_VERSION=5.1.16
ARG JQ_VERSION=1.5
ARG NODE_VERSION=16.15.0
ARG USER_ID=1000
ARG GROUP_ID=1000

FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} as php-ext-installer


FROM php:${PHP_VERSION}-fpm-alpine as php-base
WORKDIR /srv
RUN --mount=target=/usr/bin/install-php-extensions,source=/usr/bin/install-php-extensions,from=php-ext-installer \
    install-php-extensions \
     curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib \
     apcu \
     redis


FROM php-base as php-prod
RUN --mount=target=/usr/bin/install-php-extensions,source=/usr/bin/install-php-extensions,from=php-ext-installer \
    install-php-extensions opcache


FROM php-base as php-dev
# TODO add xdebug config
RUN --mount=target=/usr/bin/install-php-extensions,source=/usr/bin/install-php-extensions,from=php-ext-installer \
    install-php-extensions xdebug


FROM php-${APP_ENV} as php
RUN apk add --no-cache bash
# TODO separate base config files
COPY --link etc/php /usr/local/etc/php
ARG APP_ENV
ENV APP_ENV=${APP_ENV}


FROM scratch as scratch
WORKDIR /srv


FROM scratch as stage1
ADD production.tar.gz .


FROM composer:${COMPOSER_VERSION} as composer


FROM php as vendor-base
COPY --from=stage1 --link /srv .
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN --mount=target=/usr/bin/composer,source=/usr/bin/composer,from=composer \
    --mount=type=cache,target=/root/.composer \
    composer remove --no-update --no-scripts shopware/recovery && \
    composer require --no-install --no-scripts enqueue/amqp-bunny


FROM bash:${BASH_VERSION} as tmp-app-shell
WORKDIR /tmp/app


FROM tmp-app-shell as plugins-composer-files
RUN --mount=target=/tmp/app/custom/static-plugins,source=app/custom/static-plugins \
    [ -z "$(ls custom/static-plugins)" ] || cp -r --parents custom/static-plugins/*/composer.json /srv


FROM scratch as jq
ARG JQ_VERSION
ADD --chmod=755 https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 /usr/bin/jq


FROM vendor-base as vendor-plugins
COPY --from=plugins-composer-files --link /srv .
RUN --mount=target=/usr/bin/composer,source=/usr/bin/composer,from=composer \
    --mount=target=/usr/bin/jq,source=/usr/bin/jq,from=jq \
    --mount=type=cache,target=/root/.composer \
    [ -z "$(ls custom/static-plugins)" ] || for plugin in custom/static-plugins/*; do \
     composer require --no-install --no-scripts $(jq -r '.name' "$plugin/composer.json"); \
    done


FROM vendor-plugins as vendor-prod
RUN --mount=target=/usr/bin/composer,source=/usr/bin/composer,from=composer \
    --mount=type=cache,target=/root/.composer \
    composer install --no-interaction --optimize-autoloader --no-scripts --no-dev


FROM vendor-plugins as vendor-dev
RUN --mount=target=/usr/bin/composer,source=/usr/bin/composer,from=composer \
    --mount=type=cache,target=/root/.composer \
    composer install --no-interaction --optimize-autoloader --no-scripts


FROM vendor-${APP_ENV} as vendor


FROM php as bundle-dump
COPY --from=stage1 --link /srv .
COPY --from=vendor --link /srv .
RUN --mount=target=/srv/custom,source=app/custom \
    bin/ci bundle:dump


FROM scratch as stage2
COPY --from=stage1 --link /srv .
COPY --from=vendor --link /srv .
COPY --from=bundle-dump --link /srv/var/plugins.json ./var/plugins.json


# TODO separate prod and dev assets?
FROM node:${NODE_VERSION} as node
WORKDIR /srv


FROM tmp-app-shell as plugins-resources
RUN --mount=target=/tmp/app/custom/static-plugins,source=app/custom/static-plugins \
    [ -z "$(ls custom/static-plugins)" ] || cp -r --parents custom/static-plugins/*/src/Resources/app /srv


FROM node as compile-plugins-assets
COPY --from=stage2 --link /srv .
COPY --from=plugins-resources /srv .
ENV CI=1 \
    SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1 \
    SHOPWARE_SKIP_BUNDLE_DUMP=1 \
    SHOPWARE_SKIP_ASSET_COPY=1
RUN --mount=target=/usr/bin/jq,source=/usr/bin/jq,from=jq \
    --mount=type=cache,target=/root/.npm \
    bin/build-administration.sh


FROM tmp-app-shell as plugins-assets
RUN --mount=target=/tmp/app/custom/static-plugins,source=/srv/custom/static-plugins,from=compile-plugins-assets \
    [ -z "$(ls custom/static-plugins)" ] || cp -r --parents custom/static-plugins/*/src/Resources/public /srv


FROM scratch as stage3
COPY --from=stage2 --link /srv .
COPY --from=plugins-assets --link /srv .
COPY --link app .


FROM php
ARG USER_ID
ARG GROUP_ID
USER ${USER_ID}:${GROUP_ID}
WORKDIR /app
COPY --from=stage3 --chown=${USER_ID}:${GROUP_ID} --link /srv .
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
