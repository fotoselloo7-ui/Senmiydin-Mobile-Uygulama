param([switch]$SkipTests)
. "$PSScriptRoot/release_common.ps1"
$results=New-Object 'System.Collections.Generic.List[object]'
$logDirectory=Join-Path $script:ReleaseRoot '.local/release-check'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
function Check-ReleaseStep([string]$Name,[scriptblock]$Action) {
    try { & $Action; $results.Add([pscustomobject]@{Check=$Name;Status='OK'}) }
    catch { $results.Add([pscustomobject]@{Check=$Name;Status='FAIL'}); Write-Output "FAIL: $Name - $($_.Exception.Message)" }
}
Push-Location $script:ReleaseRoot
try {
    $flutter=Find-ReleaseTool 'flutter' 'C:\src\flutter\bin\flutter.bat'
    $php=Find-ReleaseTool 'php'
    $python=Find-ReleaseTool 'python'
    Check-ReleaseStep 'Flutter environment' { Invoke-ReleaseNative $flutter @('--version') *> (Join-Path $logDirectory 'flutter-environment.log') }
    Check-ReleaseStep 'Flutter pub get' { Invoke-ReleaseNative $flutter @('pub','get') *> (Join-Path $logDirectory 'pub-get.log') }
    Check-ReleaseStep 'Flutter analyze' { Invoke-ReleaseNative $flutter @('analyze') *> (Join-Path $logDirectory 'analyze.log') }
    if(!$SkipTests){ Check-ReleaseStep 'Flutter tests' { Invoke-ReleaseNative $flutter @('test','--reporter','expanded') *> (Join-Path $logDirectory 'flutter-tests.log') } }
    Push-Location backend
    try {
        Check-ReleaseStep 'Composer install state' {
            if(!(Test-Path -LiteralPath 'vendor/autoload.php')){ throw 'Run composer install first.' }
            Invoke-ReleaseComposer @('validate','--no-check-publish') *> (Join-Path $logDirectory 'composer-validate.log')
            Invoke-ReleaseComposer @('check-platform-reqs') *> (Join-Path $logDirectory 'composer-platform.log')
            Invoke-ReleaseComposer @('install','--dry-run','--no-interaction','--no-scripts') *> (Join-Path $logDirectory 'composer-install.log')
        }
        if(!$SkipTests){ Check-ReleaseStep 'Composer tests' { Invoke-ReleaseComposer @('test','--no-interaction') *> (Join-Path $logDirectory 'backend-tests.log') } }
        $safeJson=& $php artisan app:check --json
        $readinessExit=$LASTEXITCODE
        if($readinessExit -notin @(0,2)){ $results.Add([pscustomobject]@{Check='Production configuration';Status='FAIL'}) }
        else {
            $safeJson | Set-Content -LiteralPath (Join-Path $logDirectory 'production.json') -Encoding utf8
            $readiness=$safeJson | ConvertFrom-Json
            $results.Add([pscustomobject]@{Check='Production configuration';Status=$(if($readiness.ready){'OK'}else{'MISSING'})})
        }
        Check-ReleaseStep 'Migration status' {
            $migrationJson=& $php artisan migrate:status --no-ansi
            if($LASTEXITCODE){ throw 'Migration status unavailable. See deployment database configuration.' }
            $migrationJson | Set-Content -LiteralPath (Join-Path $logDirectory 'migrations.log')
            if($migrationJson -match '\bPending\b'){ throw 'Pending migrations must be applied before release.' }
        }
    } finally { Pop-Location }
    Check-ReleaseStep 'Package IDs and release configuration' {
        $gradle=Get-Content -LiteralPath 'android/app/build.gradle.kts' -Raw
        $iosProject=Get-Content -LiteralPath 'ios/Runner.xcodeproj/project.pbxproj' -Raw
        if($gradle -notmatch 'applicationId\s*=\s*"com.senmiydin.app"' -or $iosProject -notmatch 'PRODUCT_BUNDLE_IDENTIFIER = com.senmiydin.app;'){ throw 'Application identifiers differ.' }
        $config=Get-Content -LiteralPath 'config/production.json' -Raw | ConvertFrom-Json
        if(([uri]$config.API_BASE_URL).Scheme -ne 'https'){ throw 'Release API must use HTTPS.' }
        [xml]$manifest=Get-Content -LiteralPath 'android/app/src/main/AndroidManifest.xml'
        if($manifest.manifest.application.usesCleartextTraffic -ne 'false'){ throw 'Main/release manifest allows cleartext.' }
        [xml]$debug=Get-Content -LiteralPath 'android/app/src/debug/AndroidManifest.xml'
        if($debug.manifest.application.usesCleartextTraffic -ne 'true'){ throw 'Debug local HTTP override is missing.' }
        if($gradle -match 'signingConfig\s*=\s*signingConfigs.getByName\("debug"\)'){ throw 'Release debug-key fallback found.' }
    }
    # The REAL merged release manifest (app + every plugin/SDK manifest), not the source file. FAIL when it ships something
    # wrong; MISSING (exit 2 of the checker) only for an external credential such as the real AdMob application id.
    try {
        Invoke-ReleaseNative $python @('tool/platform_manifest_check.py','android','--build','--json', (Join-Path $logDirectory 'android-manifest.json')) *> (Join-Path $logDirectory 'android-manifest.log')
        $results.Add([pscustomobject]@{Check='Android merged release manifest';Status='OK'})
    } catch {
        $manifestStatus=(Get-Content -LiteralPath (Join-Path $logDirectory 'android-manifest.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue).status
        if($manifestStatus -eq 'MISSING'){ $results.Add([pscustomobject]@{Check='Android merged release manifest';Status='MISSING'}); Write-Output 'MISSING: real AdMob Android application id (see android-manifest.log).' }
        else { $results.Add([pscustomobject]@{Check='Android merged release manifest';Status='FAIL'}); Write-Output 'FAIL: Android merged release manifest (see .local/release-check/android-manifest.log).' }
    }
    # Static files only: no Xcode build, signing or archive is claimed (docs/IOS_MAC_HANDOFF.md lists the Mac work).
    try {
        Invoke-ReleaseNative $python @('tool/platform_manifest_check.py','ios','--json', (Join-Path $logDirectory 'ios-static.json')) *> (Join-Path $logDirectory 'ios-static.log')
        $results.Add([pscustomobject]@{Check='iOS static sanity (no Xcode build)';Status='OK'})
    } catch {
        $iosStatus=(Get-Content -LiteralPath (Join-Path $logDirectory 'ios-static.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue).status
        if($iosStatus -eq 'MISSING'){ $results.Add([pscustomobject]@{Check='iOS static sanity (no Xcode build)';Status='MISSING'}); Write-Output 'MISSING: real AdMob iOS application id (see ios-static.log).' }
        else { $results.Add([pscustomobject]@{Check='iOS static sanity (no Xcode build)';Status='FAIL'}); Write-Output 'FAIL: iOS static sanity (see .local/release-check/ios-static.log).' }
    }
    Check-ReleaseStep 'Demo seeder protection' {
        foreach($file in @('backend/database/seeders/DemoDataSeeder.php','backend/database/seeders/DevelopmentAdminSeeder.php')){
            if((Get-Content -LiteralPath $file -Raw) -notmatch "environment\('local',\s*'development'\)"){ throw 'Development seeder guard missing.' }
        }
    }
    Check-ReleaseStep 'Sensitive files and gitignore' { Invoke-ReleaseNative $python @('tool/release_safety.py','--output', (Join-Path $logDirectory 'security.json')) *> (Join-Path $logDirectory 'security.log') }
    try { Assert-ReleaseSigning; $results.Add([pscustomobject]@{Check='Android signing';Status='OK'}) }
    catch { $results.Add([pscustomobject]@{Check='Android signing';Status='MISSING'}); Write-Output 'MISSING: real Android signing information.' }
} catch {
    $results.Add([pscustomobject]@{Check='Release tooling';Status='FAIL'})
    Write-Output "FAIL: $($_.Exception.Message)"
} finally { Pop-Location }
$results | Format-Table -AutoSize
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logDirectory 'summary.json') -Encoding utf8
if($results.Status -contains 'FAIL'){ exit 1 }
if($results.Status -contains 'MISSING'){ exit 2 }
exit 0
