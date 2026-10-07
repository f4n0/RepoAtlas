// Optional: requires an already-installed Playwright and Chromium browser.
// PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH can select an installed browser executable.
// An optional first argument checks an actual exported page as well.
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { chromium } = require("playwright");

async function main() {
    const directory = await fs.mkdtemp(path.join(os.tmpdir(), "repoatlas-browser-"));
    let browser;
    try {
        browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH });
        const definitions = [
            'flowchart LR\nA["Input"] --> B["Output"]',
            "INVALID_DIAGRAM",
            "sequenceDiagram\nparticipant A\nparticipant B\nA->>B: Run\nB-->>A: Done",
            "stateDiagram-v2\n[*] --> Ready\nReady --> Done: finish\nDone --> [*]",
            'erDiagram\nOWNER ||--o{ ITEM : owns\nOWNER {\nint id PK\n}\nITEM {\nint owner_id FK\n}',
            "classDiagram\nclass Runner {\n+run()\n}\nRunner <|-- CustomRunner",
            'flowchart TD\nStart --> Decision{"Valid?"}\nDecision -->|Yes|Finish\nDecision -->|No|Failure'
        ];
        const escape = text => text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
        const asset = name => pathToFileURL(path.resolve(__dirname, "../templates/html", name)).href;
        const html = '<!doctype html><html><head><meta charset="utf-8"><script defer src="' + asset("vendor/mermaid.min.js") + '"></script><script defer src="' + asset("diagrams.js") + '"></script></head><body>' +
            definitions.map(code => '<figure data-mermaid><div class="diagram-view" hidden></div><p class="diagram-status" role="status">Diagram preview requires JavaScript.</p><details open><summary>Diagram source</summary><pre><code>' + escape(code) + '</code></pre></details></figure>').join("") + '</body></html>';
        const file = path.join(directory, "index.html");
        await fs.writeFile(file, html);
        const context = await browser.newContext();
        const requests = [];
        await context.route(/^https?:/, route => { requests.push(route.request().url()); return route.abort(); });
        const page = await context.newPage();
        await page.goto(pathToFileURL(file).href);
        await page.waitForFunction(() => [...document.querySelectorAll("[data-mermaid]")].every(node => node.dataset.rendered));
        assert.equal(await page.locator('[data-rendered="true"] svg').count(), 6);
        assert.equal(await page.locator('[data-rendered="false"] details[open]').count(), 1);
        assert.equal(await page.locator('[data-rendered="false"] .diagram-view svg').count(), 0);
        assert.equal(await page.locator('[data-rendered="true"] details[open]').count(), 0);
        assert.match(await page.locator('[data-rendered="false"] .diagram-status').textContent(), /could not be rendered/);
        assert.equal(await page.locator('[data-rendered="false"] code').textContent(), "INVALID_DIAGRAM");
        if (process.argv[2]) {
            await page.goto(pathToFileURL(path.resolve(process.argv[2])).href);
            await page.waitForFunction(() => {
                const nodes = [...document.querySelectorAll("[data-mermaid]")];
                return nodes.length && nodes.every(node => node.dataset.rendered === "true");
            });
            assert.ok(await page.locator('[data-mermaid] svg').count());
        }
        assert.deepEqual(requests, [], "Rendering attempted network access");
        const noJs = await browser.newContext({ javaScriptEnabled: false });
        const fallback = await noJs.newPage();
        await fallback.goto(pathToFileURL(file).href);
        assert.equal(await fallback.locator('details[open]').count(), definitions.length);
        assert.equal(await fallback.locator('.diagram-view:visible').count(), 0);
        assert.equal(await fallback.locator('code').first().textContent(), definitions[0]);
        console.log("Browser diagram checks passed: six views, error isolation, offline file loading, and no-JavaScript fallback.");
    } finally {
        await browser?.close();
        await fs.rm(directory, { recursive: true, force: true });
    }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
