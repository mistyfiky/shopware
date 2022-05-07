#!/usr/bin/env bash

set -e

docker-compose build
docker-compose --profile tools build
