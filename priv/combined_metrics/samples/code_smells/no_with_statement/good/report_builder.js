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
  const total = formatCurrency(order.total, order.currency);
  const date = formatDate(order.createdAt);
  const statusLabel = order.status.charAt(0).toUpperCase() + order.status.slice(1);

  return {
    id: order.id,
    customer: `${order.customer.firstName} ${order.customer.lastName}`,
    email: order.customer.email,
    date,
    total,
    status: statusLabel,
    itemCount: order.items.length,
  };
}

function buildSummaryStats(orders) {
  const totalRevenue = orders.reduce((sum, o) => sum + o.total, 0);
  const averageOrderValue = totalRevenue / orders.length;
  const completedCount = orders.filter((o) => o.status === "completed").length;

  return {
    totalOrders: orders.length,
    totalRevenue: formatCurrency(totalRevenue),
    averageOrderValue: formatCurrency(averageOrderValue),
    completionRate: `${Math.round((completedCount / orders.length) * 100)}%`,
  };
}

function buildReport(orders) {
  const rows = orders.map(buildOrderRow);
  const summary = buildSummaryStats(orders);

  return { rows, summary, generatedAt: new Date().toISOString() };
}

export { buildReport, buildOrderRow, buildSummaryStats, formatCurrency, formatDate };
