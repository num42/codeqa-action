function fmt(v) {
  if (v === 0) return '0'
  if (v >= 999999999) return '999999999'
  if (v < 0.0001) return v.toExponential(2)
  return v.toFixed(4)
}

function fmtLog(v) {
  if (v <= 0) return '—'
  return Math.log(v).toFixed(3)
}

function fmtRatio(v) {
  if (v >= 999999999) return '999999999'
  return v.toFixed(2)
}

function fmtLog10Ratio(v) {
  if (v <= 0) return '—'
  return Math.log10(v).toFixed(2)
}

export default function ScoreDisplay({ score }) {
  if (!score) return null
  const { bad, good, ratio } = score

  const cls = ratio >= 2.0 ? 'ratio-good' : ratio >= 1.0 ? 'ratio-weak' : 'ratio-bad'
  const icon = ratio >= 2.0 ? '✓' : ratio >= 1.0 ? '~' : '✗'
  const isUnderflow = bad < 1e-10 && good < 1e-10

  return (
    <table className={`score-display ${cls}`}>
      <tbody>
        <tr>
          <td className="sd-label">bad</td>
          <td className="sd-val">{fmt(bad)}</td>
          <td className="sd-log">ln={fmtLog(bad)}</td>
        </tr>
        <tr>
          <td className="sd-label">good</td>
          <td className="sd-val">{fmt(good)}</td>
          <td className="sd-log">ln={fmtLog(good)}</td>
        </tr>
        <tr>
          <td className="sd-label">ratio</td>
          <td className="sd-val sd-ratio">{fmtRatio(ratio)}x {icon}</td>
          <td className="sd-log">log₁₀={fmtLog10Ratio(ratio)}{isUnderflow ? ' ⚠' : ''}</td>
        </tr>
      </tbody>
    </table>
  )
}
