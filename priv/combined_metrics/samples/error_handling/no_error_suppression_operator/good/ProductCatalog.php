<?php

declare(strict_types=1);

namespace App\Catalog;

use App\Exception\CatalogImportException;
use App\Exception\ImageProcessingException;

class ProductCatalog
{
    public function __construct(
        private string $storageBasePath,
        private \Psr\Log\LoggerInterface $logger
    ) {
    }

    public function importFromCsv(string $filePath): array
    {
        if (!file_exists($filePath)) {
            throw new CatalogImportException("Import file not found: {$filePath}");
        }

        if (!is_readable($filePath)) {
            throw new CatalogImportException("Import file is not readable: {$filePath}");
        }

        $handle = fopen($filePath, 'r');
        if ($handle === false) {
            throw new CatalogImportException("Failed to open import file: {$filePath}");
        }

        try {
            return $this->parseRows($handle);
        } finally {
            fclose($handle);
        }
    }

    public function saveProductImage(string $sku, string $sourcePath): string
    {
        $destination = "{$this->storageBasePath}/{$sku}.jpg";

        if (!file_exists($sourcePath)) {
            throw new ImageProcessingException("Source image not found: {$sourcePath}");
        }

        $targetDir = dirname($destination);
        if (!is_dir($targetDir) && !mkdir($targetDir, 0755, true)) {
            throw new ImageProcessingException("Failed to create directory: {$targetDir}");
        }

        if (!copy($sourcePath, $destination)) {
            throw new ImageProcessingException(
                "Failed to copy image from {$sourcePath} to {$destination}"
            );
        }

        return $destination;
    }

    private function parseRows($handle): array
    {
        $products = [];
        $headers = fgetcsv($handle);

        if ($headers === false) {
            throw new CatalogImportException("CSV file is empty or unreadable");
        }

        while (($row = fgetcsv($handle)) !== false) {
            $products[] = array_combine($headers, $row);
        }

        return $products;
    }
}
