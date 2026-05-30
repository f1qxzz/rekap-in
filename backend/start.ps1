$backendDir = $PSScriptRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ABSENSI - Backend Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Kill existing processes on port 8080
try {
    $conns = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
    foreach ($conn in $conns) {
        $procId = $conn.OwningProcess
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        Write-Host "[*] Menghentikan proses PID $procId..." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 2
} catch {}

# Double check port is free
$remaining = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
if ($remaining) {
    Write-Host "[!] Port 8080 masih terpakai. Coba kill manual: netstat -ano | findstr :8080" -ForegroundColor Red
    exit 1
}

# Detect LAN IP
$lanIp = "localhost"
try {
    $lanIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress
} catch {}
if (-not $lanIp) { $lanIp = "localhost" }

$apiUrl = "http://${lanIp}:8080/api"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  URL SERVER (untuk Mobile App):" -ForegroundColor Green
Write-Host "  $apiUrl" -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Cara pakai:" -ForegroundColor Cyan
Write-Host "  1. Buka Mobile App -> Profil -> Pengaturan API Server" -ForegroundColor White
Write-Host "  2. Paste URL di atas ke kolom API Base URL" -ForegroundColor White
Write-Host "  3. Tekan Simpan" -ForegroundColor White
Write-Host ""
Write-Host "Pastikan HP dan laptop di WiFi yang sama." -ForegroundColor Yellow
Write-Host ""

# Save URL
Set-Content -Path "$backendDir\.tunnel-url" -Value $apiUrl -NoNewline

# Start backend
Write-Host "[*] Memulai Backend..." -ForegroundColor Green
Write-Host ""
Push-Location $backendDir
try {
    node --watch src/server.js
} finally {
    Pop-Location
}
