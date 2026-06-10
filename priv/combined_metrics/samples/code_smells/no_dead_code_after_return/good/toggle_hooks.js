export const TreeToggle = {
  mounted() {
    this.el.addEventListener("js:expand-all", () => {
      this.el.querySelectorAll("details").forEach((d) => (d.open = true));
    });
    this.el.addEventListener("js:collapse-all", () => {
      this.el.querySelectorAll("details").forEach((d) => (d.open = false));
    });
  },
};

export const CopyButton = {
  mounted() {
    this.el.addEventListener("click", async () => {
      const text = this.el.dataset.copy;
      if (!text) return;
      await navigator.clipboard.writeText(text);
      this.el.classList.add("copied");
    });
  },
};

export const ScrollIntoView = {
  mounted() {
    if (!this.el.dataset.scrollOnMount) return;
    this.el.scrollIntoView({ behavior: "smooth", block: "center" });
  },
};
