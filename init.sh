#!/usr/bin/env bash

set -e

cd

rm -fr .run/app
mkdir .run/app
touch .run/app/.env

mkdir -p .run/app/config/jwt

rm -fr .run/docker-entrypoint-initdb.d
mkdir .run/docker-entrypoint-initdb.d
wget -O .run/docker-entrypoint-initdb.d/schema.sql https://raw.githubusercontent.com/shopware/core/v6.4.11.1/schema.sql
