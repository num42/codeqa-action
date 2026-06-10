export const StickyOffset = {
  mounted() {
    this.target = document.getElementById(this.el.dataset.stickyOffsetTarget);
    if (!this.target) return;

    this.update = () => {
      this.el.style.setProperty("--sticky-offset", this.target.offsetHeight + "px");
    };

    this.update();
    this.observer = new ResizeObserver(() => this.update());
    this.observer.observe(this.target);
  },

  destroyed() {
    if (this.observer) this.observer.disconnect();
  },
};

export const TreeToggle = {
  mounted() {
    const expand = () => this.el.querySelectorAll("details").forEach((d) => (d.open = true));
    const collapse = () => this.el.querySelectorAll("details").forEach((d) => (d.open = false));

    this.el.addEventListener("js:expand-all", expand);
    this.el.addEventListener("js:collapse-all", collapse);
  },
};

export const AutoFocus = {
  mounted() {
    const input = this.el.querySelector("input, textarea");
    if (!input) return;

    input.focus();
    input.setSelectionRange(input.value.length, input.value.length);
  },
};
