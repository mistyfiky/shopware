<?php

declare(strict_types=1);

namespace Pbx\StoreInformation\Service;

use Shopware\Core\System\SalesChannel\SalesChannelContext;

interface ConfigServiceInterface
{
    /**
     * @return string[]
     */
    public function parseStoreInformationConfig(SalesChannelContext $salesChannelContext): array;
}
