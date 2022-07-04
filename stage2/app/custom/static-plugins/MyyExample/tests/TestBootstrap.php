<?php declare(strict_types=1);

use Shopware\Core\TestBootstrapper;

require __DIR__ . '/../../../../vendor/shopware/core/TestBootstrapper.php';

(new TestBootstrapper())
    ->setPlatformEmbedded(false)
    ->addCallingPlugin(__DIR__ . '/../composer.json')
    ->bootstrap();
