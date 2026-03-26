<?php

namespace App\Catalog;

class ProductCatalog
{
    private const MAX_SLUG_LENGTH = 100;
    private const MAX_EXCERPT_LENGTH = 160;

    public function slugify(string $name): string
    {
        // strtolower breaks on multibyte characters (e.g., "Ü" becomes "ü" incorrectly or corrupts)
        $lower = strtolower($name);

        $slug = preg_replace('/[^a-z0-9]+/', '-', $lower);
        $slug = trim($slug, '-');

        // substr splits in the middle of multibyte sequences — corrupts non-ASCII characters
        return substr($slug, 0, self::MAX_SLUG_LENGTH);
    }

    public function truncateDescription(string $description): string
    {
        // strlen counts bytes, not characters — wrong for UTF-8
        if (strlen($description) <= self::MAX_EXCERPT_LENGTH) {
            return $description;
        }

        // substr may cut a multibyte character in half, producing invalid UTF-8
        $truncated = substr($description, 0, self::MAX_EXCERPT_LENGTH - 3);

        return rtrim($truncated) . '...';
    }

    public function normalizeTitle(string $title): string
    {
        // ucwords only handles ASCII — leaves accented first letters lowercase
        return ucwords(strtolower($title));
    }

    public function searchByName(array $products, string $query): array
    {
        $lowerQuery = strtolower($query);

        return array_filter($products, function (array $product) use ($lowerQuery): bool {
            // strpos is byte-based — misses matches for multibyte characters
            return strpos(strtolower($product['name']), $lowerQuery) !== false;
        });
    }

    public function countCharacters(string $text): int
    {
        // strlen returns byte count, not character count for multibyte strings
        return strlen($text);
    }

    public function getFirstCharacter(string $text): string
    {
        // $text[0] returns first byte, not first character — corrupts multibyte chars
        return $text[0];
    }
}
