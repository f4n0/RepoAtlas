# RepoAtlas
Turn an open local repository into an evidence-based, navigable Markdown wiki using your existing AI coding assistant. No service, API integration, database, package installation, or build step is needed.

## Use it

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

The prompt is self-contained. Templates are optional examples, not files you must install in the target repository. You can also use the prompt as custom instructions for a documentation session. This toolkit does not configure your assistant or its model.

## Options

Include any of these in your request:

| Option | Default | Example |
| --- | --- | --- |
| Repository | Current open repository | `Repository: C:/Code/MyProject` |
| Output | Wiki collection root, `docs/wiki` under the repository | `Output: C:/Docs/MyProjectWiki` |
| Language | English | `Language: Spanish` |
| Audience | New contributors | `Audience: maintainers` |
| Audience ID | `contributors` for new contributors; stable folder name | `Audience ID: end-users` |
| Depth | Standard; adapt to repository size | `Depth: concise` or `comprehensive` |
| Focus | Major systems and workflows | `Focus: CLI and plugin loading` |
| Exclusions | Dependencies, generated output, binaries, secrets | `Exclude: archived/, fixtures/large/` |
| Mode | Create, or update an existing generated wiki | `Mode: update` or `resume` |

The assistant should research implementations, plan a repository-specific structure, write pages, and check them. It should not merely fill generic headings or stop after proposing a plan. Large repositories may take several sessions; each audience's `.wiki/manifest.json` records its own progress and source dependencies.

## Audience guides

New wikis use a general index and independent audience folders:

```text
docs/wiki/
  README.md                  # Choose a guide
  .wiki/audiences.json        # Registered audience IDs and titles
  contributors/
    README.md
    .wiki/manifest.json
    ...
  end-users/
    README.md
    .wiki/manifest.json
    ...
```

Only requested audiences are generated. New contributors use `contributors`; end users use `end-users`. Specify `Audience ID` to choose another stable lowercase kebab-case identifier. Display names can change without renaming folders.

To add an end-user guide without replacing the contributor wiki:

```text
Follow C:/Tools/LocalRepoWiki/prompts/repo-wiki.md.
Document the repository currently open.
Output: docs/wiki
Audience: end users
Audience ID: end-users
Focus: getting started, everyday tasks, user-facing settings, and troubleshooting.
Complete this guide and refresh the general index. Preserve other audiences.
```

Rerunning for an existing audience updates or resumes that guide. A material change to its audience or scope triggers replanning even when the code is unchanged. End-user pages describe verified user actions and outcomes rather than reusing a contributor-oriented architecture outline. The general index links all registered guides; their source snapshots, scope, and validation remain independent.

Existing single-wiki layouts still work with the scripts and can be updated in place. Converting them to audience folders requires explicit permission to move pages and rebase links; the prompt must not silently migrate or overwrite them.

## What you get

- A home page with capability-grouped contents, task-oriented reading paths, and a "Where to change what" guide when useful.
- Section indexes where the number of topics warrants them.
- Topic-specific pages: architecture views, workflow walkthroughs, configuration tables, and development guides as appropriate.
- Home, parent, and related-page navigation using relative links.
- Source citations that point to local files, with line ranges and symbols in the text, including adjacent attribution for repository code excerpts.
- A generation manifest recording scope, progress, reviewed sources, and limitations.

See the optional page sketches: [home](templates/home.md), [section index](templates/section-index.md), and [topic](templates/topic.md). Replace their placeholders with researched content and omit sections that do not apply.

## How quality is handled

Before choosing pages, the assistant maps verified capabilities to owning implementations, tests, and topic boundaries. Architecture uses a C4-style zoom from system context to runtime units, components, and selected code details only where useful. It does not require four pages, diagrams everywhere, or one page per file.

Research and review distinguish implementation, tested cases, documented intent, and uncertainty. Repository excerpts must match their cited source ranges; illustrative examples and unexecuted commands are labeled. Diagrams need verified relationships, source citations, and a prose fallback. A separate draft audit checks important claims against the deciding code; valid links alone do not prove accuracy.

## Validate locally (optional)

Requires **PowerShell 7 or later**. Run from any directory with explicit paths:

```powershell
pwsh -NoProfile -File "C:/Tools/LocalRepoWiki/scripts/Test-RepoWiki.ps1" `
  -WikiPath "C:/Code/MyProject/docs/wiki" `
  -RepoRoot "C:/Code/MyProject"
```

The validator makes no network calls and writes no files. For a collection root it checks the audience registry, general index links, and each registered guide. Pass an audience folder such as `docs/wiki/end-users` to check only that guide. Individual guide checks cover the manifest, local link destinations, page headings and navigation, page coverage, source-file paths, and explicit citation line ranges. Exit code `0` means those checks passed; `1` means a validation failure. It does **not** establish factual correctness, validate Mermaid, or check heading fragments. It supports the deliberately simple Markdown conventions in the prompt, not every possible Markdown extension. Existing external links are reported as warnings, since their availability cannot be checked offline.

To run the template, validator, and diagram-checker integration checks (temporary fixtures are removed afterward):

```powershell
pwsh -NoProfile -File ./tests/Test-Validator.ps1
```

The diagram integration tests use a renderer stand-in to test extraction and invocation. They do not test real Mermaid syntax or require Mermaid CLI.

## Read in a browser (optional)

Keep the Markdown wiki as your editable source and export a separate HTML copy. Requires **PowerShell 7+**, using its bundled Markdown renderer; no extra packages, server, or internet connection are needed.

```powershell
pwsh -NoProfile -File "C:/Tools/LocalRepoWiki/scripts/Export-RepoWikiHtml.ps1" `
  -WikiPath "C:/Code/MyProject/docs/wiki" `
  -RepoRoot "C:/Code/MyProject"
```

Open the printed `index.html` path in your browser. The default output is a sibling folder such as `docs/wiki-html`; use `-OutputPath` to choose another folder on the same filesystem volume. The [HTML exporter](scripts/Export-RepoWikiHtml.ps1) adds responsive contents navigation, a heading outline, local full-text search, and readable tables and code blocks. It converts only completed pages listed in the wiki manifest and leaves Markdown and repository files untouched.

For an audience collection, the same command exports the general index and all registered guides into matching HTML subfolders. Each guide has its own contents and search, with an "All audiences" link back to the general index. Search from the general index spans all guides and labels results by audience. Every registered guide must be complete for combined export; an incomplete guide stops export without replacing an existing copy. To export only one completed guide, pass its folder as `-WikiPath`; its general-index link remains a reference to the original Markdown index.

To regenerate an existing export, add `-Force`. Replacement is allowed only when the folder belongs to this wiki and its generated files are unchanged. Unknown files, manual edits, symbolic links, overlapping input/output paths, and conflicting HTML page names are rejected. If you want to customize presentation, edit the [HTML shell](templates/html/page.html), [stylesheet](templates/html/wiki.css), or [reader script](templates/html/wiki.js), not generated files. Raw HTML in wiki content is omitted; use normal Markdown.

Diagrams retain their code and prose fallback by default. To include SVG diagrams, also pass `-MermaidCliPath "mmdc"` or the path of an already-installed local Mermaid CLI. No renderer is installed or downloaded, and requested rendering failures stop the export without replacing an existing copy.

Source citations still refer to the original repository, which must remain alongside the exported wiki. Browsers may open or download source files rather than display them inline, and citation labels do not enable line navigation. This export is for local reading, not a self-contained publication. The integration tests cover HTML conversion, search data, safe regeneration, and diagram invocation as well as the original validator checks.

## Check diagrams (optional)

Requires **PowerShell 7+** and an already-installed, trusted **Mermaid CLI (`mmdc`)** with a working local browser runtime. Nothing is installed automatically. From the toolkit root, use its command name or replace it with the local executable path:

```powershell
pwsh -NoProfile -File ./scripts/Test-RepoWikiDiagrams.ps1 `
  -WikiPath "C:/Code/MyProject/docs/wiki" `
  -MermaidCliPath "mmdc"
```

The [diagram checker](scripts/Test-RepoWikiDiagrams.ps1) renders simple fenced Mermaid blocks into temporary SVGs and removes those files afterward. It skips fenced examples, HTML comments, and `.wiki` metadata; it does not modify wiki pages. Use ordinary top-level fences, not diagrams nested inside list items or blockquotes. Do not include external asset URLs in diagrams.

Exit code `0` means rendering passed or no diagrams were found; `1` means an input/render failure; `2` means the CLI is unavailable and rendering was **not checked**. Record the outcome separately from structural validation and factual review. Rendering success does not prove source accuracy or compatibility with another viewer's Mermaid version.

## Update a wiki

```text
Follow C:/Tools/LocalRepoWiki/prompts/repo-wiki.md.
Update the contributors guide in docs/wiki against the current working tree.
Audience ID: contributors
First map changed sources to affected pages and sections in a change-impact
report. Recheck direct and indirect dependencies, make targeted edits, keep
stable page names, preserve manual edits, and refresh citations, the manifest,
and navigation. Refresh the general index and preserve other audience guides.
Report the changes, checks, and remaining uncertainty.
```

Updates review changes to behavior, interfaces, defaults, tested cases, and citation locations. Internal refactors and test-only changes are not automatically skipped. If the previous source state is unavailable, the assistant rechecks current code and records that limitation rather than inventing a diff.

Source links work while the wiki retains its relative location to the repository. To relocate or share a wiki, move it with the repository or regenerate the source links for its new location. Citations show line numbers as text because local Markdown viewers generally do not support source-line navigation. Diagrams include prose fallbacks for viewers without Mermaid support.

## Offline behavior

Research uses only the local checkout. Reading the generated wiki and running the validator require no internet. Your assistant may use a cloud model if that is how you configured it. Completely offline generation requires an already-installed local model and an assistant able to use it; this toolkit does not download or run a model.


## Credits

Inspired by [DeepWiki-Open](https://github.com/AsyncFuncAI/deepwiki-open) by AsyncFuncAI. Credit to its authors and contributors for the original idea of AI-generated repository wikis.

Architecture and documentation workflow improvements also draw inspiration from [Litho (deepwiki-rs)](https://github.com/sopaco/deepwiki-rs) and [OpenDeepWiki](https://github.com/AIDotNet/OpenDeepWiki).