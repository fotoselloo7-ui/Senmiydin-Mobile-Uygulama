$ErrorActionPreference = 'Stop'
$backend = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../backend')).Path
$router = Join-Path $backend 'vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php'
Push-Location -LiteralPath (Join-Path $backend 'public')
try {
    & php -d upload_max_filesize=5M -d post_max_size=55M -S 127.0.0.1:8000 $router
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
