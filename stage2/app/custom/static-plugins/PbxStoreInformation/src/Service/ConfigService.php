<?php declare(strict_types=1);

namespace Pbx\StoreInformation\Service;

use Shopware\Core\Framework\Context;
use Shopware\Core\Framework\DataAbstractionLayer\EntityRepositoryInterface;
use Shopware\Core\Framework\DataAbstractionLayer\Search\Criteria;
use Shopware\Core\System\SalesChannel\SalesChannelContext;
use Shopware\Core\System\SystemConfig\SystemConfigService;

class ConfigService implements ConfigServiceInterface
{
    private const CONFIG_DOMAIN = 'PbxStoreInformation.data';
    private const CONFIG_COMPANY_ADDRESS = self::CONFIG_DOMAIN . '.companyAddress';

    private SystemConfigService $systemConfigService;

    private EntityRepositoryInterface $countryRepository;

    private EntityRepositoryInterface $countryStateRepository;

    public function __construct(
        SystemConfigService $systemConfigService,
        EntityRepositoryInterface $countryRepository,
        EntityRepositoryInterface $countryStateRepository
    ) {
        $this->systemConfigService = $systemConfigService;
        $this->countryRepository = $countryRepository;
        $this->countryStateRepository = $countryStateRepository;
    }

    public function parseStoreInformationConfig(SalesChannelContext $salesChannelContext): array
    {
        $config = $this->systemConfigService->getDomain(self::CONFIG_DOMAIN, $salesChannelContext->getSalesChannelId(), true);
        if (isset($config[self::CONFIG_COMPANY_ADDRESS])) {
            $this->processConfigAddress($config[self::CONFIG_COMPANY_ADDRESS], $salesChannelContext->getContext());
        }

        return $config;
    }

    private function processConfigAddress(array &$config, Context $context): array
    {
        $fields = [
            'country' => $this->countryRepository,
            'countryState' => $this->countryStateRepository,
        ];

        foreach ($fields as $id => $repository) {
            if (isset($config[$id])) {
                $config[$id] = $this->getEntityName($repository, $config[$id], $context);
            }
        }

        return $config;
    }

    private function getEntityName(EntityRepositoryInterface $entityRepository, string $id, Context $context): string
    {
        $entity = $entityRepository->search(new Criteria([$id]), $context)->first();
        $translated = $entity !== null ? $entity->getTranslated() : [];

        return $translated['name'] ?? '';
    }
}
