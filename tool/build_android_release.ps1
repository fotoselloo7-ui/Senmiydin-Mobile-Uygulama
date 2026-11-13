param([string]$Config='config/production.json', [switch]$RunTests, [switch]$Clean, [switch]$Apk)
. "$PSScriptRoot/release_common.ps1"
Push-Location $script:ReleaseRoot
try {
    Assert-ReleaseSigning
    $configPath=[IO.Path]::GetFullPath((Join-Path $script:ReleaseRoot $Config))
    if(!(Test-Path -LiteralPath $configPath)){ throw 'Mobile release config is missing.' }
    $settings=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $url=[uri]$settings.API_BASE_URL
    if($url.Scheme -ne 'https' -or $url.UserInfo -or $url.Query -or $url.Fragment -or $url.AbsolutePath -notmatch '/api/v1/?$'){ throw 'Release API_BASE_URL must be a credential-free HTTPS API URL.' }
    $flutter=Find-ReleaseTool 'flutter' 'C:\src\flutter\bin\flutter.bat'
    if($Clean){ Invoke-ReleaseNative $flutter @('clean') }
    Invoke-ReleaseNative $flutter @('pub','get')
    Invoke-ReleaseNative $flutter @('analyze')
    if($RunTests){ Invoke-ReleaseNative $flutter @('test') }
    Invoke-ReleaseNative $flutter @('build','appbundle','--release',"--dart-define-from-file=$configPath")
    Write-Output "AAB: $(Join-Path $script:ReleaseRoot 'build/app/outputs/bundle/release/app-release.aab')"
    if($Apk){
        Invoke-ReleaseNative $flutter @('build','apk','--release',"--dart-define-from-file=$configPath")
        Write-Output "APK: $(Join-Path $script:ReleaseRoot 'build/app/outputs/flutter-apk/app-release.apk')"
    }
} finally { Pop-Location }
