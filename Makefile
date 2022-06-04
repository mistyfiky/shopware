SHELL = /bin/bash
.SHELLFLAGS = -c
export BASH_ENV = $(PWD)/bin/activate
.ONESHELL :
.DEFAULT_GOAL := help

export SHOPWARE_VERSION = 6.4.11.1
export KANIKO_VERSION = 1.8.1

help : export BASH_ENV =
help :
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
	 'kaniko' 'build shopware image with kaniko' \
	 && :
	@>&2 printf '\nexamples:\n\n'
	@>&2 printf '%d. %s\n\n\t%s\n\n' \
	 '1' 'setup development environment' 'make build down install up urls' \
	 '2' 'switch to prod env' 'make prod build recreate urls' \
	 '3' 'perform shopware update' 'make build update recreate urls' \
	 && :
.PHONY : help

build : compose.yml Dockerfile
	docker compose --profile platform --profile tasks --profile tools build
.PHONY : build

down : compose.yml
	docker compose --profile platform down --remove-orphans --rmi local -v
.PHONY : down

install : compose.yml dump.sql stageX/app permissions
	docker compose run --rm install
.PHONY : install

up : compose.yml dump.sql
	docker compose --profile platform up -d --remove-orphans
.PHONY : up

stop : compose.yml
	docker compose --profile platform stop
.PHONY : stop

urls : export BASH_ENV =
urls :
	@>&2 printf '%20s %-30s%s\n' \
	 'storefront' 'http://localhost:8000' '- : -' \
	 'administration' 'http://localhost:8000/admin' 'admin : password' \
	 'administration-watch' 'http://localhost:8080' 'admin : password' \
	 'minio' 'http://localhost:9001' 'user : password' \
	 'rabbitmq' 'http://localhost:15672' 'user : password' \
	 'mailhog' 'http://localhost:8025' '- : -'
.PHONY : urls

prod dev :
	[ "$$APP_ENV" = "$@" ] || sed -i "s/APP_ENV=.*/APP_ENV=$@/" .env
.PHONY : prod dev

recreate : compose.yml dump.sql stageX/app
	docker compose --profile platform up -d --remove-orphans --force-recreate
.PHONY : recreate

update : compose.yml dump.sql stageX/app permissions
	docker compose run --rm update
.PHONY : update

clean :
	rm -f Dockerfile
	rm -f dump_*.sql
.PHONY : clean

purge : clean down purge-shadow
	rm -fr stageX
	rm -f .env
	rm -f compose.yml
	rm -f compose.ide.dev.yml
	rm -f config.json
	rm -f dump.sql
.PHONY : purge

watch-administration : compose.yml
	docker compose run --rm --service-ports watch-administration
.PHONY : watch-administration

cli : compose.yml
	docker compose run --rm cli
.PHONY : cli

kaniko : compose.yml config.json
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
.PHONY : kaniko

Dockerfile :
	mustache plugins.yml $@.mustache >$@
.PHONY : Dockerfile

compose.yml compose.ide.dev.yml &:
	mustache plugins.yml compose.yml.mustache >compose.yml
	APP_ENV=dev docker-compose --profile tools config | yq 'del(.services.cli.profiles)' >compose.ide.dev.yml
.PHONY : compose.yml compose.ide.dev.yml

dump.sql :
	touch $@

permissions : compose.yml
	docker compose run --rm permissions
.PHONY : permissions

purge-shadow :
	rm -fr \
	 stage1/app/config/jwt \
	 stage1/app/config/packages \
	 stage1/app/bin/install.sh \
	 stage1/app/bin/update.sh \
	 stage1/app/bin/wait-for-it.sh \
	 stage1/app/config/services/custom.xml \
	 && :
.PHONY : purge-shadow

stageX/app : compose.yml
	mkdir -p $@
	SHOPWARE_IMAGE=$$(docker compose --profile platform config | yq '.services.shopware.image')
	CONTAINER_ID=$$(docker run -d --rm $$SHOPWARE_IMAGE sleep 60)
	docker cp -a "$$CONTAINER_ID":/app/composer.json $@
	docker cp -a "$$CONTAINER_ID":/app/composer.lock $@
	mkdir -p $@/public
	docker cp -a "$$CONTAINER_ID":/app/public $@
	mkdir -p $@/vendor
	docker cp -a "$$CONTAINER_ID":/app/vendor $@
	mkdir -p $@/var
	docker cp -a "$$CONTAINER_ID":/app/var/plugins.json $@/var/plugins.json
	for name in $$(yq '.static-plugins[].name' <plugins.yml); do
	 mkdir -p "$@/custom/static-plugins/$${name}/src/Resources/public"
	 docker cp -a "$${CONTAINER_ID}:/app/custom/static-plugins/$${name}/src/Resources/public" "$@/custom/static-plugins/$${name}/src/Resources"
	 mkdir -p "$@/custom/static-plugins/$${name}/src/Resources/app/administration/node_modules"
	 [ "dev" != "$$APP_ENV" ] || docker cp -a "$${CONTAINER_ID}:/app/custom/static-plugins/$${name}/src/Resources/app/administration/node_modules" "$@/custom/static-plugins/$${name}/src/Resources/app/administration"
	done
.PHONY : stageX/app

config.json :
	@read -rp 'GitHub username: ' USER
	@read -rsp 'GitHub PAT: ' PASSWORD
	@echo -n "{\"auths\":{\"ghcr.io\":{\"auth\":\"$$(echo $$USERNAME:$$PASSWORD | base64)\"}}}" >$@

db-dump : compose.yml
	[ ! -f dump.sql ] || mv dump.sql dump_$$(date +%s).sql
	docker compose exec db mysqldump -uroot -ppassword shopware 1>dump.sql
.PHONY : db-dump

stage1/app :
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
	 --exclude */config/jwt \
	 --exclude */config/packages \
	 --exclude */config/secrets \
	 --strip-components 1
.PHONY : stage1/app
