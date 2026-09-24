// Vanilla replacement for jquery-ujs: submits data-remote forms and links
// with fetch, then dispatches the JSON contract
// (redirect_to / alert / form_errors / flash / region_html) that
// ApplicationController#redirect_to_with_json and #render_form_errors emit.
document.addEventListener("DOMContentLoaded", () => {
  document.addEventListener("submit", (event) => {
    const form = event.target.closest("form[data-remote='true']");
    if (!form) {
      return;
    }
    event.preventDefault();
    submitRemote(form, new FormData(form), form.method || "POST", form.action);
  });

  document.addEventListener("click", (event) => {
    const link = event.target.closest("a[data-remote='true'], a[data-method]");
    if (!link) {
      return;
    }
    const message = link.getAttribute("data-confirm");
    if (message && !window.confirm(message)) {
      event.preventDefault();
      return;
    }

    const method = (link.getAttribute("data-method") || "GET").toUpperCase();
    const remote = link.getAttribute("data-remote") === "true";
    if (!remote && method !== "GET") {
      // The single non-remote method link (logout): submit a hidden form so
      // the request arrives as DELETE with CSRF, exactly as rails-ujs did.
      event.preventDefault();
      const form = document.createElement("form");
      form.method = "POST";
      form.action = link.href;
      const methodInput = document.createElement("input");
      methodInput.type = "hidden";
      methodInput.name = "_method";
      methodInput.value = method;
      form.append(methodInput);
      const token = csrfToken();
      if (token) {
        const tokenInput = document.createElement("input");
        tokenInput.type = "hidden";
        tokenInput.name = "authenticity_token";
        tokenInput.value = token;
        form.append(tokenInput);
      }
      document.body.append(form);
      form.submit();
      return;
    }

    event.preventDefault();
    const disableWith = link.getAttribute("data-disable-with");
    let originalText = null;
    if (disableWith) {
      originalText = link.textContent;
      link.textContent = disableWith;
      link.setAttribute("aria-disabled", "true");
    }
    submitRemote(link, null, method, link.href).finally(() => {
      if (disableWith && originalText !== null) {
        link.textContent = originalText;
        link.removeAttribute("aria-disabled");
      }
    });
  });
});

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content;
}

function onRemoteStart(target) {
  document.querySelectorAll(".flashMessage").forEach((el) => el.remove());
  if (document.activeElement instanceof HTMLElement) {
    document.activeElement.blur();
  }
  if (target.matches("form")) {
    target
      .querySelectorAll(".js-form-submit")
      .forEach((el) => el.classList.add("is-spinning"));
  }
  if (target.classList.contains("button")) {
    target.classList.add("is-spinning");
  }
}

function unspin(target) {
  target.classList.remove("is-spinning");
  target
    .querySelectorAll(".js-form-submit")
    .forEach((el) => el.classList.remove("is-spinning"));
}

function submitRemote(target, body, method, url) {
  onRemoteStart(target);
  const headers = { Accept: "application/json" };
  const token = csrfToken();
  if (token) {
    headers["X-CSRF-Token"] = token;
  }
  return fetch(url, { method, body, headers, credentials: "same-origin" })
    .then(async (response) => {
      const data = await response.json().catch(() => null);
      if (!data) {
        console.log("Unsupported return.");
        return;
      }
      if (data.redirect_to) {
        Turbo.clearCache();
        Turbo.visit(data.redirect_to, { action: "replace" });
        console.log(`Redirected to ${data.redirect_to}`);
      }
      if (data.alert) {
        unspin(target);
        window.alert(data.alert);
      }
      if (data.form_errors) {
        if (target.matches("form")) {
          unspin(target);
          handleErrors(target, data.form_errors);
        }
      }
      if (data.flash) {
        unspin(target);
        document.querySelectorAll("body .flashMessage").forEach((el) => el.remove());
        for (const [key, value] of Object.entries(data.flash)) {
          const message = document.createElement("div");
          message.className = `flashMessage flashMessage--${key}`;
          message.textContent = value;
          document.body.prepend(message);
        }
      }
      if (data.region_html) {
        unspin(target);
        document.querySelectorAll(".js-ajax-region").forEach((region) => {
          const template = document.createElement("template");
          template.innerHTML = data.region_html.trim();
          region.replaceWith(template.content.cloneNode(true));
        });
        document.querySelector("[autofocus]")?.focus();
      }
    })
    .catch((error) => {
      unspin(target);
      console.log("Remote request failed.", error);
    });
}

function handleErrors(form, errors) {
  const html = document.createElement("div");
  html.className = "formErrors errorExplanation";
  const list = document.createElement("ul");
  errors.forEach((message) => {
    const item = document.createElement("li");
    item.textContent = message;
    list.append(item);
  });
  html.append(list);
  form.querySelectorAll(".formErrors").forEach((el) => el.remove());
  form.prepend(html);
  console.log(errors);
}
