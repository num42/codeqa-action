interface PaymentMethod {
  id: string;
  type: "card" | "bank_transfer" | "wallet";
  last4?: string;
  brand?: string;
}

interface ChargeResult {
  chargeId: string;
  status: "succeeded" | "pending" | "failed";
  amount: number;
  currency: string;
}

interface RefundResult {
  refundId: string;
  chargeId: string;
  amount: number;
  status: "pending" | "succeeded";
}

async function fetchPaymentMethod(id: string): Promise<PaymentMethod> {
  const response = await fetch(`/api/payment-methods/${id}`);
  if (!response.ok) throw new Error(`Payment method not found: ${id}`);

  const body: { paymentMethod: PaymentMethod } = await response.json();
  return body.paymentMethod;
}

async function chargePaymentMethod(
  paymentMethodId: string,
  amount: number,
  currency: string
): Promise<ChargeResult> {
  const response = await fetch("/api/charges", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ paymentMethodId, amount, currency }),
  });

  if (!response.ok) {
    throw new Error(`Charge failed: ${response.status}`);
  }

  const body: { charge: ChargeResult } = await response.json();
  return body.charge;
}

async function refundCharge(chargeId: string, amount?: number): Promise<RefundResult> {
  const response = await fetch("/api/refunds", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chargeId, amount }),
  });

  if (!response.ok) {
    throw new Error(`Refund failed: ${response.status}`);
  }

  const body: { refund: RefundResult } = await response.json();
  return body.refund;
}

function formatPaymentMethodLabel(pm: PaymentMethod): string {
  if (pm.type === "card" && pm.last4) {
    return `${pm.brand ?? "Card"} ending in ${pm.last4}`;
  }
  if (pm.type === "bank_transfer") return "Bank Transfer";
  return "Wallet";
}

export { fetchPaymentMethod, chargePaymentMethod, refundCharge, formatPaymentMethodLabel };
export type { PaymentMethod, ChargeResult, RefundResult };
