ARG SHOPWARE_ARCHIVE=v6.4.11.1_4acac2b5012d6a03377ae5881590aec8cda0196b.zip
ARG JQ_VERSION=1.5
ARG PHP_VERSION=8.1.5
ARG PHP_EXT_INSTALLER_VERSION=1.5.12
ARG COMPOSER_VERSION=2.3.5
ARG NODE_VERSION=16.15.0
ARG NGINX_VERSION=1.21.6
ARG USER_ID=1000
ARG GROUP_ID=1000
FROM mlocati/php-extension-installer:${PHP_EXT_INSTALLER_VERSION} as php-ext-installer
FROM composer:${COMPOSER_VERSION} as composer

FROM bash as production
WORKDIR /app
ARG SHOPWARE_ARCHIVE
RUN wget -O /tmp/production.zip https://releases.shopware.com/sw6/install_${SHOPWARE_ARCHIVE} && \
    unzip /tmp/production.zip

FROM bash as jq
RUN apk add gpg gpg-agent
ARG JQ_VERSION
RUN wget --no-check-certificate https://raw.githubusercontent.com/stedolan/jq/master/sig/jq-release.key -O /tmp/jq-release.key && \
    wget --no-check-certificate https://raw.githubusercontent.com/stedolan/jq/master/sig/v${JQ_VERSION}/jq-linux64.asc -O /tmp/jq-linux64.asc && \
    wget --no-check-certificate https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /tmp/jq-linux64 && \
    gpg --import /tmp/jq-release.key && \
    gpg --verify /tmp/jq-linux64.asc /tmp/jq-linux64 && \
    cp /tmp/jq-linux64 /usr/bin/jq && \
    chmod +x /usr/bin/jq


FROM php:${PHP_VERSION}-fpm as base
RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*
COPY --from=php-ext-installer /usr/bin/install-php-extensions /usr/local/bin
RUN install-php-extensions curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql phar simplexml sodium xml zip zlib
RUN install-php-extensions redis
COPY etc/php /usr/local/etc/php
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY --from=jq /usr/bin/jq /usr/bin/jq
ARG NODE_VERSION
RUN curl https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz | tar -xz -C /usr/local --strip-components 1


FROM nginx:${NGINX_VERSION} as nginx
COPY etc/nginx /etc/nginx


FROM base as build
COPY --from=production /app /app
WORKDIR /app
ENV CI=1
RUN composer require --no-install --no-scripts enqueue/amqp-bunny
# FIXME bin/build.sh
RUN composer install --no-interaction --optimize-autoloader --no-suggest
RUN composer install -d vendor/shopware/recovery --no-interaction --optimize-autoloader --no-suggest
#RUN bin/build-administration.sh


FROM base as sw
ARG USER_ID
ARG GROUP_ID
COPY --from=production --chown=${USER_ID}:${GROUP_ID} /app /app
COPY --from=build --chown=${USER_ID}:${GROUP_ID} /app/public /app/public
COPY --from=build --chown=${USER_ID}:${GROUP_ID} /app/vendor /app/vendor
COPY --chown=${USER_ID}:${GROUP_ID} app /app
WORKDIR /app
USER ${USER_ID}:${GROUP_ID}
ENV SHOPWARE_ES_ENABLED="0" \
    SHOPWARE_ES_INDEXING_ENABLED="0" \
    SHOPWARE_ES_INDEX_PREFIX="sw" \
    SHOPWARE_HTTP_CACHE_ENABLED="1" \
    SHOPWARE_HTTP_DEFAULT_TTL="7200" \
    SHOPWARE_CDN_STRATEGY_DEFAULT="id" \
    BLUE_GREEN_DEPLOYMENT="0" \
    COMPOSER_HOME="/app/var/cache/composer"


FROM sw as cli
CMD bash


FROM nginx as web
COPY --from=build --chown=nginx:nginx /app /app
WORKDIR /app
