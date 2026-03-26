import { useState, useMemo } from 'react'
import MetricRow from './MetricRow'
import ScoreDisplay from './ScoreDisplay'
import { isIntegerMultiple } from '../App'

function colValue(col, metricKey, vals, effectiveScalar) {
  switch (col) {
    case 'metric':  return metricKey
    case 'bad':     return vals.bad
    case 'good':    return vals.good
    case 'ratio':   return vals.ratio
    case 'logdiff': return vals.log_good - vals.log_bad
    case 'contrib': return Math.exp(effectiveScalar * (vals.log_good - vals.log_bad))
    case 'scalar':  return effectiveScalar
  }
}

function sortIcon(col, sortCol, sortDir) {
  if (sortCol !== col) return <span className="sort-icon muted">⇅</span>
  if (sortDir === 'asc')  return <span className="sort-icon">↑</span>
  if (sortDir === 'desc') return <span className="sort-icon">↓</span>
}

function isInDeadzone(effectiveScalar, logDiff, deadzone) {
  if (effectiveScalar === 0) return true
  const contrib = Math.exp(effectiveScalar * logDiff)
  return contrib >= deadzone && contrib <= 2 - deadzone
}

export default function BehaviorCard({ behavior, metrics, scalars, score, onScalarChange }) {
  const [showAll, setShowAll] = useState(true)
  const [sortCol, setSortCol] = useState(null)
  const [sortDir, setSortDir] = useState(null)
  const [scale, setScale] = useState(1.0)
  const [deadzone, setDeadzone] = useState(1.0)

  // Default order: by abs(suggested_scalar), stable, never depends on scalars
  const defaultEntries = useMemo(
    () => [...Object.entries(metrics)].sort(([, a], [, b]) =>
      Math.abs(b.suggested_scalar ?? 0) - Math.abs(a.suggested_scalar ?? 0)
    ),
    [metrics]
  )

  // Virtual score: use scale + deadzone filter, never modifies actual scalars
  const virtualScore = useMemo(() => {
    const compute = side => Object.entries(scalars).reduce((acc, [k, scalar]) => {
      const eff = scalar * scale
      if (eff === 0) return acc
      const bv = Math.max(metrics[k]?.bad ?? 1, 1e-300)
      const gv = Math.max(metrics[k]?.good ?? 1, 1e-300)
      const logDiff = Math.log(gv) - Math.log(bv)
      if (isInDeadzone(eff, logDiff, deadzone)) return acc
      return acc * Math.pow(side === 'bad' ? bv : gv, eff)
    }, 1.0)
    const bad = compute('bad')
    const good = compute('good')
    return { bad, good, ratio: bad > 0 ? good / bad : 0 }
  }, [scalars, scale, deadzone, metrics])

  function handleColClick(col) {
    if (sortCol !== col) { setSortCol(col); setSortDir('asc') }
    else if (sortDir === 'asc') setSortDir('desc')
    else { setSortCol(null); setSortDir(null) }
  }

  const sortedEntries = useMemo(() => {
    const base = showAll ? defaultEntries : defaultEntries.filter(([k]) => (scalars[k] ?? 0) !== 0)
    if (!sortCol || !sortDir) return base
    return [...base].sort(([ka, va], [kb, vb]) => {
      const a = colValue(sortCol, ka, va, (scalars[ka] ?? 0) * scale)
      const b = colValue(sortCol, kb, vb, (scalars[kb] ?? 0) * scale)
      if (typeof a === 'string') return sortDir === 'asc' ? a.localeCompare(b) : b.localeCompare(a)
      return sortDir === 'asc' ? a - b : b - a
    })
  }, [defaultEntries, sortCol, sortDir, showAll, scalars, scale])

  const nonZeroCount = defaultEntries.filter(([k]) => (scalars[k] ?? 0) !== 0).length
  const deadzoneCount = useMemo(() =>
    defaultEntries.filter(([k, v]) => {
      const eff = (scalars[k] ?? 0) * scale
      const logDiff = v.log_good - v.log_bad
      return isInDeadzone(eff, logDiff, deadzone)
    }).length,
    [defaultEntries, scalars, scale, deadzone]
  )

  function th(col, label) {
    return (
      <th className="sortable-th" onClick={() => handleColClick(col)}>
        {label}{sortIcon(col, sortCol, sortDir)}
      </th>
    )
  }

  return (
    <div>
      <div className="behavior-sticky">
        <ScoreDisplay score={virtualScore} />

        <div className="table-toolbar">
          <label className="ctrl-label">
            scale
            <input type="range" min="0.1" max="3" step="0.01" value={scale}
              onChange={e => setScale(parseFloat(e.target.value))} className="ctrl-slider" />
            <span className="ctrl-val">×{scale.toFixed(2)}</span>
            <button className="ctrl-reset" onClick={() => setScale(1.0)} disabled={scale === 1.0}>↺</button>
          </label>

          <label className="ctrl-label">
            deadzone
            <input type="range" min="0.9" max="1.0" step="0.001" value={deadzone}
              onChange={e => setDeadzone(parseFloat(e.target.value))} className="ctrl-slider" />
            <span className="ctrl-val">[{deadzone.toFixed(3)}, {(2 - deadzone).toFixed(3)}]</span>
            <span className="ctrl-val muted">{deadzoneCount} cut</span>
            <button className="ctrl-reset" onClick={() => setDeadzone(1.0)} disabled={deadzone === 1.0}>↺</button>
          </label>
        </div>
      </div>

      <table className="metrics-table">
        <thead>
          <tr>
            {th('metric',  'metric')}
            {th('bad',     'bad')}
            {th('good',    'good')}
            {th('ratio',   'ratio')}
            {th('logdiff', 'log diff')}
            {th('contrib', 'contrib')}
            {th('scalar',  'scalar')}
          </tr>
        </thead>
        <tbody>
          {sortedEntries.map(([metricKey, vals]) => {
            const actualScalar = scalars[metricKey] ?? 0
            const effectiveScalar = actualScalar * scale
            const logDiff = vals.log_good - vals.log_bad
            return (
              <MetricRow
                key={metricKey}
                metricKey={metricKey}
                vals={vals}
                scalar={actualScalar}
                effectiveScalar={effectiveScalar}
                isDeadzoned={isInDeadzone(effectiveScalar, logDiff, deadzone)}
                isDamped={isIntegerMultiple(vals.bad, vals.good)}
                onChange={v => onScalarChange(metricKey, v)}
              />
            )
          })}
        </tbody>
      </table>
      <button className="toggle-all" onClick={() => setShowAll(s => !s)}>
        {showAll
          ? `Hide zero-scalar metrics`
          : `Show all metrics (${defaultEntries.length - nonZeroCount} hidden)`}
      </button>
    </div>
  )
}
