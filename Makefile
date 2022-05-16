SHELL = /bin/bash
.SHELLFLAGS = -c -e
.ONESHELL:
.DEFAULT_GOAL := init

clean:
	rm -fr .app
.PHONY: clean

purge:
	rm -f docker-entrypoint-initdb.d/dump.sql
.PHONY: purge

build:
	docker compose --profile platform --profile tasks --profile tools build
.PHONY: build

up:
	docker compose --profile platform up -d
	@echo "http://localhost:8000/admin"
.PHONY: run

stop:
	docker compose --profile platform stop
.PHONY: down

down:
	docker compose --profile platform down -v --rmi local
.PHONY: down

recreate:
	docker compose --profile platform up -d --force-recreate
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
	id=$$(docker compose run --rm -d cli)
	docker cp "$$id":/app $@
	docker stop "$$id"

docker-entrypoint-initdb.d/_schema.sql:
	wget -O $@ https://raw.githubusercontent.com/shopware/core/v6.4.11.1/schema.sql

docker-entrypoint-initdb.d/dump.sql:
	[ ! -f $@ ] || mv $@ $@.bak
	docker compose exec db mysqldump -uroot -ppassword shopware >$@

docker-compose.phpstorm.yml:
	docker compose --profile platform config >$@
