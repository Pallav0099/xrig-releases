#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("xrig-release-manifest-test-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $temporary | Out-Null

try {
    $files = @(
        'xrig-identity-1.0.0-win-x64.exe',
        'Vertex-1.0.0-win-x64.exe',
        'cudart-llama-bin-win-cuda-12.4-x64.zip',
        'gemma4-12b-5060ti.json',
        'Vertex-install-1.0.0-win-x64.exe',
        'Kai-1.0.0-win-x64.exe',
        'Install-Kai-inner-1.0.0.ps1',
        'llama-b9878-bin-win-cuda-12.4-x64.zip',
        'llama-b9999-bin-win-vulkan-x64.zip',
        'llama-b9999-bin-win-openvino-2026.2.1-x64.zip',
        'Vertex-runtime-1.0.0-win-x64.tar.gz',
        'Install-Vertex-inner-1.0.0.ps1'
    )
    foreach ($file in $files) {
        [System.IO.File]::WriteAllText((Join-Path $temporary $file), "test-$file", [System.Text.UTF8Encoding]::new($false))
        if ($file -ne 'gemma4-12b-5060ti.json') {
            [System.IO.File]::WriteAllText((Join-Path $temporary "$file.sig"), '00', [System.Text.UTF8Encoding]::new($false))
        }
    }

    $manifest = Join-Path $temporary 'xrig-release-v1.manifest'
    & (Join-Path $PSScriptRoot 'New-XrigReleaseManifest.ps1') `
        -ReleaseTag v1.0.0 -PlatformVersion 1.0.0 -VertexVersion 1.0.0 -KaiVersion 1.0.0 `
        -AssetDirectory $temporary -OutputPath $manifest

    $content = [System.IO.File]::ReadAllText($manifest, [System.Text.UTF8Encoding]::new($false))
    if ($content.Contains("`r")) { throw 'Manifest must use LF line endings.' }
    $keys = @($content.Trim().Split("`n") | ForEach-Object { ($_ -split '=', 2)[0] })
    $expectedKeys = [string[]]$keys.Clone()
    [Array]::Sort($expectedKeys, [StringComparer]::Ordinal)
    if (($expectedKeys -join "`n") -ne ($keys -join "`n")) { throw 'Manifest keys are not in canonical ordinal order.' }
    if ($content -notmatch '(?m)^base_url=https://github\.com/Pallav0099/xrig-releases/releases/download/v1\.0\.0$') {
        throw 'Manifest base URL is not the versioned GitHub Release path.'
    }
    if ($content -notmatch '(?m)^asset\.windows\.amd64\.factory_config\.verification=manifest$') {
        throw 'Factory configuration must use manifest verification.'
    }
    if ($content -notmatch '(?m)^asset\.windows\.amd64\.identity\.sig_path=xrig-identity-1\.0\.0-win-x64\.exe\.sig$') {
        throw 'Platform identity detached signature is missing from the manifest.'
    }
    if ($content -notmatch '(?m)^asset\.windows\.amd64\.kai\.sig_path=Kai-1\.0\.0-win-x64\.exe\.sig$') {
        throw 'Kai package detached signature is missing from the manifest.'
    }
    foreach ($backend in @('llama_vulkan', 'llama_openvino')) {
        if ($content -notmatch "(?m)^asset\.windows\.amd64\.$backend\.verification=detached-ed25519$") {
            throw "Manifest is missing the signed $backend runtime."
        }
    }
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
