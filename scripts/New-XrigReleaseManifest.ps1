#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')]
    [string]$PlatformVersion,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')]
    [string]$VertexVersion,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')]
    [string]$KaiVersion,

    [Parameter(Mandatory = $true)]
    [string]$AssetDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$Channel = 'stable'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$assetRoot = (Resolve-Path -LiteralPath $AssetDirectory).Path
$releaseVersion = $ReleaseTag.Substring(1)
$baseURL = "https://github.com/Pallav0099/xrig-releases/releases/download/$ReleaseTag"

function Get-AssetMetadata([string]$Id, [string]$FileName, [string]$Version, [string]$Verification) {
    $path = Join-Path $assetRoot $FileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required release asset is missing: $FileName"
    }

    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $result = [ordered]@{
        id = $Id
        path = $FileName
        sha256 = $hash
        size_bytes = [int64](Get-Item -LiteralPath $path).Length
        verification = $Verification
        version = $Version
    }
    if ($Verification -eq 'detached-ed25519') {
        $signature = "$path.sig"
        if (-not (Test-Path -LiteralPath $signature -PathType Leaf)) {
            throw "Required release signature is missing: $FileName.sig"
        }
        $result.sig_path = "$FileName.sig"
    }
    return $result
}

$assets = @(
    (Get-AssetMetadata 'windows.amd64.identity' "xrig-identity-$PlatformVersion-win-x64.exe" $PlatformVersion 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.app' "Vertex-$VertexVersion-win-x64.exe" $VertexVersion 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.cudart' 'cudart-llama-bin-win-cuda-12.4-x64.zip' 'b9878' 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.factory_config' 'gemma4-12b-5060ti.json' $VertexVersion 'manifest'),
    (Get-AssetMetadata 'windows.amd64.install' "Vertex-install-$VertexVersion-win-x64.exe" $VertexVersion 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.kai' "Kai-$KaiVersion-win-x64.exe" $KaiVersion 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.kai_installer' "Install-Kai-inner-$KaiVersion.ps1" $KaiVersion 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.llama_cuda' 'llama-b9878-bin-win-cuda-12.4-x64.zip' 'b9878' 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.package' "Vertex-runtime-$VertexVersion-win-x64.tar.gz" $VertexVersion 'detached-ed25519'),
    (Get-AssetMetadata 'windows.amd64.vertex_installer' "Install-Vertex-inner-$VertexVersion.ps1" $VertexVersion 'detached-ed25519')
)

$values = @{
    architecture = 'amd64'
    base_url = $baseURL
    channel = $Channel
    cuda_runtime_version = '12.4'
    electron_version = '40.10.2'
    format = 'xrig-release-v1'
    gpu_profile = 'windows-nvidia-rtx-5060-ti-16gb-cuda'
    kai_version = $KaiVersion
    llama_cpp_version = 'b9878'
    nvidia_driver_min = '551.61'
    platform_version = $PlatformVersion
    python_version = '3.11.9'
    version = $releaseVersion
    vertex_version = $VertexVersion
    windows_min_build = '22621'
}

foreach ($asset in $assets) {
    $prefix = "asset.$($asset.id)"
    $values["$prefix.path"] = $asset.path
    $values["$prefix.sha256"] = $asset.sha256
    if ($asset.verification -eq 'detached-ed25519') {
        $values["$prefix.sig_path"] = $asset.sig_path
    }
    $values["$prefix.size_bytes"] = [string]$asset.size_bytes
    $values["$prefix.verification"] = $asset.verification
    $values["$prefix.version"] = $asset.version
}

$lines = foreach ($key in @($values.Keys | Sort-Object)) {
    "$key=$($values[$key])"
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}
[System.IO.File]::WriteAllText(
    [System.IO.Path]::GetFullPath($OutputPath),
    (($lines -join "`n") + "`n"),
    [System.Text.UTF8Encoding]::new($false)
)
