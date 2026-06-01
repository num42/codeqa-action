import { useState, useEffect, useMemo } from 'react'
import BehaviorCard from './components/BehaviorCard'
import YamlModal from './components/YamlModal'
import './App.css'

function computeScore(metricData, scalars, side) {
  return Object.entries(scalars).reduce((acc, [metricKey, scalar]) => {
    const val = metricData[metricKey]?.[side] ?? 1.0
    const safeVal = val > 0 ? val : 1.0
    return acc * Math.pow(safeVal, scalar)
  }, 1.0)
}

export function isIntegerMultiple(a, b) {
  if (a <= 0 || b <= 0) return false
  if (a < 1.0 && b < 1.0) return false  // both sub-1 fractions — not meaningful to damp
  const ratio = Math.max(a, b) / Math.min(a, b)
  return Math.abs(Math.round(ratio) - ratio) <= 0.05
}

export function dampedSuggested(vals) {
  // Raw suggested_scalar from JSON is in [-2, +2]; scale to [-3, +3]
  const raw = (vals.suggested_scalar ?? 0) * 1.5
  if (isIntegerMultiple(vals.bad, vals.good)) {
    return Math.max(-1.5, Math.min(1.5, raw))
  }
  return raw
}

export default function App() {
  const [data, setData] = useState(null)
  const [scalars, setScalars] = useState({})
  const [yamlOpen, setYamlOpen] = useState(false)
  const [selectedBehavior, setSelectedBehavior] = useState(null)
  const [reviewed, setReviewed] = useState(() => {
    try { return new Set(JSON.parse(localStorage.getItem('codeqa-reviewed') ?? '[]')) }
    catch { return new Set() }
  })

  useEffect(() => {
    fetch('/metric_report.json')
      .then(r => r.json())
      .then(json => {
        setData(json)
        const initial = {}
        for (const [behavior, metrics] of Object.entries(json)) {
          initial[behavior] = {}
          for (const [metric, vals] of Object.entries(metrics)) {
            initial[behavior][metric] = dampedSuggested(vals)
          }
        }
        setScalars(initial)
        setSelectedBehavior(Object.keys(json)[0] ?? null)
      })
  }, [])

  const scores = useMemo(() => {
    if (!data) return {}
    const out = {}
    for (const [behavior, metrics] of Object.entries(data)) {
      const s = scalars[behavior] ?? {}
      const bad = computeScore(metrics, s, 'bad')
      const good = computeScore(metrics, s, 'good')
      out[behavior] = { bad, good, ratio: bad > 0 ? good / bad : 0 }
    }
    return out
  }, [data, scalars])

  const summary = useMemo(() => {
    const total = Object.keys(scores).length
    const passing = Object.values(scores).filter(s => s.ratio >= 2.0).length
    const weak = Object.values(scores).filter(s => s.ratio >= 1.0 && s.ratio < 2.0).length
    const failing = Object.values(scores).filter(s => s.ratio < 1.0).length
    return { total, passing, weak, failing }
  }, [scores])

  const touched = useMemo(() => {
    if (!data) return {}
    const out = {}
    for (const [behavior, metrics] of Object.entries(data)) {
      const current = scalars[behavior] ?? {}
      out[behavior] = Object.keys(metrics).some(k =>
        Math.abs((current[k] ?? 0) - dampedSuggested(metrics[k])) > 0.001
      )
    }
    return out
  }, [data, scalars])

  const behaviorKeys = data ? Object.keys(data) : []
  const selectedIndex = behaviorKeys.indexOf(selectedBehavior)

  useEffect(() => {
    if (!data) return
    const handler = e => {
      if (e.target.tagName === 'INPUT') return
      if (e.key === 'j' || e.key === 'ArrowDown') {
        setSelectedBehavior(prev => behaviorKeys[Math.min(behaviorKeys.indexOf(prev) + 1, behaviorKeys.length - 1)])
      } else if (e.key === 'k' || e.key === 'ArrowUp') {
        setSelectedBehavior(prev => behaviorKeys[Math.max(behaviorKeys.indexOf(prev) - 1, 0)])
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [data, behaviorKeys])

  function setScalar(behavior, metric, value) {
    setScalars(prev => ({
      ...prev,
      [behavior]: { ...prev[behavior], [metric]: value }
    }))
  }

  function resetCurrent() {
    if (!data || !selectedBehavior) return
    const metrics = data[selectedBehavior]
    setScalars(prev => ({
      ...prev,
      [selectedBehavior]: Object.fromEntries(
        Object.entries(metrics).map(([k, v]) => [k, dampedSuggested(v)])
      )
    }))
  }

  function resetToSuggested() {
    if (!data) return
    const next = {}
    for (const [behavior, metrics] of Object.entries(data)) {
      next[behavior] = {}
      for (const [metric, vals] of Object.entries(metrics)) {
        next[behavior][metric] = dampedSuggested(vals)
      }
    }
    setScalars(next)
  }

  function resetToZero() {
    if (!data) return
    const next = {}
    for (const [behavior, metrics] of Object.entries(data)) {
      next[behavior] = {}
      for (const metric of Object.keys(metrics)) {
        next[behavior][metric] = 0
      }
    }
    setScalars(next)
  }

  function toggleReviewed(behavior) {
    setReviewed(prev => {
      const next = new Set(prev)
      if (next.has(behavior)) next.delete(behavior)
      else next.add(behavior)
      localStorage.setItem('codeqa-reviewed', JSON.stringify([...next]))
      return next
    })
  }

  if (!data) return <div className="loading">Loading metric report…</div>

  const categories = {}
  for (const key of behaviorKeys) {
    const [cat] = key.split('.')
    if (!categories[cat]) categories[cat] = []
    categories[cat].push(key)
  }

  const behavior = selectedBehavior

  return (
    <div className="app">
      <header className="header">
        <h1>Scalar Tuner</h1>
        <div className="summary">
          <span className="badge total">{summary.total} behaviors</span>
          <span className="badge pass">{summary.passing} ≥2x ✓</span>
          <span className="badge weak">{summary.weak} weak</span>
          <span className="badge fail">{summary.failing} ✗</span>
          <span className="badge total">{reviewed.size}/{summary.total} reviewed</span>
        </div>
        <div className="actions">
          <button onClick={resetToSuggested}>Reset all</button>
          <button onClick={resetToZero}>Zero all</button>
          <button className="yaml-btn" onClick={() => setYamlOpen(true)}>Copy YAML</button>
        </div>
      </header>

      <div className="app-body">
        <aside className="sidebar">
          {Object.entries(categories).map(([cat, behaviors]) => (
            <div key={cat}>
              <div className="sidebar-category">{cat.replace(/_/g, ' ')}</div>
              {behaviors.map(b => {
                const s = scores[b]
                const isUnderflow = s && s.bad < 1e-10 && s.good < 1e-10
                const ratioClass = s ? (s.ratio >= 2 ? 'sb-good' : s.ratio >= 1 ? 'sb-weak' : 'sb-bad') : ''
                const icon = s ? (s.ratio >= 2 ? '✓' : s.ratio >= 1 ? '~' : '✗') : '?'
                return (
                  <div
                    key={b}
                    className={`sidebar-item ${b === behavior ? 'selected' : ''}`}
                    onClick={() => setSelectedBehavior(b)}
                  >
                    <span className={`sb-icon ${ratioClass}`}>{icon}</span>
                    <span className="sb-name">{b.split('.').slice(1).join('.')}</span>
                    <span className="sb-flags">
                      {isUnderflow && <span className="flag-underflow" title="score underflow">⚠</span>}
                      {touched[b] && <span className="flag-touched" title="modified">●</span>}
                      {reviewed.has(b) && <span className="flag-reviewed" title="reviewed">✓</span>}
                    </span>
                  </div>
                )
              })}
            </div>
          ))}
        </aside>

        <main className="main-panel">
          <div className="nav-bar">
            <button onClick={() => setSelectedBehavior(behaviorKeys[selectedIndex - 1])} disabled={selectedIndex <= 0}>← prev</button>
            <span className="nav-pos">{selectedIndex + 1} / {behaviorKeys.length}</span>
            <button onClick={() => setSelectedBehavior(behaviorKeys[selectedIndex + 1])} disabled={selectedIndex >= behaviorKeys.length - 1}>next →</button>
            <span className="nav-name">{behavior?.split('.').slice(1).join('.')}</span>
            <div className="nav-actions">
              <button onClick={resetCurrent}>Reset this</button>
              <button
                className={reviewed.has(behavior) ? 'btn-reviewed' : ''}
                onClick={() => toggleReviewed(behavior)}
              >
                {reviewed.has(behavior) ? '✓ reviewed' : 'mark reviewed'}
              </button>
            </div>
          </div>

          {behavior && data[behavior] && (
            <BehaviorCard
              key={behavior}
              behavior={behavior}
              metrics={data[behavior]}
              scalars={scalars[behavior] ?? {}}
              score={scores[behavior]}
              onScalarChange={(metric, val) => setScalar(behavior, metric, val)}
            />
          )}
        </main>
      </div>

      {yamlOpen && (
        <YamlModal scalars={scalars} onClose={() => setYamlOpen(false)} />
      )}
    </div>
  )
}
