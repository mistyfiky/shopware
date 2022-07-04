.DEFAULT_GOAL := checks

PLUGIN_ROOT=$(shell cd -P -- '$(shell dirname -- "$0")' && pwd -P)
export PROJECT_ROOT?=$(PLUGIN_ROOT)/../../..
ADMINISTRATION_ROOT=$(PROJECT_ROOT)/vendor/shopware/administration

clean :
	@rm -fr var/*
.PHONY : clean

ecs-lint ecs :
	@php $(PROJECT_ROOT)/vendor/bin/ecs check --config ecs.php
.PHONY : ecs-fix

ecs-fix :
	@php $(PROJECT_ROOT)/vendor/bin/ecs check --config ecs.php --fix
.PHONY : ecs-fix

$(PROJECT_ROOT)/var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml :
	@php $(PROJECT_ROOT)/vendor/shopware/core/DevOps/StaticAnalyze/PHPStan/phpstan-bootstrap.php

phpstan : $(PROJECT_ROOT)/var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml
	@php $(PROJECT_ROOT)/vendor/bin/phpstan analyze --configuration $(PLUGIN_ROOT)/phpstan.neon
.PHONY : phpstan

$(PROJECT_ROOT)/var/test/jwt/private.pem $(PROJECT_ROOT)/var/test/jwt/public.pem : export APP_ENV=test
$(PROJECT_ROOT)/var/test/jwt/private.pem $(PROJECT_ROOT)/var/test/jwt/public.pem :
	@php $(PROJECT_ROOT)/bin/console system:generate-jwt-secret --private-key-path $(PROJECT_ROOT)/var/test/jwt/private.pem --public-key-path $(PROJECT_ROOT)/var/test/jwt/public.pem

test-init : export APP_ENV=test
test-init : export FORCE_INSTALL=1
test-init : $(PROJECT_ROOT)/var/test/jwt/private.pem $(PROJECT_ROOT)/var/test/jwt/public.pem
	@php $(PLUGIN_ROOT)/tests/TestBootstrap.php
.PHONY : test-init

phpunit : export APP_ENV=test
phpunit : $(PROJECT_ROOT)/var/test/jwt/private.pem $(PROJECT_ROOT)/var/test/jwt/public.pem
	@cd $(PROJECT_ROOT); php vendor/bin/phpunit --configuration=$(PLUGIN_ROOT)
.PHONY : phpunit

eslint-lint eslint :
	@$(ADMINISTRATION_ROOT)/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore --no-error-on-unmatched-pattern \
	 --config $(ADMINISTRATION_ROOT)/Resources/app/administration/.eslintrc.js --ext .js,.vue src/Resources/app/administration
.PHONY : eslint-lint

eslint-fix :
	@$(ADMINISTRATION_ROOT)/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore --no-error-on-unmatched-pattern \
	 --config $(ADMINISTRATION_ROOT)/Resources/app/administration/.eslintrc.js --ext .js,.vue --fix src/Resources/app/administration
.PHONY : eslint-fix

checks : ecs eslint phpstan phpunit
.PHONY : checks
