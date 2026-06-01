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

function assertNever(value: never): never {
  throw new Error(`Unhandled payment status: ${String(value)}`);
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
    case "refunded":
      return "Payment refunded";
    case "disputed":
      return "Payment disputed";
    default:
      return assertNever(status);
  }
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
    case "refunded":
      return "orange";
    case "disputed":
      return "yellow";
    default:
      return assertNever(status);
  }
}

function isTerminalStatus(status: PaymentStatus): boolean {
  switch (status) {
    case "succeeded":
    case "failed":
    case "refunded":
      return true;
    case "pending":
    case "processing":
    case "disputed":
      return false;
    default:
      return assertNever(status);
  }
}

function handlePaymentEvent(event: PaymentEvent): void {
  const label = getStatusLabel(event.status);
  const terminal = isTerminalStatus(event.status);
  console.log(`[${event.chargeId}] ${label} (terminal: ${terminal})`);
}

export { getStatusLabel, getStatusColor, isTerminalStatus, handlePaymentEvent };
export type { PaymentStatus, PaymentEvent };
