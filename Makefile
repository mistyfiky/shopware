SHELL = /bin/bash
.SHELLFLAGS = -c
export BASH_ENV = $(PWD)/.bin/activate
.ONESHELL :
.DEFAULT_GOAL := help

help : export BASH_ENV =
help :
	@>&2 printf 'commands:\n'
	@>&2 printf '%10s - %s\n' \
	 'help' 'show this message' \
	 'prod, dev' 'change environment in configuration' \
	 'init' 'build, destroy old services, perform install or update and run all services' \
	 'start' 'start all services' \
	 'upgrade' 'build, perform update and recreate all services' \
	 'stop' 'stop all services' \
	 'ide' 'copy files from image for ide indexing' \
	 && :
.PHONY : help

urls : export BASH_ENV =
urls :
	@>&2 printf '%20s %-30s%s\n' \
	 'admin' 'http://localhost:8000/admin' 'admin : password' \
	 'admin-watch' 'http://localhost:8080' 'admin : password' \
	 'redis' '-' '- : -' \
	 'mysql' 'mysql://localhost:4406' 'user : password' \
	 'rabbitmq' 'http://localhost:15672' 'user : password' \
	 'minio' 'http://localhost:9001' 'user : password' \
	 'mailhog' 'http://localhost:8025' '- : -' \
	 && :
.PHONY : urls

init :
	@if [ -s dump.sql ]; then
	  make --no-print-directory build down generate-jwt update up urls
	else
	  make --no-print-directory build down install up urls
	fi
.PHONY : init

upgrade :
	@make --no-print-directory build update recreate urls
.PHONY : upgrade

clean :
	rm -f dump_*.sql
.PHONY : clean

purge : down clean
	rm -f \
	 .env \
	 compose.yml \
	 Dockerfile \
	 dump.sql \
	 && :
	rm -fr \
	 app/public/ \
	 app/src/ \
 	 app/vendor/ \
 	 app/composer.json \
 	 app/composer.lock \
 	 && :
	rm -fr \
	 app/custom/plugins/*/src/Resources/app/administration/node_modules/ \
	 app/custom/plugins/*/src/Resources/public/administration/ \
 	 app/custom/plugins/*/var/ \
 	 app/custom/plugins/*/vendor/ \
 	 && :
.PHONY : purge

prod dev :
	[ '@' = "$$APP_ENV" ] || sed -i "s/APP_ENV=.*/APP_ENV=\"$@\"/" .env
.PHONY : prod dev

build : compose-runtime
	docker compose build $$DOCKER_BUILD_OPTS
.PHONY : build

up start : compose-runtime
	docker compose up -d --remove-orphans
.PHONY : up start

stop : compose-runtime
	docker compose stop
.PHONY : stop

recreate : compose-runtime
	docker compose up -d --remove-orphans --force-recreate --renew-anon-volumes
.PHONY : recreate

down : compose-runtime
	docker compose down --remove-orphans --rmi local -v
.PHONY : down

generate-jwt jwt-generate : compose-runtime
	docker compose run --rm shopware bin/console -n system:generate-jwt-secret
.PHONY : generate-jwt jwt-generate

install : compose-runtime
	docker compose run --rm \
     -e SHOP_NAME="Storefront" \
     -e SHOP_EMAIL="admin@localhost" \
     -e SHOP_LOCALE="en-GB" \
     -e SHOP_CURRENCY="EUR" \
     -e ADMIN_PASSWORD="password" \
	 shopware bin/wait-for-it.sh -s -t 60 -h mysql -p 3306 -- bin/install.sh
.PHONY : install

update : compose-runtime
	docker compose run --rm shopware bin/wait-for-it.sh -s -t 60 -h mysql -p 3306 -- bin/update.sh
.PHONY : update

cli ssh bash shell: compose-runtime
	docker compose run --rm shopware bash
.PHONY : cli ssh bash shell

app/public app/src :
	CID=$$(docker compose run --rm -d --no-deps shopware tail -f /dev/null)
	mkdir -p $@ && docker cp -a $${CID}:/$@ $(dir $@)
	docker kill $${CID}
.PHONY : app/public app/src

app/vendor :
	CID=$$(docker compose run --rm -d --no-deps shopware tail -f /dev/null)
	mkdir -p $@ && docker cp -a $${CID}:/$@ $(dir $@)
	docker kill $${CID}
	rm -fr $@/shopware/platform/src/Administration/Resources/app/administration/node_modules
	for package in $$(yq '.composer-plugins[].package' demo.yml); do \
	  rm -fr $@/$$package/src/Resources/app/administration/node_modules; \
	done
.PHONY : app/vendor

app/composer.json app/composer.lock :
	CID=$$(docker compose run --rm -d --no-deps shopware tail -f /dev/null)
	docker cp -a $${CID}:/$@ $@
	docker kill $${CID}
.PHONY : app/composer.json app/composer.lock

ide : app/public app/src app/vendor app/composer.json app/composer.lock
.PHONY : ide

admin-watch watch-admin : dev-check compose-runtime
	# FIXME run with SHOPWARE_ADMIN_BUILD_ONLY_EXTENSIONS="1"
	docker compose run --rm -p 8080:80 \
     -e HOST="0.0.0.0" \
     -e PORT="80" \
     -e APP_URL="http://web" \
     -e ESLINT_DISABLE="true" \
     -e DISABLE_ADMIN_COMPILATION_TYPECHECK="1" \
	 shopware npm run --prefix vendor/shopware/platform/src/Administration/Resources/app/administration dev
.PHONY : admin-watch watch-admin

Dockerfile compose.yml :
	mustache demo.yml .docker/$@.mustache >$@
.PHONY : Dockerfile compose.yml

dump.sql :
	touch $@

db-dump dump-db : db-check compose-runtime
	[ ! -s dump.sql ] || mv dump.sql dump_$$(date +%s).sql
	docker compose exec mysql mysqldump -uroot -ppassword --opt shopware >dump.sql
.PHONY : db-dump dump-db

compose-runtime : Dockerfile compose.yml dump.sql
.PHONY : compose-runtime

img-size : | compose.yml
	@docker inspect $$(docker compose config | yq '.services.shopware.image') -f '{{.Size}}' | numfmt --to iec
.PHONY : img-size

dev-check :
	@[ 'dev' = "$$APP_ENV" ] || $(call tableflip,'not in dev env')
.PHONY : dev-check

db-check :
	@[ -n "$$( docker compose ps mysql -q --status running 2>/dev/null)" ] || $(call tableflip,'db service is not running')
.PHONY : db-check

define tableflip
( >&2 printf '%s\n\n\t%s\n\n' $1 '(╯°□°)╯︵ ┻━┻' && exit 1)
endef
