export const ClearOnSubmit = {
  mounted() {
    this.el.addEventListener("submit", () => {
      const inputs = this.el.querySelectorAll("input[data-clear]");
      if (inputs.length === 0) return;

      inputs.forEach((input) => {
        input.value = "";
      });
    });
  },
};

export const CharCounter = {
  mounted() {
    this.counter = this.el.querySelector("[data-char-count]");
    if (!this.counter) return;

    this.field = this.el.querySelector("textarea, input");
    if (!this.field) return;

    this.render = () => {
      this.counter.textContent = String(this.field.value.length);
    };
    this.field.addEventListener("input", this.render);
    this.render();
  },

  destroyed() {
    if (this.field) this.field.removeEventListener("input", this.render);
  },
};

export const ConfirmBeforeLeave = {
  mounted() {
    this.dirty = false;
    this.el.addEventListener("change", () => (this.dirty = true));
    window.addEventListener("beforeunload", (e) => {
      if (!this.dirty) return;
      e.preventDefault();
      e.returnValue = "";
    });
  },
};
