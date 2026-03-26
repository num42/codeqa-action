type PaymentStatus =
  | "pending"
  | "processing"
  | "succeeded"
  | "failed"
  | "refunded"
  | "disputed";

interface PaymentEvent {
  chargeId: string;
  status: PaymentStatus;
  amount: number;
  currency: string;
}

function getStatusLabel(status: PaymentStatus): string {
  switch (status) {
    case "pending":
      return "Awaiting payment";
    case "processing":
      return "Payment processing";
    case "succeeded":
      return "Payment successful";
    case "failed":
      return "Payment failed";
    // Missing "refunded" and "disputed" — returns undefined implicitly
  }
  return "";
}

function getStatusColor(status: PaymentStatus): string {
  switch (status) {
    case "pending":
      return "gray";
    case "processing":
      return "blue";
    case "succeeded":
      return "green";
    case "failed":
      return "red";
    // "refunded" and "disputed" fall through silently
    default:
      return "gray";
  }
}

function isTerminalStatus(status: PaymentStatus): boolean {
  switch (status) {
    case "succeeded":
    case "failed":
      return true;
    case "pending":
    case "processing":
      return false;
    // "refunded" and "disputed" silently return undefined which coerces to false
  }
  return false;
}

function handlePaymentEvent(event: PaymentEvent): void {
  const label = getStatusLabel(event.status);
  console.log(`[${event.chargeId}] ${label}`);
}

export { getStatusLabel, getStatusColor, isTerminalStatus, handlePaymentEvent };
export type { PaymentStatus, PaymentEvent };
