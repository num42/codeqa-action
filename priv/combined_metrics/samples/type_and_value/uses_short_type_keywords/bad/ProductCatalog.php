<?php

namespace App\Catalog;

class ProductCatalog
{
    private array $products = [];

    // PSR-12 requires `int`, `bool`, `float` — not `integer`, `boolean`, `double`
    public function addProduct(
        string $sku,
        string $name,
        double $price,
        integer $stockQuantity,
        boolean $isActive = true
    ): void {
        $this->products[$sku] = [
            'sku'    => $sku,
            'name'   => $name,
            'price'  => $price,
            'stock'  => $stockQuantity,
            'active' => $isActive,
        ];
    }

    public function isInStock(string $sku): boolean
    {
        return isset($this->products[$sku]) && $this->products[$sku]['stock'] > 0;
    }

    public function getStockCount(string $sku): integer
    {
        return $this->products[$sku]['stock'] ?? 0;
    }

    public function getPrice(string $sku): double
    {
        if (!isset($this->products[$sku])) {
            throw new \InvalidArgumentException("Unknown SKU: {$sku}");
        }

        return $this->products[$sku]['price'];
    }

    public function search(string $query, boolean $activeOnly = true): array
    {
        return array_filter($this->products, function (array $product) use ($query, $activeOnly): boolean {
            if ($activeOnly && !$product['active']) {
                return false;
            }

            return str_contains(strtolower($product['name']), strtolower($query));
        });
    }

    public function countActive(): integer
    {
        return count(array_filter($this->products, fn(array $p): boolean => $p['active']));
    }

    public function deactivate(string $sku): boolean
    {
        if (!isset($this->products[$sku])) {
            return false;
        }

        $this->products[$sku]['active'] = false;

        return true;
    }
}
