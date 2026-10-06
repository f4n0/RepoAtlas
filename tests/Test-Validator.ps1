#Requires -Version 7.0
[CmdletBinding()]
param([switch] $KeepFixture)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$toolkit = Split-Path $PSScriptRoot -Parent
$validator = Join-Path $toolkit 'scripts/Test-RepoWiki.ps1'
$diagramChecker = Join-Path $toolkit 'scripts/Test-RepoWikiDiagrams.ps1'
$htmlExporter = Join-Path $toolkit 'scripts/Export-RepoWikiHtml.ps1'
$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('repo-wiki-tests-' + [guid]::NewGuid().ToString('N'))
$checks = 0

function Assert-Check([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}

function Expand-Template([string] $Name, [hashtable] $Values) {
    $text = Get-Content -LiteralPath (Join-Path $toolkit "templates/$Name") -Raw
    foreach ($match in [regex]::Matches($text, '\{\{(?<key>[^}]+)\}\}')) {
        $key = $match.Groups['key'].Value
        if (-not $Values.ContainsKey($key)) { throw "Missing template value: $Name/$key" }
        $text = $text.Replace($match.Value, [string] $Values[$key])
    }
    return $text
}

function Invoke-Validator([int] $ExpectedExit, [string] $ExpectedMessage) {
    $output = & $pwsh -NoProfile -File $validator -WikiPath $wiki -RepoRoot $repo 2>&1
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    Assert-Check ($exitCode -eq $ExpectedExit) "Expected validator exit $ExpectedExit, got ${exitCode}: $text"
    Assert-Check ($text.Contains($ExpectedMessage)) "Missing validator message '$ExpectedMessage': $text"
}

function Invoke-DiagramCheck([int] $ExpectedExit, [string] $ExpectedMessage, [string] $CliPath) {
    $output = & $pwsh -NoProfile -File $diagramChecker -WikiPath $diagramWiki -MermaidCliPath $CliPath 2>&1
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    Assert-Check ($exitCode -eq $ExpectedExit) "Expected diagram exit $ExpectedExit, got ${exitCode}: $text"
    Assert-Check ($text.Contains($ExpectedMessage)) "Missing diagram message '$ExpectedMessage': $text"
}

function Invoke-HtmlExport([int] $ExpectedExit, [string] $ExpectedMessage, [string[]] $ExtraArguments = @(), [string] $TargetDirectory = $htmlOutput) {
    $output = & $pwsh -NoProfile -File $htmlExporter -WikiPath $wiki -RepoRoot $repo -OutputPath $TargetDirectory @ExtraArguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    Assert-Check ($exitCode -eq $ExpectedExit) "Expected HTML export exit $ExpectedExit, got ${exitCode}: $text"
    Assert-Check ($text.Contains($ExpectedMessage)) "Missing HTML export message '$ExpectedMessage': $text"
}

try {
    $repo = Join-Path $fixture 'repository with spaces'
    $wiki = Join-Path $repo 'docs/wiki'
    [IO.Directory]::CreateDirectory((Join-Path $repo 'src')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $wiki '.wiki')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $wiki 'workflows')) | Out-Null
    [IO.File]::WriteAllLines((Join-Path $repo 'src/run.ps1'), @('param()', "'safe'", "'done'"))

    $homePage = Expand-Template 'home.md' @{
        project_name                                              = 'Fixture'
        evidence_based_description                                = 'A local workflow fixture.'
        repository_relative_path                                  = 'src/run.ps1'
        start                                                     = '1'
        end                                                       = '3'
        relative_source_path                                      = '../../src/run.ps1'
        audience                                                  = 'New contributors'
        scope                                                     = 'The run workflow'
        commit_or_unknown                                         = 'Unknown'
        state                                                     = 'unknown'
        task_oriented_reading_paths                               = 'To follow a run, read [Run](workflows/run.md).'
        complete_linked_page_list_grouped_by_capability_if_useful = "### Workflows`n`n- [Workflows](workflows/README.md)`n- [Run](workflows/run.md)"
        subsystem                                                 = 'Runner'
        verified_responsibility                                   = 'Emit local results'
        where_to_change_what_section_if_useful                    = "## Where to change what`n`n| Task | Source | Guide |`n| --- | --- | --- |`n| Change results | [src/run.ps1](../../src/run.ps1) | [Run](workflows/run.md) |"
        specific_limitations                                      = 'Only the fixture workflow is covered.'
    }
    $index = Expand-Template 'section-index.md' @{
        section_title                     = 'Workflows'
        relative_home                     = '../README.md'
        section_purpose_and_boundaries    = 'Follow the run workflow; development is outside this scope.'
        topic_title                       = 'Run'
        relative_topic                    = 'run.md'
        reader_question_and_topic_summary = 'What does a run emit?'
        task_oriented_reading_order       = 'Start with [Run](run.md) to follow execution.'
    }
    $topicValues = @{
        topic_title                                               = 'Run'
        relative_home                                             = '../README.md'
        relative_parent                                           = 'README.md'
        purpose_and_boundaries                                    = 'Explain the results of a run.'
        responsibilities_inputs_outputs_and_links_to_other_topics = 'The runner emits two strings and requires no input.'
        topic_specific_sections_with_inline_citations             = "## Execution`n`n1. Emit safe.`n2. Emit done.`n`nSources: [src/run.ps1:1-3](../../../src/run.ps1)."
        short_attributed_examples_if_useful                       = @'
## Source excerpt

```powershell
param()
'safe'
'done'
```

Source: [src/run.ps1:1-3](../../../src/run.ps1).
'@
        contracts_failures_and_test_evidence_if_applicable        = ''
        related_title                                             = 'Workflows'
        relative_related_page                                     = 'README.md'
        when_to_consult_this_page                                 = 'Choose a workflow'
        deduplicated_key_source_files_if_useful                   = "## Key source files`n`n- [src/run.ps1](../../../src/run.ps1) - runner entry point."
    }
    $topic = Expand-Template 'topic.md' $topicValues
    [IO.File]::WriteAllText((Join-Path $wiki 'README.md'), $homePage)
    [IO.File]::WriteAllText((Join-Path $wiki 'workflows/README.md'), $index)
    $topicPath = Join-Path $wiki 'workflows/run.md'
    [IO.File]::WriteAllText($topicPath, $topic)
    $manifest = @{
        schemaVersion = 1
        generator     = 'local-repo-wiki'
        status        = 'complete'
        generatedAt   = '2026-01-01T00:00:00Z'
        repository    = @{ name = 'fixture'; relativeRoot = '../..'; revision = $null; workingTree = 'unknown' }
        scope         = @{ language = 'English'; audience = 'New contributors'; depth = 'standard'; include = @('workflow'); exclude = @() }
        pages         = @(
            @{ path = 'README.md'; title = 'Fixture'; kind = 'home'; status = 'complete'; sources = @('src/run.ps1') }
            @{ path = 'workflows/README.md'; title = 'Workflows'; kind = 'index'; status = 'complete'; sources = @() }
            @{ path = 'workflows/run.md'; title = 'Run'; kind = 'topic'; status = 'complete'; sources = @('src/run.ps1') }
        )
        limitations   = @('Fixture only')
        remainingWork = @()
        validation    = @{ status = 'passed'; checks = @('fixture review'); notes = @() }
    }
    [IO.File]::WriteAllText((Join-Path $wiki '.wiki/manifest.json'), ($manifest | ConvertTo-Json -Depth 10))
    Invoke-Validator 0 'Validation passed: 3 pages'

    [IO.File]::WriteAllText($topicPath, $topic.Replace('src/run.ps1:1-3', 'src/run.ps1:1-99'))
    Invoke-Validator 1 'invalid line range'
    [IO.File]::WriteAllText($topicPath, $topic + "`n[Missing](missing.md)`n")
    Invoke-Validator 1 'missing link target'
    [IO.File]::WriteAllText($topicPath, $topic + "`n{{unfinished}}`n")
    Invoke-Validator 1 'unresolved template placeholder'
    [IO.File]::WriteAllText($topicPath, $topic + "`n~~~~markdown`n# Example only`n[Missing](missing.md)`n{{example}}`n~~~~`n")
    Invoke-Validator 0 'Validation passed: 3 pages'
    [IO.File]::WriteAllText($topicPath, $topic)

    $topicVariants = @(
        "## System context`n`nA caller runs the local script.`n`nSources: [src/run.ps1:1-3](../../../src/run.ps1)."
        "## Settings`n`n| Setting | Default |`n| --- | --- |`n| Inputs | None |`n`nSources: [src/run.ps1:1-3](../../../src/run.ps1)."
        "## Change points`n`nEdit the emitted strings in the runner.`n`nSources: [src/run.ps1:1-3](../../../src/run.ps1)."
    )
    foreach ($sections in $topicVariants) {
        $values = $topicValues.Clone()
        $values.topic_specific_sections_with_inline_citations = $sections
        $values.short_attributed_examples_if_useful = ''
        [IO.File]::WriteAllText($topicPath, (Expand-Template 'topic.md' $values))
        Invoke-Validator 0 'Validation passed: 3 pages'
    }
    [IO.File]::WriteAllText($topicPath, $topic)

    $diagramWiki = Join-Path $fixture 'diagram wiki'
    [IO.Directory]::CreateDirectory((Join-Path $diagramWiki '.wiki')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $diagramWiki 'nested')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $diagramWiki 'README.md'), '# No diagrams yet')
    $missingCli = Join-Path $fixture 'missing-mmdc'
    Invoke-DiagramCheck 0 'No Mermaid diagrams found' $missingCli

    $renderer = Join-Path $fixture 'renderer stand-in.ps1'
    [IO.File]::WriteAllText($renderer, @'
param(
    [Alias('i')] [string] $InputPath,
    [Alias('o')] [string] $OutputPath,
    [Alias('c')] [string] $ConfigPath
)
$ErrorActionPreference = 'Stop'
$code = [IO.File]::ReadAllText($InputPath)
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ($config.securityLevel -ne 'strict') { throw 'Missing strict renderer configuration.' }
if ($code.Contains('DO_NOT_RENDER')) { throw 'Example, comment, or metadata was rendered.' }
if ($code.Contains('REJECT_BY_RENDERER')) {
    [Console]::Error.WriteLine('Fixture renderer rejection.')
    exit 1
}
if ($code.Contains('NO_RENDER_OUTPUT')) { exit 0 }
[IO.File]::WriteAllText($OutputPath, '<svg xmlns="http://www.w3.org/2000/svg">Fixture only</svg>')
exit 0
'@)
    $diagramPage = @'
# Diagrams

````markdown
```mermaid
DO_NOT_RENDER
```
````

<!--
```mermaid
DO_NOT_RENDER
```
-->

```mermaid
flowchart TD
    First["One"] --> Second["Two"]
```

~~~mermaid
sequenceDiagram
    First->>Second: Run
~~~~
'@
    $diagramPagePath = Join-Path $diagramWiki 'README.md'
    [IO.File]::WriteAllText($diagramPagePath, $diagramPage)
    [IO.File]::WriteAllText((Join-Path $diagramWiki 'nested/topic.md'), "# Nested`n`n   ~~~mermaid`nflowchart LR`n    One --> Two`n   ~~~`n")
    [IO.File]::WriteAllText((Join-Path $diagramWiki '.wiki/research.md'), "~~~mermaid`nDO_NOT_RENDER`n~~~")
    Invoke-DiagramCheck 2 'Mermaid CLI unavailable' $missingCli
    $before = (Get-FileHash -LiteralPath $diagramPagePath).Hash
    Invoke-DiagramCheck 0 'Mermaid rendering passed: 3 diagram(s)' $renderer
    Assert-Check ((Get-FileHash -LiteralPath $diagramPagePath).Hash -eq $before) 'Diagram checking modified a wiki page.'

    $badDiagram = Join-Path $diagramWiki 'bad.md'
    [IO.File]::WriteAllText($badDiagram, "~~~mermaid`nREJECT_BY_RENDERER`n~~~")
    Invoke-DiagramCheck 1 'Fixture renderer rejection' $renderer
    [IO.File]::WriteAllText($badDiagram, "~~~mermaid`nNO_RENDER_OUTPUT`n~~~")
    Invoke-DiagramCheck 1 'Renderer did not produce a nonempty SVG' $renderer
    [IO.File]::WriteAllText($badDiagram, "~~~mermaid`n~~~")
    Invoke-DiagramCheck 1 'empty Mermaid block' $renderer
    [IO.File]::WriteAllText($badDiagram, "~~~mermaid`nflowchart TD`n    One --> Two")
    Invoke-DiagramCheck 1 'unclosed Mermaid fence' $renderer

    $htmlOutput = Join-Path $repo 'docs/wiki-html'
    $originalHash = (Get-FileHash -LiteralPath $topicPath).Hash
    $exportOutput = & $pwsh -NoProfile -File $htmlExporter -WikiPath $wiki -RepoRoot $repo -OutputPath $htmlOutput 2>&1
    Assert-Check ($LASTEXITCODE -eq 0) "HTML export failed: $($exportOutput -join ' ')"
    $htmlHome = Get-Content -LiteralPath (Join-Path $htmlOutput 'index.html') -Raw
    $htmlTopic = Get-Content -LiteralPath (Join-Path $htmlOutput 'workflows/run.html') -Raw
    Assert-Check ($htmlHome.Contains('href="workflows/index.html"')) 'HTML home did not link to the converted section index.'
    Assert-Check ($htmlHome.Contains('href="workflows/run.html"')) 'HTML home did not link to the converted topic.'
    Assert-Check ($htmlTopic.Contains('href="../../../src/run.ps1"')) 'HTML source citation was not preserved.'
    Assert-Check ($htmlTopic.Contains('href="../index.html"')) 'HTML topic did not link home.'
    Assert-Check ($htmlTopic.Contains('href="index.html"')) 'HTML topic did not link to its parent.'
    Assert-Check ((Get-FileHash -LiteralPath $topicPath).Hash -eq $originalHash) 'HTML export modified the Markdown input.'
    Assert-Check ($htmlTopic.Contains('aria-current="page"')) 'HTML navigation did not mark the active page.'
    Assert-Check ($htmlTopic.Contains('href="#execution"')) 'HTML heading outline did not use the generated heading ID.'
    Assert-Check ($htmlHome.Contains('<table>')) 'HTML conversion lost Markdown tables.'
    $searchScript = Get-Content -LiteralPath (Join-Path $htmlOutput 'assets/search.js') -Raw
    Assert-Check ($searchScript.Contains('Emit safe.')) 'Local search did not index page body text.'
    Assert-Check ($searchScript.Contains('workflows/run.html')) 'Local search did not index the converted page path.'
    Invoke-HtmlExport 1 'HTML output already exists'
    Invoke-HtmlExport 0 'HTML export created' @('-Force')
    [IO.File]::WriteAllText((Join-Path $htmlOutput 'manual.txt'), 'Keep this file')
    Invoke-HtmlExport 1 'unfamiliar export file' @('-Force')
    Remove-Item -LiteralPath (Join-Path $htmlOutput 'manual.txt')
    $savedHtml = [IO.File]::ReadAllText((Join-Path $htmlOutput 'index.html'))
    [IO.File]::AppendAllText((Join-Path $htmlOutput 'index.html'), 'Manual edit')
    Invoke-HtmlExport 1 'modified export file' @('-Force')
    [IO.File]::WriteAllText((Join-Path $htmlOutput 'index.html'), $savedHtml)
    Invoke-HtmlExport 1 'Mermaid CLI unavailable' @('-Force', '-MermaidCliPath', $missingCli)

    $topicWithDiagram = $topic + @'

## Execution diagram

```mermaid
flowchart LR
    First["safe"] --> Second["done"]
```

The runner emits safe before done.

<!--
```mermaid
DO_NOT_RENDER
```
-->

````markdown
```mermaid
DO_NOT_RENDER
```
````

<script>alert('Not allowed')</script>
'@
    [IO.File]::WriteAllText($topicPath, $topicWithDiagram)
    Invoke-HtmlExport 0 'HTML export created' @('-Force')
    $fallbackHtml = Get-Content -LiteralPath (Join-Path $htmlOutput 'workflows/run.html') -Raw
    Assert-Check ($fallbackHtml.Contains('<summary>Diagram source</summary>')) 'HTML export omitted the no-renderer diagram fallback.'
    Assert-Check ($fallbackHtml.Contains('The runner emits safe before done.')) 'HTML export lost the diagram prose fallback.'
    Assert-Check (-not $fallbackHtml.Contains("<script>alert('Not allowed')</script>")) 'Raw repository HTML became an active script.'
    Invoke-HtmlExport 0 'HTML export created' @('-Force', '-MermaidCliPath', $renderer)
    $svgHtml = Get-Content -LiteralPath (Join-Path $htmlOutput 'workflows/run.html') -Raw
    Assert-Check ($svgHtml.Contains('src="../assets/diagram-0.svg"')) 'HTML export did not link to the rendered SVG.'
    Assert-Check (Test-Path -LiteralPath (Join-Path $htmlOutput 'assets/diagram-0.svg')) 'HTML diagram SVG was not written.'
    $exportMetadata = Get-Content -LiteralPath (Join-Path $htmlOutput '.wiki-export.json') -Raw | ConvertFrom-Json
    Assert-Check (@($exportMetadata.diagrams).Count -eq 1) 'Fenced examples or comments were treated as Mermaid diagrams.'
    Assert-Check ($exportMetadata.diagrams[0].rendered) 'HTML export did not record its diagram rendering outcome.'
    [IO.File]::WriteAllText($topicPath, $topicWithDiagram.Replace('flowchart LR', 'REJECT_BY_RENDERER'))
    Invoke-HtmlExport 1 'Mermaid rendering failed' @('-Force', '-MermaidCliPath', $renderer)
    Assert-Check ([IO.File]::ReadAllText((Join-Path $htmlOutput 'workflows/run.html')) -eq $svgHtml) 'A failed export replaced the prior HTML output.'
    [IO.File]::WriteAllText($topicPath, $topic)

    Invoke-HtmlExport 1 'must not overlap' @() (Join-Path $wiki 'html')
    $unfamiliarOutput = Join-Path $fixture 'unfamiliar output'
    [IO.Directory]::CreateDirectory($unfamiliarOutput) | Out-Null
    [IO.File]::WriteAllText((Join-Path $unfamiliarOutput 'keep.txt'), 'Do not overwrite')
    Invoke-HtmlExport 1 'unfamiliar HTML output directory' @('-Force') $unfamiliarOutput
    Assert-Check ([IO.File]::ReadAllText((Join-Path $unfamiliarOutput 'keep.txt')) -eq 'Do not overwrite') 'Unfamiliar HTML output was modified.'
    $manifest.status = 'in_progress'
    [IO.File]::WriteAllText((Join-Path $wiki '.wiki/manifest.json'), ($manifest | ConvertTo-Json -Depth 10))
    Invoke-HtmlExport 1 'requires a completed wiki' @('-Force')
    $manifest.status = 'complete'
    [IO.File]::WriteAllText((Join-Path $wiki '.wiki/manifest.json'), ($manifest | ConvertTo-Json -Depth 10))

    $sourceMarkdown = 'src/[owner]/settings (dev).md'
    [IO.Directory]::CreateDirectory((Join-Path $repo 'src/[owner]')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $repo $sourceMarkdown), "# Settings`n`nFixture settings.")
    $manifest.pages[2].sources += $sourceMarkdown
    $manifest.pages[2].title = 'Run ' + [char]0x03a9 + ' & results'
    [IO.File]::WriteAllText((Join-Path $wiki '.wiki/manifest.json'), ($manifest | ConvertTo-Json -Depth 10))
    $edgeTopic = $topicWithDiagram + @'

## Repeated

First section.

## Repeated

Second section.

Sources: [src/\[owner\]/settings (dev).md:1-3](../../../src/%5Bowner%5D/settings%20%28dev%29.md).

[Jump](run.md#repeated)

```text
[Leave this alone](README.md)
```

An inline <img src="missing.png" onerror="alert('Not allowed')"> tag is not trusted.
'@
    [IO.File]::WriteAllText($topicPath, $edgeTopic)
    Invoke-HtmlExport 0 'HTML export created' @('-Force')
    $edgeHtml = Get-Content -LiteralPath (Join-Path $htmlOutput 'workflows/run.html') -Raw
    Assert-Check ($edgeHtml.Contains('href="../../../src/%5Bowner%5D/settings%20%28dev%29.md"')) 'A Markdown source citation was converted to HTML or encoded incorrectly.'
    Assert-Check ($edgeHtml.Contains('id="repeated"') -and $edgeHtml.Contains('id="repeated-1"')) 'Duplicate headings did not receive unique IDs.'
    Assert-Check ($edgeHtml.Contains('href="run.html#repeated"')) 'An internal heading fragment was not preserved.'
    Assert-Check ($edgeHtml.Contains('[Leave this alone](README.md)')) 'A link inside a code example was rewritten.'
    Assert-Check ($edgeHtml.Contains('Run ' + [char]0x03a9 + ' &amp; results')) 'Unicode or special-character page titles were not preserved safely.'
    Assert-Check (-not $edgeHtml.Contains('onerror=')) 'Raw inline HTML attributes reached the exported page.'
    $markdownSourceHash = (Get-FileHash -LiteralPath (Join-Path $repo $sourceMarkdown)).Hash
    Invoke-HtmlExport 0 'HTML export created' @('-Force')
    Assert-Check ((Get-FileHash -LiteralPath (Join-Path $repo $sourceMarkdown)).Hash -eq $markdownSourceHash) 'HTML export changed a cited source file.'

    $collisionPage = Join-Path $wiki 'workflows/index.md'
    [IO.File]::WriteAllText($collisionPage, $topic)
    [IO.File]::WriteAllText((Join-Path $wiki 'README.md'), $homePage + "`n[Collision](workflows/index.md)`n")
    [IO.File]::WriteAllText((Join-Path $wiki 'workflows/README.md'), $index + "`n[Collision](index.md)`n")
    $originalPages = $manifest.pages
    $manifest.pages += @{ path = 'workflows/index.md'; title = 'Collision'; kind = 'topic'; status = 'complete'; sources = @('src/run.ps1') }
    [IO.File]::WriteAllText((Join-Path $wiki '.wiki/manifest.json'), ($manifest | ConvertTo-Json -Depth 10))
    Invoke-HtmlExport 1 'Duplicate HTML output path' @('-Force')
    $manifest.pages = $originalPages
    [IO.File]::WriteAllText((Join-Path $wiki '.wiki/manifest.json'), ($manifest | ConvertTo-Json -Depth 10))
    Remove-Item -LiteralPath $collisionPage
    [IO.File]::WriteAllText((Join-Path $wiki 'README.md'), $homePage)
    [IO.File]::WriteAllText((Join-Path $wiki 'workflows/README.md'), $index)
    Invoke-HtmlExport 0 'HTML export created' @('-Force')

    $wiki = Join-Path $repo 'docs/audiences'
    [IO.Directory]::CreateDirectory((Join-Path $wiki '.wiki')) | Out-Null
    $registry = @{
        schemaVersion = 1
        generator     = 'local-repo-wiki-collection'
        title         = 'Fixture documentation'
        language      = 'English'
        audiences     = @(
            @{ id = 'contributors'; title = 'New contributors' }
            @{ id = 'end-users'; title = 'End users' }
        )
    }
    $registryPath = Join-Path $wiki '.wiki/audiences.json'
    [IO.File]::WriteAllText($registryPath, ($registry | ConvertTo-Json -Depth 10))
    $generalIndex = Expand-Template 'audience-index.md' @{
        project_name                                          = 'Fixture'
        evidence_based_description                            = 'Guides to the local runner.'
        audience_links_with_reader_tasks_and_completion_notes = "- [New contributors](contributors/README.md): change the runner.`n- [End users](end-users/README.md): run it and understand results."
    }
    [IO.File]::WriteAllText((Join-Path $wiki 'README.md'), $generalIndex)
    foreach ($audience in $registry.audiences) {
        $audienceRoot = Join-Path $wiki $audience.id
        [IO.Directory]::CreateDirectory((Join-Path $audienceRoot '.wiki')) | Out-Null
        [IO.File]::WriteAllText((Join-Path $audienceRoot 'README.md'), "# $($audience.title)`n`n[All audiences](../README.md)`n`n[Run](run.md)`n")
        [IO.File]::WriteAllText((Join-Path $audienceRoot 'run.md'), "# Run`n`n[Home](README.md)`n`nA run emits safe before done.`n`nSources: [src/run.ps1:1-3](../../../src/run.ps1).`n")
        $audienceManifest = $manifest.Clone()
        $audienceManifest.repository = @{ name = 'fixture'; relativeRoot = '../../..'; revision = $null; workingTree = 'unknown' }
        $audienceManifest.scope = $manifest.scope.Clone()
        $audienceManifest.scope.audience = $audience.title
        $audienceManifest.pages = @(
            @{ path = 'README.md'; title = $audience.title; kind = 'home'; status = 'complete'; sources = @() }
            @{ path = 'run.md'; title = 'Run'; kind = 'topic'; status = 'complete'; sources = @('src/run.ps1') }
        )
        [IO.File]::WriteAllText((Join-Path $audienceRoot '.wiki/manifest.json'), ($audienceManifest | ConvertTo-Json -Depth 10))
    }
    Invoke-Validator 0 'Validation passed: 2 audiences and general index'
    [IO.File]::WriteAllText((Join-Path $wiki 'README.md'), $generalIndex.Replace('end-users/README.md', 'end-users/missing.md'))
    Invoke-Validator 1 'missing audience link'
    [IO.File]::WriteAllText((Join-Path $wiki 'README.md'), $generalIndex)
    $registry.audiences[1].id = '../outside'
    [IO.File]::WriteAllText($registryPath, ($registry | ConvertTo-Json -Depth 10))
    Invoke-Validator 1 'Invalid or duplicate audience id'
    $registry.audiences[1].id = 'contributors'
    [IO.File]::WriteAllText($registryPath, ($registry | ConvertTo-Json -Depth 10))
    Invoke-Validator 1 'Invalid or duplicate audience id'
    $registry.audiences[1].id = 'end-users'
    [IO.File]::WriteAllText($registryPath, ($registry | ConvertTo-Json -Depth 10))
    [IO.File]::AppendAllText((Join-Path $wiki 'end-users/run.md'), "`n[Broken](missing.md)`n")
    Invoke-Validator 1 'end-users:'
    [IO.File]::WriteAllText((Join-Path $wiki 'end-users/run.md'), "# Run`n`n[Home](README.md)`n`nA run emits safe before done.`n`nSources: [src/run.ps1:1-3](../../../src/run.ps1).`n")

    $htmlOutput = Join-Path $repo 'docs/audiences-html'
    $collectionHomeHash = (Get-FileHash -LiteralPath (Join-Path $wiki 'README.md')).Hash
    $contributorHash = (Get-FileHash -LiteralPath (Join-Path $wiki 'contributors/run.md')).Hash
    Invoke-HtmlExport 0 'HTML export created'
    $generalHtml = [IO.File]::ReadAllText((Join-Path $htmlOutput 'index.html'))
    $userHtml = [IO.File]::ReadAllText((Join-Path $htmlOutput 'end-users/run.html'))
    Assert-Check ($generalHtml.Contains('href="contributors/index.html"') -and $generalHtml.Contains('href="end-users/index.html"')) 'General HTML index did not link to both audiences.'
    Assert-Check ($userHtml.Contains('href="../index.html"') -and $userHtml.Contains('All audiences')) 'Audience HTML did not link to the general index.'
    Assert-Check ($userHtml.Contains('href="index.html"')) 'Audience home navigation did not stay within its guide.'
    Assert-Check ($userHtml.Contains('href="../../../src/run.ps1"')) 'Audience HTML source links used the wrong depth.'
    Assert-Check (-not $userHtml.Contains('contributors/')) 'Audience contents leaked another guide into its navigation.'
    $globalSearch = [IO.File]::ReadAllText((Join-Path $htmlOutput 'assets/search.js'))
    $userSearch = [IO.File]::ReadAllText((Join-Path $htmlOutput 'assets/search-end-users.js'))
    Assert-Check ($globalSearch.Contains('End users: Run') -and $globalSearch.Contains('contributors/run.html')) 'Shared search did not distinguish the audience guides.'
    Assert-Check ($userSearch.Contains('"path":"run.html"') -and -not $userSearch.Contains('contributors/')) 'Audience search paths were not scoped to their home.'
    Assert-Check ($userHtml.Contains('src="../assets/search-end-users.js"')) 'Audience page loaded the wrong search index.'
    $collectionMetadata = Get-Content -LiteralPath (Join-Path $htmlOutput '.wiki-export.json') -Raw | ConvertFrom-Json -AsHashtable
    Assert-Check ($collectionMetadata.manifestHashes.Count -eq 3) 'Collection export did not record all input manifests.'
    Invoke-HtmlExport 0 'HTML export created' @('-Force')
    [IO.File]::WriteAllText((Join-Path $htmlOutput 'end-users/manual.md'), 'Keep manual content')
    Invoke-HtmlExport 1 'unfamiliar export file' @('-Force')
    Remove-Item -LiteralPath (Join-Path $htmlOutput 'end-users/manual.md')
    $userManifestPath = Join-Path $wiki 'end-users/.wiki/manifest.json'
    $savedUserManifest = [IO.File]::ReadAllText($userManifestPath)
    $unfinishedManifest = $savedUserManifest | ConvertFrom-Json -AsHashtable
    $unfinishedManifest.status = 'in_progress'
    [IO.File]::WriteAllText($userManifestPath, ($unfinishedManifest | ConvertTo-Json -Depth 10))
    Invoke-HtmlExport 1 'requires a completed wiki' @('-Force')
    Assert-Check ([IO.File]::ReadAllText((Join-Path $htmlOutput 'index.html')) -eq $generalHtml) 'An incomplete audience replaced the combined HTML output.'
    [IO.File]::WriteAllText($userManifestPath, $savedUserManifest)
    [IO.File]::AppendAllText((Join-Path $wiki 'end-users/run.md'), "`nEnd-user note.`n")
    Invoke-HtmlExport 0 'HTML export created' @('-Force')
    Assert-Check ((Get-FileHash -LiteralPath (Join-Path $wiki 'contributors/run.md')).Hash -eq $contributorHash) 'Export or audience updates modified a different audience.'
    Assert-Check ((Get-FileHash -LiteralPath (Join-Path $wiki 'README.md')).Hash -eq $collectionHomeHash) 'HTML export modified the general Markdown index.'

    $insideCollection = $wiki
    $wiki = Join-Path $fixture 'external collection'
    Copy-Item -LiteralPath $insideCollection -Destination $wiki -Recurse
    foreach ($audience in $registry.audiences) {
        $audienceRoot = Join-Path $wiki $audience.id
        $audienceManifestPath = Join-Path $audienceRoot '.wiki/manifest.json'
        $externalManifest = Get-Content -LiteralPath $audienceManifestPath -Raw | ConvertFrom-Json -AsHashtable
        $externalManifest.repository.relativeRoot = '../../repository with spaces'
        [IO.File]::WriteAllText($audienceManifestPath, ($externalManifest | ConvertTo-Json -Depth 10))
        $externalTopicPath = Join-Path $audienceRoot 'run.md'
        $externalTopic = [IO.File]::ReadAllText($externalTopicPath).Replace('../../../src/run.ps1', '../../repository%20with%20spaces/src/run.ps1')
        [IO.File]::WriteAllText($externalTopicPath, $externalTopic)
    }
    Invoke-Validator 0 'Validation passed: 2 audiences and general index'
    $externalHtmlOutput = Join-Path $fixture 'external HTML'
    Invoke-HtmlExport 0 'HTML export created' @() $externalHtmlOutput
    $externalHtml = [IO.File]::ReadAllText((Join-Path $externalHtmlOutput 'end-users/run.html'))
    Assert-Check ($externalHtml.Contains('href="../../repository%20with%20spaces/src/run.ps1"')) 'External collection export broke repository links.'
    $externalCollection = $wiki
    $wiki = Join-Path $externalCollection 'end-users'
    Invoke-Validator 0 'Validation passed: 2 pages'
    Invoke-HtmlExport 0 'HTML export created' @() (Join-Path $fixture 'single audience HTML')
    $singleAudienceHtml = [IO.File]::ReadAllText((Join-Path $fixture 'single audience HTML/index.html'))
    Assert-Check ($singleAudienceHtml.Contains('href="../external%20collection/README.md"')) 'Single audience export lost the general Markdown index reference.'
    $wiki = $insideCollection

    $audienceHomePath = Join-Path $wiki 'end-users/README.md'
    $savedAudienceHome = [IO.File]::ReadAllText($audienceHomePath)
    [IO.File]::WriteAllText($audienceHomePath, $savedAudienceHome.Replace('[All audiences](../README.md)', ''))
    Invoke-Validator 1 'missing general index link'
    [IO.File]::WriteAllText($audienceHomePath, $savedAudienceHome)
    $conflictingManifest = Join-Path $wiki '.wiki/manifest.json'
    [IO.File]::WriteAllText($conflictingManifest, ($manifest | ConvertTo-Json -Depth 10))
    Invoke-Validator 1 'cannot contain both'
    Remove-Item -LiteralPath $conflictingManifest
    $registry.generator = 'unknown-generator'
    [IO.File]::WriteAllText($registryPath, ($registry | ConvertTo-Json -Depth 10))
    Invoke-Validator 1 'Unsupported audience registry'
    $registry.generator = 'local-repo-wiki-collection'
    [IO.File]::WriteAllText($registryPath, ($registry | ConvertTo-Json -Depth 10))

    "Validation integration checks passed: $checks assertions."
    if ($KeepFixture) { "Fixture retained at: $fixture" }
}
finally {
    if (-not $KeepFixture -and (Test-Path -LiteralPath $fixture)) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}