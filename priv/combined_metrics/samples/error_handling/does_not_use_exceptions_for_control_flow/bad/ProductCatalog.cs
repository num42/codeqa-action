using System;
using System.Collections.Generic;

namespace Catalog
{
    public class ProductCatalog
    {
        private readonly Dictionary<string, Product> _products = new();

        // Using exception to detect "not found" as normal control flow
        public Product GetProduct(string sku)
        {
            try
            {
                return _products[sku]; // throws KeyNotFoundException for missing keys
            }
            catch (KeyNotFoundException)
            {
                return null;
            }
        }

        // Using FormatException to drive parsing logic
        public int ParseQuantity(string input)
        {
            try
            {
                return int.Parse(input);
            }
            catch (FormatException)
            {
                return 0;
            }
            catch (OverflowException)
            {
                return 0;
            }
        }

        // Using exception to check discount applicability
        public decimal ApplyDiscount(string couponCode, decimal originalPrice)
        {
            try
            {
                decimal rate = _discountMap[couponCode]; // throws if not found
                return originalPrice * (1 - rate);
            }
            catch (KeyNotFoundException)
            {
                return originalPrice; // no discount — but this is expected, not exceptional
            }
        }

        public decimal CalculateTotalPrice(string sku, string quantityInput, string couponCode)
        {
            var product = GetProduct(sku);
            if (product == null) return 0m;

            int quantity = ParseQuantity(quantityInput);
            if (quantity <= 0) return 0m;

            decimal lineTotal = product.UnitPrice * quantity;
            return ApplyDiscount(couponCode, lineTotal);
        }

        public IReadOnlyList<Product> SearchByCategory(string category)
        {
            var results = new List<Product>();
            try
            {
                foreach (var product in _products.Values)
                {
                    // Throwing to break from nested search — very bad pattern
                    if (results.Count >= 50)
                        throw new InvalidOperationException("limit reached");

                    if (product.Category.Equals(category, StringComparison.OrdinalIgnoreCase))
                        results.Add(product);
                }
            }
            catch (InvalidOperationException)
            {
                // silently stop — exception used as a loop break
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
