ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG COMPOSER_VERSION=2.3.5
ARG PHP_VERSION=8.1.5
ARG APP_ENV=dev
ARG NODE_VERSION=16.15.0
ARG JQ_VERSION=1.5
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG PROJECT_REPO=https://github.com/mistyfiky/shopware


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
RUN wget -O /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 && \
    chmod 755 /usr/bin/jq
FROM scratch AS jq
COPY --from=jq-img /usr/bin/jq /usr/bin/jq


FROM scratch AS stage
WORKDIR /app


FROM php:${PHP_VERSION}-fpm-alpine AS php-base
COPY --from=php-ext-installer / /
RUN IPE_GD_WITHOUTAVIF=1 install-php-extensions curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib
RUN install-php-extensions amqp apcu redis


FROM php-base AS php-prod
RUN install-php-extensions opcache
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"


FROM php-base AS php-dev
RUN install-php-extensions xdebug
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"


FROM php-${APP_ENV} AS php
RUN apk add --no-cache bash
WORKDIR /app


FROM stage AS stage0
COPY stage0 /


FROM stage AS stage1
COPY stage1 /


FROM php AS dependencies
COPY --from=composer / /
COPY --from=stage1 / /
ARG APP_ENV
ENV APP_ENV=${APP_ENV} \
    COMPOSER_ALLOW_SUPERUSER=1
ARG PHP_VERSION
RUN composer config platform.php "$PHP_VERSION" && \
    composer require --no-install --no-scripts php "$PHP_VERSION" && \
    composer remove --no-update --no-scripts shopware/recovery
# FIXME automate
COPY stage2/app/custom/static-plugins/FroshTools/composer.json custom/static-plugins/FroshTools/composer.json
RUN composer require --no-install --no-scripts frosh/tools:0.1.7


FROM php AS vendor-base
COPY --from=composer / /
COPY --from=stage1 / /
COPY --from=dependencies /app/composer.json /app/composer.lock ./
ARG APP_ENV
ENV APP_ENV=${APP_ENV} \
    COMPOSER_ALLOW_SUPERUSER=1
# FIXME automate
COPY stage2/app/custom/static-plugins/FroshTools/composer.json custom/static-plugins/FroshTools/composer.json


FROM vendor-base AS vendor-prod
RUN composer install --no-interaction --optimize-autoloader --no-scripts --no-dev


FROM vendor-base AS vendor-dev
RUN composer install --no-interaction --optimize-autoloader --no-scripts


FROM vendor-${APP_ENV} AS vendor


FROM vendor AS bundle-dump
COPY stage2/app/custom/static-plugins custom/static-plugins
RUN bin/ci bundle:dump


FROM stage AS stage2
COPY stage2 /
COPY --from=dependencies /app/composer.json /app/composer.lock ./
COPY --from=vendor /app/vendor vendor
COPY --from=bundle-dump /app/var/plugins.json var/plugins.json


FROM php AS node_modules
COPY --from=node / /
COPY --from=vendor /app/vendor vendor
ENV PUPPETEER_SKIP_DOWNLOAD=1
RUN npm clean-install --prefix vendor/shopware/administration/Resources/app/administration
# FIXME automate
COPY stage2/app/custom/static-plugins/FroshTools/src/Resources/app/administration/package.json \
     stage2/app/custom/static-plugins/FroshTools/src/Resources/app/administration/package-lock.json \
     custom/static-plugins/FroshTools/src/Resources/app/administration/
RUN npm clean-install --prefix custom/static-plugins/FroshTools/src/Resources/app/administration


FROM php AS assets
COPY --from=node / /
COPY --from=stage1 / /
COPY --from=stage2 / /
COPY --from=node_modules /app/vendor/shopware/administration/Resources/app/administration/node_modules vendor/shopware/administration/Resources/app/administration/node_modules
# FIXME automate
COPY --from=node_modules /app/custom/static-plugins/FroshTools/src/Resources/app/administration/node_modules custom/static-plugins/FroshTools/src/Resources/app/administration/node_modules
WORKDIR /app/vendor/shopware/administration/Resources/app/administration
ENV PROJECT_ROOT=/app \
    SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1
RUN npm run build


FROM stage AS stage3
COPY stage3 /
# FIXME automate
COPY --from=assets /app/custom/static-plugins/FroshTools/src/Resources/public custom/static-plugins/FroshTools/src/Resources/public


FROM scratch AS base
COPY --from=php / /
COPY --from=stage0 / /


FROM base AS prod


FROM base AS dev
COPY --from=composer / /
COPY --from=node / /
COPY --from=jq / /
ARG USER_ID
ARG GROUP_ID
# FIXME npm cache
ONBUILD COPY --from=node_modules --chown=${USER_ID}:${GROUP_ID} /app/vendor/shopware/administration/Resources/app/administration/node_modules /app/vendor/shopware/administration/Resources/app/administration/node_modules
# FIXME automate
ONBUILD COPY --from=node_modules --chown=${USER_ID}:${GROUP_ID} /app/custom/static-plugins/FroshTools/src/Resources/app/administration/node_modules /app/custom/static-plugins/FroshTools/src/Resources/app/administration/node_modules


FROM ${APP_ENV}
ARG USER_ID
ARG GROUP_ID
COPY --from=stage1 --chown=${USER_ID}:${GROUP_ID} / /
COPY --from=stage2 --chown=${USER_ID}:${GROUP_ID} / /
COPY --from=stage3 /usr /usr
COPY --from=stage3 --chown=${USER_ID}:${GROUP_ID} /app /app
USER ${USER_ID}:${GROUP_ID}
ENV PHP_INI_DIR=/usr/local/etc/php
ENTRYPOINT ["docker-php-entrypoint"]
WORKDIR /app
STOPSIGNAL SIGQUIT
EXPOSE 9000
CMD ["php-fpm"]
ARG APP_ENV
ENV APP_ENV=${APP_ENV} \
    APP_DEBUG="0" \
    BLUE_GREEN_DEPLOYMENT="0" \
    DISABLE_EXTENSIONS="1" \
    SHOPWARE_ES_HOSTS="" \
    SHOPWARE_ES_ENABLED="0" \
    SHOPWARE_ES_INDEXING_ENABLED="0" \
    SHOPWARE_ES_INDEX_PREFIX="" \
    SHOPWARE_HTTP_CACHE_ENABLED="1" \
    SHOPWARE_HTTP_DEFAULT_TTL="7200" \
    SHOPWARE_CDN_STRATEGY_DEFAULT="id"
LABEL org.opencontainers.image.source=$PROJECT_REPO
