$gradlePropertiesPath = "android\gradle.properties"

if (-not (Test-Path $gradlePropertiesPath)) {
    Write-Error "No found $gradlePropertiesPath"
    exit 1
}

$content = Get-Content $gradlePropertiesPath -Raw

if ($content -notmatch "flutter.useSymlinks=false") {
    Add-Content -Path $gradlePropertiesPath -Value "`nflutter.useSymlinks=false"
    Write-Host "Fixed symlinks."
}

if ($content -notmatch "systemProp.javax.net.ssl.trustStoreType") {
    Add-Content -Path $gradlePropertiesPath -Value "`nsystemProp.javax.net.ssl.trustStoreType=Windows-ROOT"
    Add-Content -Path $gradlePropertiesPath -Value "`nsystemProp.javax.net.ssl.trustStore=NONE"
    Write-Host "Fixed SSL."
}

Write-Host "Done."
