# Check results and resolve problems

[Home](README.md) | [Parent](README.md)

Use this page before relying on a generated wiki or exporting it. Factual review, structural validation, and diagram rendering answer different questions; a successful check is not proof that the assistant's explanations are correct. Sources: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Phase 4; [scripts/Test-RepoWiki.ps1:1-8](../../../scripts/Test-RepoWiki.ps1).

## Review content and completion

1. Read the selected guide's home for its audience, source snapshot, scope, and gaps.
2. Ask the assistant to audit significant claims against deciding code branches, not just verify that cited files exist. This includes settings, defaults, outputs, errors, and diagrams where present.
3. Inspect the selected guide's `.wiki/manifest.json`: generation and page statuses should be `complete`, `remainingWork` should be empty, and validation should be `passed` before it is called finished.
4. Keep any honest limitations visible. A complete scoped guide need not claim that every subsystem, sample command, or optional renderer was checked.

Sources: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Phase 4 and manifest contract; [scripts/Test-RepoWiki.ps1:149-175](../../../scripts/Test-RepoWiki.ps1), consistency checks.

## Run structural validation

Requires PowerShell 7 or later and `pwsh` available as a command. Replace the example paths with your toolkit, generated guide, and documented repository. This command is an unverified example for another repository; this guide's own validation is recorded in its manifest.

```powershell
pwsh -NoProfile -File "C:/Tools/LocalRepoWiki/scripts/Test-RepoWiki.ps1" `
  -WikiPath "C:/Code/MyProject/docs/wiki/end-users" `
  -RepoRoot "C:/Code/MyProject"
```

`RepoRoot` is the repository being documented, not necessarily the toolkit folder. Pass the audience folder to check only that guide. To check the general index and every registered guide, run the same command with `-WikiPath "C:/Code/MyProject/docs/wiki"`. Source: [scripts/Test-RepoWiki.ps1:1-13](../../../scripts/Test-RepoWiki.ps1), parameters; [scripts/Test-RepoWiki.ps1:63-130](../../../scripts/Test-RepoWiki.ps1), collection dispatch.

| Result | Meaning | Next action |
| --- | --- | --- |
| Exit `0`, `Validation passed` | The implemented structure/reference checks passed | Review warnings and content; confirm completion separately |
| Exit `1`, `FAIL:` messages | Input, metadata, page, navigation, or reference problems were found | Repair reported problems and rerun the same check |
| Warnings about unfinished generation or missing planned pages | An unfinished guide may still pass structurally | Resume its recorded work; do not label it complete yet |
| Warning about an external URL or heading fragment | That target was not checked offline | Treat it as unverified; prefer portable local file links |

Sources: [scripts/Test-RepoWiki.ps1:149-175](../../../scripts/Test-RepoWiki.ps1), completion warnings; [scripts/Test-RepoWiki.ps1:200-264](../../../scripts/Test-RepoWiki.ps1), link checks and exit handling.

The script writes no files. It checks metadata, listed-page coverage, one H1 per page, unresolved template markers, home/parent navigation, local destinations, cited-source dependencies, and explicit citation line bounds. It does not verify factual claims, source-line meaning, Mermaid syntax, or heading-fragment validity, and it is designed for the prompt's simple Markdown conventions. Sources: [scripts/Test-RepoWiki.ps1:132-264](../../../scripts/Test-RepoWiki.ps1), individual-guide checks; [scripts/Test-RepoWiki.ps1:1-8](../../../scripts/Test-RepoWiki.ps1), scope.

## Repair common failures

| Report or symptom | Recovery |
| --- | --- |
| Missing `.wiki/manifest.json` | Confirm you selected a generated audience folder or legacy wiki, not an arbitrary docs folder; ask the assistant to inspect existing content before replacing it |
| `repository.relativeRoot does not resolve to RepoRoot` | Confirm the documented repository path and ask the assistant to recalculate metadata from the audience directory |
| Missing link target or invalid line range | Ask for the affected page and source to be reread; refresh the link or citation based on actual evidence |
| Page absent from manifest or home contents | Ask the assistant to reconcile the page plan, metadata, and contents without deleting unfamiliar/manual pages |
| Missing home, parent, or general-index link | Restore audience-local home/parent navigation and the registered home page's `All audiences` link |
| Invalid/duplicate audience ID or linked audience directory | Use a unique lowercase kebab-case ID and a real direct child directory, not a symbolic link or junction |
| Both registry and single-wiki manifest at the root | Stop and resolve the intended layout; authorize a migration if needed rather than mixing contracts |

Sources: [scripts/Test-RepoWiki.ps1:65-130](../../../scripts/Test-RepoWiki.ps1), collection rules; [scripts/Test-RepoWiki.ps1:132-253](../../../scripts/Test-RepoWiki.ps1), manifest and navigation checks; [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), preservation and migration requirements.

Collection failures identify the affected audience. Check your selected guide separately when another guide is incomplete or broken; unrelated guide failures should not be recorded as unfinished work for your guide. Combined export still requires all registered guides to be complete. Sources: [scripts/Test-RepoWiki.ps1:74-91](../../../scripts/Test-RepoWiki.ps1), child-result handling; [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Phase 4 collection validation.

## Optional diagram checks

If the wiki contains Mermaid diagrams, use a trusted, already-installed local Mermaid CLI with a working browser runtime. Nothing is installed by the checker. This is an unexecuted example for a wiki containing diagrams:

```powershell
pwsh -NoProfile -File "C:/Tools/LocalRepoWiki/scripts/Test-RepoWikiDiagrams.ps1" `
  -WikiPath "C:/Code/MyProject/docs/wiki/end-users" `
  -MermaidCliPath "mmdc"
```

Sources: [README.md](../../../README.md), local renderer prerequisites; [scripts/Test-RepoWikiDiagrams.ps1:1-14](../../../scripts/Test-RepoWikiDiagrams.ps1), requirements and parameters; [scripts/Test-RepoWikiDiagrams.ps1:84-114](../../../scripts/Test-RepoWikiDiagrams.ps1), CLI resolution and invocation.

| Exit | Meaning | Recovery |
| --- | --- | --- |
| `0` | Diagrams rendered, or no Mermaid blocks were found | Read the actual message; no diagrams means no renderer ran |
| `1` | Bad input, malformed fences, rendering errors, or missing/empty SVG output | Ask the assistant to repair the diagram or retain an accurate prose explanation and outstanding work |
| `2` | CLI unavailable and diagrams were not rendered | Record the unavailable check; keep the prose fallback |

The checker scans Markdown recursively, ignores root `.wiki` metadata, and skips diagram-like text inside examples and HTML comments. Use ordinary top-level fenced diagrams rather than list- or blockquote-nested fences. It renders temporary SVGs and removes the temporary files, leaving the wiki pages unchanged. Rendering does not verify factual relationships or guarantee compatibility with another viewer. Source: [scripts/Test-RepoWikiDiagrams.ps1:24-129](../../../scripts/Test-RepoWikiDiagrams.ps1), extraction, rendering, cleanup, and results.

## What the repository tests establish

The integration tests include broken collection links and IDs, source-link preservation during export, unchanged input Markdown, unknown/edited export-file rejection, and preservation of an existing export when rendering or completion checks fail. These are specific tested cases, not a guarantee about all inputs. The test source was reviewed for this guide; the integration suite was not rerun for this documentation change. Source: [tests/Test-Validator.ps1:232-313](../../../tests/Test-Validator.ps1), single-guide export cases; [tests/Test-Validator.ps1:405-454](../../../tests/Test-Validator.ps1), collection cases.

## Related pages

- [Choose settings and maintain guides](manage-guides.md)
- [Read a wiki in your browser](browser-export.md)