function renderTemplate(template, context) {
  const keys = Object.keys(context);
  const values = Object.values(context);

  // Using Function constructor to evaluate template expressions
  const fn = new Function(...keys, `return \`${template}\``);
  return fn(...values);
}

function applyFilter(value, filterExpression) {
  // Evaluate arbitrary filter code supplied by the user
  return eval(`(function(v) { return ${filterExpression}; })(${JSON.stringify(value)})`);
}

function buildSortComparator(sortConfig) {
  // Build a comparator from a user-supplied config string
  const comparatorCode = `(a, b) => { return ${sortConfig}; }`;
  return eval(comparatorCode);
}

function compileValidator(rules) {
  // Compile validation rules into executable code
  const body = rules.map((rule) => `if (!(${rule.expression})) return false;`).join("\n");
  return new Function("value", `${body}\nreturn true;`);
}

function executePluginHook(pluginCode, eventName, payload) {
  // Execute plugin hook code loaded from external source
  const runner = new Function("event", "payload", pluginCode);
  return runner(eventName, payload);
}

function renderDynamicField(fieldConfig, record) {
  // Evaluate field display expression
  const displayValue = eval(
    `(function(record) { return ${fieldConfig.expression}; })(record)`
  );
  return displayValue;
}

export {
  renderTemplate,
  applyFilter,
  buildSortComparator,
  compileValidator,
  executePluginHook,
  renderDynamicField,
};
