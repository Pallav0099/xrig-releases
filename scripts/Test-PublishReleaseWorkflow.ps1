[CmdletBinding()]
param(
    [string]$WorkflowPath = (Join-Path $PSScriptRoot '..\.github\workflows\publish-release.yml')
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-StepBlock {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $escapedName = [Regex]::Escape($Name)
    $match = [Regex]::Match(
        $Content,
        "(?ms)^      - name: $escapedName\r?\n(?<body>.*?)(?=^      - name: |\z)"
    )
    Assert-True $match.Success "Workflow step '$Name' was not found."
    return $match.Groups['body'].Value
}

$resolvedWorkflow = (Resolve-Path -LiteralPath $WorkflowPath).Path
$content = Get-Content -LiteralPath $resolvedWorkflow -Raw

Assert-True ($content -match '(?m)^on:\r?$') 'Workflow trigger block is missing.'
Assert-True ($content -match '(?m)^  workflow_dispatch:\r?$') 'Release workflow must remain workflow_dispatch-only.'
Assert-True ($content -notmatch '(?m)^  (push|pull_request|schedule):') 'Release workflow must not run on push, pull request, or schedule.'
Assert-True ($content -notmatch '[\u2018\u2019\u201C\u201D]') 'Workflow contains typographic quotes that can break PowerShell parsing.'

$usesLines = @([Regex]::Matches($content, '(?m)^\s+uses:\s+([^\r\n#]+)') | ForEach-Object { $_.Groups[1].Value.Trim() })
Assert-True ($usesLines.Count -gt 0) 'Workflow contains no pinned actions.'
foreach ($uses in $usesLines) {
    Assert-True ($uses -match '@[0-9a-f]{40}$') "Action is not pinned to a full commit SHA: $uses"
}

$firstStep = $content.IndexOf('      - name: ')
Assert-True ($firstStep -ge 0) 'Workflow contains no steps.'
$jobHeader = $content.Substring(0, $firstStep)
Assert-True ($jobHeader -notmatch '(?m)^\s+GH_TOKEN:') 'GH_TOKEN must not be exposed at job scope.'
Assert-True ($jobHeader -notmatch '(?m)^\s+GITHUB_TOKEN:') 'GITHUB_TOKEN must not be exposed at job scope.'

$kaiStep = Get-StepBlock $content 'Build tagged Kai artifact'
Assert-True ($kaiStep -match "(?m)^          GH_TOKEN: ''\r?$") 'Kai build must explicitly clear GH_TOKEN.'
Assert-True ($kaiStep -match "(?m)^          GITHUB_TOKEN: ''\r?$") 'Kai build must explicitly clear GITHUB_TOKEN.'
Assert-True ($kaiStep -match 'npm run dist:win:nsis --workspace apps/desktop -- --publish never') 'Kai build must disable electron-builder publication explicitly.'

$publishStep = Get-StepBlock $content 'Publish immutable GitHub Release assets'
Assert-True ($publishStep -match '(?m)^          GH_TOKEN: \$\{\{ github\.token \}\}\r?$') 'GitHub token must be scoped to the release publication step.'
Assert-True ($publishStep -match 'gh release list') 'Release existence check must use a non-failing release listing command.'
Assert-True ($publishStep -notmatch 'if \(& gh release view') 'Release publication must not probe a missing release with a strict native command.'

$verifyStep = Get-StepBlock $content 'Verify published asset inventory'
Assert-True ($verifyStep -match '(?m)^          GH_TOKEN: \$\{\{ github\.token \}\}\r?$') 'GitHub token must be scoped to the published-inventory step.'

$signStep = Get-StepBlock $content 'Sign immutable release payloads'
Assert-True ($signStep -match '\$relativePath = \$_.Path\.Substring\(\$artifactRoot\.Length\)') 'SHA256SUMS must derive portable relative paths.'
Assert-True ($signStep -notmatch '\.Replace\(\(Resolve-Path artifacts\)') 'SHA256SUMS must not retain runner-absolute paths.'

$inventoryStep = Get-StepBlock $content 'Validate candidate artifact inventory'
Assert-True ($inventoryStep -match "\$kaiPayload = 'src/kai/apps/desktop/release/win-unpacked/kai\.exe'") 'Kai package validation must inspect the embedded x64 executable.'
Assert-True ($inventoryStep -match '0x8664') 'Candidate inventory must validate AMD64 PE payloads.'

Write-Host 'XRIG release workflow contract passed.'
