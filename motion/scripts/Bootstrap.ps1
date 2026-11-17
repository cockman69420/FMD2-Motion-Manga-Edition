param([string]$BuildRoot = (Join-Path $PSScriptRoot '../../.motion-build'))
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
New-Item -ItemType Directory -Force $BuildRoot | Out-Null
$lock = Get-Content (Join-Path $PSScriptRoot '../dependencies.lock.json') -Raw | ConvertFrom-Json
function Download-Checked($url, $file, $hash) {
    if (!(Test-Path -LiteralPath $file)) { Invoke-WebRequest -Uri $url -OutFile $file }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $hash) {
        throw "Checksum mismatch: $file. Upstream download changed; review the dependency lock instead of accepting it automatically."
    }
}
foreach ($entry in @($lock.lazarus, $lock.extractor)) {
    Download-Checked $entry.url (Join-Path $BuildRoot $entry.file) $entry.sha256
}
$extractor = Join-Path $BuildRoot 'innoextract/innoextract.exe'
if (!(Test-Path -LiteralPath $extractor)) { Expand-Archive -LiteralPath (Join-Path $BuildRoot $lock.extractor.file) -DestinationPath (Join-Path $BuildRoot 'innoextract') }
$toolchain = Join-Path $BuildRoot 'toolchain'
if (!(Test-Path -LiteralPath (Join-Path $toolchain 'app/lazbuild.exe'))) {
    & $extractor --extract --output-dir $toolchain (Join-Path $BuildRoot $lock.lazarus.file)
    if ($LASTEXITCODE) { throw 'Lazarus extraction failed' }
}
$deps = Join-Path $BuildRoot 'deps'
New-Item -ItemType Directory -Force $deps | Out-Null
foreach ($entry in $lock.archives) {
    $zip = Join-Path $deps ($entry.name + '.zip')
    Download-Checked ('https://packages.lazarus-ide.org/' + $entry.name + '.zip') $zip $entry.sha256
    $dir = Join-Path $deps $entry.name
    if (!(Test-Path -LiteralPath $dir)) { Expand-Archive -LiteralPath $zip -DestinationPath $dir }
}
foreach ($entry in $lock.git) {
    $dir = Join-Path $deps $entry.name
    if (!(Test-Path -LiteralPath $dir)) {
        & git init $dir
        if ($LASTEXITCODE) { throw "Cannot create $dir" }
        & git -C $dir fetch --depth=1 $entry.url $entry.commit
        if ($LASTEXITCODE) { throw "Cannot fetch $($entry.name)" }
        & git -C $dir checkout --detach FETCH_HEAD
        if ($LASTEXITCODE) { throw "Cannot check out $($entry.name)" }
    }
    $actual = & git -c safe.directory=$dir -C $dir rev-parse HEAD
    if ($actual -ne $entry.commit) { throw "Unexpected dependency revision: $($entry.name)" }
}
Copy-Item -LiteralPath (Join-Path $deps 'flre/src/FLRE.pas') -Destination (Join-Path $deps 'internettools/data/FLRE.pas') -Force
Copy-Item -LiteralPath (Join-Path $deps 'pucu/src/PUCU.pas') -Destination (Join-Path $deps 'internettools/data/PUCU.pas') -Force
Write-Output "Toolchain: $(Join-Path $toolchain 'app')"
Write-Output "Dependencies: $deps"
