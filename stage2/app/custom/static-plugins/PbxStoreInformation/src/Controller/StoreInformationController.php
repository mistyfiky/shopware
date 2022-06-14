<?php declare(strict_types=1);

namespace Pbx\StoreInformation\Controller;

use OpenApi\Annotations as OA;
use Pbx\StoreInformation\PbxStoreInformation;
use Pbx\StoreInformation\Service\ConfigServiceInterface;
use Shopware\Core\Framework\Routing\Annotation\RouteScope;
use Shopware\Core\System\SalesChannel\SalesChannelContext;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Annotation\Route;

class StoreInformationController extends AbstractController
{
    private ConfigServiceInterface $configService;

    public function __construct(ConfigServiceInterface $configService)
    {
        $this->configService = $configService;
    }

    /**
     * @RouteScope(scopes={"store-api"})
     * @OA\Get(
     *     path="/store-info",
     *     summary="Gets store info",
     *     tags={"Store API", "Store Information"},
     *     @OA\Response(
     *         response="200",
     *         description="",
     *         content={
     *             @OA\MediaType(
     *                 mediaType="application/json",
     *                 @OA\Schema(
     *                     example={
     *                          "PbxStoreInformation.data.appstoreLink": "https://apps.apple.com/us/app/company",
     *                          "PbxStoreInformation.data.facebookUrl": "https://facebook.com/company",
     *                          "PbxStoreInformation.data.googlePlayLink": "https://play.google.com/store/apps/details",
     *                          "PbxStoreInformation.data.instagramUrl": "https://instagram.com/company",
     *                          "PbxStoreInformation.data.companyAddress": {
     *                              "city": "Krakow",
     *                              "email": "contact@example.com",
     *                              "street": "ul. Testowa 15",
     *                              "company": "Firma sp. z.o.o.",
     *                              "country": "Poland",
     *                              "zipcode": "31-522",
     *                              "phoneNumber": "777 777 777"
     *                          }
     *                     }
     *                 )
     *             )
     *         }
     *     )
     * )
     * @Route("/store-api/store-info", name="store-api.pbx2.store-info", methods={"GET"})
     */
    public function storeInformation(SalesChannelContext $salesChannelContext): JsonResponse
    {
        return new JsonResponse($this->configService->parseStoreInformationConfig($salesChannelContext));
    }
}
