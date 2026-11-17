# FMD2 Motion source kit

`FMD2/` contains the complete modified FMD2 source, original license and GitHub workflows. `dependency-sources/` contains the third-party source archives used to build it. No personal settings, accounts, manga chapters, downloaded sample pages or browser profiles are included.

The original program is GPLv2. Modification sources use GPL-2.0-or-later where indicated. Keep the original and third-party notices when redistributing. Dependencies retain their own license files inside their archives. Compiler and test tools are not part of the runtime program.

To build from this snapshot, use `FMD2/motion/BUILDING.md`. `Bootstrap.ps1` can fetch the pinned toolchain and dependency revisions. Alternatively, extract each dependency archive into a folder named after the archive, supply the resulting parent directory to `Build.ps1 -DependenciesDir`, and copy FLRE/PUCU as described in the build guide. A separately installed Lazarus 4.8 can be supplied with `-LazarusDir`.

To recreate a history-preserving fork from the original baseline:

```powershell
git clone https://github.com/dazedcat19/FMD2.git FMD2-Motion
git -C FMD2-Motion switch -c motion-manga 2.0.34.5
git -C FMD2-Motion apply --binary ../motion-changes.patch
git -C FMD2-Motion add .
git -C FMD2-Motion commit -m "Add original-media motion manga support and offline reader"
git -C FMD2-Motion remote rename origin upstream
```

Configure your Git author identity before committing. Then create a GitHub fork, add it as `origin`, and push `motion-manga`. No remote fork is created just by extracting this source kit. See `FMD2/motion/UPDATES.md` for synchronization, conflicts, release drafts and the protected update channel.
