package com.example.orders;

import java.io.IOException;
import java.sql.SQLException;
import java.util.logging.Level;
import java.util.logging.Logger;

public class OrderService {

    private static final Logger logger = Logger.getLogger(OrderService.class.getName());

    private final OrderRepository repository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository repository, PaymentGateway paymentGateway) {
        this.repository = repository;
        this.paymentGateway = paymentGateway;
    }

    public Order placeOrder(Cart cart, PaymentDetails payment) {
        Order order = Order.from(cart);

        try {
            paymentGateway.charge(payment, order.totalAmount());
        } catch (PaymentDeclinedException e) {
            // Payment was declined by the gateway; surface this to the caller
            // so they can prompt the user to retry with different details.
            throw new OrderPlacementException("Payment declined: " + e.getReason(), e);
        } catch (IOException e) {
            // Network error communicating with the payment gateway.
            // Log at ERROR level and rethrow so the caller can handle retries.
            logger.log(Level.SEVERE, "Network failure while charging payment for order", e);
            throw new OrderPlacementException("Payment gateway unreachable", e);
        }

        try {
            repository.save(order);
        } catch (SQLException e) {
            // Database write failed after successful payment — log with order
            // context so support can reconcile the charge manually.
            logger.log(Level.SEVERE, "Failed to persist order after successful payment: orderId=" + order.getId(), e);
            throw new OrderPlacementException("Order could not be saved", e);
        }

        return order;
    }

    public void cancelOrder(String orderId) {
        Order order;
        try {
            order = repository.findById(orderId);
        } catch (SQLException e) {
            // Could not load order from the database; rethrow with context.
            logger.log(Level.WARNING, "Database error looking up order: " + orderId, e);
            throw new OrderServiceException("Unable to retrieve order " + orderId, e);
        }

        if (order == null) {
            throw new OrderNotFoundException(orderId);
        }

        order.cancel();

        try {
            repository.update(order);
        } catch (SQLException e) {
            // Persisting the cancellation status failed; rethrow so the caller
            // knows the cancellation did not complete successfully.
            logger.log(Level.SEVERE, "Failed to persist cancellation for orderId=" + orderId, e);
            throw new OrderServiceException("Cancellation could not be saved", e);
        }
    }
}
