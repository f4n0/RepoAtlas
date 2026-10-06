# RepoAtlas for end users

[All audiences](../README.md)

RepoAtlas supplies portable instructions for an AI coding assistant to research a local repository and write a navigable Markdown wiki. It also supplies optional local PowerShell tools for validation, diagram checks, and HTML export. The instructions do not configure or run the assistant's model. Sources: [README.md](../../../README.md), [prompts/repo-wiki.md](../../../prompts/repo-wiki.md).

## Scope and snapshot

This English, standard-depth guide is for people using the toolkit, not extending its scripts. It covers first use, settings and audience guides, updates, checking results, and browser reading. It documents local commit `867d457d28fa743a55ce4f1a3509d921265a6857`; the working tree was clean before generation and is now modified only by this documentation collection.

## Choose your task

| Task | Read next |
| --- | --- |
| Use the toolkit for the first time | [Generate your first wiki](getting-started.md) |
| Change language, scope, or audience; add or update a guide | [Choose settings and maintain guides](manage-guides.md) |
| Check completion, repair references, or handle diagrams | [Check results and resolve problems](validation-and-recovery.md) |
| Export, search, or refresh an HTML copy | [Read a wiki in your browser](browser-export.md) |

For a first run, follow these pages in order: generation, settings as needed, validation, then optional browser export. All topic pages are listed above.

## What performs each task

| Capability | What you use | Result |
| --- | --- | --- |
| Research and writing | The generation instructions with your local-file-capable assistant | An audience guide, source citations, and progress metadata |
| Structure checking | `Test-RepoWiki.ps1` with explicit wiki and repository paths | A read-only report of structure and reference problems |
| Optional diagram checking | `Test-RepoWikiDiagrams.ps1` with a trusted, already-installed Mermaid CLI | A render-check result, separate from factual review |
| Browser reading | `Export-RepoWikiHtml.ps1` on a completed guide or collection | A separate HTML copy with local navigation and search |

Sources: [prompts/repo-wiki.md:1-19](../../../prompts/repo-wiki.md), generation entry point; [scripts/Test-RepoWiki.ps1:1-13](../../../scripts/Test-RepoWiki.ps1), structural checker; [scripts/Test-RepoWikiDiagrams.ps1:1-14](../../../scripts/Test-RepoWikiDiagrams.ps1), optional diagram checker; [scripts/Export-RepoWikiHtml.ps1:1-16](../../../scripts/Export-RepoWikiHtml.ps1), HTML export.

## Coverage and limitations

The home and four task pages were factually reviewed against the local generation instructions, deciding script branches, reader controls, and relevant integration-test definitions. Structural checks cover local destinations, citation bounds, metadata, and navigation, not the truth of implementation claims.

The guide does not cover changing the toolkit implementation, choosing an AI model, or installing a Mermaid renderer. Commands with example paths are unverified examples unless explicitly recorded as executed. The integration suite and HTML export were not run for this documentation change. The diagram scan found no Mermaid blocks and invoked no renderer; local `mmdc` was unavailable. Check details and source dependencies are recorded in the guide's manifest.

## Source references

Source links point into this local checkout. Citation line ranges, when supplied, are text labels rather than editor-specific jumps. Keep the guide with its repository so relative links remain usable.