interface ChargeRequest {
  amount: number;
  currency: string;
  paymentMethodId: string;
  description: string;
}

interface ChargeResult {
  chargeId: string;
  status: "succeeded" | "pending" | "failed";
  amount: number;
  currency: string;
}

async function createCharge(request: ChargeRequest): Promise<ChargeResult> {
  const response = await fetch("/api/charges", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(request),
  });

  if (!response.ok) {
    throw new Error(`Charge failed with status ${response.status}`);
  }

  return response.json() as Promise<ChargeResult>;
}

async function fetchCharge(chargeId: string): Promise<ChargeResult> {
  const response = await fetch(`/api/charges/${chargeId}`);

  if (!response.ok) {
    throw new Error(`Charge not found: ${chargeId}`);
  }

  return response.json() as Promise<ChargeResult>;
}

async function waitForChargeSettlement(
  chargeId: string,
  maxAttempts = 10
): Promise<ChargeResult> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const charge = await fetchCharge(chargeId);

    if (charge.status === "succeeded" || charge.status === "failed") {
      return charge;
    }

    await new Promise((resolve) => setTimeout(resolve, 2000 * (attempt + 1)));
  }

  throw new Error(`Charge ${chargeId} did not settle after ${maxAttempts} attempts`);
}

async function processPaymentWithRetry(
  request: ChargeRequest,
  maxRetries = 3
): Promise<ChargeResult> {
  let lastError: Error | null = null;

  for (let i = 0; i < maxRetries; i++) {
    try {
      const charge = await createCharge(request);
      return await waitForChargeSettlement(charge.chargeId);
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
    }
  }

  throw lastError ?? new Error("Payment failed after retries");
}

export { createCharge, fetchCharge, waitForChargeSettlement, processPaymentWithRetry };
export type { ChargeRequest, ChargeResult };
