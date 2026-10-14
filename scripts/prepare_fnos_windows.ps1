$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expectedRevision = 'ee80f08bbf97172ec030b8751ceab557177a34a6'
$flutterRoot = Join-Path $repoRoot '.porting\tools\flutter'
$pubCache = Join-Path $repoRoot '.porting\pub-cache'
$sdkExport = Join-Path $repoRoot '.porting\docker-sdk\flutter'
$pubExport = Join-Path $repoRoot '.porting\docker-pub'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git for Windows is required. Install Git, reopen PowerShell, then run this script again.'
}
if (-not (Test-Path (Join-Path $repoRoot 'pubspec.lock'))) {
    throw 'Run this script from a complete Git checkout of NipaPlay-fnOS.'
}

New-Item -ItemType Directory -Force -Path (Split-Path $flutterRoot) | Out-Null
if (-not (Test-Path (Join-Path $flutterRoot '.git'))) {
    & git clone --depth 1 --branch 3.44.6 --filter=blob:none `
        https://github.com/flutter/flutter.git $flutterRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not download Flutter 3.44.6.' }
}
$actualRevision = (& git -C $flutterRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
    throw "Flutter SDK revision mismatch. Expected $expectedRevision; found $actualRevision."
}

& git -C $repoRoot submodule update --init third_party/media-kit-upstream
if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the media-kit-upstream submodule required by pubspec.yaml.' }

$env:FLUTTER_ROOT = $flutterRoot
$env:PUB_CACHE = $pubCache
$flutterBat = Join-Path $flutterRoot 'bin\flutter.bat'
if (-not (Test-Path $flutterBat)) { throw 'Flutter Windows launcher is missing.' }

# pub get may regenerate desktop plugin files; keep and restore the checkout's
# exact versions so preparing the Docker contexts doesn't dirty user source.
$generatedFiles = @(
    'linux/flutter/generated_plugin_registrant.cc',
    'linux/flutter/generated_plugins.cmake',
    'macos/Flutter/GeneratedPluginRegistrant.swift',
    'windows/flutter/generated_plugin_registrant.cc',
    'windows/flutter/generated_plugins.cmake'
)
$backupRoot = Join-Path $repoRoot ('.porting\generated-backup-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
try {
    foreach ($relative in $generatedFiles) {
        $source = Join-Path $repoRoot $relative
        if (Test-Path $source) {
            $backup = Join-Path $backupRoot $relative
            New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup
        }
    }
    Push-Location $repoRoot
    try {
        & $flutterBat pub get --enforce-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
    } finally { Pop-Location }
} finally {
    foreach ($relative in $generatedFiles) {
        $backup = Join-Path $backupRoot $relative
        if (Test-Path $backup) {
            Copy-Item -LiteralPath $backup -Destination (Join-Path $repoRoot $relative) -Force
        }
    }
    Remove-Item -LiteralPath $backupRoot -Recurse -Force
}

if (Test-Path (Join-Path $sdkExport '.ready')) {
    $readyRevision = (Get-Content -LiteralPath (Join-Path $sdkExport '.ready') -Raw).Trim()
    if ($readyRevision -ne $expectedRevision) { throw 'Existing Docker Flutter SDK export has a different revision.' }
} else {
    if (Test-Path $sdkExport) { throw "Incomplete SDK export exists at $sdkExport. Move it aside and rerun." }
    New-Item -ItemType Directory -Force -Path $sdkExport | Out-Null
    & robocopy $flutterRoot $sdkExport /E /XD (Join-Path $flutterRoot '.git') `
        (Join-Path $flutterRoot 'bin\cache') /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -ge 8) { throw 'Could not export Flutter source for Docker.' }
    Copy-Item -LiteralPath (Join-Path $flutterRoot '.git') `
        -Destination (Join-Path $sdkExport '.git') -Recurse
    Set-Content -LiteralPath (Join-Path $sdkExport '.ready') `
        -Value $expectedRevision -NoNewline
}

New-Item -ItemType Directory -Force -Path $pubExport | Out-Null
foreach ($name in @('hosted', 'hosted-hashes', 'git')) {
    $source = Join-Path $pubCache $name
    if (-not (Test-Path $source)) { throw "Missing Pub cache '$name'; dependency resolution did not finish." }
    $target = Join-Path $pubExport $name
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    & robocopy $source $target /E /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -ge 8) { throw "Could not export Pub cache '$name'." }
}
Write-Host "Windows Docker build contexts are ready. Flutter revision: $expectedRevision"
