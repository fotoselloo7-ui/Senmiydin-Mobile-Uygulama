$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
python "$PSScriptRoot\export_brand_icons.py"
Write-Host "Final SenMiydin branding assets applied across Flutter, Android, iOS, and Web/Admin."
