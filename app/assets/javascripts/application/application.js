//= require turbo
//= require_tree ./vendor/.
//= require_self
//= require_tree .

document.addEventListener("DOMContentLoaded", () => {
  if (/firefox/i.test(navigator.userAgent)) {
    document.documentElement.classList.add("browser-firefox");
  }

  initMultiboxes();
  initCredentialInputs();

  document.addEventListener("keyup", (event) => {
    if (event.target.matches("input, select, textarea")) {
      return;
    }
    const key = event.key.toLowerCase();
    if (key === "s") {
      document.querySelector(".js-focus-on-s")?.focus();
      event.preventDefault();
    }
    if (key === "f") {
      document.querySelector(".js-focus-on-f")?.focus();
      event.preventDefault();
    }
  });

  document.addEventListener("click", (event) => {
    const flash = event.target.closest("html.main .flashMessage");
    if (flash) {
      flash.style.transition = "opacity 0.2s";
      flash.style.opacity = "0";
      setTimeout(() => flash.remove(), 220);
    }

    const helpToggle = event.target.closest(".js-toggle-helpbox");
    if (helpToggle) {
      document.querySelector(".js-helpbox")?.classList.toggle("is-hidden");
      event.preventDefault();
    }

    const toggle = event.target.closest(".js-toggle");
    if (toggle) {
      const selector = toggle.getAttribute("data-element");
      if (selector) {
        toggle.parentElement
          ?.querySelectorAll(selector)
          .forEach((el) => el.classList.toggle("is-hidden"));
      }
      event.preventDefault();
    }
  });

  document.addEventListener("input", (event) => {
    if (!event.target.matches("input[type=range]")) {
      return;
    }
    const updateAttr = event.target.getAttribute("data-update");
    if (updateAttr && updateAttr.length) {
      const target = document.querySelector(`.${updateAttr}`);
      if (target) {
        target.textContent = parseFloat(event.target.value, 10).toFixed(1);
      }
    }
  });

  document.addEventListener("change", (event) => {
    if (event.target.matches(".js-checkbox-list-toggle")) {
      const list = event.target.parentElement?.querySelector(".checkboxList");
      if (list) {
        list.style.display = event.target.value === "false" ? "" : "none";
      }
    }

    if (event.target.matches("select#credential_type")) {
      toggleCredentialInputs(event.target.value);
    }
  });
});

document.addEventListener("turbo:load", () => {
  initMultiboxes();
  initCredentialInputs();
});

function initMultiboxes() {
  document.querySelectorAll(".js-multibox:not([data-multibox-ready])").forEach((el) => {
    el.dataset.multiboxReady = "true";
    new Multibox(el, {
      inputCount: 6,
      classNames: { container: "multibox", input: "input input--text multibox__input" },
    });
  });
}

function toggleCredentialInputs(type) {
  document.querySelectorAll("[data-credential-key-type]").forEach((el) => {
    el.style.display = "none";
  });
  document
    .querySelectorAll("[data-credential-key-type] input")
    .forEach((input) => {
      input.disabled = true;
    });
  const selector =
    type === "SMTP-IP"
      ? "[data-credential-key-type=smtp-ip]"
      : "[data-credential-key-type=all]";
  document.querySelectorAll(selector).forEach((el) => {
    el.style.display = "";
  });
  document.querySelectorAll(`${selector} input`).forEach((input) => {
    input.disabled = false;
  });
}

function initCredentialInputs() {
  const input = document.querySelector("select#credential_type");
  if (input) {
    toggleCredentialInputs(input.value);
  }
}
