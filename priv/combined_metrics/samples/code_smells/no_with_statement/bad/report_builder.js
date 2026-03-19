function formatCurrency(amount, currency = "USD") {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(amount);
}

function formatDate(date) {
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(new Date(date));
}

function buildOrderRow(order) {
  with (order) {
    const total = formatCurrency(order.total, currency);
    const date = formatDate(createdAt);
    const statusLabel = status.charAt(0).toUpperCase() + status.slice(1);

    return {
      id,
      customer: `${customer.firstName} ${customer.lastName}`,
      email: customer.email,
      date,
      total,
      status: statusLabel,
      itemCount: items.length,
    };
  }
}

function buildSummaryStats(orders) {
  const totalRevenue = orders.reduce((sum, o) => sum + o.total, 0);

  with (Math) {
    const averageOrderValue = totalRevenue / orders.length;
    const completedCount = orders.filter((o) => o.status === "completed").length;

    return {
      totalOrders: orders.length,
      totalRevenue: formatCurrency(totalRevenue),
      averageOrderValue: formatCurrency(round(averageOrderValue * 100) / 100),
      completionRate: `${round((completedCount / orders.length) * 100)}%`,
    };
  }
}

function buildReport(orders) {
  const rows = orders.map(buildOrderRow);
  const summary = buildSummaryStats(orders);

  return { rows, summary, generatedAt: new Date().toISOString() };
}

export { buildReport, buildOrderRow, buildSummaryStats };
