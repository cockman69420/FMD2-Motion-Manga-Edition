# FMD2 Motion Manga Edition 0.1.0

Windows x64 · baseret på FMD2 2.0.34.5 · 17. november 2026

## Kom i gang

1. Pak hele Windows-ZIP-filen ud i en ny mappe, eksempelvis `Dokumenter\FMD2-Motion`. Kør programmet fra den udpakkede mappe.
2. Start `fmd.exe`. Der kræves ikke Python, .NET eller Lazarus til at bruge programmet.
3. Vælg Manga District under de tilgængelige websites, og indsæt seriens link som i almindelig FMD2. Vælg og download kapitlerne.
4. Højreklik på downloadlisten, og vælg **Motion reader (offline)...**. Alternativt åbn `motion\reader.html` i en opdateret Edge eller Chrome.
5. Vælg **Åbn kapitel** i læseren, og åbn den downloadede CBZ. **Åbn mappe** kan åbne billeder eller flere kapitler fra en lokal mappe. `Demo-motion.cbz` indeholder en neutral testanimation.

Pakken er portabel og usigneret. Den installerer ingen tjenester og kræver ikke administratorrettigheder. Browseren skal allerede være installeret. Efter download fungerer læsning uden internet; selve hjemmesiden og mediefilerne hentes naturligvis online.

## Bevar din eksisterende FMD2

Luk både den gamle og nye FMD2, før du kopierer data. Tag først en kopi af din eksisterende FMD2-mappe. Kopiér derefter `userdata` og eventuelt `data` fra den gamle mappe til den nye Motion-mappe. `userdata` indeholder blandt andet favoritter, downloadkø, historik, indstillinger og konti. Databaserne får samme format som i FMD2 2.0.34.5.

Downloadede kapitler kan blive i deres nuværende mappe. Kontrollér gemmestierne: relative stier bliver fortolket i forhold til den nye programmappe. Kopiér ikke gamle programfiler eller den gamle `lua`-mappe oven i Motion-pakken. Kopiér ikke `config.json` oven i en senere udgave, der er tilknyttet fork'ens opdateringskanal.

Der er ikke foretaget ændringer i din eksisterende FMD2-installation. Rul tilbage ved at lukke Motion-versionen og starte den gamle installation.

## Formater og kvalitet

- Manga District gemmes med originalfilerne uændret, også hvis en generel PNG/WebP-konvertering er slået til.
- Animeret AVIF, WebP, GIF og APNG samt direkte MP4/WebM gemmes uden omkodning. Originale pixels, frames og timingdata bevares i filerne.
- CBZ er et ZIP-arkiv, og mediefilerne gemmes uden yderligere billedkomprimering. Traditionelle CBZ-læsere kan mangle animationsunderstøttelse; brug den medfølgende læser.
- Vælges PDF eller EPUB til et kapitel med beskyttede motion-formater, gemmes netop dette kapitel som CBZ. PDF kan ikke bevare denne animation. Den globale indstilling ændres ikke. Almindelig statisk manga kan stadig eksporteres til PDF.
- Læseren omkoder ikke. Browserens dekoder og computerens hastighed bestemmer afspilningen; tunge AVIF-animationer kan kræve betydelig hukommelse. Original størrelse kan vælges i læseren.

## Opdateringer

Almindelige website-moduler og databaseopdateringer beholder FMD2's officielle feeds. Motion-modulet beskyttes mod overskrivning og sletning. En officiel programopdatering blokeres, hvis den ville erstatte Motion-versionen.

GitHub-workflows til synkronisering, Windows-build og test følger med kildekoden. De er **ikke aktiveret på en GitHub-konto i denne levering**. Når fork'en er oprettet og forbundet, kan nye fork-pakker bruge en særskilt opdateringskanal med SHA-256-kontrol. Se `motion\UPDATES.md`.

## Kendte begrænsninger

Denne udgave er bygget og testet på Windows x64. Windows 10 og Windows 11 er målplatforme; der er ikke gennemført en separat fuld test på begge operativsystemer. Der leveres ikke en 32-bit-udgave.

Læsningen foregår i browseren, åbnet fra FMD2's menu. Der er ikke indlejret en browser direkte i FMD2-vinduet. MP4/WebM afhænger af browserens codecs. HLS/DASH, DRM, beskyttede streamingtjenester og interaktive hjemmesider arkiveres ikke. Ukendte medieformater og tomme kapitler meldes som fejl frem for at blive registreret som fuldførte kapitler.

Der er lavet en reel downloadtest af første kapitel i den angivne MangaDistrict-serie og automatiske regressionstests. Alle websites, alle eksisterende indstillinger og hele den grafiske brugerflade er ikke systematisk gennemtestet. Se testresultaterne i `motion\TEST-REPORT.md`.
