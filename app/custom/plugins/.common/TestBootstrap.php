<?php declare(strict_types=1);

use Shopware\Core\TestBootstrapper;

require __DIR__ . '/../../../vendor/shopware/platform/src/Core/TestBootstrapper.php';

$forceInstallPlugins = (bool) ($_SERVER['FORCE_INSTALL_PLUGINS'] ?? false);

(new TestBootstrapper())
    ->setPlatformEmbedded(true)
    ->addCallingPlugin(getcwd() . '/composer.json')
    ->setForceInstallPlugins($forceInstallPlugins)
    ->bootstrap();
