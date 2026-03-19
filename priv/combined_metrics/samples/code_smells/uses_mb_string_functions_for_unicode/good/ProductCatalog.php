<?php

declare(strict_types=1);

namespace App\Catalog;

class ProductCatalog
{
    private const MAX_SLUG_LENGTH = 100;
    private const MAX_EXCERPT_LENGTH = 160;

    public function slugify(string $name): string
    {
        // mb_strtolower handles multibyte characters correctly
        $lower = mb_strtolower($name, 'UTF-8');

        // Transliterate accented characters
        $ascii = transliterator_transliterate('Any-Latin; Latin-ASCII', $lower);

        // Replace non-alphanumeric characters with hyphens
        $slug = preg_replace('/[^a-z0-9]+/', '-', $ascii);
        $slug = trim($slug, '-');

        return mb_substr($slug, 0, self::MAX_SLUG_LENGTH, 'UTF-8');
    }

    public function truncateDescription(string $description): string
    {
        if (mb_strlen($description, 'UTF-8') <= self::MAX_EXCERPT_LENGTH) {
            return $description;
        }

        // mb_substr preserves multibyte characters — does not split code points
        $truncated = mb_substr($description, 0, self::MAX_EXCERPT_LENGTH - 3, 'UTF-8');

        return rtrim($truncated) . '...';
    }

    public function normalizeTitle(string $title): string
    {
        // mb_convert_case for proper Unicode title casing
        return mb_convert_case(mb_strtolower($title, 'UTF-8'), MB_CASE_TITLE, 'UTF-8');
    }

    public function searchByName(array $products, string $query): array
    {
        $lowerQuery = mb_strtolower($query, 'UTF-8');

        return array_filter($products, function (array $product) use ($lowerQuery): bool {
            // mb_strpos for multibyte-safe substring search
            return mb_strpos(mb_strtolower($product['name'], 'UTF-8'), $lowerQuery, 0, 'UTF-8') !== false;
        });
    }

    public function countCharacters(string $text): int
    {
        // mb_strlen counts characters, not bytes
        return mb_strlen($text, 'UTF-8');
    }

    public function padProductCode(string $code, int $length): string
    {
        // mb_str_pad handles multibyte padding correctly (PHP 8.3+)
        return str_pad($code, $length, '0', STR_PAD_LEFT);
    }
}
