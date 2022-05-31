SHELL = /bin/bash
.SHELLFLAGS = -c -e
.ONESHELL:
.DEFAULT_GOAL := help

export APP_ENV?=dev
export SHOPWARE_VERSION=6.4.11.1
export KANIKO_VERSION=1.8.1

help:
	@>&2 printf 'commands:\n'
	@>&2 printf '\tTODO\n'
	@>&2 printf 'urls:\n'
	$(MAKE) --no-print-directory urls
.PHONY: help

urls:
	@>&2 printf '%20s %-28s%s\n' \
	 'storefront' 'http://localhost:8000' '- : -' \
	 'storefront-watch' 'http://localhost:????' '- : -' \
	 'administration' 'http://localhost:8000/admin' 'admin : password' \
	 'administration-watch' 'http://localhost:3000' 'admin : password' \
	 'minio' 'http://localhost:9001' 'user : password' \
	 'rabbitmq' 'http://localhost:15672' 'user : password' \
	 'mailhog' 'http://localhost:8025' '- : -'
.PHONY: urls

clean:
	rm -fr .app
	rm -fr compose.phpstorm.dev.yml
	rm -f dump_*.sql
.PHONY: clean

purge:
	rm -f dump.sql
.PHONY: purge

build:
	docker compose --profile platform --profile tasks --profile tools build
.PHONY: build

build-plain:
	docker compose --profile platform --profile tasks --profile tools build --progress plain
.PHONY: build

up: dump.sql
	docker compose --profile platform up -d --remove-orphans
.PHONY: up

stop:
	docker compose --profile platform stop
.PHONY: stop

down:
	docker compose --profile platform down --remove-orphans --rmi local -v
.PHONY: down

recreate: dump.sql
	docker compose --profile platform up -d --remove-orphans --force-recreate
.PHONY: recreate

install: dump.sql
	docker compose run --rm install
.PHONY: install

update: dump.sql
	docker compose run --rm update
.PHONY: update

reinstall: build down install
.PHONY: reinstall

cli:
	docker compose run --rm cli
.PHONY: cli

app:
	mkdir -p $@
	CONTAINER_ID=$$(APP_ENV=dev docker compose run -d --no-deps --rm cli sleep 30)
	docker cp -a "$$CONTAINER_ID":/app/composer.json $@
	docker cp -a "$$CONTAINER_ID":/app/composer.lock $@
	docker cp -a "$$CONTAINER_ID":/app/vendor $@/vendor

dump.sql:
	touch $@

db-dump:
	[ ! -f dump.sql ] || mv dump.sql dump_$$(date +%s).sql
	docker compose exec db mysqldump -uroot -ppassword shopware 1>dump.sql
.PHONY: db-dump

compose.phpstorm.dev.yml:
	APP_ENV=dev docker compose --profile tools config | yq 'del(.services.cli.profiles)' >$@
.PHONY: compose.phpstorm.dev.yml

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

config.json:
	@read -rp 'GitHub username: ' USER
	@read -rsp 'GitHub PAT: ' PASSWORD
	@echo -n "{\"auths\":{\"ghcr.io\":{\"auth\":\"$$(echo $$USERNAME:$$PASSWORD | base64)\"}}}" >$@

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
