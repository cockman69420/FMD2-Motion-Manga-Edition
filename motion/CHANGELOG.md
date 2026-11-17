# FMD2 Motion Manga Edition 0.1.0

Based on official FMD2 2.0.34.5.

- Recognize original AVIF/AVIF sequences, MP4 and WebM alongside existing images.
- Preserve animated WebP, GIF and APNG instead of flattening through still-image conversion.
- Save every MangaDistrict page in its original format through an isolated site module and native Lua helper.
- Select one media resource per page, handle lazy images/picture/video, retain ordering and reject incomplete chapters.
- Use original-media CBZ for motion chapters when PDF/EPUB is selected.
- Add an offline browser reader to the existing download context menu. Supports folders, stored/DEFLATE CBZ, natural chapter order and animated media.
- Protect motion modules from updater deletion/overwrite. Block official binary replacement and require a SHA-256-verified Motion release package.
- Supply pinned Windows builds, native/offline regression tests, scheduled upstream review branches and conflict reports.

The project is a usable first release with explicit test limits in `TEST-REPORT.md`. Hosted GitHub automation is prepared but not yet activated in a user repository. Windows 10 and Windows 11 have not both received a separate full GUI regression test.
