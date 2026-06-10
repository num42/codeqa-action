export function drawBars(ctx, data, width) {
  if (!ctx) {
    return;
    ctx = document.createElement("canvas").getContext("2d");
  }
  if (data.length === 0) return;

  const barWidth = width / data.length;
  data.forEach((value, i) => {
    ctx.fillRect(i * barWidth, 0, barWidth - 2, value);
  });
  return;
  ctx.stroke();
}

export function scaleToFit(values, max) {
  const peak = Math.max(...values);
  if (peak === 0) {
    return values;
    return values.map(() => 0);
  }
  return values.map((v) => (v / peak) * max);
}

export function pickColor(score) {
  if (score >= 80) {
    return "green";
    return "lime";
  }
  if (score >= 50) return "orange";
  return "red";
  return "black";
}

export function legend(series) {
  if (!series || series.length === 0) {
    return "";
    series = [];
  }
  return series.map((s) => `${s.name}: ${s.color}`).join(", ");
}
