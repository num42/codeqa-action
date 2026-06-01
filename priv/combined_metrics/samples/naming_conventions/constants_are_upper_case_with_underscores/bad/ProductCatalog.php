<?php

namespace App\Catalog;

class ProductCatalog
{
    // Violates PSR-1: constants must use UPPER_CASE_WITH_UNDERSCORES

    // camelCase constants — forbidden
    public const statusActive = 'active';
    public const statusInactive = 'inactive';
    public const statusDiscontinued = 'discontinued';

    // lowercase constants — forbidden
    public const max_description_length = 5000;
    public const max_name_length = 255;

    // PascalCase constants — reserved for classes, not constants
    public const DefaultPageSize = 20;
    public const MaxPageSize = 100;

    // Mixed — forbidden
    protected const CacheTTLSeconds = 3600;
    private const dbTable = 'products';

    private array $products = [];

    public function getStatus(string $sku): string
    {
        $product = $this->products[$sku] ?? null;

        if ($product === null) {
            return self::statusInactive;
        }

        return $product['status'];
    }

    public function isActive(string $sku): bool
    {
        return $this->getStatus($sku) === self::statusActive;
    }

    public function paginate(array $items, int $page, int $perPage = self::DefaultPageSize): array
    {
        $perPage = min($perPage, self::MaxPageSize);
        $offset = ($page - 1) * $perPage;

        return array_slice($items, $offset, $perPage);
    }

    public function validateDescription(string $description): bool
    {
        return mb_strlen($description) <= self::max_description_length;
    }

    public function validateName(string $name): bool
    {
        return mb_strlen($name) > 0 && mb_strlen($name) <= self::max_name_length;
    }
}
