param(
    [string]$DartDefineFile = (Join-Path $env:LOCALAPPDATA 'kirakira-build\danmaku-credentials.json'),
    [switch]$ConfigurationOnly
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $DartDefineFile -PathType Leaf)) {
    throw 'Danmaku configuration missing. Provide -DartDefineFile with DANMAKU_API_BASE_URL, or approved DANDANAPI_APPID and DANDANAPI_KEY.'
}
$credentials = Get-Content -LiteralPath $DartDefineFile -Raw | ConvertFrom-Json
if ($credentials.DANMAKU_API_BASE_URL) {
    $baseUrl = [string]$credentials.DANMAKU_API_BASE_URL
    $uri = $null
    if (-not [Uri]::TryCreate($baseUrl, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $baseUrl -ne $baseUrl.Trim()) {
        throw 'Self-hosted danmaku requires a valid HTTPS base URL without query parameters or userinfo.'
    }
    if ($ConfigurationOnly) {
        Write-Output 'Self-hosted danmaku configuration is complete; no DanDanPlay credentials required.'
        return
    }
    try {
        $result = Invoke-RestMethod -Uri ($baseUrl.TrimEnd('/') + '/api/v2/search/anime?keyword=' + [Uri]::EscapeDataString('葬送的芙莉莲')) -TimeoutSec 120
    } catch {
        throw ('Self-hosted danmaku service check failed: ' + $_.Exception.GetType().Name)
    }
    if ($result.success -ne $true -or -not $result.animes) { throw 'Self-hosted danmaku service returned no valid search results.' }
    Write-Output 'Self-hosted danmaku authenticated search succeeded. Private endpoint was not logged.'
    return
}
$appId = [string]$credentials.DANDANAPI_APPID
$appSecret = [string]$credentials.DANDANAPI_KEY
if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($appSecret)) {
    throw 'Danmaku credentials are empty. Apply at https://dev.dandanplay.com/ and fill the local credentials file first.'
}
if ($appId -ne $appId.Trim() -or $appSecret -ne $appSecret.Trim()) {
    throw 'Remove leading or trailing whitespace from the credential values.'
}
if ($ConfigurationOnly) {
    Write-Output 'Danmaku configuration is complete; remote authentication has not been checked.'
    return
}

$apiPath = '/api/v2/bangumi/bgmtv/622288'
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString([Globalization.CultureInfo]::InvariantCulture)
$hash = [Security.Cryptography.SHA256]::Create()
try {
    $signature = [Convert]::ToBase64String($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($appId + $timestamp + $apiPath + $appSecret)))
} finally { $hash.Dispose() }
$headers = @{'X-AppId'=$appId; 'X-Timestamp'=$timestamp; 'X-Signature'=$signature}
try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri ('https://api.dandanplay.net' + $apiPath) -Headers $headers -UserAgent 'kirakira/2.3.9' -TimeoutSec 30
} catch {
    $serverResponse = $_.Exception.Response
    if (-not $serverResponse) { throw 'Danmaku validation failed before a response was received. Check network connectivity.' }
    $status = [int]$serverResponse.StatusCode
    $reason = ''
    if ($serverResponse -is [Net.HttpWebResponse]) {
        $reason = $serverResponse.Headers['X-Error-Message']
    } elseif ($serverResponse.Headers.Contains('X-Error-Message')) {
        $reason = ($serverResponse.Headers.GetValues('X-Error-Message') -join ', ')
    }
    $knownReasons = @('Missing Authentication Headers','Invalid Timestamp','Invalid AppId','Invalid Signature','Invalid AppSecret')
    if ($reason -notin $knownReasons) { $reason = 'Check application approval, permissions, or quota in the developer center.' }
    throw "Danmaku authentication failed (HTTP $status): $reason"
}
$data = $response.Content | ConvertFrom-Json
if ($data.success -ne $true -or -not $data.bangumi) {
    throw 'Danmaku API returned a business error. Check application status and quota before packaging.'
}
Write-Output 'Danmaku authentication and Bangumi lookup succeeded. Credential values were not logged.'
