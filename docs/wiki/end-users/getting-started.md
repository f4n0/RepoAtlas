# Generate your first wiki

[Home](README.md) | [Parent](README.md)

Use this page to create a wiki for a local repository. RepoAtlas is a set of assistant instructions and optional checking/export tools, not a hosted documentation service or an application that runs a model for you. Source: [README.md](../../../README.md).

## Before you start

- Have the repository you want documented available locally.
- Use an AI coding assistant that can read, search, and write local files, and give it access to the toolkit's generation instructions.
- Decide who will read the wiki. If you do not specify an audience for a new collection, the instructions default to new contributors, not end users.
- PowerShell 7 or later is needed only for the supplied validation, diagram, and HTML scripts. The writing instructions themselves are tool-neutral, and the toolkit needs no package installation or server.

Sources: [README.md](../../../README.md), [prompts/repo-wiki.md](../../../prompts/repo-wiki.md).

## Create an end-user guide

1. Open the repository you want documented in your assistant's workspace. If several repositories are open, specify the repository path explicitly.
2. Attach, paste, or reference the toolkit's [prompts/repo-wiki.md](../../../prompts/repo-wiki.md). You do not need to copy the optional templates into the target repository.
3. Send the request below after replacing the toolkit path. If another repository is open, specify that repository rather than accidentally documenting the toolkit.
4. Let the assistant complete its research, pages, factual review, and validation. For a large repository it may leave an honest in-progress checkpoint; see [resume and update](manage-guides.md).
5. Open the generated collection's `docs/wiki/README.md` in Markdown preview, choose **End users**, and follow its task links. Within this toolkit's own generated collection, [All audiences](../README.md) opens that index.

Illustrative assistant request, unverified as a separate generation run:

```text
Follow C:/Tools/LocalRepoWiki/prompts/repo-wiki.md.
Document the repository currently open.
Output: docs/wiki
Language: English
Audience: end users
Audience ID: end-users
Depth: standard
Focus: getting started, everyday tasks, user-facing settings, and troubleshooting.
Complete the research, pages, factual review, and validation.
Preserve existing guides and manual edits. Refresh the general index.
```

The path in this request locates the toolkit; `Output` belongs to the repository being documented. Sources: [README.md](../../../README.md), [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), input defaults and audience routing.

## Recognize the result

A new collection has this layout; only audiences you request are generated:

```text
docs/wiki/
  README.md                    selection index
  .wiki/audiences.json          registered guides
  end-users/
    README.md                  end-user home and contents
    .wiki/manifest.json         scope, sources, progress, and checks
    ...                        task pages chosen for this repository
```

Do not expect a fixed number of pages. The assistant should organize verified reader tasks rather than create one page per source file. Topic pages include local evidence and navigation; the home explains the project, its scope, and coverage limitations. Source: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), audience routing and Phases 2-3.

The Markdown is the editable source. HTML is an optional separate copy, described in [browser export](browser-export.md). Existing legacy wikis can have their manifest directly at the wiki root; updating one does not automatically convert it to audience folders. Source: [README.md](../../../README.md).

## Privacy and offline boundaries

The generation instructions restrict research to local evidence, exclude secrets and generated output, and forbid fetching URLs or downloading dependencies. The validator and exported reader also work locally. However, your assistant may send context to its configured cloud model. Fully offline generation requires an already-installed local model and an assistant capable of using it; RepoAtlas does not supply either. Sources: [prompts/repo-wiki.md](../../../prompts/repo-wiki.md), working rules; [README.md](../../../README.md), Offline behavior.

## Before relying on the guide

Check its stated audience, snapshot, and limitations. Ask for unfinished work to be completed rather than accepting an outline or assuming a successful link check proves the content. Use [validation and recovery](validation-and-recovery.md) to distinguish factual review, structure checking, and optional rendering.

## Related pages

- [Choose settings and maintain guides](manage-guides.md)
- [Check results and resolve problems](validation-and-recovery.md)
- [Read a wiki in your browser](browser-export.md)