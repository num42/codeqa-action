using System;
using System.Collections.Generic;

namespace Inventory
{
    public class InventoryService
    {
        private readonly IProductRepository _productRepository;
        private readonly ILogger _logger;

        public InventoryService(IProductRepository productRepository, ILogger logger)
        {
            _productRepository = productRepository;
            _logger = logger;
        }

        public StockLevel GetStockLevel(string productCode)
        {
            var product = _productRepository.FindByCode(productCode);
            if (product == null)
                throw new ProductNotFoundException(productCode);

            return new StockLevel(product.Id, product.QuantityOnHand, product.ReorderThreshold);
        }

        public IReadOnlyList<Product> FindLowStockProducts(int threshold)
        {
            var allProducts = _productRepository.GetAll();
            var results = new List<Product>();

            foreach (var product in allProducts)
            {
                if (product.QuantityOnHand < threshold)
                    results.Add(product);
            }

            _logger.Info($"Found {results.Count} low-stock products below threshold {threshold}");
            return results.AsReadOnly();
        }

        public void AdjustStock(string productCode, int delta, string reason)
        {
            if (string.IsNullOrWhiteSpace(reason))
                throw new ArgumentException("Adjustment reason is required.", nameof(reason));

            var product = _productRepository.FindByCode(productCode)
                ?? throw new ProductNotFoundException(productCode);

            int updatedQuantity = product.QuantityOnHand + delta;
            if (updatedQuantity < 0)
                throw new InsufficientStockException(productCode, product.QuantityOnHand, delta);

            _productRepository.UpdateQuantity(product.Id, updatedQuantity);
            _logger.Info($"Adjusted {productCode} by {delta}: {reason}");
        }
    }
}
