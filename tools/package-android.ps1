param(
    [string]$DartDefineFile = (Join-Path $env:LOCALAPPDATA 'kirakira-build\dandan-credentials.json'),
    [string]$SigningFile = (Join-Path $env:LOCALAPPDATA 'kirakira-build\android-signing.json'),
    [switch]$IncludeEmulator
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not $env:ANDROID_HOME -or -not $env:JAVA_HOME) {
    throw 'Set ANDROID_HOME and JAVA_HOME to the local Android SDK and JDK first.'
}
& (Join-Path $PSScriptRoot 'check-danmaku-access.ps1') -DartDefineFile $DartDefineFile -ConfigurationOnly
$DartDefineFile = (Resolve-Path -LiteralPath $DartDefineFile).Path
$SigningFile = (Resolve-Path -LiteralPath $SigningFile).Path
$signing = Get-Content -LiteralPath $SigningFile -Raw | ConvertFrom-Json
foreach ($field in @('storeFile','storePassword','keyAlias','keyPassword')) {
    if (-not $signing.$field) { throw "Missing Android signing field: $field" }
}
if (-not (Test-Path -LiteralPath $signing.storeFile)) { throw 'Private Android signing key not found.' }
$env:KIRAKIRA_ANDROID_SIGNING_FILE = $SigningFile
$targets = 'android-arm64'
if ($IncludeEmulator) { $targets += ',android-x64' }
$flutterCommand = Get-Command flutter -ErrorAction Stop
# A normal release build refreshes plugin registration and excludes dev plugins.
& $flutterCommand.Source build apk --release --split-per-abi "--target-platform=$targets" "--dart-define-from-file=$DartDefineFile"
if ($LASTEXITCODE -ne 0) { throw 'Android release build failed.' }
$version = (Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
$outputDir = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$displayName = -join (0x30AD,0x30E9,0x30AD,0x30E9 | ForEach-Object { [char]$_ })
foreach ($abi in @('arm64-v8a','x86_64')) {
    if ($abi -eq 'x86_64' -and -not $IncludeEmulator) { continue }
    $apk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$abi-release.apk"
    if (-not (Test-Path -LiteralPath $apk)) { throw "Expected APK missing: $abi" }
    $destination = Join-Path $outputDir "${displayName}-${version}-android-$abi.apk"
    Copy-Item -LiteralPath $apk -Destination $destination -Force
    Get-FileHash -LiteralPath $destination -Algorithm SHA256
}
Write-Host 'Danmaku credentials were injected; live approval is a separate check.'
