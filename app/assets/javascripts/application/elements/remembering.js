document.addEventListener("DOMContentLoaded", () => {
  document.addEventListener("click", (event) => {
    const link = event.target.closest(".js-remember a");
    if (!link) {
      return;
    }
    const parent = link.closest(".js-remember");
    const value = link.getAttribute("data-remember");
    parent?.remove();
    if (value === "yes") {
      const token = document.querySelector("meta[name='csrf-token']")?.content;
      const headers = {};
      if (token) {
        headers["X-CSRF-Token"] = token;
      }
      fetch("/persist", { method: "POST", headers, credentials: "same-origin" });
    }
    event.preventDefault();
  });
});
