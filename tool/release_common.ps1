Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ReleaseRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Find-ReleaseTool([string]$Name, [string]$Fallback='') {
    $found = Get-Command $Name -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    if ($Fallback -and (Test-Path -LiteralPath $Fallback)) { return $Fallback }
    throw "Required tool missing: $Name"
}
function Invoke-ReleaseNative([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $([IO.Path]::GetFileName($Executable))" }
}
function Assert-ReleaseSigning {
    $propertiesPath = Join-Path $script:ReleaseRoot 'android/key.properties'
    if (!(Test-Path -LiteralPath $propertiesPath)) { throw 'Missing Android signing. Run tool/create_android_keystore.ps1 yourself or supply existing real android/key.properties.' }
    $values=@{}
    foreach($row in Get-Content -LiteralPath $propertiesPath){
        if($row -match '^\s*(storeFile|storePassword|keyAlias|keyPassword)\s*=(.*)$'){ $values[$Matches[1]]=$Matches[2].Trim() }
    }
    foreach($name in @('storeFile','storePassword','keyAlias','keyPassword')){
        if(!$values.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($values[$name])) { throw "Signing property missing: $name" }
    }
    $keyPath=$values['storeFile'].Replace('\\','\').Replace('\:',':').Replace('\ ',' ')
    if(![IO.Path]::IsPathRooted($keyPath)){ $keyPath=Join-Path (Join-Path $script:ReleaseRoot 'android/app') $keyPath }
    if(!(Test-Path -LiteralPath $keyPath -PathType Leaf)){ throw 'Configured signing keystore is not readable.' }
}

function Invoke-ReleaseComposer([string[]]$Arguments) {
    $native=Get-Command composer -ErrorAction SilentlyContinue
    if($native){ Invoke-ReleaseNative $native.Source $Arguments; return }
    $phar=Join-Path $script:ReleaseRoot '.local/composer.phar'
    if(!(Test-Path -LiteralPath $phar)){ throw 'Composer is missing. Install Composer 2 or provide the verified .local/composer.phar.' }
    $php=Find-ReleaseTool 'php'
    Invoke-ReleaseNative $php (@($phar)+$Arguments)
}
