using System;
using System.Collections.Generic;

namespace Catalog
{
    public class ProductCatalog
    {
        private readonly Dictionary<string, Product> _products = new();

        public bool TryGetProduct(string sku, out Product product)
        {
            return _products.TryGetValue(sku, out product);
        }

        public bool TryParseQuantity(string input, out int quantity)
        {
            return int.TryParse(input, out quantity) && quantity > 0;
        }

        public bool TryApplyDiscount(string couponCode, decimal originalPrice, out decimal discountedPrice)
        {
            discountedPrice = originalPrice;

            if (string.IsNullOrWhiteSpace(couponCode))
                return false;

            if (!_discountMap.TryGetValue(couponCode, out decimal rate))
                return false;

            discountedPrice = originalPrice * (1 - rate);
            return true;
        }

        public decimal CalculateTotalPrice(string sku, string quantityInput, string couponCode)
        {
            if (!TryGetProduct(sku, out var product))
                return 0m;

            if (!TryParseQuantity(quantityInput, out int quantity))
                return 0m;

            decimal lineTotal = product.UnitPrice * quantity;

            if (TryApplyDiscount(couponCode, lineTotal, out decimal discounted))
                return discounted;

            return lineTotal;
        }

        public IReadOnlyList<Product> SearchByCategory(string category)
        {
            var results = new List<Product>();
            foreach (var product in _products.Values)
            {
                if (product.Category.Equals(category, StringComparison.OrdinalIgnoreCase))
                    results.Add(product);
            }
            return results.AsReadOnly();
        }

        private readonly Dictionary<string, decimal> _discountMap = new()
        {
            ["SAVE10"] = 0.10m,
            ["SAVE20"] = 0.20m,
        };
    }
}
