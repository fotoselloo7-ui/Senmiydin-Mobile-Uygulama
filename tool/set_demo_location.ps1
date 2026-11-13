param(
    [ValidateRange(-90, 90)][double]$Latitude = 36.544,
    [ValidateRange(-180, 180)][double]$Longitude = 32.000,
    [switch]$Reset
)
$ErrorActionPreference = 'Stop'
$adb = 'C:\Android\Sdk\platform-tools\adb.exe'
$serial = $null
foreach ($line in (& $adb devices)) {
    if ($line -notmatch '^(emulator-\d+)\s+device$') { continue }
    $candidate = $Matches[1]
    if ((& $adb -s $candidate emu avd name) -contains 'Pixel_6a') {
        $serial = $candidate
        break
    }
}
if (!$serial) { throw 'Pixel 6a emülatörü açık olmalı.' }

function Invoke-Device {
    & $adb -s $serial @args
    if ($LASTEXITCODE) { throw 'Pixel 6a konum komutu başarısız.' }
}

if ($Reset) {
    foreach ($provider in @('gps', 'fused')) {
        Invoke-Device shell cmd location providers remove-test-provider $provider
    }
    Invoke-Device shell appops set com.android.shell android:mock_location default
    return
}

$culture = [Globalization.CultureInfo]::InvariantCulture
$lat = $Latitude.ToString($culture)
$lng = $Longitude.ToString($culture)
Invoke-Device emu geo fix $lng $lat
Invoke-Device shell appops set com.android.shell android:mock_location allow
foreach ($provider in @('gps', 'fused')) {
    & $adb -s $serial shell cmd location providers set-test-provider-enabled $provider true 2>&1 | Out-Null
    if ($LASTEXITCODE) {
        Invoke-Device shell cmd location providers add-test-provider $provider
        Invoke-Device shell cmd location providers set-test-provider-enabled $provider true
    }
    Invoke-Device shell cmd location providers set-test-provider-location $provider --location "$lat,$lng" --accuracy 5
}
