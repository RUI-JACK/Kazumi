param(
    [ValidateSet('windows', 'android')]
    [string]$Platform = 'windows',
    [switch]$Msix,
    [switch]$Installer,
    [string]$DartDefineFile = (Join-Path $env:LOCALAPPDATA 'kirakira-build\danmaku-credentials.json')
)

$ErrorActionPreference = 'Stop'
$displayName = -join (0x30AD,0x30E9,0x30AD,0x30E9 | ForEach-Object { [char]$_ })
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
& (Join-Path $PSScriptRoot 'check-danmaku-access.ps1') -DartDefineFile $DartDefineFile -ConfigurationOnly
$DartDefineFile = (Resolve-Path -LiteralPath $DartDefineFile).Path
$buildDefines = @("--dart-define-from-file=$DartDefineFile")
$flutterCommand = Get-Command flutter -ErrorAction Stop
$versionMatch = Select-String -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)'
$appVersion = $versionMatch.Matches[0].Groups[1].Value
$outputDir = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

& $flutterCommand.Source pub get
if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency setup failed.' }

if ($Platform -eq 'android') {
    & $flutterCommand.Source build apk --release --split-per-abi @buildDefines
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    foreach ($abi in @('arm64-v8a', 'armeabi-v7a', 'x86_64')) {
        $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-$abi-release.apk"
        if (Test-Path -LiteralPath $apkPath) {
            Copy-Item -LiteralPath $apkPath -Destination (Join-Path $outputDir "${displayName}_android_${appVersion}_$abi.apk")
        }
    }
} else {
    # ech_http embeds a CA bundle larger than MSVC's string literal limit.
    # Configure only the native hook cache with clang-cl if MSVC cannot build it.
    $clangCompiler = Join-Path $env:ProgramFiles 'LLVM\bin\clang-cl.exe'
    $env:CL = (@($env:CL, '/utf-8') -join ' ').Trim()
    & $flutterCommand.Source build windows --release @buildDefines
    if ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath $clangCompiler)) {
        & (Join-Path $PSScriptRoot 'prepare-windows-native.ps1') -ProjectRoot $projectRoot -Compiler $clangCompiler
        & $flutterCommand.Source build windows --release --no-pub @buildDefines
    }
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed. Check Visual Studio C++ tools and Windows SDK.' }
    $releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    if (-not (Test-Path -LiteralPath (Join-Path $releaseDir 'kirakira.exe'))) {
        throw 'Expected kirakira.exe was not produced.'
    }
    if ($Installer) {
        & (Join-Path $PSScriptRoot 'package-windows.ps1') -ReleaseDir $releaseDir
    } else {
        Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath (Join-Path $outputDir "${displayName}_windows_$appVersion.zip") -Force
    }
    if ($Msix) {
        & $flutterCommand.Source pub run msix:create --build-windows false
        if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging failed.' }
        $msixFile = Get-ChildItem -LiteralPath $releaseDir -Filter "$displayName.msix" -File | Select-Object -First 1
        if ($null -eq $msixFile) { throw 'Expected MSIX was not produced.' }
        Copy-Item -LiteralPath $msixFile.FullName -Destination (Join-Path $outputDir "${displayName}_windows_$appVersion.msix")
    }
}
Write-Host "Application packages: $outputDir"
