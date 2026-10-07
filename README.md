# RepoAtlas
Turn an open local repository into an evidence-based, navigable Markdown wiki using your existing AI coding assistant. No service, API integration, database, package installation, or build step is needed.

## Quick start

1. Open the repository you want to document in an assistant that can read, search, and write local files.
2. Give the assistant access to [prompts/repo-wiki.md](prompts/repo-wiki.md), either by attaching it, pasting it, or referencing its absolute path.
3. Send this request, replacing the toolkit path:

```text
Follow C:/Tools/LocalRepoWiki/prompts/repo-wiki.md.
Document the repository currently open.
Write the wiki to docs/wiki. Use English, target new contributors,
and use standard depth. Complete the research, pages, and validation.
```

4. Open `docs/wiki/README.md` in your editor's Markdown preview and follow the links.

The prompt is self-contained; templates are optional examples. RepoAtlas does not configure or run your assistant's model.

## Documentation

Start with the [end-user guide](docs/wiki/end-users/README.md) or the [documentation index](docs/wiki/README.md).

| Task | Guide |
| --- | --- |
| Generate your first wiki and understand its output | [Getting started](docs/wiki/end-users/getting-started.md) |
| Choose settings, add audiences, resume, update, or relocate a guide | [Settings and guide maintenance](docs/wiki/end-users/manage-guides.md) |
| Review quality, validate references, check diagrams, or resolve failures | [Validation and recovery](docs/wiki/end-users/validation-and-recovery.md) |
| Export a completed wiki, search it locally, or refresh an HTML copy | [Browser export](docs/wiki/end-users/browser-export.md) |

Markdown remains the editable source. HTML exports are local reading copies, not self-contained publications: source citations still depend on the original repository and do not enable source-line navigation.

## Requirements and privacy

Generation needs an assistant with local read, search, and write access. The optional checking and HTML scripts require **PowerShell 7+**. HTML diagrams render offline in a modern browser using bundled **Mermaid.js**, with no CLI or server required. Separate diagram checks and optional static SVG export need an already-installed, trusted **Mermaid CLI** with a working local browser runtime. Nothing is installed automatically.

Research and local reading/checks use the local checkout, but your configured assistant may use a cloud model. Completely offline generation requires an already-installed local model and a compatible assistant.

## Development checks

Run the integration checks from the toolkit root with PowerShell 7+:

```powershell
pwsh -NoProfile -File ./tests/Test-Validator.ps1
```

Diagram tests use a renderer stand-in; they do not validate real Mermaid syntax or require Mermaid CLI.

Optional real-browser checks require an existing Node.js/Playwright installation and browser:

```powershell
node ./tests/Test-BrowserDiagrams.cjs
```

These checks open local files, block network requests, and exercise all six recommended diagram types, invalid-diagram recovery, and the JavaScript-disabled fallback. Bundle provenance and rebuilding instructions are in [the vendor notes](templates/html/vendor/README.md).

## Credits

Inspired by [DeepWiki-Open](https://github.com/AsyncFuncAI/deepwiki-open) by AsyncFuncAI. Credit to its authors and contributors for the original idea of AI-generated repository wikis.

Architecture and documentation workflow improvements also draw inspiration from [Litho (deepwiki-rs)](https://github.com/sopaco/deepwiki-rs) and [OpenDeepWiki](https://github.com/AIDotNet/OpenDeepWiki).
