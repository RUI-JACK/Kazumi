param(
    [string]$DartDefineFile = (Join-Path $env:LOCALAPPDATA 'kirakira-build\dandan-credentials.json'),
    [switch]$ConfigurationOnly
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $DartDefineFile -PathType Leaf)) {
    throw 'Danmaku credentials file missing. Provide -DartDefineFile with your approved DANDANAPI_APPID and DANDANAPI_KEY.'
}
$credentials = Get-Content -LiteralPath $DartDefineFile -Raw | ConvertFrom-Json
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
