param([switch]$Offline)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$check = Join-Path $repo '.scanner_check'
New-Item -ItemType Directory -Force "$check/lib", "$check/test" | Out-Null
Copy-Item "$PSScriptRoot/scanner_pubspec.yaml" "$check/pubspec.yaml" -Force
foreach ($folder in @('scanner', 'models', 'utils')) {
    Copy-Item "$repo/$folder" "$check/lib" -Recurse -Force
}
New-Item -ItemType Directory -Force "$check/lib/services", "$check/lib/pages", "$check/lib/components" | Out-Null
if (Test-Path -LiteralPath "$check/lib/services/omr_service.dart") {
    Remove-Item -LiteralPath "$check/lib/services/omr_service.dart"
}
foreach ($file in @('local_omr_service', 'pdf_service', 'aluno_service', 'prova_service', 'resultado_service', 'turma_services')) {
    Copy-Item "$repo/services/$file.dart" "$check/lib/services" -Force
}
Copy-Item "$repo/pages/camera_scanner_page.dart" "$check/lib/pages" -Force
Copy-Item "$repo/components/selecionar_aluno_dialog.dart" "$check/lib/components" -Force
Copy-Item "$repo/tests/*.dart" "$check/test" -Force
Copy-Item "$repo/tests/fixtures" "$check/test" -Recurse -Force
Push-Location $check
try {
    if ($Offline) { flutter pub get --offline } else { flutter pub get }
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao resolver dependências.' }
    dart analyze lib/pages/camera_scanner_page.dart lib/scanner lib/services/local_omr_service.dart lib/services/pdf_service.dart test
    if ($LASTEXITCODE -ne 0) { throw 'Falha na análise estática.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes.' }
} finally { Pop-Location }
