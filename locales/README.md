# BJM local multilingual foundation — Phase 1

English root HTML is the source/master. No translations are included yet.
URL directories: `fr`, `de`, `zh`, `ja`. HTML/hreflang codes: `fr`, `de`,
`zh-CN`, `ja`; English `en` stays at root and is x-default.

Catalogs contain `schemaVersion`, `language`, `directory`, `shared`, and `pages`.
`shared` is an array of exact replacement objects: `from`, `to`, `count`.
`pages` maps an existing English filename to an object with:

```json
{
  "ready": false,
  "sourceHash": "",
  "sourceTitle": "",
  "sourceDescription": "",
  "title": "",
  "description": "",
  "replacements": []
}
```

Do not mark a page ready until all its visible copy, shared navigation/footer,
metadata, language-dependent accessibility labels and dynamic UI strings have
approved translations. Replacements can target exact HTML/text/attribute or JS
string fragments. Preserve tags, classes, business facts, URLs and structure.
Use complete fragments when the same words occur in multiple contexts; `count`
is required and generation fails if the English source no longer matches.
Encode translated text/attribute HTML correctly (`&amp;`, `&quot;`, etc.).
Title and description are plain strings, escaped by the generator.

From the project directory:

```powershell
powershell -NoProfile -File scripts/generate-locales.ps1 -CheckOnly
powershell -NoProfile -File scripts/generate-locales.ps1
powershell -NoProfile -File scripts/generate-locales.ps1 -Locale fr -Page index.html -CheckOnly
powershell -NoProfile -File scripts/generate-locales.ps1 -Locale fr -Page index.html
```

No locale/page arguments: refresh only `locales/availability.json` from approved
pages on disk. Locale/page arguments: validate and generate only that page.
CheckOnly never writes files. Empty/not-ready catalog pages cannot be generated.
No mass-generation command is provided.

Output is static HTML, readable without JavaScript. Asset URLs are root-relative;
links to translated equivalents use the locale directory, while unavailable
equivalents go to the English page. Fragment-only links stay on the current page.
CSS URLs and srcset assets are handled too. JavaScript-generated relative URLs,
JSON-LD language-dependent content and additional metadata require explicit
catalog replacements and review; there is no automatic JS translation.

The switcher uses availability.json for the current equivalent filename. A missing
translation remains disabled (no forced homepage fallback or broken link).
English is available for every existing root HTML file. No preference storage or
browser-language redirects are added. Query strings and fragments are preserved.

Generated pages have self canonical, translated description/Open Graph metadata,
and hreflang for English, themselves and approved existing equivalents; English
is x-default. No nonexistent language is advertised. Phase 1 does NOT rewrite
English HTML or sitemap.xml. Before exposing approved translations publicly, add
reciprocal hreflang to English/other equivalents and real localized sitemap
entries together, and regenerate affected equivalents. This publishing/SEO step
is not performed by Phase 1. Never add sitemap URLs for missing pages.

Use `/fr/index.html` locally. `server.ps1` adds the JSON MIME type so the selector
can read availability.json; it does not map `/fr/` to its index automatically.
Assets/API behavior is otherwise unchanged. Restart the local server after this update.

Next: add ONLY `pages.index.html` and approved shared/homepage replacements to
`fr.json`, validate with CheckOnly, then generate that one page and visually
check desktop/mobile, paths, equivalents, accessibility and metadata locally.
French is not enabled until its ready page actually exists.

## English source tracking

Validate all catalogs without writing anything:

```powershell
powershell -NoProfile -File scripts/generate-locales.ps1 -CheckOnly
powershell -NoProfile -File scripts/generate-locales.ps1 -Locale fr -Page index.html -CheckOnly
```

Each replacement's existing `from` is its exact approved English snapshot, with
`count` the expected occurrence count. Add a stable `key` (for example
`hero.heading`) to identify it in reports; otherwise its array position is used.
Title and description retain their plain translated strings; `sourceTitle` and
`sourceDescription` store the corresponding decoded English metadata snapshots.
`sourceHash` stores the English master file's SHA-256 at manual approval:

```powershell
(Get-FileHash -LiteralPath index.html -Algorithm SHA256).Hash
```

CURRENT means the translated value exists and its English snapshot still matches.
OUTDATED / NEEDS REVIEW identifies the locale/page/key when the snapshot/count
differs or is missing. MISSING identifies absent pages/translated values or an
unapproved page. Reports include individual entries and a page fingerprint; a
matching entry can remain CURRENT while the page needs review elsewhere.
The whole-file hash catches additions outside mapped entries too. It is deliberately
conservative: markup, whitespace, or layout-only edits also require page review.

Generation requires every status for the requested page to be CURRENT and ready.
Otherwise it stops before writing the localized page or availability manifest;
existing translations and previously generated output are left untouched.
Targeted CheckOnly reports all states without generation. All-catalog validation
reports missing pages normally and fails if any existing translation needs review.
No command updates translations or snapshots automatically. After reviewing the
English change, manually update the affected translations, their snapshots/counts,
and the page sourceHash, then validate and regenerate only that page. Never refresh
the hash merely to bypass review. Unmapped content still requires manual completeness
review before marking a page ready; this is source tracking, not translation discovery.
