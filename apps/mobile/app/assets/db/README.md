# Bundled read-only databases

## quran_index.sqlite

The 6,236-row ayah index (surah, ayah, juz, hizb, page, line, word count) that
makes range → page/line/juz math work offline. Generate it once with the seed
script in `packages/db`, then drop the file here. It is read-only at runtime and
is opened directly from the asset bundle — never migrated by Drift.

Not committed as a binary blob by default; regenerate or fetch it during CI.
