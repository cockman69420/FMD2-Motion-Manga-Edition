param(
    [Parameter(Mandatory=$true)][string]$Destination,
    [string]$Repository = '',
    [string]$ReleaseTag = 'motion-0.1.0'
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$Destination = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Destination) { throw 'Choose a new, empty destination; existing installations are never overwritten.' }
foreach ($required in @('fmd.exe','updater.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $root ('bin/x86_64-win64/'+$required)))) { throw "Missing compiled $required" }
}
New-Item -ItemType Directory -Force $Destination | Out-Null
foreach ($folder in @('images','languages','licenses','lua')) { Copy-Item -LiteralPath (Join-Path $root $folder) -Destination $Destination -Recurse }
Copy-Item (Join-Path $root 'dist/x86_64-win64/*') -Destination $Destination -Force
foreach ($file in @('fmd.exe','updater.exe')) { Copy-Item -LiteralPath (Join-Path $root ('bin/x86_64-win64/'+$file)) -Destination $Destination }
Copy-Item -LiteralPath (Join-Path $root 'dist/config.json') -Destination $Destination
foreach ($file in @('license.txt','changelog.txt','readme.rtf')) { Copy-Item -LiteralPath (Join-Path $root $file) -Destination $Destination }
$motionDir = Join-Path $Destination 'motion'
New-Item -ItemType Directory $motionDir | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'motion/reader.html') -Destination $motionDir
Copy-Item -LiteralPath (Join-Path $root 'motion/INSTALLATION-DA.md') -Destination (Join-Path $Destination 'START-HER.md')
Copy-Item -LiteralPath (Join-Path $root 'motion/TEST-REPORT.md') -Destination $motionDir
Copy-Item -LiteralPath (Join-Path $root 'motion/UPDATES.md') -Destination $motionDir
if (Test-Path -LiteralPath (Join-Path $root 'motion/tests/fixtures/demo-motion.cbz')) {
    Copy-Item -LiteralPath (Join-Path $root 'motion/tests/fixtures/demo-motion.cbz') -Destination (Join-Path $Destination 'Demo-motion.cbz')
}
# Keep official module/database feeds. Only the fork owns motion-specific files.
if ($Repository) {
    if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Repository must be owner/name.' }
    if ($Repository -ieq 'dazedcat19/FMD2') { throw 'Motion binaries cannot use the official binary feed.' }
    $config = Get-Content (Join-Path $Destination 'config.json') -Raw | ConvertFrom-Json
    $config.config.update_url = "https://github.com/$Repository/releases/latest/download/motion-latest.json"
    $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Destination 'config.json') -Encoding utf8
}
$checksumPath = Join-Path $Destination 'SHA256SUMS.txt'
$lines = Get-ChildItem -LiteralPath $Destination -File -Recurse | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($Destination.Length+1).Replace('\','/')
    ((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()+'  '+$relative)
}
$lines | Set-Content -LiteralPath $checksumPath -Encoding ascii
$parent = Split-Path $Destination -Parent
$archive = Join-Path $parent ("fmd-motion_${ReleaseTag}_x86_64-win64.7z")
if (Test-Path -LiteralPath $archive) { throw "Archive already exists: $archive" }
& (Join-Path $Destination '7za.exe') a $archive ($Destination+'\*') -t7z -mx5 -y
if ($LASTEXITCODE) { throw 'Packaging failed' }
if ($Repository) {
    $baseVersion = (Get-Item -LiteralPath (Join-Path $Destination 'fmd.exe')).VersionInfo.FileVersion
    if ($baseVersion -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw 'Compiled FMD version is missing.' }
    $versionSource = Get-Content (Join-Path $root 'baseunits/MotionUpdatePolicy.pas') -Raw
    if ($versionSource -notmatch "MOTION_VERSION = '(\d+\.\d+\.\d+\.\d+)'") { throw 'Motion version constant is missing.' }
    $motionVersion = $Matches[1]
    $manifest = @{'x86_64-win64'=@{
        version=$baseVersion
        motion_version=$motionVersion
        sha256=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLower()
        download_url="https://github.com/$Repository/releases/download/$ReleaseTag/$(Split-Path $archive -Leaf)"
        changelog_url="https://raw.githubusercontent.com/$Repository/$ReleaseTag/motion/CHANGELOG.md"
    }}
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $parent 'motion-latest.json') -Encoding utf8
}
Write-Output "Portable installation: $Destination"
Write-Output "Release archive: $archive"
