ARG SHOPWARE_VERSION=6.4.11.1
ARG JQ_VERSION=1.5
ARG PHP_VERSION=8.1.5
ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG COMPOSER_VERSION=2.3.5
ARG NODE_VERSION=16.15.0
ARG NGINX_VERSION=1.21.6
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG APP_ENV
FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} as php-ext-installer
FROM composer:${COMPOSER_VERSION} as composer


FROM bash as production
WORKDIR /app
ARG SHOPWARE_VERSION
RUN wget -q https://github.com/shopware/production/archive/refs/tags/v${SHOPWARE_VERSION}.tar.gz -O - | tar -xz \
     --exclude */.github \
     --exclude */.gitlab-ci \
     --exclude */.dockerignore \
     --exclude */.gitlab-ci.yml \
     --exclude */Dockerfile \
     --strip-components 1


FROM bash as jq
RUN apk add gpg gpg-agent
ARG JQ_VERSION
RUN wget -q --no-check-certificate https://raw.githubusercontent.com/stedolan/jq/master/sig/jq-release.key -O /tmp/jq-release.key && \
    wget -q --no-check-certificate https://raw.githubusercontent.com/stedolan/jq/master/sig/v${JQ_VERSION}/jq-linux64.asc -O /tmp/jq-linux64.asc && \
    wget -q --no-check-certificate https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /tmp/jq-linux64 && \
    gpg --import /tmp/jq-release.key && \
    gpg --verify /tmp/jq-linux64.asc /tmp/jq-linux64 && \
    cp /tmp/jq-linux64 /usr/bin/jq && \
    chmod +x /usr/bin/jq


FROM php:${PHP_VERSION}-fpm as php-base
RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*
COPY --from=php-ext-installer /usr/bin/install-php-extensions /usr/local/bin
RUN install-php-extensions curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib
RUN install-php-extensions redis
# TODO separate base config files
COPY etc/php /usr/local/etc/php


FROM php-base as php-prod


FROM php-base as php-dev
# TODO add xdebug config
RUN install-php-extensions xdebug


FROM php-${APP_ENV} as php


FROM php as php-composer
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1


FROM php-composer as vendor-base
COPY --from=production /app/composer.json /app/composer.lock /app/
COPY --from=production /app/custom /app/custom
WORKDIR /app
RUN composer remove --no-update --no-scripts shopware/recovery
RUN composer require --no-install --no-scripts enqueue/amqp-bunny


FROM vendor-base as vendor-prod
RUN composer install --no-interaction --optimize-autoloader --no-scripts --no-dev


FROM vendor-base as vendor-dev
RUN composer install --no-interaction --optimize-autoloader --no-scripts


FROM vendor-${APP_ENV} as vendor


FROM php as php-node
COPY --from=jq /usr/bin/jq /usr/bin/jq
ARG NODE_VERSION
RUN curl https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz | tar -xz -C /usr/local --strip-components 1


# TODO separate prod and de assets?
FROM php-node as assets
COPY --from=production /app /app
COPY --from=vendor /app /app
WORKDIR /app
ARG APP_ENV
ENV APP_ENV=${APP_ENV} \
    CI=1 \
    SHOPWARE_SKIP_BUNDLE_DUMP=1 \
    SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS=1
# TODO SHOPWARE_SKIP_ASSET_COPY=1 and copy only built assets from custom and vendor
RUN bin/build-administration.sh


FROM scratch as app
COPY --from=production /app /app
COPY --from=vendor /app /app
COPY --from=assets /app/public /app/public
COPY app /app


FROM php as sw
ARG USER_ID
ARG GROUP_ID
COPY --from=app --chown=${USER_ID}:${GROUP_ID} /app /app
USER ${USER_ID}:${GROUP_ID}
WORKDIR /app
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


# TODO is this necessary?
FROM sw as cli
CMD bash


FROM nginx:${NGINX_VERSION} as nginx
COPY etc/nginx /etc/nginx


# TODO replace with ingress service
FROM nginx as web
COPY --from=app --chown=nginx:nginx /app /app
WORKDIR /app
