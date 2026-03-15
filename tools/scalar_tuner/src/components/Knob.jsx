import { useEffect, useRef, useState } from 'react'

const MIN_ANGLE = -135
const MAX_ANGLE = 135

function angleToFactor(angle) {
  // center (0°) = ×1.0, full CW (+135°) = ×3.0, full CCW (-135°) = ×0.0
  if (angle >= 0) return 1 + (angle / MAX_ANGLE) * 2
  else return 1 + (angle / Math.abs(MIN_ANGLE)) * 1
}

export default function Knob({ onFactor }) {
  const [angle, setAngle] = useState(0)
  const [dragging, setDragging] = useState(false)
  const startRef = useRef(null)
  const angleRef = useRef(0)

  function onMouseDown(e) {
    e.preventDefault()
    startRef.current = { y: e.clientY, startAngle: angleRef.current }
    setDragging(true)
  }

  useEffect(() => {
    if (!dragging) return

    function onMouseMove(e) {
      const dy = startRef.current.y - e.clientY
      const newAngle = Math.max(MIN_ANGLE, Math.min(MAX_ANGLE, startRef.current.startAngle + dy))
      angleRef.current = newAngle
      setAngle(newAngle)
      onFactor(angleToFactor(newAngle), false)
    }

    function onMouseUp() {
      onFactor(angleToFactor(angleRef.current), true)
      angleRef.current = 0
      setAngle(0)
      setDragging(false)
    }

    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseup', onMouseUp)
    return () => {
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('mouseup', onMouseUp)
    }
  }, [dragging])

  const factor = angleToFactor(angle)

  return (
    <div className="knob-wrap">
      <div className="knob-track">
        <span className="knob-end-label">0</span>
        <div
          className={`knob${dragging ? ' knob-active' : ''}`}
          onMouseDown={onMouseDown}
          style={{ transform: `rotate(${angle}deg)` }}
        >
          <div className="knob-pip" />
        </div>
        <span className="knob-end-label">3×</span>
      </div>
      <span className="knob-readout">{dragging ? `×${factor.toFixed(2)}` : 'scale all'}</span>
    </div>
  )
}
