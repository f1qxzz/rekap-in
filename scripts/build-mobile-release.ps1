param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$MobileDir = Join-Path $Root 'mobile'

function Resolve-Flutter {
    $Command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($Command) {
        return $Command.Source
    }

    $Fallback = 'C:\flutter\bin\flutter.bat'
    if (Test-Path -LiteralPath $Fallback) {
        return $Fallback
    }

    throw 'Flutter tidak ditemukan di PATH atau C:\flutter\bin\flutter.bat'
}

$ApiBaseUrl = $ApiBaseUrl.Trim().TrimEnd('/')
$Uri = [System.Uri]::new($ApiBaseUrl)
if (-not $Uri.Scheme -or -not $Uri.Host) {
    throw 'API base URL belum valid.'
}

$Flutter = Resolve-Flutter

Push-Location $MobileDir
try {
    & $Flutter pub get
    & $Flutter build apk --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
} finally {
    Pop-Location
}

$Apk = Join-Path $MobileDir 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host ""
Write-Host "Release APK: $Apk"
