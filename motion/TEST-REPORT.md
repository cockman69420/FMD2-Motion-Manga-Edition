# Testresultater — FMD2 Motion Manga Edition 0.1.0

Dato: 17. november 2026. Baseline: FMD2 2.0.34.5, `64fe87d04a0bf6ff371d79f3575e10e8d55d7f77`. Windows 10 x64 build 19045, Lazarus 4.8 og FPC 3.2.2. Testbrowser: Chromium 151.0.7922.34, Playwright 1.62.1.

## Gennemført

| Område | Resultat |
|---|---|
| Windows-program | FMD2 x64 kompileret fra den modificerede kildekode |
| Opdateringsprogram | Updater x64 kompileret fra den medfølgende kildekode |
| Native tests | 82 kontroller bestået med gemt live-HTML; filgenkendelse, uændrede bytes, timingdata, almindelig PNG/WebP-konvertering, PDF/CBZ, Lua/XPath og SHA-256-politik |
| Offline-browser | 17 kontroller bestået; synligt forskellige frames fra AVIF/WebP/GIF/APNG/MP4/WebM, original billedbredde, CBZ uden/med DEFLATE, CRC-fejl, mapper og kapitelskift |
| Netværksfri læsning | Browserens netværk deaktiveret; 0 HTTP(S)-forespørgsler og 0 JavaScript-fejl under testen |
| Faktiske AVIF-filer offline | Alle 5 AVIF-filer fra live-kapitlet afspillede bevægelse i læseren med netværk deaktiveret. Hver fil viste 7–8 forskellige frames i 8 stikprøver fra browserens renderede output. Ingen kapitelbilleder blev gemt som testskærmbilleder |
| Programstart | Den udpakkede FMD2-pakke blev startet skjult, svarede, oprettede de tre eksisterende bruger-databaser og accepterede normal lukning. Dette var en opstartstest, ikke visuel kontrol af alle menuer |
| Upstream-synkronisering | 2 kontroller bestået med lokale repositories: ren merge bevarer tilpasning; konflikt registreres, mergen afbrydes, tilpasningen bevares |
| Reel MangaDistrict-download | Første kapitel i brugerens serie: 44 sider, 5 animerede AVIF-filer, 59.373.040 originalbytes. Downloadet med FMD2's HTTP/Lua-kode og gemt via original-media-bindingen. Alle sider matchede originalbytes, også efter CBZ-pakning og udpakning |

Native tests kontrollerer også AVIF-brand i kompatibilitetslisten, `avis`-sekvenser, tomme/afkortede data, HTML-fejlsider, Matroska som ikke er WebM, APNG efter over 64 KB metadata, manglende kontrolsum, forkert SHA-256, officielle binærpakker og en domæneadresse der ligner GitHub.

## Live-testgrundlag

Der er testet det første kapitel fra brugerens angivne offentlige MangaDistrict-link med `?style=list`. Det konkrete serielink er ikke indbygget i den publicerbare kildekode. En ny live-test tager serien fra `MOTION_LIVE_SERIES_URL`.

De fem AVIF-filer havde henholdsvis 128, 128, 97, 160 og 128 frames. Bredde: 1440 pixels; højder: 2876, 2696, 3376, 3820 og 3484 pixels. Format og frameantal er aflæst fra filmetadata. Bevaringskontrollen sammenlignede hele filindholdet; der er ikke konverteret frames eller genskabt tidsstempler. Kvaliteten kan derfor ikke være forringet af download- eller arkiveringskoden i den gennemførte test.

Det er et afprøvet kapitel, ikke en garanti for alle kapitler eller fremtidige ændringer på hjemmesiden. Browserens billeddekoder kan vælge at springe frames over under belastning, selv om filernes originale timingdata er bevaret.

## Ikke verificeret fuldt ud

- Windows 11-test og fuld Windows 10/11-testmatrix samt 32-bit-build.
- Systematisk visuel regressionstest af hele FMD2's brugerflade.
- Samtlige websites, favoritscenarier, konti og indstillingskombinationer. Databaseskemaer og de eksisterende funktioners implementering er ikke ændret.
- GitHub-hostede workflows, online PR-/issue-oprettelse og udgivelse: kræver et tilsluttet repository. De lokale build- og merge-scripts er kørt.
- Automatisk installation af en fremtidig release over en rigtig brugerinstallation. URL- og kontrolsumspolitikken er testet; der er ikke publiceret en opdateringspakke til at gennemføre en sådan ende-til-ende-test.
- HLS/DASH, DRM, andre video-containere, forældede browsere, ZIP64 og adgangskodebeskyttede arkiver. Pak store/ZIP64-arkiver ud og åbn mappen.

Læseren er åbnet fra FMD2 og afspiller i browseren. Den er ikke en indlejret native WebView. Almindelige PDF-eksporter er bevaret; motion-kapitler går bevidst til CBZ, fordi PDF/den eksisterende EPUB-eksport ikke kan bevare animationerne.

## Filer med evidens

Leverancens separate testmappe indeholder bygge-/testlogfiler, browserens JSON-resultat, neutrale skærmbilleder af læseren og kontrolsummer. Kapitelbilleder og private brugerdata følger ikke med distributionspakkerne.

Kilder: officiel FMD2-kildekode https://github.com/dazedcat19/FMD2, AVIF-formatet https://aomedia.org/docs/AV1%20Image%20File%20Format%20%28AVIF%29%20v1.2.0.pdf, browserformater https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types og Edge-formatunderstøttelse https://learn.microsoft.com/en-us/microsoft-edge/web-platform/site-impacting-changes.
