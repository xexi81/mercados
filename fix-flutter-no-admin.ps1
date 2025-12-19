# Script para configurar proyectos Flutter sin permisos de administrador
param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = "."
)

$gradlePropertiesPath = Join-Path $ProjectPath "android\gradle.properties"

if (-not (Test-Path $gradlePropertiesPath)) {
    Write-Error "No se encontró android/gradle.properties en $ProjectPath"
    exit 1
}

Write-Host "Configurando $gradlePropertiesPath..." -ForegroundColor Cyan

# Leer el contenido actual
$content = Get-Content $gradlePropertiesPath -Raw

# Verificar si ya tiene la configuración
if ($content -notmatch "flutter.useSymlinks=false") {
    # Agregar flutter.useSymlinks
    Add-Content -Path $gradlePropertiesPath -Value "flutter.useSymlinks=false"
    Write-Host "✓ Agregado flutter.useSymlinks=false" -ForegroundColor Green
} else {
    Write-Host "○ flutter.useSymlinks ya configurado" -ForegroundColor Yellow
}

if ($content -notmatch "systemProp.javax.net.ssl.trustStoreType") {
    # Agregar propiedades SSL
    Add-Content -Path $gradlePropertiesPath -Value "systemProp.javax.net.ssl.trustStoreType=Windows-ROOT"
    Add-Content -Path $gradlePropertiesPath -Value "systemProp.javax.net.ssl.trustStore=NONE"
    Write-Host "✓ Agregadas propiedades SSL" -ForegroundColor Green
} else {
    Write-Host "○ Propiedades SSL ya configuradas" -ForegroundColor Yellow
}

# Modificar org.gradle.jvmargs si existe
$lines = Get-Content $gradlePropertiesPath
$newLines = @()
$jvmargsUpdated = $false
foreach ($line in $lines) {
    if ($line -match "^org.gradle.jvmargs=" -and $line -notmatch "javax.net.ssl.trustStore") {
        $newLine = $line.TrimEnd() + " -Djavax.net.ssl.trustStore=NONE -Djavax.net.ssl.trustStoreType=Windows-ROOT"
        $newLines += $newLine
        $jvmargsUpdated = $true
    } else {
        $newLines += $line
    }
}

if ($jvmargsUpdated) {
    $newLines | Set-Content $gradlePropertiesPath
    Write-Host "✓ Actualizado org.gradle.jvmargs" -ForegroundColor Green
} else {
    Write-Host "○ org.gradle.jvmargs ya configurado" -ForegroundColor Yellow
}

Write-Host "`n✓ Configuración completada!" -ForegroundColor Green
Write-Host "`nAhora puedes ejecutar:" -ForegroundColor Cyan
Write-Host "  flutter run --no-pub" -ForegroundColor White
