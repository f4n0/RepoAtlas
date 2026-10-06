#Requires -Version 7.0
<#
.SYNOPSIS
Validates a Local Repo Wiki without network access or modifying files.
.DESCRIPTION
Checks simple inline Markdown links outside code examples, manifest coverage,
navigation, and local source citations. Does not validate heading fragments,
Mermaid, factual accuracy, or arbitrary Markdown extensions.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $WikiPath,
    [Parameter(Mandatory)] [string] $RepoRoot
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$comparer = if ($IsWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }
$lineCounts = [System.Collections.Generic.Dictionary[string, int]]::new($comparer)
$pageTargets = [System.Collections.Generic.Dictionary[string, object]]::new($comparer)

function Test-Within([string] $Path, [string] $Root) {
    return $Path.Equals($Root, $comparison) -or $Path.StartsWith($Root.TrimEnd('/', '\') + [IO.Path]::DirectorySeparatorChar, $comparison)
}

function Resolve-LocalPath([string] $Base, [string] $Relative) {
    return [IO.Path]::GetFullPath([IO.Path]::Combine($Base, $Relative.Replace('/', [IO.Path]::DirectorySeparatorChar)))
}

function Test-RelativeFile([string] $Value) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and -not [IO.Path]::IsPathRooted($Value) -and $Value -notmatch '[:\\]' -and $Value -notmatch '(^|/)\.\.(/|$)'
}

function Get-Prose([string] $Text) {
    # Preserve line breaks while removing fenced examples, including links within them.
    $result = [System.Collections.Generic.List[string]]::new()
    $fenceChar = ''
    $fenceLength = 0
    foreach ($line in ($Text -split '\r?\n')) {
        if (-not $fenceChar -and $line -match '^\s{0,3}(`{3,}|~{3,})') {
            $fenceChar = $Matches[1].Substring(0, 1)
            $fenceLength = $Matches[1].Length
            $result.Add('')
        } elseif ($fenceChar) {
            if ($line -match ('^\s{0,3}' + [regex]::Escape($fenceChar) + '{' + $fenceLength + ',}\s*$')) {
                $fenceChar = ''
            }
            $result.Add('')
        } else {
            $result.Add($line)
        }
    }
    $prose = [regex]::Replace(($result -join "`n"), '<!--[\s\S]*?-->', '')
    return [regex]::Replace($prose, '(?<!`)(`+)(?!`)[^\r\n]*?\1(?!`)', '')
}

try {
    $wiki = (Resolve-Path -LiteralPath $WikiPath).Path
    $repo = (Resolve-Path -LiteralPath $RepoRoot).Path
    if (-not (Test-Path -LiteralPath $wiki -PathType Container) -or -not (Test-Path -LiteralPath $repo -PathType Container)) {
        throw 'WikiPath and RepoRoot must both be directories.'
    }
    $manifestPath = Join-Path $wiki '.wiki/manifest.json'
    $registryPath = Join-Path $wiki '.wiki/audiences.json'
    if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
        if (Test-Path -LiteralPath $manifestPath) { throw 'Wiki root cannot contain both an audience registry and a single-wiki manifest.' }
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -AsHashtable
        if ($registry.schemaVersion -ne 1 -or $registry.generator -ne 'local-repo-wiki-collection') { throw 'Unsupported audience registry schemaVersion or generator.' }
        if ([string]::IsNullOrWhiteSpace($registry.title) -or [string]::IsNullOrWhiteSpace($registry.language)) { throw 'Audience registry requires title and language.' }
        if (@($registry.audiences).Count -eq 0) { throw 'Audience registry must contain at least one audience.' }
        $identifiers = [System.Collections.Generic.HashSet[string]]::new($comparer)
        $audienceHomes = [System.Collections.Generic.HashSet[string]]::new($comparer)
        $pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
        foreach ($audience in $registry.audiences) {
            $identifier = [string] $audience.id
            if ($identifier -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or -not $identifiers.Add($identifier)) { throw "Invalid or duplicate audience id: $identifier" }
            if ([string]::IsNullOrWhiteSpace($audience.title)) { throw "Missing audience title: $identifier" }
            $audienceRoot = Join-Path $wiki $identifier
            if (-not (Test-Path -LiteralPath $audienceRoot -PathType Container)) { throw "Missing audience directory: $identifier" }
            if ((Get-Item -LiteralPath $audienceRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked audience directory is not supported: $identifier" }
            if (-not (Test-Path -LiteralPath (Join-Path $audienceRoot '.wiki/manifest.json') -PathType Leaf)) { throw "Missing audience manifest: $identifier" }
            $null = $audienceHomes.Add((Join-Path $audienceRoot 'README.md'))
            $result = & $pwsh -NoProfile -File $PSCommandPath -WikiPath $audienceRoot -RepoRoot $repo 2>&1
            if ($LASTEXITCODE -ne 0) { $errors.Add("${identifier}: $($result -join ' ')") }
            else { $result | ForEach-Object { Write-Output "${identifier}: $_" } }
        }
        $homePage = Join-Path $wiki 'README.md'
        if (-not (Test-Path -LiteralPath $homePage -PathType Leaf)) { throw 'Missing general index README.md.' }
        $text = Get-Prose (Get-Content -LiteralPath $homePage -Raw)
        if ([regex]::Matches($text, '(?m)^# [^\r\n]+').Count -ne 1) { $errors.Add('General index: expected exactly one H1 heading.') }
        if ($text -match '\{\{[^}]+\}\}') { $errors.Add('General index: unresolved template placeholder.') }
        $null = ConvertFrom-Markdown -InputObject ''
        $document = [Markdig.Markdown]::Parse($text)
        $targets = [System.Collections.Generic.HashSet[string]]::new($comparer)
        foreach ($link in [Markdig.Syntax.MarkdownObjectExtensions]::Descendants($document)) {
            if ($link -isnot [Markdig.Syntax.Inlines.LinkInline] -or $link.IsImage) { continue }
            $url = $link.Url
            if (-not $url) { $errors.Add('General index: empty link destination.'); continue }
            if ($url -match '^https?://') { $warnings.Add("General index: external link not checked: $url"); continue }
            if ($url.StartsWith('#')) { $warnings.Add("General index: heading fragment not checked: $url"); continue }
            $decoded = [Uri]::UnescapeDataString(($url -split '#', 2)[0])
            if ([IO.Path]::IsPathRooted($decoded) -or $decoded -match '[:\\?]') { $errors.Add("General index: nonportable local destination: $url"); continue }
            $target = Resolve-LocalPath $wiki $decoded
            if ((-not (Test-Within $target $wiki) -and -not (Test-Within $target $repo)) -or -not (Test-Path -LiteralPath $target -PathType Leaf)) {
                $errors.Add("General index: missing or out-of-scope link target: $url")
                continue
            }
            $null = $targets.Add($target)
        }
        foreach ($audienceHome in $audienceHomes) {
            if (-not $targets.Contains($audienceHome)) { $errors.Add("General index: missing audience link: $([IO.Path]::GetRelativePath($wiki, $audienceHome))") }
        }
        foreach ($warning in $warnings) { Write-Warning $warning }
        foreach ($failure in $errors) { [Console]::Error.WriteLine("FAIL: $failure") }
        if ($errors.Count) { exit 1 }
        "Validation passed: $($identifiers.Count) audiences and general index."
        exit 0
    }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Missing .wiki/manifest.json.' }
    $collectionHome = $null
    $parentRoot = [IO.Path]::GetDirectoryName($wiki)
    $parentRegistryPath = Join-Path $parentRoot '.wiki/audiences.json'
    if (Test-Path -LiteralPath $parentRegistryPath -PathType Leaf) {
        $parentRegistry = Get-Content -LiteralPath $parentRegistryPath -Raw | ConvertFrom-Json -AsHashtable
        if ($parentRegistry.generator -eq 'local-repo-wiki-collection' -and $parentRegistry.schemaVersion -eq 1 -and [IO.Path]::GetFileName($wiki) -cin @($parentRegistry.audiences.id)) {
            $collectionHome = Join-Path $parentRoot 'README.md'
        }
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
    if ($manifest.schemaVersion -ne 1 -or $manifest.generator -ne 'local-repo-wiki') { $errors.Add('Unsupported manifest schemaVersion or generator.') }
    if ($manifest.status -notin @('planned', 'in_progress', 'complete')) { $errors.Add('Invalid manifest status.') }
    $timestamp = [DateTimeOffset]::MinValue
    $timestampText = if ($manifest.generatedAt -is [datetime]) { $manifest.generatedAt.ToString('o') } else { [string] $manifest.generatedAt }
    if ($timestampText -notmatch '^\d{4}-\d{2}-\d{2}T.*(?:Z|\+00:00)$' -or -not [DateTimeOffset]::TryParse($timestampText, [ref] $timestamp) -or $timestamp.Offset -ne [TimeSpan]::Zero) {
        $errors.Add('generatedAt must be an ISO 8601 UTC timestamp.')
    }
    if (-not $manifest.repository -or [string]::IsNullOrWhiteSpace($manifest.repository.name)) { $errors.Add('Missing repository name.') }
    if ($manifest.repository.workingTree -notin @('clean', 'modified', 'unknown')) { $errors.Add('Invalid workingTree status.') }
    if ([string]::IsNullOrWhiteSpace($manifest.repository.relativeRoot)) {
        $errors.Add('Missing repository.relativeRoot.')
    } elseif ([IO.Path]::IsPathRooted($manifest.repository.relativeRoot) -or -not (Resolve-LocalPath $wiki $manifest.repository.relativeRoot).Equals($repo, $comparison)) {
        $errors.Add('repository.relativeRoot does not resolve to RepoRoot.')
    }
    foreach ($field in @('language', 'audience', 'depth', 'include', 'exclude')) {
        if (-not $manifest.scope -or -not $manifest.scope.ContainsKey($field)) { $errors.Add("Missing scope.$field.") }
    }
    if ($manifest.validation.status -notin @('not_run', 'passed', 'failed')) { $errors.Add('Invalid validation status.') }
    if ($manifest.status -eq 'complete' -and @($manifest.remainingWork).Count -gt 0) { $errors.Add('Completed wiki has remainingWork entries.') }
    if ($manifest.status -eq 'complete' -and $manifest.validation.status -ne 'passed') { $errors.Add('Completed wiki must record passed validation.') }
    if ($manifest.status -ne 'complete') { $warnings.Add('Wiki generation is not marked complete.') }

    $pages = [System.Collections.Generic.Dictionary[string, object]]::new($comparer)
    $homePage = Join-Path $wiki 'README.md'
    $homeCount = 0
    foreach ($page in $manifest.pages) {
        $path = [string] $page.path
        if (-not (Test-RelativeFile $path) -or $path -notmatch '\.md$') { $errors.Add("Invalid page path: $path"); continue }
        $fullPath = Resolve-LocalPath $wiki $path
        if ($pages.ContainsKey($fullPath)) { $errors.Add("Duplicate page: $path"); continue }
        $pages.Add($fullPath, $page)
        if ([string]::IsNullOrWhiteSpace($page.title)) { $errors.Add("${path}: missing title.") }
        if ($page.kind -notin @('home', 'index', 'topic')) { $errors.Add("${path}: invalid kind.") }
        if ($page.kind -eq 'home') {
            $homeCount++
            if (-not $fullPath.Equals($homePage, $comparison)) { $errors.Add('Home page must be README.md at the wiki root.') }
        }
        if ($page.status -notin @('planned', 'in_progress', 'complete')) { $errors.Add("${path}: invalid status.") }
        if ($manifest.status -eq 'complete' -and $page.status -ne 'complete') { $errors.Add("${path}: incomplete page in a completed wiki.") }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            if ($page.status -eq 'planned' -and $manifest.status -ne 'complete') { $warnings.Add("Planned page not yet written: $path") }
            else { $errors.Add("Missing page: $path") }
        }
        if ($page.kind -eq 'topic' -and $page.status -eq 'complete' -and @($page.sources).Count -eq 0) { $errors.Add("${path}: completed topic has no source dependencies.") }
        foreach ($source in $page.sources) {
            if (-not (Test-RelativeFile $source) -or -not (Test-Path -LiteralPath (Resolve-LocalPath $repo $source) -PathType Leaf)) {
                $errors.Add("${path}: invalid or missing source dependency: $source")
            }
        }
    }
    if ($homeCount -ne 1) { $errors.Add('Manifest must contain exactly one home page.') }
    foreach ($file in (Get-ChildItem -LiteralPath $wiki -Filter '*.md' -File -Recurse)) {
        if (Test-Within $file.FullName (Join-Path $wiki '.wiki')) { continue }
        if (-not $pages.ContainsKey($file.FullName)) { $errors.Add("Markdown page absent from manifest: $($file.FullName)") }
    }

    # Simple inline link syntax required by the portable prompt. Escaped brackets
    # in labels and angle-bracket destinations are supported; reference links are not.
    $linkPattern = '(?<!!)\[(?<label>(?:\\.|[^\]\\\r\n])*)\]\(\s*(?:<(?<angle>[^>\r\n]*)>|(?<plain>[^\s()]*))\s*\)'
    foreach ($entry in $pages.GetEnumerator()) {
        $pageFile = $entry.Key
        $page = $entry.Value
        if (-not (Test-Path -LiteralPath $pageFile -PathType Leaf)) { continue }
        $text = Get-Prose (Get-Content -LiteralPath $pageFile -Raw)
        if ([regex]::Matches($text, '(?m)^# [^\r\n]+').Count -ne 1) { $errors.Add("$($page.path): expected exactly one H1 heading.") }
        if ($text -match '\{\{[^}]+\}\}') { $errors.Add("$($page.path): unresolved template placeholder.") }
        $targets = [System.Collections.Generic.HashSet[string]]::new($comparer)
        $pageTargets[$pageFile] = $targets
        $sourceCitations = 0
        foreach ($link in [regex]::Matches($text, $linkPattern)) {
            $destination = if ($link.Groups['angle'].Success) { $link.Groups['angle'].Value } else { $link.Groups['plain'].Value }
            $label = [regex]::Replace($link.Groups['label'].Value, '\\(.)', '$1')
            if ([string]::IsNullOrWhiteSpace($destination)) { $errors.Add("$($page.path): empty link destination: $label"); continue }
            if ($destination -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') {
                if ($destination -match '^https?://') { $warnings.Add("$($page.path): external link not checked: $destination") }
                else { $errors.Add("$($page.path): nonportable URI: $destination") }
                continue
            }
            $pathPart = ($destination -split '#', 2)[0]
            if (-not $pathPart) { $warnings.Add("$($page.path): heading fragment not checked: $destination"); continue }
            $decoded = [Uri]::UnescapeDataString($pathPart)
            if ([IO.Path]::IsPathRooted($decoded) -or $decoded -match '[\\?]') { $errors.Add("$($page.path): nonportable local destination: $destination"); continue }
            $target = Resolve-LocalPath ([IO.Path]::GetDirectoryName($pageFile)) $decoded
            if (-not (Test-Within $target $wiki) -and -not (Test-Within $target $repo) -and $target -ne $collectionHome) { $errors.Add("$($page.path): link leaves wiki and repository: $destination"); continue }
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $errors.Add("$($page.path): missing link target: $destination"); continue }
            $targets.Add($target) | Out-Null
            if (Test-Within $target $repo) {
                $sourcePath = [IO.Path]::GetRelativePath($repo, $target).Replace('\', '/')
                $citation = [regex]::Match($label, '^(?<path>.+):(?<start>\d+)(?:-(?<end>\d+))?$')
                $citedPath = if ($citation.Success) { $citation.Groups['path'].Value } else { $label }
                if ($citedPath -eq $sourcePath) {
                    $sourceCitations++
                    if ($sourcePath -notin @($page.sources)) { $errors.Add("$($page.path): cited source absent from dependencies: $sourcePath") }
                }
                if ($citation.Success) {
                    if ($citedPath -ne $sourcePath) { $errors.Add("$($page.path): citation label does not match target: $label") }
                    if (-not $lineCounts.ContainsKey($target)) { $lineCounts[$target] = [IO.File]::ReadAllLines($target).Length }
                    $start = [long] $citation.Groups['start'].Value
                    $end = if ($citation.Groups['end'].Success) { [long] $citation.Groups['end'].Value } else { $start }
                    if ($start -lt 1 -or $end -lt $start -or $end -gt $lineCounts[$target]) { $errors.Add("$($page.path): invalid line range: $label (file has $($lineCounts[$target]) lines)") }
                }
            }
        }
        if ($page.kind -eq 'topic' -and $page.status -eq 'complete' -and $sourceCitations -eq 0) { $errors.Add("$($page.path): no local source citations found.") }
        if ($page.kind -ne 'home' -and -not $targets.Contains($homePage)) { $errors.Add("$($page.path): missing home link.") }
        if ($page.kind -eq 'topic') {
            $parent = Join-Path ([IO.Path]::GetDirectoryName($pageFile)) 'README.md'
            if (-not $targets.Contains($parent)) { $errors.Add("$($page.path): missing parent index link.") }
        }
    }
    if ($pageTargets.ContainsKey($homePage)) {
        if ($collectionHome -and -not $pageTargets[$homePage].Contains($collectionHome)) { $errors.Add('Audience home: missing general index link.') }
        foreach ($entry in $pages.GetEnumerator()) {
            if ($entry.Key.Equals($homePage, $comparison)) { continue }
            if ($entry.Value.status -eq 'planned' -and -not (Test-Path -LiteralPath $entry.Key -PathType Leaf)) { continue }
            if (-not $pageTargets[$homePage].Contains($entry.Key)) { $errors.Add("$($entry.Value.path): absent from home contents.") }
            $parent = Join-Path ([IO.Path]::GetDirectoryName($entry.Key)) 'README.md'
            if ($entry.Value.kind -eq 'topic' -and $pageTargets.ContainsKey($parent) -and -not $pageTargets[$parent].Contains($entry.Key)) {
                $errors.Add("$($entry.Value.path): absent from parent index.")
            }
        }
    }
} catch {
    $errors.Add($_.Exception.Message)
}

foreach ($warning in $warnings) { Write-Warning $warning }
foreach ($failure in $errors) { [Console]::Error.WriteLine("FAIL: $failure") }
if ($errors.Count -gt 0) {
    [Console]::Error.WriteLine("Validation failed: $($errors.Count) error(s), $($warnings.Count) warning(s).")
    exit 1
}
"Validation passed: $($pages.Count) pages, $($lineCounts.Count) source files with checked line ranges, $($warnings.Count) warning(s)."
exit 0
