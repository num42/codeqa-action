<?php

declare(strict_types=1);

namespace App\Catalog;

class ProductCatalog
{
    private array $products = [];

    public function addProduct(
        string $sku,
        string $name,
        float $price,
        int $stockQuantity,
        bool $isActive = true
    ): void {
        $this->products[$sku] = [
            'sku'           => $sku,
            'name'          => $name,
            'price'         => $price,
            'stock'         => $stockQuantity,
            'active'        => $isActive,
        ];
    }

    public function isInStock(string $sku): bool
    {
        return isset($this->products[$sku]) && $this->products[$sku]['stock'] > 0;
    }

    public function getStockCount(string $sku): int
    {
        return $this->products[$sku]['stock'] ?? 0;
    }

    public function getPrice(string $sku): float
    {
        if (!isset($this->products[$sku])) {
            throw new \InvalidArgumentException("Unknown SKU: {$sku}");
        }

        return $this->products[$sku]['price'];
    }

    public function search(string $query, bool $activeOnly = true): array
    {
        return array_filter($this->products, function (array $product) use ($query, $activeOnly): bool {
            if ($activeOnly && !$product['active']) {
                return false;
            }

            return str_contains(strtolower($product['name']), strtolower($query));
        });
    }

    public function countActive(): int
    {
        return count(array_filter($this->products, fn(array $p): bool => $p['active']));
    }

    public function deactivate(string $sku): bool
    {
        if (!isset($this->products[$sku])) {
            return false;
        }

        $this->products[$sku]['active'] = false;

        return true;
    }
}
