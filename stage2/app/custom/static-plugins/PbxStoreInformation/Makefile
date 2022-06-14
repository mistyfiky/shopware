.DEFAULT_GOAL := help

PLUGIN_ROOT=$(shell cd -P -- '$(shell dirname -- "$0")' && pwd -P)
PROJECT_ROOT=$(PLUGIN_ROOT)/../../..
TOOLS_ROOT=$(PROJECT_ROOT)/tools
ADMINISTRATION_ROOT=$(PROJECT_ROOT)/vendor/shopware/administration/Resources/app/administration

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help

ecs-fix: ## Run easy coding standard on php
	@php $(TOOLS_ROOT)/vendor/bin/ecs check --fix --config=$(PROJECT_ROOT)/easy-coding-standard.php src tests
	@php $(TOOLS_ROOT)/vendor/bin/ecs check --fix src tests
.PHONY: ecs-fix

phpstan:
	@php $(PLUGIN_ROOT)/bin/phpstan-config-generator.php
	@php $(TOOLS_ROOT)/vendor/bin/phpstan analyze --configuration $(PLUGIN_ROOT)/phpstan.neon src tests
.PHONY: phpstan

psalm:
	@cd $(TOOLS_ROOT); php vendor/bin/psalm --config=$(PLUGIN_ROOT)/psalm.xml $(PLUGIN_ROOT)/src $(PLUGIN_ROOT)/tests --diff --threads=4
.PHONY: psalm

phpunit:
	@$(TOOLS_ROOT)/vendor/bin/phpunit $(test)
.PHONY: phpunit

phpunit-coverage:
	make phpunit test="--coverage-html coverage $(test)"
.PHONY: phpunit

administration-fix: ## Run eslint on the administration files
	$(ADMINISTRATION_ROOT)/node_modules/.bin/eslint --ignore-path .eslintignore --config $(ADMINISTRATION_ROOT)/.eslintrc.js --ext .js,.vue --fix src/Resources/app/administration
.PHONY: administration-fix

administration-lint: ## Run eslint on the administration files
	$(ADMINISTRATION_ROOT)/node_modules/.bin/eslint --ignore-path .eslintignore --config $(ADMINISTRATION_ROOT)/.eslintrc.js --ext .js,.vue src/Resources/app/administration
.PHONY: administration-lint
