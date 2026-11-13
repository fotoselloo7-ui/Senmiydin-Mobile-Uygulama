param([string]$ApiBaseUrl)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot
$flutterPath = 'C:\src\flutter\bin\flutter.bat'
$adbPath = 'C:\Android\Sdk\platform-tools\adb.exe'
$emulatorPath = 'C:\Android\Sdk\emulator\emulator.exe'
function Find-Pixel6a {
    $serials = & $adbPath devices | ForEach-Object { if ($_ -match '^(emulator-\d+)\s+device$') { $Matches[1] } }
    foreach ($serial in $serials) {
        $avdName = & $adbPath -s $serial emu avd name
        if ($avdName -contains 'Pixel_6a') { return $serial }
    }
    return $null
}
$pixelSerial = Find-Pixel6a
if (-not $pixelSerial) {
    $previousSdk = $env:ANDROID_SDK_ROOT
    try {
        $env:ANDROID_SDK_ROOT = 'C:\Users\pc\AppData\Local\Android\Sdk'
        Start-Process -FilePath $emulatorPath -ArgumentList @('-avd','Pixel_6a')
    } finally { $env:ANDROID_SDK_ROOT = $previousSdk }
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        Start-Sleep -Seconds 1
        $pixelSerial = Find-Pixel6a
        if ($pixelSerial) { break }
    }
}
if (-not $pixelSerial) { throw 'Pixel 6a başlatılamadı. Android Studio Device Manager üzerinden açmayı deneyin.' }
Write-Host "SenMiydin? Pixel 6a üzerinde başlatılıyor: $pixelSerial"
$flutterArguments = @('run', '-d', $pixelSerial)
if ($ApiBaseUrl) { $flutterArguments += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
& $flutterPath @flutterArguments
exit $LASTEXITCODE
