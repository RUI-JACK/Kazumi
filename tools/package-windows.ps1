param(
    [string]$ReleaseDir,
    [string]$Compiler
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $ReleaseDir) { $ReleaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release' }
$ReleaseDir = (Resolve-Path -LiteralPath $ReleaseDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $ReleaseDir 'kirakira.exe'))) {
    throw 'Build the Windows release before packaging.'
}

# Ship Microsoft's redistributable runtime DLLs app-local; no admin install needed.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsRoot) { throw 'Visual Studio C++ redistributable files not found.' }
$redistRoot = Join-Path $vsRoot 'VC\Redist\MSVC'
$crtDir = Get-ChildItem -LiteralPath $redistRoot -Directory | Where-Object Name -Match '^\d+\.' |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $_.FullName 'x64') -Directory -Filter '*.CRT' } |
    Select-Object -First 1
if (-not $crtDir) { throw 'The x64 Visual C++ runtime is missing.' }
Copy-Item -Path (Join-Path $crtDir.FullName '*.dll') -Destination $ReleaseDir -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE'), (Join-Path $projectRoot 'KIRAKIRA-THEME.md') -Destination $ReleaseDir -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'licenses') -Destination $ReleaseDir -Recurse -Force

if (-not $Compiler) {
    $Compiler = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe')
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $Compiler) { throw 'Install Inno Setup before packaging.' }
$versionMatch = Select-String -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Pattern '^version:\s*([^+\s]+)'
$appVersion = $versionMatch.Matches[0].Groups[1].Value
$outputDir = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
& $Compiler "/DReleaseDir=$ReleaseDir" "/DPackageDir=$outputDir" "/DAppVersion=$appVersion" (Join-Path $PSScriptRoot 'windows-installer\kirakira.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
$displayName = -join (0x30AD,0x30E9,0x30AD,0x30E9 | ForEach-Object { [char]$_ })
Compress-Archive -Path (Join-Path $ReleaseDir '*') -DestinationPath (Join-Path $outputDir "${displayName}-${appVersion}-windows-x64-portable.zip") -Force
Get-ChildItem -LiteralPath $outputDir -File | Where-Object { $_.Extension -in '.exe','.zip' } | Get-FileHash -Algorithm SHA256
