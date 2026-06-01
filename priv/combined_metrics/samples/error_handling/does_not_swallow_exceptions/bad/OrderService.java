package com.example.orders;

import java.io.IOException;
import java.sql.SQLException;
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
            // silently swallowed — caller will never know the charge failed
        } catch (IOException e) {
            // silently swallowed — network errors are completely hidden
        }

        try {
            repository.save(order);
        } catch (SQLException e) {
            // silently swallowed — order may not have been saved at all
        }

        return order;
    }

    public void cancelOrder(String orderId) {
        Order order = null;
        try {
            order = repository.findById(orderId);
        } catch (SQLException e) {
            // silently swallowed — order is null but execution continues
        }

        if (order == null) {
            return;
        }

        order.cancel();

        try {
            repository.update(order);
        } catch (SQLException e) {
            // silently swallowed — cancellation may not have been persisted
        }
    }

    public double getOrderTotal(String orderId) {
        try {
            Order order = repository.findById(orderId);
            return order.totalAmount();
        } catch (Exception e) {
            // catch-all swallowed; returns 0 as if the order doesn't exist
            return 0.0;
        }
    }
}
