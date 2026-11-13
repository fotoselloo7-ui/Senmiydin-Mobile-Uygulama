param([switch]$WithVendor)
. "$PSScriptRoot/release_common.ps1"
Push-Location $script:ReleaseRoot
try {
    $python=Find-ReleaseTool 'python'
    $arguments=@('tool/build_backend_release.py')
    if($WithVendor){ $arguments+='--with-vendor' }
    Invoke-ReleaseNative $python $arguments
} finally { Pop-Location }
