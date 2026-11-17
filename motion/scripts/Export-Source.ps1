param(
    [Parameter(Mandatory=$true)][string]$Destination,
    [string]$DependenciesDir = (Join-Path $PSScriptRoot '../../.motion-build/deps')
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$Destination=[IO.Path]::GetFullPath($Destination)
if(Test-Path -LiteralPath $Destination){throw 'Choose a new source-kit destination.'}
if(& git -c safe.directory=$root -C $root status --porcelain){throw 'Commit the source changes before exporting the exact build source.'}
New-Item -ItemType Directory -Force $Destination | Out-Null
$code=Join-Path $Destination 'FMD2'
$tempZip=Join-Path $Destination 'source-snapshot.zip'
& git -c safe.directory=$root -C $root archive --format=zip --output=$tempZip HEAD
if($LASTEXITCODE){throw 'Source archive failed'}
Expand-Archive -LiteralPath $tempZip -DestinationPath $code
Remove-Item -LiteralPath $tempZip
$patch=Join-Path $Destination 'motion-changes.patch'
& git -c safe.directory=$root -C $root diff --binary --output=$patch 2.0.34.5 HEAD
if($LASTEXITCODE){throw 'Fork patch export failed'}
$deps=Join-Path $Destination 'dependency-sources'
New-Item -ItemType Directory $deps | Out-Null
$lock=Get-Content (Join-Path $root 'motion/dependencies.lock.json') -Raw | ConvertFrom-Json
foreach($entry in $lock.archives){Copy-Item -LiteralPath (Join-Path $DependenciesDir ($entry.name+'.zip')) -Destination $deps}
foreach($entry in $lock.git){
    $dir=(Resolve-Path -LiteralPath (Join-Path $DependenciesDir $entry.name)).Path
    $archive=Join-Path $deps ($entry.name+'.zip')
    & git -c safe.directory=$dir -C $dir archive --format=zip --output=$archive $entry.commit
    if($LASTEXITCODE){throw "Dependency source export failed: $($entry.name)"}
}
Copy-Item -LiteralPath (Join-Path $root 'motion/SOURCE-KIT.md') -Destination (Join-Path $Destination 'README.md')
$files=Get-ChildItem -LiteralPath $Destination -File -Recurse | Sort-Object FullName
$files | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()+'  '+$_.FullName.Substring($Destination.Length+1).Replace('\','/') } | Set-Content -LiteralPath (Join-Path $Destination 'SHA256SUMS.txt') -Encoding ascii
$zip=$Destination+'.zip'
if(Test-Path -LiteralPath $zip){throw 'Source zip already exists'}
Compress-Archive -Path (Join-Path $Destination '*') -DestinationPath $zip -CompressionLevel Optimal
Write-Output "Source kit: $zip"
