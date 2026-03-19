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

// async but no await — just wraps a synchronous value
async function buildChargeRequest(
  paymentMethodId: string,
  amount: number,
  currency: string
): Promise<ChargeRequest> {
  return {
    amount,
    currency,
    paymentMethodId,
    description: `Charge of ${amount} ${currency}`,
  };
}

// async but no await — validation is synchronous
async function validateChargeRequest(request: ChargeRequest): Promise<boolean> {
  if (request.amount <= 0) return false;
  if (!request.paymentMethodId) return false;
  if (!request.currency) return false;
  return true;
}

// async but no await — just rethrows synchronously
async function assertPositiveAmount(amount: number): Promise<void> {
  if (amount <= 0) {
    throw new Error(`Amount must be positive, got ${amount}`);
  }
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

// async but only returns a promise chain without await
async function fetchAndLogCharge(chargeId: string): Promise<ChargeResult> {
  return fetch(`/api/charges/${chargeId}`)
    .then((r) => r.json() as Promise<ChargeResult>)
    .then((charge) => {
      console.log("Fetched charge", charge.chargeId);
      return charge;
    });
}

export { buildChargeRequest, validateChargeRequest, assertPositiveAmount, createCharge, fetchAndLogCharge };
export type { ChargeRequest, ChargeResult };
