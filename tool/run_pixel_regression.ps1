# FreshChat remains a compatibility switch; each run always owns a fresh conversation.
param([switch]$FreshChat, [switch]$SkipClean, [ValidateSet('regression','location-time')][string]$Suite='regression')
. "$PSScriptRoot/release_common.ps1"
Push-Location $script:ReleaseRoot
$job=$null
$registered=$false
$log=$null
try {
    $adb=Find-ReleaseTool 'adb' 'C:\Android\Sdk\platform-tools\adb.exe'
    $flutter=Find-ReleaseTool 'flutter' 'C:\src\flutter\bin\flutter.bat'
    $php=Find-ReleaseTool 'php'
    $devices=@()
    foreach($line in (& $adb devices)){
        if($line -match '^(emulator-\d+)\s+device$'){
            $candidate=$Matches[1]
            if((& $adb -s $candidate emu avd name) -contains 'Pixel_6a'){ $devices+=$candidate }
        }
    }
    if($devices.Count -ne 1){ throw 'Exactly one running Pixel_6a emulator is required. Other devices will not be changed.' }
    $serial=$devices[0]
    if(!$SkipClean){
        foreach($relative in @('build','.dart_tool','android/.gradle')){
            $path=Join-Path $script:ReleaseRoot $relative
            if((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint)){ throw 'Refusing clean across a generated-directory link.' }
        }
        Invoke-ReleaseNative $flutter @('clean')
        Invoke-ReleaseNative $flutter @('pub','get')
    }
    Push-Location backend
    try { Invoke-ReleaseNative $php @('artisan','demo:refresh-locations') } finally { Pop-Location }
    Invoke-ReleaseNative $adb @('-s',$serial,'reverse','tcp:8000','tcp:8000')
    $target=if($Suite -eq 'location-time'){'integration_test/location_time_test.dart'}else{'integration_test/regression_test.dart'}
    $logName=if($Suite -eq 'location-time'){'.local/pixel-location-time.log'}else{'.local/pixel-release-regression.log'}
    $log=Join-Path $script:ReleaseRoot $logName
    [IO.File]::WriteAllText($log,'')
    Invoke-ReleaseNative $php @('tool/pixel_fixtures.php')
    $scenarioDefines=Join-Path $script:ReleaseRoot '.local/pixel-fixture-defines.json'
    if(!(Test-Path -LiteralPath $scenarioDefines)){ throw 'Scenario fixture defines were not created.' }
    $job=Start-Job -ArgumentList $script:ReleaseRoot,$flutter,$serial,$log,$scenarioDefines,$target -ScriptBlock {
        param($root,$flutter,$serial,$log,$scenarioDefines,$target)
        Set-Location -LiteralPath $root
        & $flutter test $target -d $serial '--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1' '--dart-define=ADS_DISABLED=true' "--dart-define-from-file=$scenarioDefines" --reporter expanded *> $log
        [int]$LASTEXITCODE
    }
    $granted=$false
    $registered=$false
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while($job.State -in @('Running','NotStarted')){
        if($watch.Elapsed.TotalMinutes -gt 20){ throw 'Pixel regression exceeded 20 minutes.' }
        if(!$granted -and (Select-String -LiteralPath $log -Pattern '^00:00 \+0: (Account setup|SenMiydin active city)' -Quiet)){
            if((& $adb -s $serial emu avd name) -notcontains 'Pixel_6a'){ throw 'Target device changed.' }
            Invoke-ReleaseNative $adb @('-s',$serial,'shell','pm','grant','com.senmiydin.app','android.permission.ACCESS_FINE_LOCATION')
            Invoke-ReleaseNative $adb @('-s',$serial,'shell','pm','grant','com.senmiydin.app','android.permission.ACCESS_COARSE_LOCATION')
            $granted=$true
        }
        if(!$registered){
            $marker=Select-String -LiteralPath $log -Pattern 'SENMIYDIN_ACCOUNT_CREATED:([0-9]+)' | Select-Object -First 1
            if($marker){
                Invoke-ReleaseNative $php @('tool/pixel_fixtures.php',("--register-account="+$marker.Matches[0].Groups[1].Value))
                $registered=$true
            }
        }
        $ankara=(Select-String -LiteralPath $log -SimpleMatch 'SENMIYDIN_GPS_ANKARA' -Quiet)
        $alanya=(Select-String -LiteralPath $log -SimpleMatch 'SENMIYDIN_GPS_ALANYA' -Quiet)
        if($ankara -and !$alanya) {
            & "$PSScriptRoot/set_demo_location.ps1" -Latitude 39.9208 -Longitude 32.8541 | Out-Null
        } else {
            & "$PSScriptRoot/set_demo_location.ps1" | Out-Null
        }
        Start-Sleep -Seconds 3
    }
    $result=@(Receive-Job -Job $job -Wait)
    Get-Content -LiteralPath $log -Tail 26
    $code=@($result | Where-Object {$_ -is [int]}) | Select-Object -Last 1
    if($null -eq $code -or $code -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'All tests passed!' -Quiet)){ throw 'Pixel regression failed. See the suite log in .local.' }
    Write-Output 'Pixel 6a full regression: OK'
} finally {
    if($job){ if($job.State -eq 'Running'){ Stop-Job -Job $job }; Remove-Job -Job $job -Force }
    if(Test-Path -LiteralPath (Join-Path $script:ReleaseRoot '.local/pixel-fixtures.json')) {
        if(!$registered -and $log -and (Test-Path -LiteralPath $log)) {
            $marker=Select-String -LiteralPath $log -Pattern 'SENMIYDIN_ACCOUNT_CREATED:([0-9]+)' | Select-Object -First 1
            if($marker){ Invoke-ReleaseNative $php @('tool/pixel_fixtures.php',("--register-account="+$marker.Matches[0].Groups[1].Value)) }
        }
        & $php 'tool/pixel_fixtures.php' --cleanup
        if($LASTEXITCODE -or (Test-Path -LiteralPath (Join-Path $script:ReleaseRoot '.local/pixel-fixtures.json'))){ throw 'Owned scenario cleanup failed.' }
    }
    Pop-Location
}
