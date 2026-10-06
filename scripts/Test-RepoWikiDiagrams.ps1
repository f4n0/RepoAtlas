#Requires -Version 7.0
<#
.SYNOPSIS
Checks wiki diagrams using an already-installed local Mermaid CLI.
.DESCRIPTION
Extracts Mermaid fences outside examples and comments, then renders each with
the supplied CLI. Input pages are not modified. Temporary render files are
removed afterward. Exit codes: 0 passed/no diagrams, 1 failed, 2 CLI unavailable.
Rendering does not establish factual accuracy or compatibility with every viewer.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $WikiPath,
    [string] $MermaidCliPath = 'mmdc'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$errors = [System.Collections.Generic.List[string]]::new()
$blocks = [System.Collections.Generic.List[object]]::new()
$temporary = $null
$rendered = 0

try {
    $wiki = (Resolve-Path -LiteralPath $WikiPath).Path
    if (-not (Test-Path -LiteralPath $wiki -PathType Container)) { throw 'WikiPath must be a directory.' }
    foreach ($file in (Get-ChildItem -LiteralPath $wiki -Filter '*.md' -File -Recurse | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($wiki, $file.FullName).Replace('\', '/')
        if ($relative -like '.wiki/*') { continue }
        $fenceChar = ''
        $fenceLength = 0
        $isMermaid = $false
        $inComment = $false
        $startLine = 0
        $body = [System.Collections.Generic.List[string]]::new()
        $lines = [IO.File]::ReadAllLines($file.FullName)
        for ($lineIndex = 0; $lineIndex -lt $lines.Length; $lineIndex++) {
            $line = $lines[$lineIndex]
            if ($fenceChar) {
                if ($line -match ('^ {0,3}' + [regex]::Escape($fenceChar) + '{' + $fenceLength + ',}\s*$')) {
                    if ($isMermaid) {
                        $code = $body -join "`n"
                        if ([string]::IsNullOrWhiteSpace($code)) { throw "${relative}:${startLine}: empty Mermaid block." }
                        $blocks.Add([pscustomobject] @{ Page = $relative; Line = $startLine; Code = $code })
                    }
                    $fenceChar = ''
                }
                elseif ($isMermaid) {
                    $body.Add($line)
                }
                continue
            }

            $visibleLine = $line
            if ($inComment) {
                $commentEnd = $visibleLine.IndexOf('-->')
                if ($commentEnd -lt 0) { continue }
                $visibleLine = $visibleLine.Substring($commentEnd + 3)
                $inComment = $false
            }
            while (($commentStart = $visibleLine.IndexOf('<!--')) -ge 0) {
                $commentEnd = $visibleLine.IndexOf('-->', $commentStart + 4)
                if ($commentEnd -lt 0) {
                    $visibleLine = $visibleLine.Substring(0, $commentStart)
                    $inComment = $true
                    break
                }
                $visibleLine = $visibleLine.Remove($commentStart, $commentEnd + 3 - $commentStart)
            }
            $opening = [regex]::Match($visibleLine, '^ {0,3}(?<fence>`{3,}|~{3,})(?<info>.*)$')
            if (-not $opening.Success) { continue }
            $fence = $opening.Groups['fence'].Value
            $fenceChar = $fence.Substring(0, 1)
            $fenceLength = $fence.Length
            $isMermaid = $opening.Groups['info'].Value.Trim() -match '^mermaid(?:\s|$)'
            $startLine = $lineIndex + 1
            $body.Clear()
        }
        if ($fenceChar -and $isMermaid) { throw "${relative}:${startLine}: unclosed Mermaid fence." }
    }

    if ($blocks.Count -eq 0) {
        'No Mermaid diagrams found; no renderer invoked.'
        exit 0
    }
    $cli = Get-Command -Name $MermaidCliPath -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cli) {
        Write-Warning "Mermaid CLI unavailable: $MermaidCliPath. No tools were installed and no diagrams were rendered."
        exit 2
    }

    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('repo-wiki-diagrams-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temporary) | Out-Null
    $configFile = Join-Path $temporary 'mermaid.json'
    [IO.File]::WriteAllText($configFile, (@{ securityLevel = 'strict'; flowchart = @{ htmlLabels = $false } } | ConvertTo-Json -Depth 3))
    for ($blockIndex = 0; $blockIndex -lt $blocks.Count; $blockIndex++) {
        $block = $blocks[$blockIndex]
        $inputFile = Join-Path $temporary "$blockIndex.mmd"
        $outputFile = Join-Path $temporary "$blockIndex.svg"
        [IO.File]::WriteAllText($inputFile, $block.Code)
        try {
            $LASTEXITCODE = 0
            $output = & $cli.Source -i $inputFile -o $outputFile -c $configFile 2>&1
            $exitCode = $LASTEXITCODE
            if ($exitCode -ne 0) { throw "Renderer exit ${exitCode}: $($output -join ' ')" }
            if (-not (Test-Path -LiteralPath $outputFile -PathType Leaf) -or (Get-Item -LiteralPath $outputFile).Length -eq 0) {
                throw 'Renderer did not produce a nonempty SVG.'
            }
            $rendered++
        }
        catch {
            $errors.Add("$($block.Page):$($block.Line): $($_.Exception.Message)")
        }
    }
}
catch {
    $errors.Add($_.Exception.Message)
}
finally {
    if ($temporary -and (Test-Path -LiteralPath $temporary)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}

foreach ($failure in $errors) { [Console]::Error.WriteLine("FAIL: $failure") }
if ($errors.Count -gt 0) {
    [Console]::Error.WriteLine("Mermaid rendering failed: $($errors.Count) error(s), $rendered diagram(s) rendered.")
    exit 1
}
"Mermaid rendering passed: $rendered diagram(s). Source accuracy and other viewers were not checked."
exit 0