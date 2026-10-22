# RepoAtlas wiki interrogation guide

Use this guide to query the generated RepoAtlas documentation quickly and precisely. It routes a question to the audience page that answers it, names the exact search terms and source paths, and records where the wiki is limited. It is a companion to the Markdown wiki, not a substitute for the cited repository sources.

## Scope and snapshot

- Repository: RepoAtlas, the local toolkit documented by this wiki.
- Snapshot: commit `3f3d6e2e192951ee08ad5b25de6d81aff9bc9e69`; working tree modified by the toolkit changes described here and by this documentation collection.
- Language: English.
- Scope: end-user generation, request settings, audience maintenance, validation and recovery, local HTML reading, and the root `SKILL.md` interrogation guide.
- Not covered: toolkit implementation internals, choosing or configuring an AI model, installing a Mermaid renderer, and executing model workflows. See the limitations below.

## Audience guide

| Audience ID | Title | Home | Reader tasks |
| --- | --- | --- | --- |
| `end-users` | End users | [README.md](end-users/README.md) | Generate a wiki, choose settings, maintain guides, validate results, read the HTML copy, and use this guide. |

The general index at [README.md](README.md) selects the registered guide. The guide is complete for its stated scope; its manifest records passed structural validation and the limitations below.

## Question routing

Read the listed page before opening other files. Search terms are exact strings or topics that occur in the page or its cited sources.

| Question | Read in order | Search terms |
| --- | --- | --- |
| How do I create my first wiki? | [Generate your first wiki](end-users/getting-started.md) | `Follow`, `Output`, `Audience`, `end-users`, `SKILL.md` |
| What should the generated collection look like? | [getting-started.md](end-users/getting-started.md) | `docs/wiki/`, `audiences.json`, `manifest.json`, `SKILL.md` |
| How do I choose language, depth, audience, or output? | [Choose settings and maintain guides](end-users/manage-guides.md) | `Inputs and defaults`, `Audience ID`, `Depth`, `Output` |
| How do I add another audience without replacing the current guide? | [manage-guides.md](end-users/manage-guides.md) | `Add a guide`, `All audiences`, `registry`, `SKILL.md` |
| How do I update or resume a guide after source changes? | [manage-guides.md](end-users/manage-guides.md) | `Update after repository changes`, `remainingWork`, `working tree`, `SKILL.md` |
| How do I validate structure and citations? | [Check results and resolve problems](end-users/validation-and-recovery.md) | `Test-RepoWiki.ps1`, `WikiPath`, `RepoRoot`, `Validation passed`, `SKILL.md` |
| What does a validation warning or failure mean? | [validation-and-recovery.md](end-users/validation-and-recovery.md) | `FAIL:`, `unfinished`, `invalid line range`, `missing link target` |
| How do I export, search, or refresh the HTML copy? | [Read a wiki in your browser](end-users/browser-export.md) | `Export-RepoWikiHtml.ps1`, `-Force`, `index.html`, `search` |
| Why is `SKILL.md` not in the HTML export? | [browser-export.md](end-users/browser-export.md) | `manifest pages`, `SKILL.md`, `companion` |
| What are the known coverage gaps? | [End-user home](end-users/README.md), [validation-and-recovery.md](end-users/validation-and-recovery.md) | `limitations`, `not run`, `mmdc`, `model` |

## Page catalog

| Page | Purpose | Status | Key terms | Repository sources |
| --- | --- | --- | --- | --- |
| [README.md](README.md) | Collection selection index and guide status. | Complete | audience, guide, progress | — |
| [End-user home](end-users/README.md) | Scope, tasks, tool map, and limitations. | Complete | end users, tools, coverage | `README.md`, `prompts/repo-wiki.md`, `scripts/Test-RepoWiki.ps1`, `scripts/Test-RepoWikiDiagrams.ps1`, `scripts/Export-RepoWikiHtml.ps1` |
| [getting-started.md](end-users/getting-started.md) | First generation request, expected layout, privacy. | Complete | request, layout, SKILL.md, offline | `README.md`, `prompts/repo-wiki.md` |
| [manage-guides.md](end-users/manage-guides.md) | Settings, audiences, updates, resume, relocation. | Complete | settings, audience ID, update, migration | `README.md`, `prompts/repo-wiki.md`, `scripts/Test-RepoWiki.ps1` |
| [validation-and-recovery.md](end-users/validation-and-recovery.md) | Review, structural checks, repairs, diagrams. | Complete | validator, exit codes, Mermaid, SKILL.md | `README.md`, `prompts/repo-wiki.md`, `scripts/Test-RepoWiki.ps1`, `scripts/Test-RepoWikiDiagrams.ps1`, `tests/Test-Validator.ps1` |
| [browser-export.md](end-users/browser-export.md) | Export, navigate, search, refresh, diagram fallback. | Complete | exporter, Force, HTML, search | `README.md`, `scripts/Export-RepoWikiHtml.ps1`, `templates/html/page.html`, `templates/html/wiki.js`, `templates/html/diagrams.js`, `tests/Test-Validator.ps1` |

## Evidence and links

- Wiki links are relative to the page containing them. Source citations point at repository files and include line labels where useful; line labels are text, not guaranteed editor jumps.
- The wiki describes the recorded snapshot, not necessarily the current working tree. Recheck a cited source before relying on a claim that may have changed.
- `SKILL.md` is a companion artifact at the collection root. It is not listed in an audience manifest, not part of an audience's navigation, and not included in the HTML export. Do not cite this guide as repository evidence.

## Retrieval protocol

1. Match the question to **Question routing**. Use the page order and search terms.
2. Read only the routed page or pages. Follow their links to related pages when the first page delegates a topic.
3. Confirm the answer against the page's cited source files. If the working tree differs, prefer the current source and state the discrepancy.
4. Report the page and source used. If the wiki does not cover the question, say so and fall back to the page catalog or general index, not a full-wiki read.
5. If the answer depends on an unverified example, an optional tool, or the integration suite, label that uncertainty.

Examples:

- "How do I create my first wiki?" Read `getting-started.md`, then cite its request example and the generation prompt. Do not claim the example was executed.
- "Why is `SKILL.md` missing from the HTML copy?" Read `browser-export.md`, then confirm that the exporter enumerates manifest pages and the general index only.

## Limitations and validation

- Structural validation passed for the collection and the selected guide; this covers metadata, manifest coverage, local links, navigation, citation bounds, and exact one-H1 checks.
- The integration suite was run for this update and passed. It covers the root `SKILL.md` exemption in standalone and collection layouts, export guards, and completion behavior. It does not prove factual correctness.
- The guide has no Mermaid diagrams. The optional diagram checker found no blocks and invoked no renderer; `mmdc` was unavailable.
- HTML export was not run for this update. The generated `docs/wiki-html` is a separate reading copy and may not include the `SKILL.md` companion.
- Commands and requests with illustrative paths are examples, not executed workflows unless explicitly noted.
- Factual review covered the home and four task pages; implementation extension, model selection, and renderer installation remain outside scope.
