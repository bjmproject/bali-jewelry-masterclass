$ErrorActionPreference = 'Stop'

# Load the local .env value only when the process environment does not already
# provide a token. The file is intentionally not logged or returned to clients.
$tokenName = 'INSTAGRAM_ACCESS_TOKEN'
$envFile = Join-Path $PSScriptRoot '.env'
if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($tokenName, 'Process')) -and (Test-Path -LiteralPath $envFile)) {
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match '^\s*INSTAGRAM_ACCESS_TOKEN\s*=\s*(.*?)\s*$') {
            $tokenValue = $Matches[1]
            if ($tokenValue.Length -ge 2 -and (($tokenValue.StartsWith('"') -and $tokenValue.EndsWith('"')) -or ($tokenValue.StartsWith("'") -and $tokenValue.EndsWith("'")))) {
                $tokenValue = $tokenValue.Substring(1, $tokenValue.Length - 2)
            }
            [Environment]::SetEnvironmentVariable($tokenName, $tokenValue, 'Process')
            break
        }
    }
}

function Send-JsonResponse {
    param(
        [Parameter(Mandatory = $true)] $Context,
        [Parameter(Mandatory = $true)] [int] $StatusCode,
        [Parameter(Mandatory = $true)] $Payload
    )

    $json = ConvertTo-Json -InputObject $Payload -Depth 8 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = 'application/json; charset=utf-8'
    $Context.Response.Headers['Cache-Control'] = 'no-store'
    $Context.Response.ContentLength64 = $bytes.Length
    $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $Context.Response.Close()
}

function Send-StaticFileResponse {
    param(
        [Parameter(Mandatory = $true)] $Context,
        [Parameter(Mandatory = $true)] [int] $StatusCode,
        [Parameter(Mandatory = $true)] [string] $ContentType,
        [byte[]] $Bytes = @()
    )

    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = $ContentType
    $Context.Response.Headers['Cache-Control'] = 'no-store'
    $Context.Response.ContentLength64 = $Bytes.Length
    if ($Context.Request.HttpMethod -ne 'HEAD' -and $Bytes.Length -gt 0) {
        $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    }
    $Context.Response.Close()
}

$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add('http://127.0.0.1:4173/')

try {
    $listener.Start()
    Write-Host 'BJM local API listening at http://127.0.0.1:4173/'
    Write-Host 'Instagram endpoint: http://127.0.0.1:4173/api/instagram'
    Write-Host 'Press Ctrl+C to stop.'

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            if ($context.Request.Url.AbsolutePath -ne '/api/instagram') {
                if ($context.Request.HttpMethod -notin @('GET', 'HEAD')) {
                    $context.Response.Headers['Allow'] = 'GET, HEAD'
                    Send-JsonResponse -Context $context -StatusCode 405 -Payload @{ error = 'Method not allowed.' }
                    continue
                }

                $requestedPath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath)
                if ($requestedPath -eq '/') { $requestedPath = '/index.html' }
                $pathParts = @($requestedPath.TrimStart('/') -split '/')
                $hasHiddenSegment = @($pathParts | Where-Object { $_.StartsWith('.') }).Count -gt 0
                $extension = [IO.Path]::GetExtension($requestedPath).ToLowerInvariant()
                $contentTypes = @{
                    '.css' = 'text/css; charset=utf-8'
                    '.gif' = 'image/gif'
                    '.html' = 'text/html; charset=utf-8'
                    '.ico' = 'image/x-icon'
                    '.jpeg' = 'image/jpeg'
                    '.jpg' = 'image/jpeg'
                    '.js' = 'text/javascript; charset=utf-8'
                    '.json' = 'application/json; charset=utf-8'
                    '.png' = 'image/png'
                    '.svg' = 'image/svg+xml'
                    '.txt' = 'text/plain; charset=utf-8'
                    '.webp' = 'image/webp'
                    '.woff' = 'font/woff'
                    '.woff2' = 'font/woff2'
                    '.xml' = 'application/xml; charset=utf-8'
                }

                if ($hasHiddenSegment -or -not $contentTypes.ContainsKey($extension)) {
                    Send-StaticFileResponse -Context $context -StatusCode 404 -ContentType 'text/plain; charset=utf-8'
                    continue
                }

                $siteRoot = [IO.Path]::GetFullPath($PSScriptRoot)
                $rootPrefix = $siteRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
                $filePath = [IO.Path]::GetFullPath((Join-Path $siteRoot ($requestedPath.TrimStart('/') -replace '/', [IO.Path]::DirectorySeparatorChar)))
                if (-not $filePath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                    Send-StaticFileResponse -Context $context -StatusCode 404 -ContentType 'text/plain; charset=utf-8'
                    continue
                }

                $fileBytes = [IO.File]::ReadAllBytes($filePath)
                Send-StaticFileResponse -Context $context -StatusCode 200 -ContentType $contentTypes[$extension] -Bytes $fileBytes
                continue
            }

            if ($context.Request.HttpMethod -ne 'GET') {
                $context.Response.Headers['Allow'] = 'GET'
                Send-JsonResponse -Context $context -StatusCode 405 -Payload @{ error = 'Method not allowed.' }
                continue
            }

            $accessToken = [Environment]::GetEnvironmentVariable($tokenName, 'Process')
            if ([string]::IsNullOrWhiteSpace($accessToken)) {
                Send-JsonResponse -Context $context -StatusCode 503 -Payload @{ error = 'Instagram feed is not configured.' }
                continue
            }

            $query = [Uri]::EscapeDataString('id,media_type,media_url,thumbnail_url,permalink,timestamp')
            $encodedToken = [Uri]::EscapeDataString($accessToken)
            $uri = "https://graph.instagram.com/me/media?fields=$query&limit=24&access_token=$encodedToken"

            try {
                $graphResponse = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 20 -ErrorAction Stop
                $items = @(
                    foreach ($item in @($graphResponse.data) | Select-Object -First 24) {
                        [PSCustomObject]@{
                            id            = $item.id
                            media_type    = $item.media_type
                            media_url     = $item.media_url
                            thumbnail_url = $item.thumbnail_url
                            permalink     = $item.permalink
                            timestamp     = $item.timestamp
                        }
                    }
                )
                Send-JsonResponse -Context $context -StatusCode 200 -Payload @{ data = $items }
            }
            catch {
                # Do not include upstream error details; some providers echo request data.
                Send-JsonResponse -Context $context -StatusCode 502 -Payload @{ error = 'Unable to fetch Instagram media.' }
            }
        }
        catch {
            if ($context.Response -and $context.Response.OutputStream.CanWrite) {
                try { Send-JsonResponse -Context $context -StatusCode 500 -Payload @{ error = 'The local API encountered an error.' } } catch { }
            }
        }
    }
}
finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}
