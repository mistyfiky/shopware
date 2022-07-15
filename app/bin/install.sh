#!/usr/bin/env bash

BIN_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

set -euo pipefail

php "${BIN_DIR}/console" -n system:install -f --create-database --basic-setup \
 --shop-name="$SHOP_NAME" \
 --shop-email="$SHOP_EMAIL" \
 --shop-locale="$SHOP_LOCALE" \
 --shop-currency="$SHOP_CURRENCY"

php "${BIN_DIR}/console" -n user:change-password -p "$ADMIN_PASSWORD" admin
