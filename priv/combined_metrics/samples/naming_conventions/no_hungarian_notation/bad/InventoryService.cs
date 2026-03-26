using System;
using System.Collections.Generic;

namespace Inventory
{
    public class InventoryService
    {
        private readonly IProductRepository _objProductRepository;
        private readonly ILogger _objLogger;

        public InventoryService(IProductRepository objProductRepository, ILogger objLogger)
        {
            _objProductRepository = objProductRepository;
            _objLogger = objLogger;
        }

        public StockLevel GetStockLevel(string strProductCode)
        {
            var objProduct = _objProductRepository.FindByCode(strProductCode);
            if (objProduct == null)
                throw new ProductNotFoundException(strProductCode);

            return new StockLevel(objProduct.Id, objProduct.QuantityOnHand, objProduct.ReorderThreshold);
        }

        public IReadOnlyList<Product> FindLowStockProducts(int iThreshold)
        {
            var lstAllProducts = _objProductRepository.GetAll();
            var lstResults = new List<Product>();

            foreach (var objProduct in lstAllProducts)
            {
                if (objProduct.QuantityOnHand < iThreshold)
                    lstResults.Add(objProduct);
            }

            _objLogger.Info($"Found {lstResults.Count} low-stock products below threshold {iThreshold}");
            return lstResults.AsReadOnly();
        }

        public void AdjustStock(string strProductCode, int iDelta, string strReason)
        {
            if (string.IsNullOrWhiteSpace(strReason))
                throw new ArgumentException("Adjustment reason is required.", nameof(strReason));

            var objProduct = _objProductRepository.FindByCode(strProductCode)
                ?? throw new ProductNotFoundException(strProductCode);

            int iUpdatedQuantity = objProduct.QuantityOnHand + iDelta;
            if (iUpdatedQuantity < 0)
                throw new InsufficientStockException(strProductCode, objProduct.QuantityOnHand, iDelta);

            _objProductRepository.UpdateQuantity(objProduct.Id, iUpdatedQuantity);
            _objLogger.Info($"Adjusted {strProductCode} by {iDelta}: {strReason}");
        }
    }
}
