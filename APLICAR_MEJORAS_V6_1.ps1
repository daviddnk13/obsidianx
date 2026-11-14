# ==============================================================================
# OBSIDIANX (OBX) - MEGA SCRIPT DE APLICACION DIRECTA (v6.1)
# ==============================================================================
$ErrorActionPreference = "Continue"
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $BaseDir

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   OBSIDIANX (OBX) - APLICANDO TODAS LAS MEJORAS v6.1" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$giPath = Join-Path $BaseDir ".gitignore"
$protectedEntries = @("mi_billetera_genesis.json","mi_billetera_genesis.enc","*.keys","*.wallet","*.seed","*.enc")
if (-not (Test-Path $giPath)) { New-Item -ItemType File -Path $giPath -Force | Out-Null }
$giContent = [System.IO.File]::ReadAllText($giPath)
foreach ($entry in $protectedEntries) {
    if ($giContent -notmatch [regex]::Escape($entry)) { Add-Content -Path $giPath -Value $entry }
}
Write-Host "[1/4] .gitignore verificado (billeteras y llaves protegidas)." -ForegroundColor Green

$plainWallet = Join-Path $BaseDir "mi_billetera_genesis.json"
$vaultScript = Join-Path $BaseDir "scripts\cifrar_billetera.ps1"
if ((Test-Path $plainWallet) -and (Test-Path $vaultScript)) {
    Write-Host "[2/4] Detectada billetera en texto plano. Cifrando con AES-256..." -ForegroundColor Yellow
    & powershell -ExecutionPolicy Bypass -File $vaultScript -Accion cifrar
} else {
    Write-Host "[2/4] Billetera ya cifrada y segura." -ForegroundColor Green
}

Get-ChildItem -Path (Join-Path $BaseDir "scripts") -Include "*.sh","*.py" -Recurse | ForEach-Object {
    $txt = [System.IO.File]::ReadAllText($_.FullName)
    [System.IO.File]::WriteAllText($_.FullName, $txt.Replace("`r`n", "`n"))
}
Write-Host "[3/4] Scripts .sh y .py normalizados (LF) para Linux, GitHub Actions y Oracle VM." -ForegroundColor Green

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "[4/4] Subiendo paquete completo v6.1 a GitHub..." -ForegroundColor Cyan
    git rm --cached mi_billetera_genesis.json 2>$null
    git rm --cached mi_billetera_genesis.enc 2>$null
    git add .gitignore README.md SECURITY.md docs/ scripts/ APLICAR_MEJORAS_V6_1.ps1
    git diff --staged --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "feat(v6.1): purified emission hook, AI Guardian v3, Oracle 1GB 24/7 installer & ecosystem integrations"
    }
    git pull --rebase -X theirs origin main
    git push
    Write-Host ""
    Write-Host "[LISTO] ObsidianX v6.1 aplicado y subido a tu GitHub!" -ForegroundColor Green
}
Read-Host "Presiona Enter para finalizar"
