param(
    [string]$LazarusDir = (Join-Path $PSScriptRoot '../../.motion-build/toolchain/app'),
    [string]$DependenciesDir = (Join-Path $PSScriptRoot '../../.motion-build/deps'),
    [string]$BuildRoot = (Join-Path $PSScriptRoot '../../.motion-build'),
    [switch]$TestsOnly,
    [string]$LiveHTML = ''
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$LazarusDir = (Resolve-Path -LiteralPath $LazarusDir).Path
$DependenciesDir = (Resolve-Path -LiteralPath $DependenciesDir).Path
$BuildRoot = [IO.Path]::GetFullPath($BuildRoot)
$configDir = Join-Path $BuildRoot 'lazconfig'
New-Item -ItemType Directory -Force $configDir | Out-Null
$fpcRoot = Join-Path $LazarusDir 'fpc/3.2.2'
$fpcBin = Join-Path $fpcRoot 'bin/x86_64-win64'
$env:PATH = $fpcBin + ';' + $env:PATH
# Lazarus' installer normally expands these paths. We extract without installing.
@('-MObjFPC','-Sg','-O1','-vewn',('-Fu'+$fpcRoot+'\units\$fpctarget\*'),('-FD'+$fpcRoot+'\bin\$fpctarget')) | Set-Content -LiteralPath (Join-Path $fpcBin 'fpc.cfg')
[xml]$config = '<CONFIG><EnvironmentOptions><Version Value="110"/><LazarusDirectory Value=""/><CompilerFilename Value=""/><MakeFilename Value=""/></EnvironmentOptions></CONFIG>'
$config.CONFIG.EnvironmentOptions.LazarusDirectory.SetAttribute('Value',$LazarusDir)
$config.CONFIG.EnvironmentOptions.CompilerFilename.SetAttribute('Value',(Join-Path $fpcBin 'fpc.exe'))
$config.CONFIG.EnvironmentOptions.MakeFilename.SetAttribute('Value',(Join-Path $fpcBin 'make.exe'))
$config.Save((Join-Path $configDir 'environmentoptions.xml'))
$lazbuild = Join-Path $LazarusDir 'lazbuild.exe'
$common = @('--quiet', ('--primary-config-path='+$configDir), ('--lazarusdir='+$LazarusDir))
foreach ($pkg in Get-ChildItem -LiteralPath $DependenciesDir -Recurse -Filter '*.lpk' | Where-Object { $_.Name -notin @('internettools_autoupdate.lpk','dcpcrypt_laz.lpk','metadarkstyledsgn226.lpk') }) {
    & $lazbuild @common --add-package-link $pkg.FullName *> $null
    if ($LASTEXITCODE) { throw "Package registration failed: $($pkg.FullName)" }
}
$revision = & git -c safe.directory=$root -C $root rev-parse HEAD 2>$null
if ($LASTEXITCODE) { $revision = 'source-snapshot' }
@('const', "  REVISION_NUMBER = 'motion-0.1.0';", "  REVISION_SHA = '$revision';") | Set-Content -LiteralPath (Join-Path $root 'baseunits/revision.inc')
$bin = Join-Path $root 'bin/x86_64-win64'
New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item (Join-Path $root 'dist/x86_64-win64/*') -Destination $bin -Force

function Compile($project, $log) {
    & $lazbuild @common --build-all --build-mode=Win64 $project *> $log
    if ($LASTEXITCODE) { Get-Content -LiteralPath $log -Tail 35; throw "Build failed: $project" }
}

if (!$TestsOnly) {
    # Never let upstream's revision batch overwrite the source-snapshot metadata.
    # A generated project preserves every compiler option and package dependency.
    [xml]$main = Get-Content (Join-Path $root 'mangadownloader/md.lpi')
    foreach ($hook in @($main.SelectNodes('//ExecuteBefore|//ExecuteAfter'))) { $hook.ParentNode.RemoveChild($hook) | Out-Null }
    $mainProject = Join-Path $root 'mangadownloader/motion-build.lpi'
    $main.Save($mainProject)
    Compile $mainProject (Join-Path $BuildRoot 'build.log')
    Compile (Join-Path $root 'updaterslim/updater.lpi') (Join-Path $BuildRoot 'updater-build.log')
}

[xml]$test = Get-Content (Join-Path $root 'mangadownloader/md.lpi')
$test.CONFIG.ProjectOptions.Units.Unit0.Filename.Value = '..\motion\tests\native.lpr'
foreach ($target in $test.SelectNodes('//Target/Filename')) { $target.SetAttribute('Value','..\bin\$(TargetCPU)-$(TargetOS)\motion-tests') }
foreach ($graphic in $test.SelectNodes('//GraphicApplication')) { $graphic.SetAttribute('Value','False') }
foreach ($hook in @($test.SelectNodes('//ExecuteBefore|//ExecuteAfter'))) { $hook.ParentNode.RemoveChild($hook) | Out-Null }
$testProject = Join-Path $root 'mangadownloader/motion-tests.lpi'
$test.Save($testProject)
Compile $testProject (Join-Path $BuildRoot 'native-build.log')
if (!(Test-Path -LiteralPath (Join-Path $root 'motion/tests/fixtures/animated.avif'))) { throw 'Generate fixtures with motion/tests/generate-fixtures.py first.' }
$arguments = @($root)
if ($LiveHTML) { $arguments += (Resolve-Path -LiteralPath $LiveHTML).Path }
& (Join-Path $bin 'motion-tests.exe') @arguments | Tee-Object -FilePath (Join-Path $BuildRoot 'native-tests.log')
if ($LASTEXITCODE) { throw 'Native tests failed' }
Write-Output "Windows build and native tests passed: $bin"
