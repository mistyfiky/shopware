.DEFAULT_GOAL := checks

PLUGIN_ROOT=$(shell cd -P -- '$(shell dirname -- "$0")' && pwd -P)
PROJECT_ROOT=$(PLUGIN_ROOT)/../../..
ADMINISTRATION_ROOT=$(PROJECT_ROOT)/vendor/shopware/administration

clean :
	@rm -fr var
.PHONY : clean

ecs-lint ecs :
	@php $(PROJECT_ROOT)/vendor/bin/ecs check
.PHONY : ecs-fix

ecs-fix :
	@php $(PROJECT_ROOT)/vendor/bin/ecs check --fix
.PHONY : ecs-fix

$(PROJECT_ROOT)/var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml :
	@php $(PROJECT_ROOT)/vendor/shopware/core/DevOps/StaticAnalyze/PHPStan/phpstan-bootstrap.php

phpstan : $(PROJECT_ROOT)/var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml
	@php $(PROJECT_ROOT)/vendor/bin/phpstan analyze --configuration $(PLUGIN_ROOT)/phpstan.neon
.PHONY : phpstan

phpunit : export APP_ENV=test
phpunit :
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
