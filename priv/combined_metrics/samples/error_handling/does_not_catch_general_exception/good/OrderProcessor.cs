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
            catch (SqlException ex)
            {
                _logger.Error("Database error while processing order {orderId}", ex);
                throw new OrderProcessingException("Failed to access order data", ex);
            }
            catch (InvalidOrderException ex)
            {
                _logger.Warning("Order {orderId} failed validation: {message}", ex.Message);
                throw;
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
            catch (UnauthorizedAccessException ex)
            {
                _logger.Warning("Cannot write invoice to {path}: access denied", ex);
                return false;
            }
            catch (IOException ex)
            {
                _logger.Warning("IO error writing invoice to {path}", ex);
                return false;
            }
        }

        private void ValidateOrder(Order order)
        {
            if (order.Items.Count == 0)
                throw new InvalidOrderException("Order must contain at least one item");
            if (order.CustomerId <= 0)
                throw new InvalidOrderException("Order must be associated with a valid customer");
        }

        private string GenerateInvoiceContent(Order order) => $"Invoice for order {order.Id}";
    }
}
