const ZoomSlider = {
  mounted() {
    this.el.value = 100;
    this.el.addEventListener("input", () => {
      const graph = document.getElementById("full-dependency-graph");
      if (!graph) return;

      graph.dispatchEvent(
        new CustomEvent("force-graph:zoom-set", {
          detail: { percent: parseInt(this.el.value, 10) },
        }),
      );
    });
  },
};

function resolveLayout(kind) {
  switch (kind) {
    case "radial":
      return { type: "radial", spacing: 80 };
    case "tree":
      return { type: "tree", spacing: 120 };
    default:
      return { type: "force", spacing: 100 };
  }
}

async function loadGraphData(url) {
  const response = await fetch(url);
  if (!response.ok) return null;

  const data = await response.json();
  return data.nodes ? data : null;
}

export { ZoomSlider, resolveLayout, loadGraphData };
