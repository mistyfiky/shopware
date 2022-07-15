.DEFAULT_GOAL := checks

PROJECT_ROOT ?= ../../..
PLATFORM_ROOT ?= $(PROJECT_ROOT)/vendor/shopware/platform
CORE_ROOT ?= $(PLATFORM_ROOT)/src/Core
ADMINISTRATION_ROOT ?= $(PLATFORM_ROOT)/src/Administration

clean :
	rm -fr var
.PHONY : clean

ecs-lint ecs :
	php $(PLATFORM_ROOT)/vendor/bin/ecs check --config ecs.php
.PHONY : ecs-fix

ecs-fix :
	php $(PLATFORM_ROOT)/vendor/bin/ecs check --config ecs.php --fix
.PHONY : ecs-fix

$(PROJECT_ROOT)/var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml :
	php $(CORE_ROOT)/DevOps/StaticAnalyze/PHPStan/phpstan-bootstrap.php

phpstan : $(PROJECT_ROOT)/var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml
	php $(PLATFORM_ROOT)/vendor/bin/phpstan analyze --configuration phpstan.neon
.PHONY : phpstan

$(PROJECT_ROOT)/var/test/jwt :
	mkdir -p $@

test-init phpunit $(PROJECT_ROOT)/var/test/jwt/private.pem $(PROJECT_ROOT)/var/test/jwt/public.pem : export APP_ENV = test

$(PROJECT_ROOT)/var/test/jwt/private.pem $(PROJECT_ROOT)/var/test/jwt/public.pem &: | $(PROJECT_ROOT)/var/test/jwt
	php $(PROJECT_ROOT)/bin/console -n system:generate-jwt-secret -f --private-key-path $(firstword $|)/private.pem --public-key-path $(firstword $|)/public.pem

test-init : export FORCE_INSTALL_PLUGINS = 1
test-init : | $(PROJECT_ROOT)/var/test/jwt/private.pem $(PROJECT_ROOT)/var/test/jwt/public.pem
	php ../.common/TestBootstrap.php
.PHONY : test-init

phpunit :
	php $(PROJECT_ROOT)/vendor/bin/phpunit --configuration phpunit.xml
.PHONY : phpunit

eslint-lint eslint :
	$(ADMINISTRATION_ROOT)/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore --no-error-on-unmatched-pattern \
	 --config $(ADMINISTRATION_ROOT)/Resources/app/administration/.eslintrc.js --ext .js,.vue src/Resources/app/administration
.PHONY : eslint-lint

eslint-fix :
	$(ADMINISTRATION_ROOT)/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore --no-error-on-unmatched-pattern \
	 --config $(ADMINISTRATION_ROOT)/Resources/app/administration/.eslintrc.js --ext .js,.vue --fix src/Resources/app/administration
.PHONY : eslint-fix

checks check : ecs eslint phpstan phpunit
.PHONY : checks
