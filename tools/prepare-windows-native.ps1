param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Compiler = (Join-Path $env:ProgramFiles 'LLVM\bin\clang-cl.exe')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Compiler)) { throw 'Install LLVM with clang-cl first.' }
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$cmakeRoot = Join-Path $vsRoot 'Common7\IDE\CommonExtensions\Microsoft\CMake'
$cmake = Join-Path $cmakeRoot 'CMake\bin\cmake.exe'
$ninja = Join-Path $cmakeRoot 'Ninja\ninja.exe'
$hookRoot = Join-Path $ProjectRoot '.dart_tool\hooks_runner\shared\ech_http\build'
$caches = Get-ChildItem -Path (Join-Path $hookRoot '*\native\CMakeCache.txt') -File
if (-not $caches) { throw 'Run the Windows release build once to initialize native hook caches.' }
foreach ($cache in $caches) {
    $native = $cache.Directory.FullName
    if (-not $native.StartsWith($hookRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Unexpected native build directory.'
    }
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $cache.FullName) {
        if ($line -match '^([^/#][^:]*):[^=]+=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    $capture = Join-Path $cache.Directory.Parent.FullName 'compiler_environment.cmd'
    foreach ($line in (& $capture)) {
        $equals = $line.IndexOf('=')
        if ($equals -gt 0) {
            [Environment]::SetEnvironmentVariable($line.Substring(0,$equals), $line.Substring($equals+1), 'Process')
        }
    }
    & $cmake -S $values['CMAKE_HOME_DIRECTORY'] -B $native -G Ninja `
        "-DCMAKE_MAKE_PROGRAM=$ninja" "-DCMAKE_C_COMPILER=$Compiler" "-DCMAKE_CXX_COMPILER=$Compiler" `
        '-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /GR /EHsc /utf-8' `
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
        "-DEH_DEPS_ROOT=$($values['EH_DEPS_ROOT'])" "-DEH_DART_INCLUDE=$($values['EH_DART_INCLUDE'])"
    if ($LASTEXITCODE -ne 0) { throw 'Native clang-cl configuration failed.' }
    & $cmake --build $native --target ech_http --parallel 8
    if ($LASTEXITCODE -ne 0) { throw 'Native clang-cl compilation failed.' }
}
