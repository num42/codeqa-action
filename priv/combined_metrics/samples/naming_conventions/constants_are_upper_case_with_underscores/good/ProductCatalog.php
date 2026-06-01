<?php

declare(strict_types=1);

namespace App\Catalog;

class ProductCatalog
{
    // Class constants use UPPER_CASE_WITH_UNDERSCORES — PSR-1
    public const STATUS_ACTIVE = 'active';
    public const STATUS_INACTIVE = 'inactive';
    public const STATUS_DISCONTINUED = 'discontinued';

    public const MAX_DESCRIPTION_LENGTH = 5000;
    public const MAX_NAME_LENGTH = 255;
    public const DEFAULT_PAGE_SIZE = 20;
    public const MAX_PAGE_SIZE = 100;

    protected const CACHE_TTL_SECONDS = 3600;
    private const DB_TABLE = 'products';

    private array $products = [];

    public function getStatus(string $sku): string
    {
        $product = $this->products[$sku] ?? null;

        if ($product === null) {
            return self::STATUS_INACTIVE;
        }

        return $product['status'];
    }

    public function isActive(string $sku): bool
    {
        return $this->getStatus($sku) === self::STATUS_ACTIVE;
    }

    public function paginate(array $items, int $page, int $perPage = self::DEFAULT_PAGE_SIZE): array
    {
        $perPage = min($perPage, self::MAX_PAGE_SIZE);
        $offset = ($page - 1) * $perPage;

        return array_slice($items, $offset, $perPage);
    }

    public function validateDescription(string $description): bool
    {
        return mb_strlen($description) <= self::MAX_DESCRIPTION_LENGTH;
    }

    public function validateName(string $name): bool
    {
        return mb_strlen($name) > 0 && mb_strlen($name) <= self::MAX_NAME_LENGTH;
    }
}
