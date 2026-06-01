class StringUtils {
  static slugify(text) {
    return text
      .toLowerCase()
      .trim()
      .replace(/[^\w\s-]/g, "")
      .replace(/[\s_-]+/g, "-")
      .replace(/^-+|-+$/g, "");
  }

  static truncate(text, maxLength, ellipsis = "...") {
    if (text.length <= maxLength) return text;
    return text.slice(0, maxLength - ellipsis.length) + ellipsis;
  }

  static capitalize(text) {
    if (!text) return text;
    return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
  }

  static titleCase(text) {
    return text.replace(/\b\w/g, (c) => c.toUpperCase());
  }

  static stripHtml(html) {
    return html.replace(/<[^>]+>/g, "");
  }

  static countWords(text) {
    return text.trim().split(/\s+/).filter(Boolean).length;
  }

  static interpolate(template, variables) {
    return template.replace(/\{\{(\w+)\}\}/g, (_, key) => {
      return key in variables ? String(variables[key]) : `{{${key}}}`;
    });
  }

  static padStart(text, targetLength, padChar = " ") {
    return String(text).padStart(targetLength, padChar);
  }

  static camelToKebab(text) {
    return text.replace(/([a-z])([A-Z])/g, "$1-$2").toLowerCase();
  }

  static kebabToCamel(text) {
    return text.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
  }
}

export { StringUtils };
