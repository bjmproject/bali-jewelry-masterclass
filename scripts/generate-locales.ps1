param(
    [ValidateSet('fr', 'de', 'zh', 'ja')] [string] $Locale,
    [string] $Page,
    [switch] $CheckOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$utf8 = [Text.UTF8Encoding]::new($false)
$languages = [ordered]@{ en = ''; fr = 'fr'; de = 'de'; 'zh-CN' = 'zh'; ja = 'ja' }
$catalogs = @{}
foreach ($directory in @('fr', 'de', 'zh', 'ja')) {
    $catalog = Get-Content -LiteralPath (Join-Path $root "locales/$directory.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($catalog.schemaVersion -ne 1 -or $catalog.directory -ne $directory -or $languages[$catalog.language] -ne $directory) { throw "Invalid catalog: $directory" }
    $catalogs[$directory] = $catalog
}
$manifest = [ordered]@{ schemaVersion = 1; languages = $languages; pages = [ordered]@{} }
foreach ($file in Get-ChildItem -LiteralPath $root -File -Filter '*.html') {
    $manifest.pages[$file.Name] = [ordered]@{ en = '/' + $(if ($file.Name -eq 'index.html') { '' } else { $file.Name }) }
}
# Only explicitly approved pages already on disk are available to the switcher.
foreach ($directory in $catalogs.Keys) {
    $catalog = $catalogs[$directory]
    foreach ($property in $catalog.pages.PSObject.Properties) {
        if ($property.Value.ready -eq $true -and $manifest.pages.Contains($property.Name) -and (Test-Path -LiteralPath (Join-Path $root "$directory/$($property.Name)"))) {
            $manifest.pages[$property.Name][$catalog.language] = "/$directory/$($property.Name)"
        }
    }
}
function Apply-Replacements([string] $html, $replacements) {
    foreach ($entry in $replacements) {
        if ([string]::IsNullOrEmpty($entry.from) -or $null -eq $entry.to -or $null -eq $entry.count) { throw 'Replacement requires from, to, count.' }
        $count = [regex]::Matches($html, [regex]::Escape([string]$entry.from)).Count
        if ($count -ne [int]$entry.count) { throw "Source mismatch: expected $($entry.count), found $count for $($entry.from)" }
        $html = $html.Replace([string]$entry.from, [string]$entry.to)
    }
    return $html
}
function Get-TranslationStatus([string] $directory, [string] $filename) {
    $catalog = $catalogs[$directory]
    $property = $catalog.pages.PSObject.Properties[$filename]
    $prefix = "$directory/$filename"
    if (!$property) { return "MISSING | $prefix | page" }
    $translation = $property.Value
    $sourcePath = Join-Path $root $filename
    if (!(Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        return "OUTDATED / NEEDS REVIEW | $prefix | source page removed"
    }
    $source = [IO.File]::ReadAllText($sourcePath)
    # A page-wide approval fingerprint also catches new/unmapped English copy.
    $hash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if (!$translation.sourceHash -or $translation.sourceHash -ine $hash) {
        "OUTDATED / NEEDS REVIEW | $prefix | sourceHash (English page changed or approval snapshot missing)"
    } else { "CURRENT | $prefix | sourceHash" }
    foreach ($name in @('title', 'description')) {
        $pattern = if ($name -eq 'title') { '(?s)<title>(.*?)</title>' } else { '<meta\b[^>]*name="description"[^>]*content="([^"]*)"[^>]*>' }
        $match = [regex]::Match($source, $pattern)
        $english = if ($match.Success) { [Net.WebUtility]::HtmlDecode($match.Groups[1].Value) } else { '' }
        $snapshot = $translation.PSObject.Properties['source' + [char]::ToUpper($name[0]) + $name.Substring(1)]
        if ([string]::IsNullOrWhiteSpace($translation.$name)) {
            "MISSING | $prefix | $name"
        } elseif (!$snapshot -or [string]$snapshot.Value -cne $english) {
            "OUTDATED / NEEDS REVIEW | $prefix | $name (English metadata changed or snapshot missing)"
        } else { "CURRENT | $prefix | $name" }
    }
    foreach ($group in @('shared', 'replacements')) {
        $entries = if ($group -eq 'shared') { @($catalog.shared) } else { @($translation.replacements) }
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $replacement = $entries[$i]
            $key = if ($replacement.key) { $replacement.key } else { "$group[$i]" }
            if ([string]::IsNullOrEmpty($replacement.to)) {
                "MISSING | $prefix | $key"
            } elseif ([string]::IsNullOrEmpty($replacement.from) -or $null -eq $replacement.count -or [int]$replacement.count -lt 1 -or [regex]::Matches($source, [regex]::Escape([string]$replacement.from)).Count -ne [int]$replacement.count) {
                "OUTDATED / NEEDS REVIEW | $prefix | $key (English source snapshot/count no longer matches)"
            } else { "CURRENT | $prefix | $key" }
        }
    }
    if ($translation.ready -ne $true) { "MISSING | $prefix | ready (translation not approved)" }
}
if (!$Locale -and !$Page) {
    $reports = @(foreach ($directory in @('fr', 'de', 'zh', 'ja')) {
        $filenames = @($manifest.pages.Keys) + @($catalogs[$directory].pages.PSObject.Properties.Name)
        foreach ($filename in ($filenames | Where-Object { $_ } | Sort-Object -Unique)) { Get-TranslationStatus $directory $filename }
    })
    $reports | Write-Output
    if (@($reports | Where-Object { $_ -like 'OUTDATED*' }).Count) { throw 'OUTDATED / NEEDS REVIEW: manually review catalog entries before continuing. No files written.' }
}
if ($Locale -or $Page) {
    if (!$Locale -or !$Page -or $Page -notmatch '^[a-z0-9-]+\.html$' -or !$manifest.pages.Contains($Page)) { throw 'Specify a valid root HTML page and locale together.' }
    $catalog = $catalogs[$Locale]
    $reports = @(Get-TranslationStatus $Locale $Page)
    $reports | Write-Output
    $blocked = @($reports | Where-Object { $_ -notlike 'CURRENT*' })
    if ($blocked.Count) {
        if ($CheckOnly) { return }
        throw 'Translation is MISSING or OUTDATED / NEEDS REVIEW. No localized page or manifest written; manually review translations and source snapshots.'
    }
    $pageProperty = $catalog.pages.PSObject.Properties[$Page]
    if (!$pageProperty -or $pageProperty.Value.ready -ne $true) { throw "No approved ready translation for $Locale/$Page. No page generated." }
    $entry = $pageProperty.Value
    if ([string]::IsNullOrWhiteSpace($entry.title) -or [string]::IsNullOrWhiteSpace($entry.description)) { throw 'Translated title and description are required.' }
    $html = [IO.File]::ReadAllText((Join-Path $root $Page))
    $html = Apply-Replacements $html $catalog.shared
    $html = Apply-Replacements $html $entry.replacements
    $html = [regex]::Replace($html, '<html lang="en">', '<html lang="' + $catalog.language + '">')
    $html = [regex]::Replace($html, '(?s)<title>.*?</title>', '<title>' + [Net.WebUtility]::HtmlEncode($entry.title) + '</title>')
    $html = [regex]::Replace($html, '<meta\b[^>]*(?:name="description"|property="og:(?:url|title|description)")[^>]*>\s*', '')
    $html = [regex]::Replace($html, '<link\b[^>]*rel="(?:canonical|alternate)"[^>]*>\s*', '')
    $manifest.pages[$Page][$catalog.language] = "/$Locale/$Page"
    # HTML URLs: assets remain shared; unavailable page links stay on English.
    $html = [regex]::Replace($html, '(?<prefix>\b(?:href|src|poster|action)=")(?<url>[^"]+)(?<suffix>")', [Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $url = $m.Groups['url'].Value
        if ($url -match '^(?:[a-z][a-z0-9+.-]*:|//|#|/)' ) { return $m.Value }
        $parts = [regex]::Match($url, '^([^?#]+)(.*)$')
        $path = $parts.Groups[1].Value; $tail = $parts.Groups[2].Value
        if ($path -match '(^|/)\.\.?(/|$)') { throw "Unsafe relative path: $url" }
        if ($manifest.pages.Contains($path)) {
            $target = $manifest.pages[$path][$catalog.language]
            if (!$target) { $target = $manifest.pages[$path]['en'] }
        } else { $target = '/' + $path }
        return $m.Groups['prefix'].Value + $target + $tail + '"'
    })
    # CSS image/font references inside inline styles also use shared root assets.
    $html = [regex]::Replace($html, 'url\(\s*(?:(?<quote>["''])(?<url>.*?)\k<quote>|(?<url>[^)\s]+))\s*\)', [Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $url = $m.Groups['url'].Value.Trim()
        if ($url -match '^(?:[a-z][a-z0-9+.-]*:|//|#|/)') { return $m.Value }
        return 'url(' + $m.Groups['quote'].Value + '/' + $url + $m.Groups['quote'].Value + ')'
    })
    $html = [regex]::Replace($html, '\bsrcset="([^"]+)"', [Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $candidates = foreach ($candidate in ($m.Groups[1].Value -split ',')) {
            $value = $candidate.Trim()
            if ($value -notmatch '^(?:[a-z][a-z0-9+.-]*:|//|/)') { $value = '/' + $value }
            $value
        }
        return 'srcset="' + ($candidates -join ', ') + '"'
    })
    $base = 'https://balijewelrymasterclass.com'
    $canonical = $base + $manifest.pages[$Page][$catalog.language]
    $seo = '<meta name="description" content="' + [Net.WebUtility]::HtmlEncode($entry.description) + '">' + "`n"
    $seo += '<link rel="canonical" href="' + $canonical + '">' + "`n"
    $seo += '<meta property="og:url" content="' + $canonical + '">' + "`n"
    $seo += '<meta property="og:title" content="' + [Net.WebUtility]::HtmlEncode($entry.title) + '">' + "`n"
    $seo += '<meta property="og:description" content="' + [Net.WebUtility]::HtmlEncode($entry.description) + '">' + "`n"
    foreach ($code in $manifest.pages[$Page].Keys) { $seo += '<link rel="alternate" hreflang="' + $code + '" href="' + $base + $manifest.pages[$Page][$code] + '">' + "`n" }
    $seo += '<link rel="alternate" hreflang="x-default" href="' + $base + $manifest.pages[$Page]['en'] + '">' + "`n"
    $html = $html.Replace('</head>', $seo + '</head>')
    if (!$CheckOnly) {
        $directory = Join-Path $root $Locale
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        [IO.File]::WriteAllText((Join-Path $directory $Page), $html, $utf8)
    }
    Write-Output "Validated $Locale/$Page (check only: $CheckOnly)"
}
if (!$CheckOnly) { [IO.File]::WriteAllText((Join-Path $root 'locales/availability.json'), ($manifest | ConvertTo-Json -Depth 12), $utf8) }
Write-Output 'Catalogs and availability validated. English master HTML is never modified.'
