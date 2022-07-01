<?php declare(strict_types=1);

use PhpCsFixer\Fixer\PhpTag\BlankLineAfterOpeningTagFixer;
use PhpCsFixer\Fixer\Strict\DeclareStrictTypesFixer;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;
use Symplify\EasyCodingStandard\ValueObject\Option;
use Symplify\EasyCodingStandard\ValueObject\Set\SetList;

return static function (ContainerConfigurator $containerConfigurator): void {
    $parameters = $containerConfigurator->parameters();
    $parameters->set(Option::CACHE_DIRECTORY, __DIR__ . '/var/cache/cs_fixer');
    $parameters->set(Option::PATHS, [__DIR__ . '/src', __DIR__ . '/tests']);

    $containerConfigurator->import(SetList::SYMFONY);
    $containerConfigurator->import(SetList::SYMFONY_RISKY);
    $containerConfigurator->import(SetList::ARRAY);
    $containerConfigurator->import(SetList::CONTROL_STRUCTURES);
    $containerConfigurator->import(SetList::STRICT);
    $containerConfigurator->import(SetList::PSR_12);
    $parameters->set(Option::SKIP, [
        BlankLineAfterOpeningTagFixer::class => null,
    ]);

    $services = $containerConfigurator->services();
    $services->set(DeclareStrictTypesFixer::class);
};
