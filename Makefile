SHELL = /bin/bash
.SHELLFLAGS = -c
export BASH_ENV = $(PWD)/bin/activate
.ONESHELL :
.DEFAULT_GOAL := help

export SHOPWARE_VERSION = 6.4.11.1

help : export BASH_ENV =
help :
	@>&2 printf 'commands:\n'
	@>&2 printf '%20s - %s\n' \
	 'help' 'show this message' \
	 'build' 'build shopware image' \
	 'down' 'stop all services and remove their data' \
	 'install' 'run install script' \
	 'up' 'start all services' \
	 'urls' 'show services urls' \
	 'prod, dev' 'change environment in configuration' \
	 'recreate' 'recreate all services' \
	 'jwt' 'generate a new jwt secret' \
	 'update' 'run update script' \
	 'ide' 'prepare configuration and copy files from image for IDE' \
	 'stop' 'stop all services' \
	 'clean' 'remove unnecessary files' \
	 'purge' 'down and remove all runtime files' \
	 'watch-administration' 'run administration watch' \
	 'cli' 'open shell inside container' \
	 && :
	@>&2 printf '\nexamples:\n\n'
	@>&2 printf '%d. %s\n\n\t%s\n\n' \
	 '1' 'setup development environment' 'make build down install up urls' \
	 '2' 'setup dev env from dump.sql' 'make build down jwt update up urls' \
	 '3' 'switch to prod env' 'make prod build recreate urls' \
	 '4' 'perform shopware update' 'make build update recreate urls' \
	 && :
.PHONY : help

build : compose-runtime
	docker compose --profile platform --profile tasks --profile tools build $$DOCKER_BUILD_OPTS
.PHONY : build

down : compose-runtime
	docker compose --profile platform down --remove-orphans --rmi local -v
.PHONY : down

install : compose-runtime permissions
	docker compose run --rm install
.PHONY : install

up start : compose-runtime
	docker compose --profile platform up -d --remove-orphans
.PHONY : up start

stop : compose-runtime
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
	 'mailhog' 'http://localhost:8025' '- : -' \
	 'database' 'mysql://localhost:4406' 'user : password' \
	 && :
.PHONY : urls

prod dev :
	[ '@' = "$$APP_ENV" ] || sed -i "s/APP_ENV=.*/APP_ENV=\"$@\"/" .env
.PHONY : prod dev

recreate : compose-runtime
	docker compose --profile platform up -d --remove-orphans --force-recreate --renew-anon-volumes
.PHONY : recreate

jwt : compose-runtime permissions
	docker compose run --rm generate-jwt-secret
.PHONY : jwt

update : compose-runtime
	docker compose run --rm update
.PHONY : update

clean :
	rm -f dump_*.sql
.PHONY : clean

purge : down purge-shadow
	$(MAKE) --no-print-directory clean
	rm -f .env
	rm -f compose.ide.dev.yml
	rm -f compose.yml
	rm -f Dockerfile
	rm -f dump.sql
	rm -fr stageX
.PHONY : purge

watch-administration : dev-check compose-runtime
	docker compose run --rm --service-ports watch-administration
.PHONY : watch-administration

cli : compose-runtime
	docker compose run --rm cli
.PHONY : cli

Dockerfile compose.yml :
	mustache demo.yml $@.mustache >$@
.PHONY : Dockerfile compose.yml

dump.sql :
	touch $@

stageX/app/public/dev stageX/app/var/test/jwt :
	mkdir -p $@

compose-runtime : Dockerfile compose.yml dump.sql stageX/app/public/dev stageX/app/var/test/jwt
.PHONY : compose-runtime

dev-check :
	@[ 'dev' = "$$APP_ENV" ] || $(call tableflip,'not in dev env')
.PHONY : dev-check

permissions : compose-runtime
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
	 stage2/app/custom/static-plugins/*/src/Resources/app/administration/node_modules \
	 stage2/app/custom/static-plugins/*/src/Resources/public/administration \
	 stage2/app/custom/static-plugins/*/vendor \
	 && :
.PHONY : purge-shadow

compose.ide.dev.yml :
	APP_ENV=dev docker-compose --profile tools config | yq 'del(.services.cli.profiles)' >$@
.PHONY : compose.ide.dev.yml

stageX/app : compose-runtime
	docker compose up -d --force-recreate noop
	mkdir -p $@
	docker compose cp -a noop:/app/composer.json $@
	docker compose cp -a noop:/app/composer.lock $@
	mkdir -p $@/vendor
	docker compose cp -a noop:/app/vendor $@
	mkdir -p $@/vendor-bin
	docker compose cp -a noop:/app/vendor-bin $@
	for name in $$(yq '.static-plugins[].name' <demo.yml); do
	  mkdir -p "$@/custom/static-plugins/$${name}/src/Resources/app/administration/node_modules"
	  docker compose cp -a "noop:/app/custom/static-plugins/$${name}/src/Resources/app/administration/node_modules" "$@/custom/static-plugins/$${name}/src/Resources/app/administration"
	done
	docker compose rm -fs noop
.PHONY : stageX/app

ide : compose.ide.dev.yml stageX/app
.PHONY : ide

db-check :
	@[ -n "$$( docker compose ps db -q --status running 2>/dev/null)" ] || $(call tableflip,'db service is not running')
.PHONY : db-check

db-dump : db-check compose-runtime
	[ ! -s dump.sql ] || mv dump.sql dump_$$(date +%s).sql
	docker compose exec db mysqldump -uroot -ppassword shopware 1>dump.sql
.PHONY : db-dump

stage1/app :
	cd stage1
	rm -fr app
	mkdir app
	wget https://github.com/shopware/production/archive/refs/tags/v$${SHOPWARE_VERSION}.tar.gz -O - | tar -xzvC app \
	 --exclude "production-$${SHOPWARE_VERSION}/.github" \
	 --exclude "production-$${SHOPWARE_VERSION}/.gitlab-ci" \
	 --exclude "production-$${SHOPWARE_VERSION}/artifacts" \
	 --exclude "production-$${SHOPWARE_VERSION}/.dockerignore" \
	 --exclude "production-$${SHOPWARE_VERSION}/.gitignore" \
	 --exclude "production-$${SHOPWARE_VERSION}/.gitlab-ci.yml" \
	 --exclude "production-$${SHOPWARE_VERSION}/Dockerfile" \
	 --exclude "production-$${SHOPWARE_VERSION}/docker-compose.yml" \
	 --exclude "production-$${SHOPWARE_VERSION}/easy-coding-standard.php" \
	 --exclude "production-$${SHOPWARE_VERSION}/README.md" \
	 --exclude "production-$${SHOPWARE_VERSION}/bin/.gitignore" \
	 --exclude "production-$${SHOPWARE_VERSION}/config/jwt" \
	 --exclude "production-$${SHOPWARE_VERSION}/config/packages" \
	 --exclude "production-$${SHOPWARE_VERSION}/config/secrets" \
	 --exclude "production-$${SHOPWARE_VERSION}/config/README.md" \
	 --strip-components 1
	mkdir app/platform
	wget https://raw.githubusercontent.com/shopware/platform/v$${SHOPWARE_VERSION}/composer.json -O app/platform/composer.json
	mkdir app/vendor-bin
	for n in cs-fixer psalm; do
	  mkdir app/vendor-bin/$${n};
	  wget https://raw.githubusercontent.com/shopware/platform/v$${SHOPWARE_VERSION}/vendor-bin/$${n}/composer.json -O app/vendor-bin/$${n}/composer.json;
	done
.PHONY : stage1/app

img-size : | compose.yml
	@docker inspect $$(docker compose --profile platform config | yq '.services.shopware.image') -f '{{.Size}}' | numfmt --to iec
.PHONY : img-size

define tableflip
( >&2 printf '%s\n\n\t%s\n\n' $1 '(╯°□°)╯︵ ┻━┻' && exit 1)
endef
