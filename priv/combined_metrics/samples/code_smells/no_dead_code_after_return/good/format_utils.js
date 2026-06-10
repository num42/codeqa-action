export function formatCurrency(cents, locale) {
  if (cents == null) return "";
  if (!Number.isFinite(cents)) return "—";

  const value = cents / 100;
  return new Intl.NumberFormat(locale, { style: "currency", currency: "EUR" }).format(value);
}

export function truncate(text, max) {
  if (!text) return "";
  if (text.length <= max) return text;
  return text.slice(0, max - 1) + "…";
}

export function parsePercent(raw) {
  const n = Number.parseFloat(raw);
  if (Number.isNaN(n)) return null;
  return Math.min(100, Math.max(0, n));
}

export function pluralize(count, singular, plural) {
  if (count === 1) return `${count} ${singular}`;
  return `${count} ${plural}`;
}

export function classNames(...parts) {
  return parts.filter(Boolean).join(" ");
}
