class OrderProcessor {
  calculateOrderTotals(orders) {
    const processedOrders = orders.reduce((accumulator, order) => {
      const orderSubtotal = order.price * order.quantity;
      const orderSummary = { id: order.id, total: orderSubtotal, status: order.status };

      let finalizedOrder;
      if (orderSubtotal > 100) {
        const discountedOrder = this.applyDiscount(orderSummary, 0.1);
        finalizedOrder = this.addTax(discountedOrder, 0.2);
      } else {
        finalizedOrder = this.addTax(orderSummary, 0.2);
      }

      accumulator.push(finalizedOrder);
      return accumulator;
    }, []);

    return processedOrders;
  }

  applyDiscount(order, discountRate) {
    const discountedTotal = order.total * (1 - discountRate);
    return { ...order, total: discountedTotal };
  }

  addTax(order, taxRate) {
    const taxedTotal = order.total * (1 + taxRate);
    return { ...order, total: taxedTotal };
  }

  filterByMinimumTotal(orders, minimumTotal) {
    return orders.filter(order => order.total > minimumTotal);
  }

  summarizeOrders(orders) {
    const roundedOrders = orders.map(order => {
      const roundedTotal = Math.round(order.total * 100) / 100;
      return { id: order.id, total: roundedTotal, status: order.status };
    });

    const grandTotal = roundedOrders.reduce((runningTotal, order) => runningTotal + order.total, 0);

    return { items: roundedOrders, grandTotal };
  }

  groupByTotalThreshold(orders, threshold) {
    return orders.reduce((groupedOrders, order) => {
      const groupKey = order.total > threshold ? 'highValue' : 'lowValue';
      if (!groupedOrders[groupKey]) groupedOrders[groupKey] = [];
      groupedOrders[groupKey].push(order);
      return groupedOrders;
    }, {});
  }

  validateOrders(orders) {
    return orders.filter(order => {
      const hasPositivePrice = order.price > 0;
      const hasPositiveQuantity = order.quantity > 0;
      const hasStatus = order.status != null;
      return hasPositivePrice && hasPositiveQuantity && hasStatus;
    });
  }

  enrichWithCustomerData(orders, customerMap) {
    return orders.map(order => {
      const customerData = customerMap[order.id] || {};
      const enrichedOrder = { ...order, ...customerData };
      return enrichedOrder;
    });
  }

  formatOrdersForDisplay(orders) {
    return orders.map(order => {
      const formattedOrder = {
        id: order.id,
        total: `$${order.total.toFixed(2)}`,
        status: order.status.toUpperCase()
      };
      return formattedOrder;
    });
  }

  sortOrdersByField(orders, sortField) {
    return [...orders].sort((orderA, orderB) => orderA[sortField] - orderB[sortField]);
  }

  paginateOrders(orders, paginationOpts) {
    const currentPage = paginationOpts.page || 1;
    const ordersPerPage = paginationOpts.perPage || 10;
    const offset = (currentPage - 1) * ordersPerPage;
    return orders.slice(offset, offset + ordersPerPage);
  }
}

module.exports = OrderProcessor;
