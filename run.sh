#!/usr/bin/env bash

set -e

docker-compose run --rm .run
docker-compose run --rm system-setup
docker-compose run --rm system-install
docker-compose up -d
