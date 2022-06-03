SHELL = /bin/bash
.SHELLFLAGS = -c -e
export BASH_ENV = $(PWD)/bin/activate
.ONESHELL:
.DEFAULT_GOAL := help

export SHOPWARE_VERSION=6.4.11.1
export KANIKO_VERSION=1.8.1

help:
	@>&2 printf 'commands:\n'
	@>&2 printf '%20s - %s\n' \
	 'help' 'show this message' \
	 'build' 'build shopware image' \
	 'down' 'stop all services and remove their data' \
	 'install' 'run install script' \
	 'up' 'start all services' \
	 'stop' 'stop all services' \
	 'urls' 'show services urls' \
	 'prod, dev' 'change environment in configuration' \
	 'recreate' 'recreate all services' \
	 'update' 'run update script' \
	 'clean' 'remove unnecessary files' \
	 'purge' 'down and remove all runtime files' \
	 'watch-administration' 'run administration watch' \
	 'cli' 'open shell inside container' \
	 'ide' 'prepare files for ide indexing' \
	 'kaniko' 'build shopware image with kaniko' \
	 && :
	@>&2 printf '\nexamples:\n\n'
	@>&2 printf '%d. %s\n\n\t%s\n\n' \
	 '1' 'setup development environment' 'make build down install up urls' \
	 '2' 'switch to prod env' 'make prod build recreate urls' \
	 '3' 'perform shopware update' 'make build update recreate urls' \
	 && :
.PHONY: help

build:
	docker compose --profile platform --profile tasks --profile tools build
.PHONY: build

build-plain:
	docker compose --profile platform --profile tasks --profile tools build --progress plain
.PHONY: build

down:
	docker compose --profile platform down --remove-orphans --rmi local -v
.PHONY: down

install: dump.sql stageX/app permissions
	docker compose run --rm install
.PHONY: install

up: dump.sql
	docker compose --profile platform up -d --remove-orphans
.PHONY: up

stop:
	docker compose --profile platform stop
.PHONY: stop

urls:
	@>&2 printf '%20s %-30s%s\n' \
	 'storefront' 'http://localhost:8000' '- : -' \
	 'administration' 'http://localhost:8000/admin' 'admin : password' \
	 'administration-watch' 'http://localhost:8080' 'admin : password' \
	 'minio' 'http://localhost:9001' 'user : password' \
	 'rabbitmq' 'http://localhost:15672' 'user : password' \
	 'mailhog' 'http://localhost:8025' '- : -'
.PHONY: urls

prod dev:
	[ "$$APP_ENV" = "$@" ] || sed -i "s/APP_ENV=.*/APP_ENV=$@/" .env
.PHONY: prod dev

recreate: dump.sql stageX/app
	docker compose --profile platform up -d --remove-orphans --force-recreate
.PHONY: recreate

update: dump.sql stageX/app permissions
	docker compose run --rm update
.PHONY: update

clean:
	rm -f dump_*.sql
.PHONY: clean

purge: down purge-shadow
	rm -fr stageX
	rm -f .env
	rm -f compose.ide.dev.yml
	rm -f config.json
	rm -f dump.sql
.PHONY: purge

watch-administration:
	docker compose run --rm --service-ports watch-administration
.PHONY: watch-administration

cli:
	docker compose run --rm cli
.PHONY: cli

ide:
	APP_ENV=dev docker-compose --profile tools config | yq 'del(.services.cli.profiles)' >compose.ide.dev.yml
.PHONY: ide

kaniko: config.json
	SHOPWARE_IMAGE=$$(docker compose --profile platform config | yq '.services.shopware.image')
	docker run --rm -it \
	 -v "$$(pwd)":/workspace \
	 -v "$$(pwd)/config.json":/kaniko/.docker/config.json:ro \
	 gcr.io/kaniko-project/executor:v$${KANIKO_VERSION} \
	 --dockerfile=/workspace/Dockerfile \
	 --context=dir:///workspace/ \
	 --destination="$$SHOPWARE_IMAGE" \
	 --cache=true \
	 --build-arg APP_ENV="$$APP_ENV"
.PHONY: kaniko

dump.sql:
	touch $@

permissions:
	docker compose run --rm permissions
.PHONY: permissions

purge-shadow:
	# TODO automate
	rm -f \
	 stage1/app/config/services/custom.xml \
	 stage1/app/bin/wait-for-it.sh \
	 stage1/app/bin/update.sh \
	 stage1/app/bin/install.sh
	PURGE_SHADOW_DIRS=$$(find . -user root -type d | sort -r); [ -z "$$PURGE_SHADOW_DIRS" ] || echo "$$PURGE_SHADOW_DIRS" | xargs sudo rmdir
.PHONY: purge-shadow

stageX/app:
	mkdir -p $@
	# FIXME prod
	SHOPWARE_IMAGE=$$(APP_ENV=dev docker compose --profile platform config | yq '.services.shopware.image')
	CONTAINER_ID=$$(docker run -d --rm $$SHOPWARE_IMAGE sleep 60)
	docker cp -a "$$CONTAINER_ID":/app/composer.json $@
	docker cp -a "$$CONTAINER_ID":/app/composer.lock $@
	mkdir -p $@/public
	docker cp -a "$$CONTAINER_ID":/app/public $@
	mkdir -p $@/vendor
	docker cp -a "$$CONTAINER_ID":/app/vendor $@
	mkdir -p $@/var
	docker cp -a "$$CONTAINER_ID":/app/var/plugins.json $@/var/plugins.json
	# FIXME prod
	# TODO automate
	mkdir -p $@/custom/static-plugins/FroshTools/src/Resources/public
	docker cp -a "$$CONTAINER_ID":/app/custom/static-plugins/FroshTools/src/Resources/public $@/custom/static-plugins/FroshTools/src/Resources
	mkdir -p $@/custom/static-plugins/FroshTools/src/Resources/app/administration/node_modules
	docker cp -a "$$CONTAINER_ID":/app/custom/static-plugins/FroshTools/src/Resources/app/administration/node_modules $@/custom/static-plugins/FroshTools/src/Resources/app/administration
.PHONY: stageX/app

config.json:
	@read -rp 'GitHub username: ' USER
	@read -rsp 'GitHub PAT: ' PASSWORD
	@echo -n "{\"auths\":{\"ghcr.io\":{\"auth\":\"$$(echo $$USERNAME:$$PASSWORD | base64)\"}}}" >$@

db-dump:
	[ ! -f dump.sql ] || mv dump.sql dump_$$(date +%s).sql
	docker compose exec db mysqldump -uroot -ppassword shopware 1>dump.sql
.PHONY: db-dump

stage1/app:
	cd stage1
	rm -fr app
	mkdir app
	wget https://github.com/shopware/production/archive/refs/tags/v$${SHOPWARE_VERSION}.tar.gz -O - | tar -xzvC app \
	 --exclude */.github \
	 --exclude */.gitlab-ci \
	 --exclude */artifacts \
	 --exclude */.dockerignore \
	 --exclude */.gitignore \
	 --exclude */.gitlab-ci.yml \
	 --exclude */Dockerfile \
	 --exclude */docker-compose.yml \
	 --exclude */README.md \
	 --strip-components 1
.PHONY: stage1/app
