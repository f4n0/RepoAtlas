# Read a wiki in your browser

[Home](README.md) | [Parent](README.md)

Export a completed Markdown wiki to a separate HTML copy, then open it locally. The exporter does not research, write, or adapt the guide for a different audience. Source: [scripts/Export-RepoWikiHtml.ps1:1-16](../../../scripts/Export-RepoWikiHtml.ps1), purpose and parameters; [README.md](../../../README.md), audience guides and browser reading.

## Before exporting

- Use PowerShell 7 or later, with `pwsh` available as a command. The script uses PowerShell's bundled Markdown renderer; no extra packages, internet connection, or web server are required.
- Finish and validate the selected guide. For combined export, every registered guide must be complete.
- Keep input and output on the same filesystem volume as the documented repository. Choose a separate output folder, not a location inside the wiki or an ancestor containing the wiki/repository.
- Treat generated HTML as a reading copy; retain the Markdown wiki and local repository as the source of truth.

Sources: [scripts/Export-RepoWikiHtml.ps1:1-8](../../../scripts/Export-RepoWikiHtml.ps1), prerequisites; [scripts/Export-RepoWikiHtml.ps1:91-164](../../../scripts/Export-RepoWikiHtml.ps1), path, validation, and completion checks.

## Export and open

1. Replace the example paths below with the toolkit location, wiki collection, and documented repository.
2. Run the command. It validates input before converting pages.
3. On success, open the printed `index.html` path in your browser. No local development server is needed.
4. Keep the exported assets beside the HTML pages and retain access to the original repository for source citations.

Unverified example command; HTML export was not run as part of writing this guide:

```powershell
pwsh -NoProfile -File "C:/Tools/LocalRepoWiki/scripts/Export-RepoWikiHtml.ps1" `
  -WikiPath "C:/Code/MyProject/docs/wiki" `
  -RepoRoot "C:/Code/MyProject"
```

Without `OutputPath`, the script appends `-html` to the resolved wiki directory: this example produces `docs/wiki-html`. Add `-OutputPath "C:/Code/MyProject/docs/wiki-browser"` to choose another same-volume destination. `README.md` pages become `index.html`; other listed Markdown pages keep their base names with `.html`. Sources: [scripts/Export-RepoWikiHtml.ps1:91-105](../../../scripts/Export-RepoWikiHtml.ps1), destination and validation; [scripts/Export-RepoWikiHtml.ps1:155-164](../../../scripts/Export-RepoWikiHtml.ps1), page mapping; [scripts/Export-RepoWikiHtml.ps1:372-377](../../../scripts/Export-RepoWikiHtml.ps1), result/error messages.

### One guide or the collection

Passing the collection root exports the general index and matching audience subfolders. Passing `docs/wiki/end-users` exports only that completed guide; its default output is `docs/wiki/end-users-html`, and its `All audiences` reference leads to the original general Markdown index rather than creating a combined HTML index. This is useful when another guide is unfinished. Sources: [scripts/Export-RepoWikiHtml.ps1:91-156](../../../scripts/Export-RepoWikiHtml.ps1), contexts and standalone collection reference; [scripts/Export-RepoWikiHtml.ps1:247-257](../../../scripts/Export-RepoWikiHtml.ps1), link rewriting; [tests/Test-Validator.ps1:440-477](../../../tests/Test-Validator.ps1), incomplete collection and standalone export tests.

## Navigate and search

1. Choose a page from **Contents**. When its button is shown, **Contents** toggles the navigation panel; Escape closes it.
2. Use **Home** to return to the current guide. In a combined export, **All audiences** returns to the selection index. **On this page** links target the page's H2/H3 headings.
3. Type into **Search this wiki** to search titles and page text locally. Each whitespace-separated term must occur somewhere in the title/text, without case sensitivity. The matching-page count can exceed the first 30 links displayed; narrow the query when needed.
4. Clear the search field to restore the contents list. Searching from the general index spans all exported guides and labels audience results; searching within a guide stays within that audience.

Sources: [templates/html/page.html](../../../templates/html/page.html), visible labels and hidden-by-default search; [templates/html/wiki.js](../../../templates/html/wiki.js), toggle, matching, result limit, and reset; [scripts/Export-RepoWikiHtml.ps1:232-237](../../../scripts/Export-RepoWikiHtml.ps1), outline; [scripts/Export-RepoWikiHtml.ps1:265-327](../../../scripts/Export-RepoWikiHtml.ps1), navigation and audience-scoped indexes.

Search needs JavaScript and the generated local search asset. Without JavaScript, the shell still contains ordinary page navigation, but search stays hidden. Source: [templates/html/page.html](../../../templates/html/page.html), deferred scripts and navigation; [templates/html/wiki.js](../../../templates/html/wiki.js), activation after search-data detection.

## Refresh an existing copy

1. Update the Markdown guide, complete its review, and rerun validation.
2. Repeat your export command with `-Force` only if the destination is an unchanged previous export of this same wiki.
3. If the script reports unfamiliar or modified content, preserve those files and use a new empty output folder instead of deleting or overwriting them to bypass the guard.

`-Force` is not unconditional overwrite permission. The exporter checks ownership metadata and file hashes, rejects unknown/modified files and linked entries, and rejects destinations passing through symbolic links or junctions. It builds the new copy in staging, rechecks inputs and the destination before replacement, and reports failure with exit `1`. Sources: [scripts/Export-RepoWikiHtml.ps1:48-88](../../../scripts/Export-RepoWikiHtml.ps1), replacement guard; [scripts/Export-RepoWikiHtml.ps1:330-380](../../../scripts/Export-RepoWikiHtml.ps1), input checks and staged replacement. Tests specifically check that rendering failure and an incomplete audience do not replace existing copies: [tests/Test-Validator.ps1:298-313](../../../tests/Test-Validator.ps1), [tests/Test-Validator.ps1:443-449](../../../tests/Test-Validator.ps1).

## Diagrams and source references

Without `MermaidCliPath`, diagrams appear as expandable **Diagram source** blocks; their authored prose explanations remain available. To include SVGs, add `-MermaidCliPath "mmdc"`, or the executable path of a trusted installed local CLI. The exporter installs nothing and fails if the requested CLI is unavailable or rendering does not produce a nonempty SVG. Sources: [scripts/Export-RepoWikiHtml.ps1:182-185](../../../scripts/Export-RepoWikiHtml.ps1), CLI lookup; [scripts/Export-RepoWikiHtml.ps1:203-231](../../../scripts/Export-RepoWikiHtml.ps1), rendering/fallback. For separate rendering checks, see [validation and recovery](validation-and-recovery.md).

Source citations are rebased to the original repository files, not copied into the export. A browser may open or download them rather than show code inline, and displayed citation ranges do not provide source-line navigation. Keep the repository available in the relative location used by the export; this is not a self-contained publication bundle. Sources: [scripts/Export-RepoWikiHtml.ps1:247-257](../../../scripts/Export-RepoWikiHtml.ps1), local-target rebasing; [README.md](../../../README.md), source-reference limitations.

## Resolve export problems

| Message or symptom | Action |
| --- | --- |
| `Wiki validation failed` | Run the structural validator on the selected input and repair its reported problems |
| `HTML export requires a completed wiki` | Resume unfinished work; export only a completed audience when another is unfinished |
| `HTML output already exists` | Use `-Force` for an unchanged owned export, or select a new empty destination |
| `unfamiliar`, `modified`, or `different wiki` output | Preserve the existing content and choose another destination; do not bypass ownership guards |
| Output overlap, different volume, or linked-path error | Choose a real, separate same-volume directory |
| `Duplicate HTML output path` | Ask for a reviewed page rename and navigation/manifest update; for example, `README.md` and `index.md` in one folder both map to `index.html` |
| `Mermaid CLI unavailable` or rendering failure | Correct the trusted local CLI/runtime, or omit the option to retain diagram source and prose |
| `Wiki manifest changed during export` or `Wiki page changed during export` | Let the writer finish, then rerun against stable input |
| Raw HTML absent from a page | Use ordinary Markdown; the exporter removes raw HTML blocks and tags |
| Search absent | Check that JavaScript is enabled and exported local assets remain beside the pages |

Sources: [scripts/Export-RepoWikiHtml.ps1:48-105](../../../scripts/Export-RepoWikiHtml.ps1), path/ownership/validation failures; [scripts/Export-RepoWikiHtml.ps1:155-195](../../../scripts/Export-RepoWikiHtml.ps1), completion, collisions, and HTML removal; [scripts/Export-RepoWikiHtml.ps1:203-231](../../../scripts/Export-RepoWikiHtml.ps1), diagram errors; [scripts/Export-RepoWikiHtml.ps1:334-339](../../../scripts/Export-RepoWikiHtml.ps1), concurrent edits; [templates/html/wiki.js](../../../templates/html/wiki.js), search activation.

## Related pages

- [Check results and resolve problems](validation-and-recovery.md)
- [Choose settings and maintain guides](manage-guides.md)