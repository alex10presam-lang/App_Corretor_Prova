param([Parameter(Mandatory = $true)][string]$ProjectPath)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$target = (Resolve-Path -LiteralPath $ProjectPath).Path
$manifest = Join-Path $target 'pubspec.yaml'
if (!(Test-Path -LiteralPath $manifest) -or !(Select-String -LiteralPath $manifest -Pattern '^name:\s*corretor_provas\s*$' -Quiet)) {
    throw 'A pasta precisa conter o projeto Flutter corretor_provas.'
}
$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6)
$backup = Join-Path $target ".scanner-backups/$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$records = [System.Collections.Generic.List[object]]::new()
function Backup-File([string]$relative) {
    $destination = [IO.Path]::GetFullPath((Join-Path $target $relative))
    if (!$destination.StartsWith($target.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Destino fora do projeto.' }
    $exists = Test-Path -LiteralPath $destination
    $records.Add([pscustomobject]@{ path = $relative; existed = $exists })
    if ($exists) {
        $saved = Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $destination -Destination $saved
    }
    # Persist before replacing anything, so partial installation is recoverable.
    $records | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'manifest.json') -Encoding utf8
    return $destination
}
$files = @{
    'scanner/scan_contract.dart' = 'lib/scanner/scan_contract.dart'
    'scanner/sheet_layout.dart' = 'lib/scanner/sheet_layout.dart'
    'scanner/local_omr.dart' = 'lib/scanner/local_omr.dart'
    'services/local_omr_service.dart' = 'lib/services/local_omr_service.dart'
    'services/pdf_service.dart' = 'lib/services/pdf_service.dart'
    'pages/camera_scanner_page.dart' = 'lib/pages/camera_scanner_page.dart'
    'tests/scanner_test.dart' = 'test/scanner_test.dart'
    'tests/pdf_test.dart' = 'test/pdf_test.dart'
    'tests/fixtures/printed_sheet.png' = 'test/fixtures/printed_sheet.png'
    'docs/scanner.md' = 'docs/scanner-local.md'
}
# Validate inputs before writing application files.
foreach ($source in $files.Keys) {
    if (!(Test-Path -LiteralPath (Join-Path $repo $source))) { throw "Arquivo ausente: $source" }
}
foreach ($source in $files.Keys) {
    $destination = Backup-File $files[$source]
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo $source) -Destination $destination -Force
}
$imports = @{
    'lib/main.dart' = @("import '/login_page.dart';", "import 'login_page.dart';")
    'lib/pages/editar_resultado_page.dart' = @("../scanner/validator.dart", "../utils/validator.dart")
}
foreach ($relative in $imports.Keys) {
    $file = Backup-File $relative
    $content = [IO.File]::ReadAllText($file)
    [IO.File]::WriteAllText($file, $content.Replace($imports[$relative][0], $imports[$relative][1]), [Text.UTF8Encoding]::new($false))
}
$android = Backup-File 'android/app/src/main/AndroidManifest.xml'
$xml = [Xml.XmlDocument]::new()
$xml.PreserveWhitespace = $true
$xml.XmlResolver = $null
$xml.Load($android)
$ns = 'http://schemas.android.com/apk/res/android'
foreach ($permission in @('android.permission.CAMERA','android.permission.INTERNET')) {
    $found = @($xml.manifest.SelectNodes('uses-permission')) | Where-Object { $_.GetAttribute('name', $ns) -eq $permission }
    if (!$found) {
        $element = $xml.CreateElement('uses-permission')
        $element.SetAttribute('name', $ns, $permission) | Out-Null
        $xml.manifest.InsertBefore($element, $xml.manifest.SelectSingleNode('application')) | Out-Null
    }
}
$xml.Save($android)
$ios = Backup-File 'ios/Runner/Info.plist'
$plist = [IO.File]::ReadAllText($ios)
if (!$plist.Contains('<key>NSCameraUsageDescription</key>')) {
    $plist = $plist.Replace('<dict>', "<dict>`n`t<key>NSCameraUsageDescription</key>`n`t<string>A câmera identifica a folha e lê as respostas diretamente no celular.</string>")
    [IO.File]::WriteAllText($ios, $plist, [Text.UTF8Encoding]::new($false))
}
$ignore = Backup-File '.gitignore'
if (!(Test-Path -LiteralPath $ignore) -or !(Select-String -LiteralPath $ignore -SimpleMatch '.scanner-backups/' -Quiet)) {
    Add-Content -LiteralPath $ignore -Value "`n.scanner-backups/"
}
Write-Output "Scanner local integrado em: $target"
Write-Output "Backup dos arquivos anteriores: $backup"
