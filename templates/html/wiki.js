(() => {
    "use strict";
    document.documentElement.classList.add("js");
    const sidebar = document.getElementById("sidebar");
    const toggle = document.querySelector(".menu-toggle");
    toggle.addEventListener("click", () => {
        const opened = toggle.getAttribute("aria-expanded") !== "true";
        toggle.setAttribute("aria-expanded", String(opened));
        sidebar.classList.toggle("is-open", opened);
    });
    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") {
            sidebar.classList.remove("is-open");
            toggle.setAttribute("aria-expanded", "false");
        }
    });

    const pages = window.REPO_WIKI_SEARCH;
    if (!Array.isArray(pages)) return;
    const form = document.querySelector(".search");
    const input = document.getElementById("wiki-search");
    const results = document.getElementById("search-results");
    const panel = document.querySelector(".search-results");
    const contents = document.querySelector(".contents");
    const status = document.querySelector(".search-status");
    const home = document.getElementById("wiki-home");
    form.hidden = false;
    form.addEventListener("submit", (event) => event.preventDefault());
    input.addEventListener("input", () => {
        const query = input.value.trim().toLocaleLowerCase();
        results.replaceChildren();
        panel.hidden = !query;
        contents.hidden = Boolean(query);
        if (!query) return;
        const terms = query.split(/\s+/);
        const matches = pages.filter((entry) => {
            const haystack = `${entry.title} ${entry.text}`.toLocaleLowerCase();
            return terms.every((term) => haystack.includes(term));
        });
        status.textContent = matches.length ? `${matches.length} matching page${matches.length === 1 ? "" : "s"}` : "No matching pages";
        for (const entry of matches.slice(0, 30)) {
            const item = document.createElement("li");
            const link = document.createElement("a");
            link.href = new URL(entry.path, home.href).href;
            link.textContent = entry.title;
            const excerpt = document.createElement("p");
            const found = entry.text.toLocaleLowerCase().indexOf(terms[0]);
            const start = Math.max(0, found - 45);
            excerpt.textContent = `${start ? "..." : ""}${entry.text.slice(start, start + 165)}${entry.text.length > start + 165 ? "..." : ""}`;
            item.append(link, excerpt);
            results.append(item);
        }
    });
})();