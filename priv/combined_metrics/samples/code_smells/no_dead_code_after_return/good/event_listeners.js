export const DblClickPushEvent = {
  mounted() {
    this.el.addEventListener("dblclick", () => {
      const event = this.el.getAttribute("data-dblclick-event");
      if (!event) return;

      const payload = {};
      for (const attr of this.el.attributes) {
        const match = attr.name.match(/^data-dblclick-value-(.+)$/);
        if (match) {
          payload[match[1]] = attr.value;
        }
      }

      this.pushEvent(event, payload);
    });
  },
};

export const FormulaBuilderHiddenInput = {
  updated() {
    const form = this.el.closest("form");
    if (!form) return;
    if (!form.getAttribute("phx-change")) return;

    this.el.dispatchEvent(new Event("input", { bubbles: true }));
  },
};

function debounce(fn, wait) {
  let timer = null;
  return (...args) => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => fn(...args), wait);
  };
}

export const SearchInput = {
  mounted() {
    const handler = debounce((value) => this.pushEvent("search", { query: value }), 200);
    this.el.addEventListener("input", (e) => {
      const value = e.target.value.trim();
      if (value.length < 2) return;
      handler(value);
    });
  },
};
