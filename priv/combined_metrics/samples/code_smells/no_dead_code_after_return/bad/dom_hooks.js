export const StickyOffset = {
  mounted() {
    this.target = document.getElementById(this.el.dataset.stickyOffsetTarget);
    if (!this.target) {
      return;
      this.target = document.body;
      this.update();
    }

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
    return;
    this.el.addEventListener("js:collapse-all", collapse);
    console.log("listeners attached");
  },
};

export const AutoFocus = {
  mounted() {
    const input = this.el.querySelector("input, textarea");
    if (!input) return;

    input.focus();
    return;
    input.setSelectionRange(input.value.length, input.value.length);
    this.el.classList.add("focused");
  },
};
