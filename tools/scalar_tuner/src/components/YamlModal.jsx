import { useMemo } from 'react'

function toYaml(scalars) {
  const categories = {}

  for (const [behaviorKey, metrics] of Object.entries(scalars)) {
    const dotIdx = behaviorKey.indexOf('.')
    const category = behaviorKey.slice(0, dotIdx)
    const behavior = behaviorKey.slice(dotIdx + 1)

    if (!categories[category]) categories[category] = {}

    const nonZero = Object.entries(metrics).filter(([, v]) => v !== 0)
    if (nonZero.length === 0) continue

    const grouped = {}
    for (const [metricKey, scalar] of nonZero) {
      const [group, key] = metricKey.split('.')
      if (!grouped[group]) grouped[group] = {}
      grouped[group][key] = scalar
    }

    categories[category][behavior] = grouped
  }

  let out = ''
  for (const [category, behaviors] of Object.entries(categories)) {
    out += `# ${category}\n`
    for (const [behavior, groups] of Object.entries(behaviors)) {
      out += `${behavior}:\n`
      for (const [group, keys] of Object.entries(groups)) {
        out += `  ${group}:\n`
        for (const [key, scalar] of Object.entries(keys)) {
          out += `    ${key}: ${scalar.toFixed(4)}\n`
        }
      }
      out += '\n'
    }
  }
  return out.trim()
}

export default function YamlModal({ scalars, onClose }) {
  const yaml = useMemo(() => toYaml(scalars), [scalars])

  function copy() {
    navigator.clipboard.writeText(yaml)
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h3>YAML Export</h3>
          <div>
            <button onClick={copy}>Copy to clipboard</button>
            <button onClick={onClose}>✕</button>
          </div>
        </div>
        <pre className="yaml-output">{yaml}</pre>
      </div>
    </div>
  )
}
