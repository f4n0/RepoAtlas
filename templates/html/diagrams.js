(() => {
    "use strict";
    const diagrams = document.querySelectorAll("[data-mermaid]");
    if (!diagrams.length) return;
    const mermaid = window.RepoWikiMermaid?.default;
    if (!mermaid) return;

    // Keep viewer policy independent of configuration embedded in diagram text.
    mermaid.initialize({
        startOnLoad: false,
        securityLevel: "strict",
        suppressErrorRendering: true,
        htmlLabels: false,
        fontFamily: 'Candara, "Trebuchet MS", sans-serif',
        secure: ["secure", "securityLevel", "startOnLoad", "suppressErrorRendering", "htmlLabels", "flowchart"],
        flowchart: { htmlLabels: false }
    });

    async function renderDiagrams() {
        await document.fonts?.ready;
        for (const [index, diagram] of Array.from(diagrams).entries()) {
            const view = diagram.querySelector(".diagram-view");
            const status = diagram.querySelector(".diagram-status");
            const source = diagram.querySelector("code").textContent;
            status.textContent = "Rendering diagram…";
            try {
                const { svg } = await mermaid.render(`repo-wiki-diagram-${index}`, source);
                view.innerHTML = svg;
                view.hidden = false;
                diagram.querySelector("details").open = false;
                status.hidden = true;
                diagram.dataset.rendered = "true";
            } catch {
                view.replaceChildren();
                view.hidden = true;
                status.textContent = "Diagram could not be rendered. Read its source and the accompanying explanation.";
                diagram.querySelector("details").open = true;
                diagram.dataset.rendered = "false";
            }
        }
    }
    renderDiagrams();
})();
