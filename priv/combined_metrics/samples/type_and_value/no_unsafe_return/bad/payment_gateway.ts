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

async function fetchPaymentMethod(id: string): Promise<PaymentMethod> {
  const response = await fetch(`/api/payment-methods/${id}`);
  if (!response.ok) throw new Error(`Payment method not found: ${id}`);

  const body: any = await response.json();
  // Unsafe return: body.paymentMethod is typed as any
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

  if (!response.ok) throw new Error(`Charge failed: ${response.status}`);

  const data: any = await response.json();
  return data.charge;
}

function buildChargePayload(paymentMethodId: string, amount: number): ChargeResult {
  const raw: any = {
    chargeId: "temp",
    status: "pending",
    amount,
    currency: "USD",
    paymentMethodId,
    createdAt: Date.now(),
  };
  return raw;
}

function parseWebhookEvent(payload: any): ChargeResult {
  return payload.data.object;
}

export { fetchPaymentMethod, chargePaymentMethod, buildChargePayload, parseWebhookEvent };
export type { PaymentMethod, ChargeResult };
