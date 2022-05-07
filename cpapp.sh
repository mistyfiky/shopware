#!/usr/bin/env bash

set -e

rm -fr .run/.app
id=$(docker-compose run --rm -d cli)
docker cp "$id":/app .run/.app
docker stop "$id"
