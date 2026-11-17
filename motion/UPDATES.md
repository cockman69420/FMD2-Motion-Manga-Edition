# Vedligeholdelse og officielle opdateringer

## Udgangspunkt

Original: https://github.com/dazedcat19/FMD2

Basistag: `2.0.34.5`, commit `64fe87d04a0bf6ff371d79f3575e10e8d55d7f77`.

Motion-version: `0.1.0.0` i `baseunits/MotionUpdatePolicy.pas`. Den oprindelige FMD-version beholdes i programressourcen. De to versionsnumre kontrolleres separat, så motion-rettelser også kan tilbydes, når FMD-versionen er uændret.

## Isolering og plugin-vurdering

Website-logikken ligger primært i `lua/motion/MangaDistrict.lua`. Den almindelige moduls ID beholdes, så eksisterende favoritter kan genfinde modulet. `lua/modules/MangaDistrict.lua` er en lille adapter til den oprindelige Madara-skabelon, motion-parseren og den nye `fmd.motion.SaveOriginal`-funktion.

En ren Lua-plugin var ikke tilstrækkelig: FMD2 2.0.34.5 genkender ikke AVIF/MP4/WebM som sidefiler. Selv hvis Lua gemte filerne, kunne genoptagelse og pakning overse dem. PDF/EPUB og WebP-konverteringen kunne desuden kassere animationer. Derfor består løsningen af et isoleret Lua-modul, to små Pascal-hjælpere, en Lua-binding og få indgreb i genkendelse, gemning, pakning og opdatering.

Læsning er en selvstændig, afhængighedsfri HTML-fil åbnet fra én ekstra FMD2-menuhandling. En indlejret WebView2-læser ville kræve ekstra komponenter, runtime-håndtering og flere ændringer i Lazarus-brugerfladen. Browserløsningen er implementeret og testet; indlejret WebView2 er ikke implementeret.

## Automatisk upstream-kontrol

`motion-upstream-sync.yml` kører dagligt kl. 03.37 UTC eller manuelt fra Actions:

1. Hent officiel `master` til en ren checkout af fork'ens standardbranch.
2. Hvis revisionen allerede er indeholdt, afslut uden ændringer.
3. Opret en separat `automation/upstream-...`-branch og foretag en almindelig Git-merge. Der bruges ikke force-push eller automatisk valg af upstream-filer.
4. Ved konflikt: registrér filstier i `sync-result.json`, opret en GitHub-issue, gem rapporten som Actions-artifact og afbryd mergen. Tilpasningerne bliver på standardbranchen.
5. Ved ren merge: opret en pull request og kald Windows-build og tests direkte som genbrugelig workflow. Det er nødvendigt, fordi ændringer oprettet med `GITHUB_TOKEN` ikke automatisk udløser en ny workflow-kørsel.
6. Ingen automatisk merge eller automatisk udskiftning af brugerens program. En vedligeholder gennemgår og accepterer ændringen efter grønne tests.

Tekstkonflikter er ikke den eneste risiko. En officiel ændring kan også introducere en ny konverteringsvej, som ikke rammer en konflikt. Gennemgå derfor især downloader, ImageMagick, pakning og Lua-API ved en opdatering. Den aktuelle baseline har ikke master-branchens nyere ImageMagick-pipeline; den skal have samme beskyttelse, når den integreres. Hele upstream-master er ikke på forhånd accepteret som kompatibel.

## Aktivér på GitHub

GitHub-forbindelsen er tilgængelig, men fjernfork'en er endnu ikke oprettet. Kildefork'en og workflows er klargjort lokalt. Oprettelsen af repository kræver også et browserlogin, fordi den tilsluttede GitHub-forbindelse ikke har en handling til at oprette repositories. Der er endnu ikke kørt GitHub-hostede Actions.

Opret en fork på den ønskede konto. Genskab Git-historikken fra den officielle repo og `motion-changes.patch` i kildepakken, eller publicér den allerede klargjorte lokale `motion-manga`-branch. Behold den officielle repo som remote `upstream`, og brug din egen fork som `origin`. Sæt Motion-branchen som standardbranch. I repo-indstillingerne skal Actions være aktiveret, og **Allow GitHub Actions to create and approve pull requests** skal tillade oprettelse af PR'er. GitHub-workflowet anmoder selv om de nødvendige repo-rettigheder. Brug branch-beskyttelse med krav om grønne tests.

## Udgivelser og opdateringskanal

1. Integrér og gennemgå ændringerne. Hæv `MOTION_VERSION` for en ny Motion-udgave; behold upstream-versionen fra det integrerede FMD-projekt.
2. Opret et tag, eksempelvis `motion-0.1.1`. Release-workflowet bygger, tester og opretter en **kladde** til en release med binærpakke, kildekode og `motion-latest.json`.
3. Kontrollér kladden og publicér releasen. Kildepakken indeholder også de fastlåste tredjepartskilder.
4. Pakker bygget med `Package.ps1 -Repository owner/repo` peger på `https://github.com/owner/repo/releases/latest/download/motion-latest.json`.

Manifestet indeholder både `version`, `motion_version`, downloadadresse, ændringslogadresse og SHA-256. Programmet accepterer kun HTTPS GitHub-releasepakker med navnet `fmd-motion_...` fra en anden repo end originalen og verificerer filens SHA-256 før lagring og genstart. Dette er integritetskontrol og beskyttelse mod utilsigtet overskrivning, ikke en digital signatur eller en garanti mod kompromittering af fork'ens konto.

I den lokalt leverede pakke bruges stadig det officielle feed til at opdage nyere upstream-versioner. Installationen af sådanne officielle binærpakker afvises. Man skal derfor installere en fremtidig, godkendt Motion-pakke manuelt første gang, eller angive fork'ens manifestadresse i `config.json`, når den findes. Website-moduler og databaser kan fortsat opdateres fra originalen. Motion-specifikke Lua-filer opdateres gennem fork-pakkerne.

## Lokal validering

`Sync-Upstream.ps1 -NoPublish` må kun køres i en ren, disponibel checkout. Den skifter branch og opretter en lokal merge-commit ved en ren merge. Ved konflikt afslutter den med kode 2 efter `git merge --abort`. Den sender ingen PR eller issue med `-NoPublish`.

`motion/tests/sync-tests.ps1` verificerer både en ren merge og en konflikt med syntetiske lokale repositories. Testen kontrollerer, at tilpasningen bevares, og at konfliktens sti bliver registreret.

GitHub-referencer: https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows og https://docs.github.com/en/actions/reference/security/secure-use.
