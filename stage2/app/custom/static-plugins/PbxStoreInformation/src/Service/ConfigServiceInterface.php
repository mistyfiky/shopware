<?php declare(strict_types=1);

namespace Pbx\StoreInformation\Service;

use Shopware\Core\System\SalesChannel\SalesChannelContext;

interface ConfigServiceInterface
{
    public function parseStoreInformationConfig(SalesChannelContext $salesChannelContext): array;
}
