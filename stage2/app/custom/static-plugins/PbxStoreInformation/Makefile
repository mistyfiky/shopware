.DEFAULT_GOAL := checks

PLUGIN_ROOT=$(shell cd -P -- '$(shell dirname -- "$0")' && pwd -P)
PROJECT_ROOT=$(PLUGIN_ROOT)/../../..
ADMINISTRATION_ROOT=$(PROJECT_ROOT)/vendor/shopware/administration

clean :
	@rm -fr var
	@rm -f .phpunit.result.cache
	@rm -f phpstan.neon
.PHONY : clean

ecs-lint ecs :
	@php $(PROJECT_ROOT)/vendor/bin/ecs check
.PHONY : ecs-fix

ecs-fix :
	@php $(PROJECT_ROOT)/vendor/bin/ecs check --fix
.PHONY : ecs-fix

phpstan:
	@php $(PLUGIN_ROOT)/bin/phpstan-config-generator.php
	@php $(PROJECT_ROOT)/vendor/bin/phpstan analyze --configuration $(PLUGIN_ROOT)/phpstan.neon src tests
.PHONY : phpstan

phpunit : export APP_ENV=test
phpunit :
	@cd $(PROJECT_ROOT); php vendor/bin/phpunit --configuration=$(PLUGIN_ROOT)
.PHONY : phpunit

administration-fix :
	@$(ADMINISTRATION_ROOT)/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore \
	 --config $(ADMINISTRATION_ROOT)/Resources/app/administration/.eslintrc.js --ext .js,.vue --fix src/Resources/app/administration
.PHONY : administration-fix

administration-lint :
	@$(ADMINISTRATION_ROOT)/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore \
	 --config $(ADMINISTRATION_ROOT)/Resources/app/administration/.eslintrc.js --ext .js,.vue src/Resources/app/administration
.PHONY : administration-lint

checks : ecs-lint phpstan phpunit administration-lint
.PHONY : checks
