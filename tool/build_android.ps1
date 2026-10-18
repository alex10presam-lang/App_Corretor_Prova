param([Parameter(Mandatory = $true)][string]$ProjectPath)
$ErrorActionPreference = 'Stop'
$target = (Resolve-Path -LiteralPath $ProjectPath).Path
if (!(Test-Path -LiteralPath (Join-Path $target 'pubspec.yaml'))) { throw 'Projeto Flutter não encontrado.' }
$socketPath = Join-Path $target '.gradle/java-sockets'
New-Item -ItemType Directory -Path $socketPath -Force | Out-Null
# A project-local socket directory avoids Windows filesystem virtualization
# affecting Java NIO. This setting exists only for the child build process.
$previousOptions = $env:JAVA_TOOL_OPTIONS
$env:JAVA_TOOL_OPTIONS = ($previousOptions + ' -Djdk.net.unixdomain.tmpdir="' + $socketPath + '"').Trim()
Push-Location $target
try {
    flutter build apk --debug
    if ($LASTEXITCODE -ne 0) { throw 'A compilação Android falhou.' }
} finally {
    Pop-Location
    $env:JAVA_TOOL_OPTIONS = $previousOptions
}
