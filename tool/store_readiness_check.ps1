param([switch]$SkipRuntime, [switch]$RefreshAndroidAudit, [switch]$Json)
$ErrorActionPreference='Stop'
# Exit 2 is an intentional MISSING/WAITING result, not a PowerShell exception.
$PSNativeCommandUseErrorActionPreference=$false
$workspaceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $workspaceRoot
try {
    $python=(Get-Command python -ErrorAction Stop).Source
    if($RefreshAndroidAudit) {
        if(!$env:JAVA_HOME -and (Test-Path -LiteralPath 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot')) {
            $env:JAVA_HOME='C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot'
        }
        $auditLog=Join-Path $workspaceRoot '.local/store-android-dependencies.log'
        if(!(Test-Path -LiteralPath (Join-Path $workspaceRoot '.local'))){[void](New-Item -ItemType Directory -Path (Join-Path $workspaceRoot '.local'))}
        Push-Location -LiteralPath (Join-Path $workspaceRoot 'android')
        try {
            $nativePreference=$ErrorActionPreference
            try {
                $ErrorActionPreference='Continue'
                & .\gradlew.bat :app:dependencies --configuration releaseRuntimeClasspath :app:processReleaseMainManifest --console=plain --no-daemon 2>&1 | Out-File -LiteralPath $auditLog -Encoding utf8
                $nativeCode=$LASTEXITCODE
            } finally {$ErrorActionPreference=$nativePreference}
            if($nativeCode){Write-Output 'FAIL | Android release dependency/manifest audit'; exit 1}
        } finally {Pop-Location}
    }
    $auditArguments=@((Join-Path $workspaceRoot 'tool/store_readiness.py'))
    if($SkipRuntime){$auditArguments+='--skip-runtime'}
    if($Json){$auditArguments+='--json'}
    & $python @auditArguments
    exit $LASTEXITCODE
} finally {Pop-Location}
