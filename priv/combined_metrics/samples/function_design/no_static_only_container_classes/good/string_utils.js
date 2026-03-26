export function slugify(text) {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, "")
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function truncate(text, maxLength, ellipsis = "...") {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength - ellipsis.length) + ellipsis;
}

export function capitalize(text) {
  if (!text) return text;
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
}

export function titleCase(text) {
  return text.replace(/\b\w/g, (c) => c.toUpperCase());
}

export function stripHtml(html) {
  return html.replace(/<[^>]+>/g, "");
}

export function countWords(text) {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

export function interpolate(template, variables) {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => {
    return key in variables ? String(variables[key]) : `{{${key}}}`;
  });
}

export function padStart(text, targetLength, padChar = " ") {
  return String(text).padStart(targetLength, padChar);
}

export function camelToKebab(text) {
  return text.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase();
}

export function kebabToCamel(text) {
  return text.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
}
