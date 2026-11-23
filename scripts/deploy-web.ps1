<#
.SYNOPSIS
Exports a Godot Web release and deploys it to the itch.io html5 channel.
.EXAMPLE
.\scripts\deploy-web.ps1
.EXAMPLE
.\scripts\deploy-web.ps1 -ExportOnly
.EXAMPLE
.\scripts\deploy-web.ps1 -Version 1.1 -Godot C:\Tools\Godot_console.exe
#>
[CmdletBinding()]
param(
    [switch] $ExportOnly,
    [string] $Version,
    [string] $Godot = 'godot_console'
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$target = 'akatona/you-are-what-you-eat:html5'
$godotPath = (Get-Command $Godot -CommandType Application).Source
if (-not $ExportOnly) {
    $butlerPath = (Get-Command butler -CommandType Application).Source
}

$exports = Join-Path $project 'exports'
New-Item -ItemType Directory -Path $exports -Force | Out-Null
$ignoreFile = Join-Path $exports '.gdignore'
if (-not (Test-Path -LiteralPath $ignoreFile)) {
    New-Item -ItemType File -Path $ignoreFile | Out-Null
}

# A fresh folder keeps failed exports and leftover files out of the upload.
$buildId = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $PID
$build = Join-Path $exports "web-$buildId"
$index = Join-Path $build 'index.html'
$log = Join-Path $exports "web-$buildId.log"
New-Item -ItemType Directory -Path $build | Out-Null

Write-Host "Exporting Web release to $build"
& $godotPath --headless --quiet --path $project --log-file $log --export-release Web $index
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed. See $log"
}

foreach ($name in 'index.html', 'index.js', 'index.wasm', 'index.pck') {
    $file = Get-Item -LiteralPath (Join-Path $build $name) -ErrorAction SilentlyContinue
    if (-not $file -or $file.Length -eq 0) {
        throw "Godot did not produce $name. See $log"
    }
}
Write-Host "Web build ready at $index"
if ($ExportOnly) {
    return
}

& $butlerPath validate $build
if ($LASTEXITCODE -ne 0) {
    throw "Butler validation failed for $build."
}

$pushArgs = @('push', $build, $target, '--if-changed', '--context-timeout=45')
if ($Version) {
    $pushArgs += @('--userversion', $Version)
}
& $butlerPath @pushArgs
if ($LASTEXITCODE -ne 0) {
    throw "Butler upload failed for $target. The build is available at $build."
}

& $butlerPath status $target
if ($LASTEXITCODE -ne 0) {
    throw "Butler could not retrieve status for $target after the push."
}
