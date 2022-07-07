.DEFAULT_GOAL := checks

clean :
	@rm -fr var
.PHONY : clean

ecs-lint ecs :
	@php ../../../vendor/bin/ecs check --config ecs.php
.PHONY : ecs-fix

ecs-fix :
	@php ../../../vendor/bin/ecs check --config ecs.php --fix
.PHONY : ecs-fix

../../../var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml :
	@php ../../../vendor/shopware/core/DevOps/StaticAnalyze/PHPStan/phpstan-bootstrap.php

phpstan : ../../../var/cache/phpstan_dev/Shopware_Core_DevOps_StaticAnalyze_StaticAnalyzeKernelPhpstan_devDebugContainer.xml
	@php ../../../vendor/bin/phpstan analyze --configuration phpstan.neon
.PHONY : phpstan

../../../var/test/jwt/private.pem ../../../var/test/jwt/public.pem : export APP_ENV = test
../../../var/test/jwt/private.pem ../../../var/test/jwt/public.pem :
	@php ../../../bin/console system:generate-jwt-secret --private-key-path ../../../var/test/jwt/private.pem --public-key-path ../../../var/test/jwt/public.pem

test-init phpunit : export APP_ENV = test

test-init : export FORCE_INSTALL = 1
test-init : ../../../var/test/jwt/private.pem ../../../var/test/jwt/public.pem
	@php ../.common/TestBootstrap.php
.PHONY : test-init

phpunit : ../../../var/test/jwt/private.pem ../../../var/test/jwt/public.pem
	@php ../../../vendor/bin/phpunit
.PHONY : phpunit

eslint-lint eslint :
	@../../../vendor/shopware/administration/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore --no-error-on-unmatched-pattern \
	 --config ../../../vendor/shopware/administration/Resources/app/administration/.eslintrc.js --ext .js,.vue src/Resources/app/administration
.PHONY : eslint-lint

eslint-fix :
	@../../../vendor/shopware/administration/Resources/app/administration/node_modules/.bin/eslint --ignore-path .eslintignore --no-error-on-unmatched-pattern \
	 --config ../../../vendor/shopware/administration/Resources/app/administration/.eslintrc.js --ext .js,.vue --fix src/Resources/app/administration
.PHONY : eslint-fix

checks check : ecs eslint phpstan phpunit
.PHONY : checks
