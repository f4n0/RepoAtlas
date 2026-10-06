# Choose settings and maintain guides

[Home](README.md) | [Parent](README.md)

Use settings in your assistant request to choose the reader and coverage, then update the same guide as the repository changes. These are generation instructions, not command-line switches for the checking or export scripts. Source: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Inputs and defaults.

## Choose settings

| Request setting | Default or rule | When to specify it |
| --- | --- | --- |
| Repository | Specified local folder, otherwise the open repository; ambiguity requires clarification | More than one repository is open, or the target is elsewhere |
| Output | `docs/wiki` under the documented repository | You want another local collection location |
| Language | English | Readers need a different language |
| Audience | New contributors for a new collection; an existing selected guide retains its audience | Use `Audience: end users` for a task-oriented user guide |
| Audience ID | `contributors` for new contributors, `end-users` for end users; reuse registered IDs | Identify the exact guide to create or update |
| Depth | Standard, adapted to complexity | Request concise or comprehensive coverage |
| Focus / exclusions | Major workflows; dependencies, generated output, binaries, and secrets excluded by default | Prioritize user tasks or omit a named subsystem |
| Mode | Create a missing audience guide, otherwise update or resume it | Make your intent explicit for an existing collection |

Source: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Inputs and defaults and working rules. No fixed page count is imposed.

Focus and exclusions should appear in the guide's scope and limitations. Changing the audience or materially changing coverage triggers review and adaptation even if the source files have not changed. Changing only an audience's display name does not require a content rewrite. Source: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Updates and resuming.

## Add a guide without replacing another

1. Point the assistant at the existing collection root.
2. State `Audience: end users` and `Audience ID: end-users`, or reuse the relevant registered ID.
3. Ask it to create only that audience guide, preserve all other guides and manual edits, and refresh the general index.
4. Check the general index to confirm both guides remain accessible and that their separate limitations are visible.

IDs are lowercase kebab-case direct subfolders, such as `end-users`. Names, aliases, capitalization, or translated display titles should not produce duplicate guides. Each audience has an independent manifest and source snapshot; reviewing one does not imply the others were reviewed. Symbolic links and junctions are not supported as audience folders. Sources: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Audience routing; [scripts/Test-RepoWiki.ps1:65-91](../../../scripts/Test-RepoWiki.ps1), collection branch.

If `Output` already names a registered audience directory, the instructions use it directly instead of nesting another `end-users` folder. If an existing output has no generation metadata, the assistant must inspect it and ask before replacing conflicting content. Source: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), audience routing and working rule 5.

## Resume interrupted work

1. Use the same collection, audience ID, and intended scope.
2. Ask the assistant to read the selected guide's manifest and existing pages first.
3. Ask it to finish the `planned` and `in_progress` pages and the manifest's `remainingWork`, preserving completed content and manual edits.
4. Ask for renewed factual review and applicable checks, not just a change of status to `complete`.

The instructions require progress to be recorded before completion. A finished guide has complete pages, no remaining work, and passed validation. The validator warns about unfinished generation and permits missing planned pages in an unfinished guide, so exit code `0` alone does not mean writing is done. Sources: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), manifest contract; [scripts/Test-RepoWiki.ps1:149-175](../../../scripts/Test-RepoWiki.ps1).

## Update after repository changes

Illustrative assistant request, unverified as a separate update run:

```text
Follow C:/Tools/LocalRepoWiki/prompts/repo-wiki.md.
Update the end-users guide in docs/wiki against the current working tree.
Audience: end users
Audience ID: end-users
First map changed behavior and sources to affected pages and sections.
Recheck direct and indirect dependencies, preserve manual edits and stable
page names, and refresh citations, navigation, and the manifest.
Refresh the general index. Preserve all other audience guides.
Complete factual review and applicable validation; report remaining gaps.
```

The assistant should compare actual working-tree files, including uncommitted changes, rather than treating the recorded commit as a complete change detector. Changed tests, internal refactors, moved sources, and indirect dependencies can affect explanations or citations. If the previous source state is unavailable, it must reread current sources and report that limitation rather than invent a diff. Source: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Updates and resuming.

## Legacy layouts and relocation

A legacy single guide has a root `.wiki/manifest.json` instead of a collection registry. Updating the same audience retains that layout. Creating another audience or converting the collection requires an explained migration and your permission before moving existing pages or replacing the root index. The validator rejects a root containing both metadata formats. Sources: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), legacy routing; [scripts/Test-RepoWiki.ps1:65-70](../../../scripts/Test-RepoWiki.ps1).

Source references depend on the wiki's relative location. Move the guide with the repository, or ask for links and `repository.relativeRoot` to be recalculated and checked after relocation. An external output directory is allowed, but links must still resolve to the documented local repository. Source: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), Links and citations and migration rules.

## Related pages

- [Generate your first wiki](getting-started.md)
- [Check results and resolve problems](validation-and-recovery.md)
- [Read a wiki in your browser](browser-export.md)