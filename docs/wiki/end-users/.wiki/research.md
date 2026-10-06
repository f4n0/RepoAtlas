# End-user research checkpoint

## Routing and snapshot

- Repository: C:/_Data/GitHub/LocalRepoWiki; product title in README: RepoAtlas.
- Collection: C:/_Data/GitHub/LocalRepoWiki/docs/wiki.
- Selected audience: end-users, English, standard depth; no prior wiki or registry exists.
- Git revision: 867d457d28fa743a55ce4f1a3509d921265a6857. Initial git status --short was empty. New documentation makes the final working tree modified.
- Global instructions supplied in context apply. No local AGENTS.md, copilot-instructions.md, or *.instructions.md was found.
- All generated collection files are excluded from source research. No services, downloads, installations, or application-source edits are authorized.

## Initial capability map

| Reader task | Evidence actually read | Boundary and dependencies | Proposed page |
| --- | --- | --- | --- |
| Ask the assistant to generate a wiki | README.md; attached prompts/repo-wiki.md, inputs and generation phases | Assistant performs local research and writing; toolkit does not run a model | getting-started.md |
| Choose audiences and update existing pages | README.md; attached prompts/repo-wiki.md, audience routing and updates | Independent guide metadata; shared registry and selection index | manage-guides.md |
| Validate a guide or collection | scripts/Test-RepoWiki.ps1:1-210, parameter block and collection/manifest branches | Explicit WikiPath and RepoRoot; planned missing pages are warnings in unfinished guides | validation-and-recovery.md |
| Read an HTML copy | README.md only so far; exporter implementation review outstanding | Optional export, not content generation; page plan tentative pending review | browser-export.md |

## First falsifiable check

Hypothesis: a separate end-users guide with version-1 metadata, a general index, and planned topics is accepted as an unfinished collection. Run scripts/Test-RepoWiki.ps1 with the absolute collection and repository paths. Unexpected errors in relativeRoot, registration, or navigation would disconfirm the layout before topic writing.

## Verified capability map for drafting

| Reader task | Owning evidence actually read | Boundary and dependencies | Page |
| --- | --- | --- | --- |
| Generate and read an end-user guide | README.md; attached prompts/repo-wiki.md, input defaults and Phases 1-4 | Local-file-capable assistant writes source-grounded Markdown; no model runner supplied | getting-started.md |
| Choose settings, add audiences, resume, update, relocate | prompts/repo-wiki.md, audience routing and updates; scripts/Test-RepoWiki.ps1:63-175 | Stable audience IDs and independent snapshots; permission required for legacy migration | manage-guides.md |
| Review completion and validate references | scripts/Test-RepoWiki.ps1:1-264; tests/Test-Validator.ps1:405-419 | Read-only structural checks; completion warnings can accompany exit 0; no factual verification | validation-and-recovery.md |
| Check optional diagrams | scripts/Test-RepoWikiDiagrams.ps1:1-129 | Local trusted CLI, temporary SVGs, no input writes; no-diagram exit 0 before CLI lookup | validation-and-recovery.md |
| Export, navigate, search, regenerate, recover | scripts/Export-RepoWikiHtml.ps1:1-380; templates/html/page.html; templates/html/wiki.js; tests/Test-Validator.ps1:230-490 | Completed manifests, local assets and original source links; guard/staging before replacement; scoped search | browser-export.md |

## Focused checkpoint result

The initial collection validator returned exit 0: one audience and general index passed, with five expected warnings for unfinished generation and planned pages. This verifies registration and relativeRoot, not topic content or completion.

## Important verified branches

- Validator: root collection dispatch versus individual guide; missing planned pages accepted only in unfinished generation; complete requires passed validation and no remaining work; citation ranges only checked for bounds.
- Exporter: validates first; every selected context must be complete; all volume/path and ownership guards precede replacement; raw HTML nodes removed; Mermaid is optional and explicit; no CLI means source/prose fallback; input hashes rechecked; staging is moved into place only after generation succeeds.
- Reader: labels verified in page.html; menu/Escape handlers and all-term case-insensitive matching verified in wiki.js; counts all matches but displays the first 30; general search labels audiences and guide search is scoped in exporter.
- Tests read, not executed: input Markdown preserved, source paths and body-text search exported, Force guards, diagram fallback/stand-in invocation, failed rendering leaves prior output, incomplete collection leaves prior output, collection/standalone/external audience link rebasing.
- No new Mermaid diagrams are needed for this task-oriented guide; numbered user actions explain the workflows without introducing unverified rendering.

## Final factual review

| Page | Deciding evidence reread or checked | Review outcome |
| --- | --- | --- |
| README.md | Prompt entry/defaults; script parameter blocks; source snapshot | Product description, task routing, actual tools, and coverage limits agree with local sources |
| getting-started.md | On-disk prompt inputs, audience routing, phases; repository README use/offline sections | End-user request explicitly selects end-users rather than relying on contributor default; local research distinguished from cloud-model privacy |
| manage-guides.md | On-disk prompt routing, preservation, updates, and manifest contract; validator collection/completion branches | Independent audiences, legacy permission boundary, current-working-tree updates, and resume rules accurately described |
| validation-and-recovery.md | Validator:149-264; diagram checker:80-129; actual collection test bodies | Exit 0 distinguished from completion; bounds distinguished from source accuracy; no-diagram exit precedes CLI lookup; tested definitions not presented as a new successful suite run |
| browser-export.md | Exporter:48-170 and 300-380; reader handlers and shell; diagram/link branches previously read; export test bodies | Same-volume/overlap/Force safeguards, completed-guide requirement, staged replacement, local search scope, source rebasing, and standalone output correctly described |

- Draft structural check found two citation endpoints beyond EOF. Corrected diagram checker range to 129 and exporter range to 380; rerun passed with only the in-progress warning.
- Local PowerShell version verified as 7.6.6; mmdc discovery returned unavailable. Diagram checker on the selected audience returned exit 0 with no diagrams and no renderer invocation.
- Final snapshot rechecked: revision unchanged, git status shows only nine new files under docs/wiki. No application source or existing project instructions were modified.
- Completed scope: home plus four flat task pages, each reachable from home and each topic linked to its home/parent. No section folders, architecture diagrams, or implementation excerpts are needed for these reader tasks.
- Finalization timestamp: 2026-10-06T14:47:24Z. Manifest records factual review, structural validation, and diagram scan separately. No required research remains; example workflows, integration suite, and HTML/browser execution remain explicitly unverified optional coverage.