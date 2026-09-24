const ENTER = 13;
const DOWN_ARROW = 40;
const UP_ARROW = 38;

function getContainer(el) {
  return el.closest(".js-searchable");
}

function getEmpty(container) {
  return container.querySelector(".js-searchable__empty");
}

function getList(container) {
  return container.querySelector(".js-searchable__list");
}

function getItems(container) {
  return [...container.querySelectorAll(".js-searchable__item")];
}

function getIndex(container) {
  const raw = container.dataset.searchifyIndex;
  return raw === undefined || raw === "" ? undefined : Number(raw);
}

function setIndex(container, index) {
  if (index === undefined) {
    delete container.dataset.searchifyIndex;
  } else {
    container.dataset.searchifyIndex = String(index);
  }
}

function getMatches(container) {
  return getItems(container).filter((item) => !item.classList.contains("is-hidden"));
}

function highlightItem(container, scope, index) {
  getItems(container).forEach((item) => item.classList.remove("is-highlighted"));
  if (index !== undefined && scope.length) {
    scope[index]?.classList.add("is-highlighted");
  }
}

function toggleState(container, predicate) {
  getEmpty(container)?.classList.toggle("is-hidden", predicate);
  getList(container)?.classList.toggle("is-hidden", !predicate);
}

function filterList(container, query) {
  const items = getItems(container);
  let index = getIndex(container);
  const re = new RegExp(query, "g");
  const matches = items.filter((item) => re.test(item.dataset.value || ""));
  items.forEach((item) => item.classList.add("is-hidden"));
  matches.forEach((item) => item.classList.remove("is-hidden"));
  toggleState(container, matches.length > 0);
  if (index !== undefined) {
    index = 0;
    setIndex(container, index);
  }
  highlightItem(container, matches, index);
}

function showAll(container) {
  const items = getItems(container);
  let index = getIndex(container);
  items.forEach((item) => item.classList.remove("is-hidden"));
  toggleState(container, true);
  if (index !== undefined) {
    index = 0;
    setIndex(container, index);
    highlightItem(container, items, index);
  }
}

function highlightNext(container) {
  const matches = getMatches(container);
  const index = getIndex(container);
  if (!matches.length) {
    return;
  }
  let newIndex;
  if (index !== undefined) {
    if (index === matches.length - 1) {
      return;
    }
    newIndex = index + 1;
  } else {
    newIndex = 0;
  }
  setIndex(container, newIndex);
  highlightItem(container, matches, newIndex);
}

function highlightPrev(container) {
  const matches = getMatches(container);
  const index = getIndex(container);
  if (!matches.length) {
    return;
  }
  let newIndex;
  if (index !== undefined) {
    if (index === 0) {
      return;
    }
    newIndex = index - 1;
  } else {
    newIndex = 0;
  }
  setIndex(container, newIndex);
  highlightItem(container, matches, newIndex);
}

function selectHighlighted(container) {
  const index = getIndex(container);
  const matches = getMatches(container);
  if (index === undefined || !matches.length) {
    return;
  }
  const url = matches[index]?.dataset.url;
  if (url) {
    Turbo.visit(url);
  }
}

function searchify(str) {
  return str.toLowerCase().replace(/\W/g, "");
}

function handleInput(event) {
  const input = event.target;
  const container = getContainer(input);
  const query = searchify(input.value);
  if (query.length) {
    filterList(container, query);
  } else {
    showAll(container);
  }
}

function handleKeydown(event) {
  const container = getContainer(event.target);
  if (event.keyCode === DOWN_ARROW) {
    event.preventDefault();
    highlightNext(container);
  } else if (event.keyCode === ENTER) {
    event.preventDefault();
    selectHighlighted(container);
  } else if (event.keyCode === UP_ARROW) {
    event.preventDefault();
    highlightPrev(container);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  document.addEventListener("input", (event) => {
    if (event.target.matches(".js-searchable__input")) {
      handleInput(event);
    }
  });
  document.addEventListener("keydown", (event) => {
    if (event.target.matches(".js-searchable__input")) {
      handleKeydown(event);
    }
  });
});
