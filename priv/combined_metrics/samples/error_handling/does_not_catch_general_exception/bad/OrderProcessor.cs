using System;
using System.Data.SqlClient;
using System.IO;

namespace OrderService
{
    public class OrderProcessor
    {
        private readonly IOrderRepository _repository;
        private readonly ILogger _logger;

        public OrderProcessor(IOrderRepository repository, ILogger logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public void ProcessOrder(int orderId)
        {
            try
            {
                var order = _repository.GetById(orderId);
                ValidateOrder(order);
                _repository.MarkAsProcessed(order);
            }
            catch (Exception ex)
            {
                // Catches everything — hides programming errors, thread aborts, etc.
                _logger.Error("Something went wrong: " + ex.Message);
            }
        }

        public bool TrySaveInvoice(Order order, string path)
        {
            try
            {
                var content = GenerateInvoiceContent(order);
                File.WriteAllText(path, content);
                return true;
            }
            catch (Exception)
            {
                // Swallows all exceptions silently, including OutOfMemoryException
                return false;
            }
        }

        public void FinalizeOrders()
        {
            try
            {
                var pending = _repository.GetPendingOrders();
                foreach (var order in pending)
                {
                    _repository.Finalize(order);
                }
            }
            catch (Exception ex)
            {
                // Re-throwing System.Exception as a new Exception loses the specific type
                throw new Exception("Finalization failed", ex);
            }
        }

        private void ValidateOrder(Order order)
        {
            if (order.Items.Count == 0)
                throw new InvalidOrderException("Order must contain at least one item");
        }

        private string GenerateInvoiceContent(Order order) => $"Invoice for order {order.Id}";
    }
}
