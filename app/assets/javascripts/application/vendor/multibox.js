// Vanilla replacement for the vendored jquery.multibox plugin: splits one
// hidden input into N single-character boxes (used for the domain
// verification code), keeping the hidden input in sync. Same observable
// behavior: filter regex, auto-advance, backspace navigation, paste spread,
// initial value fill, autofocus handling.
class Multibox {
  constructor(el, options = {}) {
    this.el = el;
    this.options = {
      classNames: {
        container: "multibox",
        input: "multibox-input",
        ...(options.classNames || {}),
      },
      inputCount: options.inputCount ?? 4,
      regex: options.regex ?? /\D/g,
    };
    this.draw();
    this.listen();
  }

  destroy() {
    this.inputs.forEach((input) => input.removeEventListener("input", this.onInput));
    this.inputs.forEach((input) => input.removeEventListener("keydown", this.onKeydown));
    this.inputs.forEach((input) => input.removeEventListener("paste", this.onPaste));
    this.container.replaceWith(this.el);
    if (this.previousType) {
      this.el.setAttribute("type", this.previousType);
    }
  }

  draw() {
    const inputAutofocus = this.el.hasAttribute("autofocus");
    const inputType = this.el.getAttribute("type");
    const inputValue = this.el.value || "";

    if (inputType !== "hidden") {
      this.previousType = inputType;
      this.el.setAttribute("type", "hidden");
    }

    this.container = document.createElement("div");
    this.container.className = this.options.classNames.container;

    this.inputs = [];
    for (let i = 0; i < this.options.inputCount; i += 1) {
      const input = document.createElement("input");
      input.className = this.options.classNames.input;
      input.setAttribute("maxlength", "1");
      input.setAttribute("size", "1");
      input.setAttribute("type", "text");
      this.container.append(input);
      this.inputs.push(input);
    }

    this.el.replaceWith(this.container);
    this.container.append(this.el);

    const text = this.filterString(inputValue);
    let focusIndex;
    if (text.length) {
      const inputIndex = this.setFromString(0, text);
      focusIndex = inputIndex;
    }

    if (inputAutofocus) {
      if (focusIndex === undefined) {
        focusIndex = 0;
      } else if (focusIndex >= this.inputs.length) {
        focusIndex = this.inputs.length - 1;
      }
      this.inputs[focusIndex]?.focus();
    }
  }

  listen() {
    this.onInput = (event) => this.handleInput(event);
    this.onKeydown = (event) => this.handleKeydown(event);
    this.onPaste = (event) => this.handlePaste(event);
    this.inputs.forEach((input) => {
      input.addEventListener("input", this.onInput);
      input.addEventListener("keydown", this.onKeydown);
      input.addEventListener("paste", this.onPaste);
    });
  }

  handleKeydown(event) {
    if (event.key !== "Backspace") {
      return;
    }
    event.preventDefault();
    const input = event.target;
    const prev = input.previousElementSibling;
    if (prev) {
      prev.focus();
    }
    if (input.value) {
      input.value = "";
    } else if (prev) {
      prev.value = "";
    }
    this.update();
  }

  handleInput(event) {
    const input = event.target;
    const filtered = this.filterString(input.value);
    input.value = filtered;
    if (filtered) {
      const next = input.nextElementSibling;
      if (next && next.tagName === "INPUT") {
        next.focus();
      }
    }
    this.update();
  }

  handlePaste(event) {
    event.preventDefault();
    const input = event.target;
    const text = (event.clipboardData?.getData("text") || "");
    const filtered = this.filterString(text);
    if (!filtered.length) {
      return;
    }
    const inputIndex = this.setFromString(this.inputs.indexOf(input), filtered);
    const focusIndex =
      inputIndex >= this.inputs.length ? this.inputs.length - 1 : inputIndex;
    this.inputs[focusIndex]?.focus();
    this.update();
  }

  filterString(str) {
    return str.replace(this.options.regex, "");
  }

  setFromString(index, str) {
    let inputIndex = index;
    let strIndex = 0;
    while (this.inputs[inputIndex] && str[strIndex]) {
      this.inputs[inputIndex].value = str[strIndex];
      inputIndex += 1;
      strIndex += 1;
    }
    return inputIndex;
  }

  update() {
    this.el.value = this.inputs.map((input) => input.value).join("");
    this.el.dispatchEvent(new Event("change", { bubbles: true }));
  }
}

window.Multibox = Multibox;
