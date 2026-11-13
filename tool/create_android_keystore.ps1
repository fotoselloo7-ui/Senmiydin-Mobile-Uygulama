# Run only by the actual key owner. No default password or automatic invocation.
. "$PSScriptRoot/release_common.ps1"
$destination=[IO.Path]::GetFullPath((Read-Host 'New keystore absolute path'))
$alias=Read-Host 'Key alias'
if($alias -notmatch '^[A-Za-z0-9_.-]{1,60}$'){ throw 'Alias must contain 1-60 letters, digits, dots, underscores or hyphens.' }
$propertiesPath=Join-Path $script:ReleaseRoot 'android/key.properties'
if((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath $propertiesPath)){ throw 'Refusing to overwrite an existing keystore or key.properties.' }
if(!(Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($destination)))){ throw 'Create the intended keystore parent directory first.' }
$password=Read-Host 'Keystore/key password (at least 6 characters)' -AsSecureString
$confirmation=Read-Host 'Confirm password' -AsSecureString
function Reveal-ForProcess([Security.SecureString]$Value) {
    $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
$plain=Reveal-ForProcess $password
$repeated=Reveal-ForProcess $confirmation
try {
    if($plain -cne $repeated -or $plain.Length -lt 6 -or $plain -match "[\r\n]"){ throw 'Password confirmation failed.' }
    $keytool=Find-ReleaseTool 'keytool' 'C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot\bin\keytool.exe'
    $owner=Read-Host 'Real certificate owner/organization'
    if(!$owner -or $owner -match "[\r\n]"){ throw 'Certificate owner is required.' }
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$keytool
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.EnvironmentVariables['SENMIYDIN_KEYSTORE_PASSWORD']=$plain
    $start.Arguments='-genkeypair -v -storetype PKCS12 -keystore "'+$destination+'" -alias "'+$alias+'" -keyalg RSA -keysize 4096 -validity 10000 -storepass:env SENMIYDIN_KEYSTORE_PASSWORD -keypass:env SENMIYDIN_KEYSTORE_PASSWORD -dname "CN='+$owner.Replace('"','')+'"'
    $process=[Diagnostics.Process]::Start($start)
    $process.WaitForExit()
    if($process.ExitCode -ne 0){ throw 'Keytool failed. No key.properties was created.' }
    function Escape-JavaProperty([string]$Value) {
        $escaped=New-Object Text.StringBuilder
        foreach($character in $Value.ToCharArray()){
            if([int]$character -gt 126 -or [int]$character -lt 32){ [void]$escaped.Append(('\u{0:X4}' -f [int]$character)) }
            elseif('\:=#! '.Contains([string]$character)){ [void]$escaped.Append('\'); [void]$escaped.Append($character) }
            else { [void]$escaped.Append($character) }
        }
        $escaped.ToString()
    }
    $content=[string]::Join([Environment]::NewLine,@("storeFile=$(Escape-JavaProperty $destination)","storePassword=$(Escape-JavaProperty $plain)","keyAlias=$alias","keyPassword=$(Escape-JavaProperty $plain)"))
    [IO.File]::WriteAllText($propertiesPath,$content,(New-Object Text.UTF8Encoding($false)))
    Write-Output 'Keystore and ignored android/key.properties created. Keep an encrypted offline backup; never commit them.'
} finally {
    $plain=$null; $repeated=$null; $content=$null
    $password.Dispose(); $confirmation.Dispose()
}
