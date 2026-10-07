# Bundled Mermaid browser runtime

`mermaid.min.js` bundles Mermaid **11.12.0** and its dependencies as one classic
script exposing `RepoWikiMermaid.default`. It includes all Mermaid diagram types,
with no runtime module imports, CDN requests, or web server requirement.
Mermaid's license and the bundle's dependency notices accompany exported copies.

The checked-in bundle is generated with **esbuild 0.25.12**. Generation is a
maintainer operation; users do not need Node.js or npm to export/read a wiki.
In a separate temporary build directory:

```powershell
npm install --no-audit --no-fund mermaid@11.12.0 esbuild@0.25.12
./node_modules/.bin/esbuild ./node_modules/mermaid/dist/mermaid.esm.mjs --bundle --minify --format=iife --global-name=RepoWikiMermaid --platform=browser --target=es2020 --legal-comments=external --outfile="C:/path/to/RepoAtlas/templates/html/vendor/mermaid.min.js"
```

Retain the generated `mermaid.min.js.LEGAL.txt` and `MERMAID-LICENSE.txt` when
updating the bundle. Verify direct `file://` rendering and error/source fallback
after an update. Browser rendering is deferred until reading; export metadata
records `mode: browser` and `rendered: false`, not a successful render check.
