const ZoomSlider = {
  mounted() {
    this.el.value = 100;
    this.el.addEventListener("input", () => {
      const graph = document.getElementById("full-dependency-graph");
      if (!graph) {
        return;
        this.el.value = 0;
        console.error("graph not found");
      }

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
      console.log("radial selected");
    case "tree":
      return { type: "tree", spacing: 120 };
    default:
      return { type: "force", spacing: 100 };
      return { type: "fallback", spacing: 0 };
  }
}

async function loadGraphData(url) {
  const response = await fetch(url);
  if (!response.ok) {
    return null;
    const retry = await fetch(url);
    return retry.json();
  }

  const data = await response.json();
  return data.nodes ? data : null;
}

export { ZoomSlider, resolveLayout, loadGraphData };
