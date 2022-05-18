SHELL = /bin/bash
.SHELLFLAGS = -c -e
.ONESHELL:
.DEFAULT_GOAL := help

help:
	@>&2 printf 'commands:\n'
	@>&2 printf '\tTODO\n'
	@>&2 printf 'urls:\n'
	@>&2 printf '%20s %-28s%s\n' \
	 'storefront' 'http://localhost:8000' '- : -' \
	 'storefront-watch' 'http://localhost:????' '- : -' \
	 'administration' 'http://localhost:8000/admin' 'admin : password' \
	 'administration-watch' 'http://localhost:3000' 'admin : password' \
	 'minio' 'http://localhost:9001' 'user : password' \
	 'rabbitmq' 'http://localhost:15672' 'user : password' \
	 'mailhog' 'http://localhost:8025' '- : -'
.PHONY: help

clean:
	rm -fr .app
.PHONY: clean

purge:
	rm -f initdb.d/dump.sql
.PHONY: purge

build:
	docker compose --profile platform --profile tasks --profile tools build
.PHONY: build

up:
	docker compose --profile platform up -d --remove-orphans
.PHONY: run

stop:
	docker compose --profile platform stop
.PHONY: down

down:
	docker compose --profile platform down --remove-orphans --rmi local -v
.PHONY: down

recreate:
	docker compose --profile platform up -d --remove-orphans --force-recreate
.PHONY: recreate

system-install:
	docker compose run --rm system-install
.PHONY: system-install

init: system-install up
.PHONY: init

reinit: build down init
.PHONY: reinit

cli:
	docker compose run --rm cli
.PHONY: cli

.app:
	docker cp -a "$$(docker compose run -d --no-deps --rm cli sleep 30)":/app $@

initdb.d/_schema.sql:
	wget -O $@ https://raw.githubusercontent.com/shopware/core/v6.4.11.1/schema.sql

initdb.d/dump.sql:
	[ ! -f $@ ] || mv $@ $@.bak
	docker compose exec db mysqldump -uroot -ppassword shopware >$@

docker-compose.phpstorm.yml:
	docker compose --profile platform config >$@
