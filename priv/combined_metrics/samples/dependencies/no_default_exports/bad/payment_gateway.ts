interface ChargeRequest {
  amount: number;
  currency: string;
  paymentMethodId: string;
  customerId: string;
}

interface ChargeResult {
  id: string;
  status: "succeeded" | "pending" | "failed";
  amount: number;
  currency: string;
  createdAt: string;
}

interface RefundRequest {
  chargeId: string;
  amount?: number;
  reason?: string;
}

interface RefundResult {
  id: string;
  chargeId: string;
  amount: number;
  status: "pending" | "succeeded";
}

async function createCharge(request: ChargeRequest): Promise<ChargeResult> {
  const response = await fetch("/api/charges", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });
  if (!response.ok) throw new Error(`Charge failed: ${response.status}`);
  return response.json() as Promise<ChargeResult>;
}

async function fetchCharge(chargeId: string): Promise<ChargeResult> {
  const response = await fetch(`/api/charges/${chargeId}`);
  if (!response.ok) throw new Error(`Charge not found: ${chargeId}`);
  return response.json() as Promise<ChargeResult>;
}

async function refundCharge(request: RefundRequest): Promise<RefundResult> {
  const response = await fetch("/api/refunds", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });
  if (!response.ok) throw new Error(`Refund failed: ${response.status}`);
  return response.json() as Promise<RefundResult>;
}

function formatChargeAmount(charge: ChargeResult): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: charge.currency,
  }).format(charge.amount / 100);
}

// Default export makes it hard to rename consistently across the codebase
export default {
  createCharge,
  fetchCharge,
  refundCharge,
  formatChargeAmount,
};
