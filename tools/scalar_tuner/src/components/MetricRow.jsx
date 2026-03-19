function fmtContrib(v) {
  if (v === 1) return '1.000'
  if (v > 999) return '>999'
  if (v < 0.001) return v.toExponential(1)
  return v.toFixed(3)
}

export default function MetricRow({ metricKey, vals, scalar, effectiveScalar, isDeadzoned, isDamped, onChange }) {
  const logDiff = (vals.log_good - vals.log_bad).toFixed(3)
  const ratio = vals.ratio.toFixed(3)

  const contribution = effectiveScalar !== 0
    ? Math.exp(effectiveScalar * (vals.log_good - vals.log_bad))
    : 1
  const contribPositive = contribution > 1
  const contribNeutral = isDeadzoned || Math.abs(contribution - 1) < 0.001

  return (
    <tr className={`${scalar !== 0 ? 'active-row' : ''}${isDeadzoned ? ' dead-row' : ''}`}>
      <td className="metric-key">
        {metricKey}
        {isDamped && (
          <span
            className="damped-tag"
            title="good/bad ratio is approximately an integer multiple (e.g. 6→12, 2.5→10). Suggests a trivially scaling metric — suggested scalar capped at ±1.5"
          >~int</span>
        )}
      </td>
      <td className="num">{vals.bad.toFixed(4)}</td>
      <td className="num">{vals.good.toFixed(4)}</td>
      <td className="num">{ratio}x</td>
      <td className={`num ${parseFloat(logDiff) > 0 ? 'pos' : parseFloat(logDiff) < 0 ? 'neg' : ''}`}>
        {logDiff}
      </td>
      <td className={`num contrib ${isDeadzoned ? 'dead' : contribNeutral ? '' : contribPositive ? 'pos' : 'neg'}`}>
        {isDeadzoned ? '—' : `${fmtContrib(contribution)}x`}
      </td>
      <td className="scalar-cell">
        <input
          type="range"
          min="-3"
          max="3"
          step="0.01"
          value={scalar}
          onChange={e => onChange(parseFloat(e.target.value))}
        />
        <input
          type="number"
          min="-3"
          max="3"
          step="0.01"
          value={scalar}
          onChange={e => onChange(parseFloat(e.target.value) || 0)}
          className="scalar-input"
        />
      </td>
    </tr>
  )
}
