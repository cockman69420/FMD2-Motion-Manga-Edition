param([string]$ResultRoot = (Join-Path $PSScriptRoot '../../.motion-build/sync-tests'))
$ErrorActionPreference='Stop'
$ResultRoot=[IO.Path]::GetFullPath($ResultRoot)
$testDir=Join-Path $ResultRoot ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $testDir | Out-Null
$up=Join-Path $testDir 'upstream';$fork=Join-Path $testDir 'fork'
$script=(Resolve-Path (Join-Path $PSScriptRoot '../scripts/Sync-Upstream.ps1')).Path
function RunGit([Parameter(ValueFromRemainingArguments=$true)][string[]]$a){ & git @a *> $null;if($LASTEXITCODE){throw "Test git command failed: $($a -join ' ')"} }
RunGit init --initial-branch=main $up
RunGit -C $up config user.name Motion-tests
RunGit -C $up config user.email motion-tests@localhost
'renderer=static' | Set-Content (Join-Path $up 'engine.txt')
RunGit -C $up add .
RunGit -C $up commit -m base
RunGit clone $up $fork
RunGit -C $fork config user.name Motion-tests
RunGit -C $fork config user.email motion-tests@localhost
'renderer=motion' | Set-Content (Join-Path $fork 'engine.txt')
RunGit -C $fork add .
RunGit -C $fork commit -m motion
'upstream improvement' | Set-Content (Join-Path $up 'upstream.txt')
RunGit -C $up add .
RunGit -C $up commit -m clean-update
Push-Location $fork
try { & $script -UpstreamURL $up -UpstreamBranch main -BaseBranch main -NoPublish -ResultFile (Join-Path $testDir 'clean.json'); if($LASTEXITCODE){throw 'Clean sync failed'} }
finally { Pop-Location }
$clean=Get-Content (Join-Path $testDir 'clean.json') -Raw | ConvertFrom-Json
if($clean.state -ne 'merged-for-review' -or (Get-Content (Join-Path $fork 'engine.txt')) -ne 'renderer=motion' -or !(Test-Path (Join-Path $fork 'upstream.txt'))){throw 'Clean sync lost a customization or upstream change'}
Write-Output 'PASS: clean upstream merge retains Motion customization'

'renderer=upstream-v2' | Set-Content (Join-Path $up 'engine.txt')
RunGit -C $up add .
RunGit -C $up commit -m conflicting-update
RunGit -C $fork checkout main
Push-Location $fork
try { & $script -UpstreamURL $up -UpstreamBranch main -BaseBranch main -NoPublish -ResultFile (Join-Path $testDir 'conflict.json'); if($LASTEXITCODE -ne 2){throw 'Conflict did not stop synchronization'} }
finally { Pop-Location }
$conflict=Get-Content (Join-Path $testDir 'conflict.json') -Raw | ConvertFrom-Json
if($conflict.state -ne 'conflict' -or $conflict.conflicts -notcontains 'engine.txt'){throw 'Conflict report missing'}
if((Get-Content (Join-Path $fork 'engine.txt')) -ne 'renderer=motion'){throw 'Customization changed on conflict'}
if(& git -C $fork diff --name-only --diff-filter=U){throw 'Merge was not aborted cleanly'}
Write-Output 'PASS: conflicting update records paths, stops and retains customization'
Write-Output 'RESULT: 2 upstream synchronization checks passed'
