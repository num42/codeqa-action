<?php

namespace App\Catalog;

class ProductCatalog
{
    public function __construct(
        private string $storageBasePath
    ) {
    }

    public function importFromCsv(string $filePath): array
    {
        // @ suppresses any warnings/errors from fopen — failures are invisible
        $handle = @fopen($filePath, 'r');

        if ($handle === false) {
            return [];
        }

        $products = [];
        // @ suppresses errors if file becomes unreadable mid-read
        $headers = @fgetcsv($handle);

        while (($row = @fgetcsv($handle)) !== false) {
            $products[] = array_combine($headers, $row);
        }

        @fclose($handle);

        return $products;
    }

    public function saveProductImage(string $sku, string $sourcePath): string
    {
        $destination = "{$this->storageBasePath}/{$sku}.jpg";

        // @ suppresses mkdir warnings — no way to know if it actually succeeded
        @mkdir(dirname($destination), 0755, true);

        // @ suppresses copy errors — destination may not exist but no error is thrown
        @copy($sourcePath, $destination);

        return $destination;
    }

    public function deleteImage(string $sku): bool
    {
        $path = "{$this->storageBasePath}/{$sku}.jpg";

        // @ suppresses warnings if file doesn't exist — silent success/failure
        return @unlink($path);
    }

    public function readConfig(string $iniPath): array
    {
        // @ hides parse errors in the ini file
        $config = @parse_ini_file($iniPath, true);

        return $config ?: [];
    }
}
