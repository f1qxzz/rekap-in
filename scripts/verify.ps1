param(
    [switch]$All,
    [switch]$Mobile,
    [switch]$Backend,
    [switch]$Security,
    [switch]$BuildApk
)

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

if (-not ($All -or $Mobile -or $Backend -or $Security -or $BuildApk)) {
    $Mobile = $true
    $Backend = $true
    $Security = $true
}

if ($All) {
    $Mobile = $true
    $Backend = $true
    $Security = $true
    $BuildApk = $true
}

function Resolve-Flutter {
    $Command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($Command) {
        return $Command.Source
    }

    $Fallback = "C:\flutter\bin\flutter.bat"
    if (Test-Path -LiteralPath $Fallback) {
        return $Fallback
    }

    throw "Flutter tidak ditemukan di PATH atau C:\flutter\bin\flutter.bat"
}

$Flutter = Resolve-Flutter

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "==> $Name"
    & $Command
}

if ($Mobile) {
    Invoke-Step "Flutter pub get" {
        Push-Location (Join-Path $Root "mobile")
        try { & $Flutter pub get } finally { Pop-Location }
    }

    Invoke-Step "Flutter analyze" {
        Push-Location (Join-Path $Root "mobile")
        try { & $Flutter analyze } finally { Pop-Location }
    }

    Invoke-Step "Flutter test" {
        Push-Location (Join-Path $Root "mobile")
        try { & $Flutter test } finally { Pop-Location }
    }
}

if ($BuildApk) {
    Invoke-Step "Flutter build apk debug" {
        Push-Location (Join-Path $Root "mobile")
        try { & $Flutter build apk --debug } finally { Pop-Location }
    }
}

if ($Backend) {
    Invoke-Step "Backend npm check" {
        Push-Location (Join-Path $Root "backend")
        try { npm run check } finally { Pop-Location }
    }

    Invoke-Step "Prisma validate" {
        Push-Location (Join-Path $Root "backend")
        try { npx prisma validate } finally { Pop-Location }
    }
}

if ($Security) {
    Invoke-Step "Security grep (safe static scan)" {
        Push-Location $Root
        try {
            $Patterns = @(
                "BEGIN .* KEY",
                "Bearer [A-Za-z0-9._-]{20,}",
                "(api[_-]?key|secret|private[_-]?key)\s*[:=]\s*[`"']?[A-Za-z0-9_./+=-]{12,}"
            )
            $Targets = @(
                "backend/src",
                "backend/prisma",
                "backend/scripts",
                "mobile/lib",
                "scripts",
                ".env.example",
                "backend/.env.example"
            )
            $CommonArgs = @(
                "-n",
                "-g", "!**/node_modules/**",
                "-g", "!**/build/**",
                "-g", "!**/.dart_tool/**",
                "-g", "!mobile/third_party/**",
                "-g", "!**/pubspec.lock",
                "-g", "!**/package-lock.json",
                "-g", "!scripts/verify.ps1"
            )
            $Findings = @()
            foreach ($Pattern in $Patterns) {
                $RgArgs = $CommonArgs + @($Pattern) + $Targets
                $Output = & rg @RgArgs
                if ($LASTEXITCODE -eq 0) {
                    $Findings += $Output
                } elseif ($LASTEXITCODE -gt 1) {
                    exit $LASTEXITCODE
                }
            }
            if ($Findings.Count -gt 0) {
                Write-Host "Potential secret-like literals found. Review these lines:"
                $Findings
            } else {
                Write-Host "No obvious hardcoded secrets found in scanned source paths."
            }
        } finally {
            Pop-Location
        }
    }
}

Write-Host ""
Write-Host "Verification finished."
