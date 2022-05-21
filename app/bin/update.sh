#!/usr/bin/env bash

BIN_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

set -euo pipefail

php "${BIN_DIR}/console" -n system:update:prepare
php "${BIN_DIR}/console" -n system:update:finish
