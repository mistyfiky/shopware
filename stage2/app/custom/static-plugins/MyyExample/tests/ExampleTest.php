<?php declare(strict_types=1);

namespace Myy\Example\Test;

use Myy\Example\Test\Util\ExampleTestBehaviour;
use PHPUnit\Framework\TestCase;

class ExampleTest extends TestCase
{
    use ExampleTestBehaviour;

    public function test(): void
    {
        static::assertNotNull($this->getValidCategoryId());
    }
}
