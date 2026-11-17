# Windows build

Requires Windows x64, PowerShell 7, Git, Python 3.12+ and Node.js 22 for development tests. The delivered application does not need these tools.

```powershell
./motion/scripts/Bootstrap.ps1
python -m pip install Pillow==13.0.0 imageio-ffmpeg==0.6.0
python motion/tests/generate-fixtures.py
./motion/scripts/Build.ps1
./motion/tests/sync-tests.ps1
npm install --prefix motion/tests --no-save --package-lock=false playwright@1.62.1
node motion/tests/node_modules/playwright/cli.js install chromium
node motion/tests/browser-tests.cjs
./motion/scripts/Package.ps1 -Destination .motion-build/package
```

Bootstrap downloads and extracts Lazarus 4.8/FPC 3.2.2 into `.motion-build`. It does not run an installer or change system-wide configuration. Archive hashes and Git dependency revisions are pinned in `dependencies.lock.json`. A changed upstream archive causes a hard failure until the lock is reviewed. No dependencies are silently upgraded.

An existing isolated toolchain can be used:

```powershell
./motion/scripts/Build.ps1 -LazarusDir C:/lazarus -DependenciesDir C:/fmd-deps -BuildRoot .motion-build
```

Dependencies are Synapse 40.1, InternetTools plus FLRE/PUCU, DCPCrypt, RichMemo, MultiLog, VirtualTreeViewV5, MetaDarkStyle and Lazarus_CustomControls, in addition to Lazarus' built-in packages. The supplied dependency-source archives contain the actual sources used. Copy `flre/src/FLRE.pas` and `pucu/src/PUCU.pas` into `internettools/data` before building with manually prepared dependencies.

The build script preserves the main project's compiler options, generates temporary project files and performs full rebuilds. Incremental compilation of this cyclic upstream project caused an internal FPC 3.2.2 error during development; full rebuilds succeeded. Generated project files, caches and fixture files are ignored by Git. Source identity is included in `baseunits/revision.inc` during the build.

Native tests call the actual FMD2 saver, CBZ/PDF packer, Lua runtime, XPath parser and motion helper. They deliberately enable still-image conversion and verify that motion data remains byte-identical while static PNG/WebP conversion still works. They test SHA-256 verification and update policy. Browser tests create a real browser context with networking disabled and inspect distinct rendered frames, rather than only checking that files exist.

Optional live test, using the user's supplied public series and the first chapter:

```powershell
$env:MOTION_LIVE_SERIES_URL = 'https://mangadistrict.com/series/your-series/'
./bin/x86_64-win64/motion-tests.exe (Get-Location).Path '' --live
```

It uses the actual FMD2 HTTP implementation, Lua site module, original-media saver and chapter packer. It saves private test assets under `bin/x86_64-win64/test-results`, not in distributable source or application packages. Live site tests are deliberately excluded from CI because sites and network access are external dependencies. Native tests can additionally accept a saved chapter HTML file as the second argument.

Only x64 was built. The original Win32 project modes are preserved but unverified. CI definitions are supplied, but hosted execution and release publication require a connected GitHub repository. Dependency pins make inputs auditable; builds are not claimed to be bit-for-bit reproducible.
