#Requires -Version 7.0
<#
.SYNOPSIS
Exports a completed Markdown wiki to a separate local HTML folder.
.DESCRIPTION
Uses PowerShell's bundled Markdig renderer. No packages, remote assets, or server
are required. Diagrams render in the browser using bundled Mermaid JavaScript.
An explicitly supplied local Mermaid CLI can instead create static SVGs.
Force replaces only a verified, unchanged export belonging to this wiki.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $WikiPath,
    [Parameter(Mandatory)] [string] $RepoRoot,
    [string] $OutputPath,
    [switch] $Force,
    [string] $MermaidCliPath
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$comparer = if ($IsWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }
$staging = $null
$backup = $null

function Test-Within([string] $Path, [string] $Root) {
    return $Path.Equals($Root, $comparison) -or $Path.StartsWith($Root.TrimEnd('/', '\') + [IO.Path]::DirectorySeparatorChar, $comparison)
}

function Get-LinkPath([string] $Base, [string] $Target) {
    $relative = [IO.Path]::GetRelativePath($Base, $Target).Replace('\', '/')
    if ([IO.Path]::IsPathRooted($relative)) { throw 'HTML output and source files must be on the same filesystem volume.' }
    return (($relative -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

function Get-InlineText($Container) {
    $text = [System.Text.StringBuilder]::new()
    [Markdig.Syntax.MarkdownObject] $inlineRoot = $Container
    if ($Container -is [Markdig.Syntax.LeafBlock]) { $inlineRoot = $Container.Inline }
    foreach ($inline in [Markdig.Syntax.MarkdownObjectExtensions]::Descendants($inlineRoot)) {
        if ($inline -is [Markdig.Syntax.Inlines.LiteralInline]) { $null = $text.Append($inline.Content.ToString()) }
        elseif ($inline -is [Markdig.Syntax.Inlines.CodeInline]) { $null = $text.Append($inline.Content) }
        elseif ($inline -is [Markdig.Syntax.Inlines.LineBreakInline]) { $null = $text.Append(' ') }
    }
    return $text.ToString()
}

function Assert-OutputDirectory {
    $ancestor = $destination
    while ($ancestor) {
        if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'HTML output must not pass through symbolic links or junctions.'
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    if (-not (Test-Path -LiteralPath $destination)) { return }
    if (-not (Test-Path -LiteralPath $destination -PathType Container)) { throw 'HTML output is not a directory.' }
    $existing = @(Get-ChildItem -LiteralPath $destination -Recurse -Force)
    if (-not $existing.Count) { return }
    if (-not $Force) { throw 'HTML output already exists; use -Force only for an unchanged prior export.' }
    $metadataPath = Join-Path $destination '.wiki-export.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) { throw 'Refusing to replace an unfamiliar HTML output directory.' }
    $previous = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json -AsHashtable
    if ($previous.generator -ne 'local-repo-wiki-html' -or $previous.schemaVersion -ne 1 -or -not $previous.files -or -not $previous.sourceWiki) {
        throw 'Refusing to replace an unrecognized HTML export.'
    }
    $previousWiki = [IO.Path]::GetFullPath([IO.Path]::Combine($destination, $previous.sourceWiki))
    if (-not $previousWiki.Equals($wiki, $comparison)) { throw 'HTML output belongs to a different wiki.' }
    $directories = [System.Collections.Generic.HashSet[string]]::new($comparer)
    foreach ($ownedPath in $previous.files.Keys) {
        if ([IO.Path]::IsPathRooted($ownedPath) -or $ownedPath -match '[:\\]|(^|/)\.\.(/|$)') { throw 'Invalid owned HTML output path.' }
        $directory = [IO.Path]::GetDirectoryName($ownedPath).Replace('\', '/')
        while ($directory) {
            $null = $directories.Add($directory)
            $directory = [IO.Path]::GetDirectoryName($directory).Replace('\', '/')
        }
    }
    foreach ($item in $existing) {
        $relative = [IO.Path]::GetRelativePath($destination, $item.FullName).Replace('\', '/')
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing to replace a linked export entry: $relative" }
        if ($item.PSIsContainer) {
            if (-not $directories.Contains($relative)) { throw "Refusing to replace an unfamiliar export directory: $relative" }
        }
        elseif ($relative -ne '.wiki-export.json') {
            if (-not $previous.files.ContainsKey($relative)) { throw "Refusing to replace an unfamiliar export file: $relative" }
            if ((Get-FileHash -LiteralPath $item.FullName).Hash -ne $previous.files[$relative]) { throw "Refusing to replace a modified export file: $relative" }
        }
    }
}

try {
    $wiki = (Resolve-Path -LiteralPath $WikiPath).Path
    $repo = (Resolve-Path -LiteralPath $RepoRoot).Path
    if (-not $OutputPath) { $OutputPath = $wiki.TrimEnd('/', '\') + '-html' }
    $destination = [IO.Path]::GetFullPath($OutputPath)
    if (-not [IO.Path]::GetPathRoot($destination).Equals([IO.Path]::GetPathRoot($wiki), $comparison) -or -not [IO.Path]::GetPathRoot($destination).Equals([IO.Path]::GetPathRoot($repo), $comparison)) {
        throw 'HTML output, wiki, and repository must be on the same filesystem volume.'
    }
    if ((Test-Within $destination $wiki) -or (Test-Within $wiki $destination) -or (Test-Within $repo $destination)) {
        throw 'HTML output must not overlap the wiki or contain the repository.'
    }
    Assert-OutputDirectory
    $pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
    $validation = & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-RepoWiki.ps1') -WikiPath $wiki -RepoRoot $repo 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Wiki validation failed: $($validation -join ' ')" }
    $manifestPath = Join-Path $wiki '.wiki/manifest.json'
    $registryPath = Join-Path $wiki '.wiki/audiences.json'
    $contexts = [System.Collections.Generic.List[object]]::new()
    $manifestHashes = @{}
    $collectionContext = $null
    $collectionHome = $null
    if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
        $manifestPath = $registryPath
        $manifestHash = (Get-FileHash -LiteralPath $manifestPath).Hash
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -AsHashtable
        $collectionContext = @{
            Root = $wiki; Prefix = ''; Home = 'index.html'; Search = 'assets/search.js'; Audience = $null
            Manifest = @{ repository = @{ name = $registry.title }; scope = @{ language = $registry.language } }
        }
        foreach ($audience in $registry.audiences) {
            $audienceRoot = Join-Path $wiki $audience.id
            $audienceManifestPath = Join-Path $audienceRoot '.wiki/manifest.json'
            $manifestHashes[$audienceManifestPath] = (Get-FileHash -LiteralPath $audienceManifestPath).Hash
            $audienceManifest = Get-Content -LiteralPath $audienceManifestPath -Raw | ConvertFrom-Json -AsHashtable
            $contexts.Add(@{
                    Root = $audienceRoot; Prefix = $audience.id; Home = "$($audience.id)/index.html"
                    Search = "assets/search-$($audience.id).js"; Audience = $audience.title; Manifest = $audienceManifest
                })
        }
    }
    else {
        $manifestHash = (Get-FileHash -LiteralPath $manifestPath).Hash
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $contexts.Add(@{ Root = $wiki; Prefix = ''; Home = 'index.html'; Search = 'assets/search.js'; Audience = $null; Manifest = $manifest })
        $parentRoot = [IO.Path]::GetDirectoryName($wiki)
        $parentRegistryPath = Join-Path $parentRoot '.wiki/audiences.json'
        if (Test-Path -LiteralPath $parentRegistryPath -PathType Leaf) {
            $parentRegistry = Get-Content -LiteralPath $parentRegistryPath -Raw | ConvertFrom-Json -AsHashtable
            if ($parentRegistry.generator -eq 'local-repo-wiki-collection' -and $parentRegistry.schemaVersion -eq 1 -and [IO.Path]::GetFileName($wiki) -cin @($parentRegistry.audiences.id)) {
                $collectionHome = Join-Path $parentRoot 'README.md'
            }
        }
    }
    $manifestHashes[$manifestPath] = $manifestHash
    $pages = [System.Collections.Generic.Dictionary[string, object]]::new($comparer)
    $outputs = [System.Collections.Generic.HashSet[string]]::new($comparer)
    $orderedPages = [System.Collections.Generic.List[object]]::new()
    if ($collectionContext) {
        $source = Join-Path $wiki 'README.md'
        $entry = @{ Source = $source; Path = 'index.html'; Title = $registry.title; Kind = 'home'; Hash = (Get-FileHash -LiteralPath $source).Hash; Context = $collectionContext }
        $pages.Add($source, $entry)
        $orderedPages.Add($entry)
        $null = $outputs.Add('index.html')
    }
    foreach ($context in $contexts) {
        if ($context.Manifest.status -ne 'complete') { throw "HTML export requires a completed wiki: $($context.Root)" }
        foreach ($page in $context.Manifest.pages) {
            $source = [IO.Path]::GetFullPath((Join-Path $context.Root $page.path))
            $htmlPath = if ([IO.Path]::GetFileName($page.path) -ieq 'README.md') {
                [IO.Path]::Combine([IO.Path]::GetDirectoryName($page.path), 'index.html').Replace('\', '/')
            }
            else { [IO.Path]::ChangeExtension($page.path, '.html').Replace('\', '/') }
            if ($context.Prefix) { $htmlPath = "$($context.Prefix)/$htmlPath" }
            if (-not $outputs.Add($htmlPath)) { throw "Duplicate HTML output path: $htmlPath" }
            $entry = @{ Source = $source; Path = $htmlPath; Title = $page.title; Kind = $page.kind; Hash = (Get-FileHash -LiteralPath $source).Hash; Context = $context }
            $pages.Add($source, $entry)
            $orderedPages.Add($entry)
        }
    }

    $null = ConvertFrom-Markdown -InputObject ''
    $builder = [Markdig.MarkdownPipelineBuilder]::new()
    $null = [Markdig.MarkdownExtensions]::UsePipeTables($builder)
    $null = [Markdig.MarkdownExtensions]::UseAutoIdentifiers($builder)
    $pipeline = $builder.Build()
    $templateRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates/html'
    $shell = [IO.File]::ReadAllText((Join-Path $templateRoot 'page.html'))
    $searchPages = [System.Collections.Generic.List[object]]::new()
    $diagramResults = [System.Collections.Generic.List[object]]::new()
    $linkTargets = [System.Collections.Generic.HashSet[string]]::new($comparer)
    $cli = $null
    if ($MermaidCliPath) {
        $cli = Get-Command -Name $MermaidCliPath -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cli) { throw "Mermaid CLI unavailable: $MermaidCliPath. Nothing was installed." }
    }
    $staging = Join-Path ([IO.Path]::GetDirectoryName($destination)) ('.repo-wiki-html-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory((Join-Path $staging 'assets')) | Out-Null
    foreach ($asset in @('wiki.css', 'wiki.js')) { Copy-Item -LiteralPath (Join-Path $templateRoot $asset) -Destination (Join-Path $staging "assets/$asset") }
    foreach ($page in $orderedPages) {
        $context = $page.Context
        $markdown = [IO.File]::ReadAllText($page.Source)
        $document = [Markdig.Markdown]::Parse($markdown, $pipeline)
        foreach ($htmlNode in @([Markdig.Syntax.MarkdownObjectExtensions]::Descendants($document))) {
            if ($htmlNode -is [Markdig.Syntax.HtmlBlock]) { $null = $htmlNode.Parent.Remove($htmlNode) }
            elseif ($htmlNode -is [Markdig.Syntax.Inlines.HtmlInline]) { $htmlNode.Tag = '' }
        }
        $targetPage = Join-Path $destination $page.Path
        $targetDirectory = [IO.Path]::GetDirectoryName($targetPage)
        $headings = [System.Collections.Generic.List[string]]::new()
        $searchText = [System.Collections.Generic.List[string]]::new()
        $diagramHtml = @{}
        foreach ($node in [Markdig.Syntax.MarkdownObjectExtensions]::Descendants($document)) {
            if ($node -is [Markdig.Syntax.FencedCodeBlock] -and $node.Info.ToString().Trim() -match '^mermaid(?:\s|$)') {
                $code = $node.Lines.ToString()
                if ([string]::IsNullOrWhiteSpace($code)) { throw "$($page.Path): empty Mermaid block." }
                $marker = 'wiki_diagram_' + [guid]::NewGuid().ToString('N')
                [Markdig.Renderers.Html.HtmlAttributesExtensions]::GetAttributes($node).Classes.Add($marker)
                $diagramResult = @{ page = $page.Path; line = $node.Line + 1; rendered = $false; mode = if ($cli) { 'static' } else { 'browser' } }
                if ($cli) {
                    $renderDirectory = Join-Path $staging '.render'
                    [IO.Directory]::CreateDirectory($renderDirectory) | Out-Null
                    $inputFile = Join-Path $renderDirectory 'diagram.mmd'
                    $configFile = Join-Path $renderDirectory 'mermaid.json'
                    [IO.File]::WriteAllText($inputFile, $code)
                    [IO.File]::WriteAllText($configFile, (@{ securityLevel = 'strict'; flowchart = @{ htmlLabels = $false } } | ConvertTo-Json -Depth 3))
                    $svgPath = "assets/diagram-$($diagramResults.Count).svg"
                    $svgFile = Join-Path $staging $svgPath
                    $LASTEXITCODE = 0
                    $renderOutput = & $cli.Source -i $inputFile -o $svgFile -c $configFile 2>&1
                    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $svgFile -PathType Leaf) -or (Get-Item -LiteralPath $svgFile).Length -eq 0) {
                        throw "$($page.Path): Mermaid rendering failed: $($renderOutput -join ' ')"
                    }
                    $svgHref = Get-LinkPath $targetDirectory (Join-Path $destination $svgPath)
                    $diagramHtml[$marker] = "<figure class=`"diagram`"><img src=`"$([Net.WebUtility]::HtmlEncode($svgHref))`" alt=`"Diagram for $([Net.WebUtility]::HtmlEncode($page.Title))`"></figure>"
                    $diagramResult.rendered = $true
                    Remove-Item -LiteralPath $renderDirectory -Recurse -Force
                }
                else {
                    $diagramHtml[$marker] = '<figure class="diagram" data-mermaid><div class="diagram-view" hidden></div><p class="diagram-status" role="status">Diagram preview requires JavaScript. The source is available below.</p><details open><summary>Diagram source</summary><pre><code>' + [Net.WebUtility]::HtmlEncode($code) + '</code></pre></details></figure>'
                }
                $diagramResults.Add($diagramResult)
            }
            if ($node -is [Markdig.Syntax.LeafBlock] -and $node.Inline) { $searchText.Add((Get-InlineText $node)) }
            if ($node -is [Markdig.Syntax.CodeBlock]) { $searchText.Add($node.Lines.ToString()) }
            if ($node -is [Markdig.Syntax.HeadingBlock] -and $node.Level -in @(2, 3)) {
                $identifier = [Markdig.Renderers.Html.HtmlAttributesExtensions]::GetAttributes($node).Id
                $label = [Net.WebUtility]::HtmlEncode((Get-InlineText $node))
                $headingClass = if ($node.Level -eq 3) { 'subheading' } else { '' }
                $headings.Add("<li class=`"$headingClass`"><a href=`"#$([Net.WebUtility]::HtmlEncode($identifier))`">$label</a></li>")
            }
            if ($node -isnot [Markdig.Syntax.Inlines.LinkInline]) { continue }
            $url = $node.Url
            if (-not $url) { continue }
            if ($url -match '^(?:https?://|mailto:|#)') {
                if ($node.IsImage -and -not $url.StartsWith('#')) { throw 'Remote images are not included in offline HTML exports.' }
                continue
            }
            if ($url -match '^[a-zA-Z][a-zA-Z0-9+.-]*:|^//') { $node.Url = '#'; continue }
            $parts = $url -split '#', 2
            $sourceTarget = [IO.Path]::GetFullPath([IO.Path]::Combine([IO.Path]::GetDirectoryName($page.Source), [Uri]::UnescapeDataString($parts[0])))
            if ((-not (Test-Within $sourceTarget $wiki) -and -not (Test-Within $sourceTarget $repo) -and $sourceTarget -ne $collectionHome) -or -not (Test-Path -LiteralPath $sourceTarget -PathType Leaf)) {
                throw "Missing or out-of-scope HTML link target: $url"
            }
            $target = if ($pages.ContainsKey($sourceTarget)) { Join-Path $destination $pages[$sourceTarget].Path } else { $sourceTarget }
            $null = $linkTargets.Add($target)
            $node.Url = Get-LinkPath $targetDirectory $target
            if ($parts.Length -eq 2) { $node.Url += '#' + $parts[1] }
        }
        $writer = [IO.StringWriter]::new()
        $htmlRenderer = [Markdig.Renderers.HtmlRenderer]::new($writer)
        $pipeline.Setup($htmlRenderer)
        $null = $htmlRenderer.Render($document)
        $html = $writer.ToString()
        foreach ($marker in $diagramHtml.Keys) {
            $pattern = '<pre><code class="[^\"]*\b' + $marker + '\b[^\"]*">[\s\S]*?</code></pre>'
            $replacement = $diagramHtml[$marker]
            $html = [regex]::Replace($html, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($match) return $replacement })
        }
        $navigation = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $orderedPages) {
            if ($collectionContext) {
                if ($context -eq $collectionContext -and $item.Kind -ne 'home') { continue }
                if ($context -ne $collectionContext -and $item.Context -ne $context -and $item.Context -ne $collectionContext) { continue }
            }
            $href = Get-LinkPath $targetDirectory (Join-Path $destination $item.Path)
            $current = if ($item.Source -eq $page.Source) { ' aria-current="page"' } else { '' }
            $itemClass = if ($item.Kind -eq 'index') { 'section' } elseif ($item.Path.Contains('/')) { 'nested' } else { '' }
            $label = if ($collectionContext -and $item.Context -eq $collectionContext) { 'All audiences' } else { $item.Title }
            $navigation.Add("<li class=`"$itemClass`"><a href=`"$([Net.WebUtility]::HtmlEncode($href))`"$current>$([Net.WebUtility]::HtmlEncode($label))</a></li>")
        }
        $homeHref = Get-LinkPath $targetDirectory (Join-Path $destination $context.Home)
        $breadcrumbs = "<a href=`"$([Net.WebUtility]::HtmlEncode($homeHref))`">Home</a>"
        if ($collectionContext -and $context -ne $collectionContext) {
            $collectionHref = Get-LinkPath $targetDirectory (Join-Path $destination 'index.html')
            $breadcrumbs = "<a href=`"$([Net.WebUtility]::HtmlEncode($collectionHref))`">All audiences</a>" + $breadcrumbs
        }
        $parentPath = [IO.Path]::Combine([IO.Path]::GetDirectoryName($page.Source), 'README.md')
        if ($page.Kind -eq 'topic' -and $pages.ContainsKey($parentPath) -and $pages[$parentPath].Path -ne $context.Home) {
            $parentHref = Get-LinkPath $targetDirectory (Join-Path $destination $pages[$parentPath].Path)
            $breadcrumbs += "<a href=`"$([Net.WebUtility]::HtmlEncode($parentHref))`">$([Net.WebUtility]::HtmlEncode($pages[$parentPath].Title))</a>"
        }
        $outline = if ($headings.Count) { '<h2>On this page</h2><ul>' + ($headings -join '') + '</ul>' } else { '' }
        $diagramScripts = ''
        if (-not $cli -and $diagramHtml.Count) {
            if (-not (Test-Path -LiteralPath (Join-Path $staging 'assets/mermaid.min.js'))) {
                foreach ($asset in @('mermaid.min.js', 'mermaid.min.js.LEGAL.txt', 'MERMAID-LICENSE.txt')) {
                    Copy-Item -LiteralPath (Join-Path $templateRoot "vendor/$asset") -Destination (Join-Path $staging "assets/$asset")
                }
                Copy-Item -LiteralPath (Join-Path $templateRoot 'diagrams.js') -Destination (Join-Path $staging 'assets/diagrams.js')
            }
            $mermaidHref = [Net.WebUtility]::HtmlEncode((Get-LinkPath $targetDirectory (Join-Path $destination 'assets/mermaid.min.js')))
            $diagramsHref = [Net.WebUtility]::HtmlEncode((Get-LinkPath $targetDirectory (Join-Path $destination 'assets/diagrams.js')))
            $diagramScripts = "<script defer src=`"$mermaidHref`"></script><script defer src=`"$diagramsHref`"></script>"
        }
        $values = @{
            language      = [Net.WebUtility]::HtmlEncode($context.Manifest.scope.language)
            page_title    = [Net.WebUtility]::HtmlEncode($page.Title)
            project_title = [Net.WebUtility]::HtmlEncode($context.Manifest.repository.name)
            home_href     = [Net.WebUtility]::HtmlEncode($homeHref)
            styles_href   = Get-LinkPath $targetDirectory (Join-Path $destination 'assets/wiki.css')
            script_href   = Get-LinkPath $targetDirectory (Join-Path $destination 'assets/wiki.js')
            search_href   = Get-LinkPath $targetDirectory (Join-Path $destination $context.Search)
            diagram_scripts = $diagramScripts
            navigation    = '<ul>' + ($navigation -join '') + '</ul>'
            breadcrumbs   = $breadcrumbs
            outline       = $outline
            content       = $html
        }
        $pageHtml = [regex]::Replace($shell, '\{\{(?<key>\w+)\}\}', [System.Text.RegularExpressions.MatchEvaluator] {
                param($match)
                return [string] $values[$match.Groups['key'].Value]
            })
        $targetFile = Join-Path $staging $page.Path
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($targetFile)) | Out-Null
        [IO.File]::WriteAllText($targetFile, $pageHtml)
        $searchPages.Add(@{ title = $page.Title; path = $page.Path; text = ($searchText -join ' '); audience = $context.Audience; prefix = $context.Prefix })
    }
    $searchContexts = @($contexts)
    if ($collectionContext) { $searchContexts += $collectionContext }
    foreach ($context in $searchContexts) {
        $entries = @(
            foreach ($entry in $searchPages) {
                if ($context.Prefix -and $entry.prefix -ne $context.Prefix) { continue }
                $title = if ($context -eq $collectionContext -and $entry.audience) { "$($entry.audience): $($entry.title)" } else { $entry.title }
                $path = if ($context.Prefix) { $entry.path.Substring($context.Prefix.Length + 1) } else { $entry.path }
                @{ title = $title; path = $path; text = $entry.text }
            }
        )
        $searchJson = ConvertTo-Json -InputObject $entries -Depth 5 -Compress
        $searchJson = $searchJson.Replace('<', '\u003c').Replace([string][char]0x2028, '\u2028').Replace([string][char]0x2029, '\u2029')
        [IO.File]::WriteAllText((Join-Path $staging $context.Search), "window.REPO_WIKI_SEARCH = $searchJson;")
    }
    foreach ($target in $linkTargets) {
        $checkPath = if (Test-Within $target $destination) { Join-Path $staging ([IO.Path]::GetRelativePath($destination, $target)) } else { $target }
        if (-not (Test-Path -LiteralPath $checkPath -PathType Leaf)) { throw "Missing generated HTML destination: $target" }
    }
    foreach ($inputManifest in $manifestHashes.Keys) {
        if ((Get-FileHash -LiteralPath $inputManifest).Hash -ne $manifestHashes[$inputManifest]) { throw 'Wiki manifest changed during export.' }
    }
    $pageHashes = @{}
    foreach ($page in $orderedPages) {
        if ((Get-FileHash -LiteralPath $page.Source).Hash -ne $page.Hash) { throw "Wiki page changed during export: $($page.Source)" }
        $pageHashes[[IO.Path]::GetRelativePath($wiki, $page.Source).Replace('\', '/')] = $page.Hash
    }
    $ownedFiles = @{}
    foreach ($file in (Get-ChildItem -LiteralPath $staging -File -Recurse -Force)) {
        $ownedFiles[[IO.Path]::GetRelativePath($staging, $file.FullName).Replace('\', '/')] = (Get-FileHash -LiteralPath $file.FullName).Hash
    }
    $metadata = @{
        generator      = 'local-repo-wiki-html'
        schemaVersion  = 1
        generatedAt    = [DateTimeOffset]::UtcNow.ToString('o')
        sourceWiki     = [IO.Path]::GetRelativePath($destination, $wiki).Replace('\', '/')
        manifestHash   = $manifestHash
        manifestHashes = @{}
        pageHashes     = $pageHashes
        diagrams       = $diagramResults.ToArray()
        files          = $ownedFiles
    }
    foreach ($inputManifest in $manifestHashes.Keys) {
        $metadata.manifestHashes[[IO.Path]::GetRelativePath($wiki, $inputManifest).Replace('\', '/')] = $manifestHashes[$inputManifest]
    }
    [IO.File]::WriteAllText((Join-Path $staging '.wiki-export.json'), ($metadata | ConvertTo-Json -Depth 8))
    Assert-OutputDirectory
    if (Test-Path -LiteralPath $destination) {
        $backup = $destination + '-previous-' + [guid]::NewGuid().ToString('N')
        [IO.Directory]::Move($destination, $backup)
    }
    try { [IO.Directory]::Move($staging, $destination) } catch {
        if ($backup -and -not (Test-Path -LiteralPath $destination)) { [IO.Directory]::Move($backup, $destination); $backup = $null }
        throw
    }
    $staging = $null
    if ($backup) { Remove-Item -LiteralPath $backup -Recurse -Force; $backup = $null }
    "HTML export created: $(Join-Path $destination 'index.html')"
}
catch {
    [Console]::Error.WriteLine("HTML export failed: $($_.Exception.Message)")
    exit 1
}
finally {
    if ($staging -and (Test-Path -LiteralPath $staging)) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
