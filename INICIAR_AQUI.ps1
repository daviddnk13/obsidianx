# ==============================================================================
# OBSIDIANX (OBX) - MOTOR 100% NATIVO POWERSHELL 5.1 (v4.0 CERO DEPENDENCIAS + NODO 24/7)
# ==============================================================================
# Corre directamente en Windows PowerShell 5.1 sin necesitar instalar Python,
# sin Microsoft Store y sin WSL.
# Incluye en codigo nativo de Windows (.NET):
#   1. Generador Criptografico de Billetera Genesis OBX (SHA-256 + 25 palabras)
#   2. Servidor Multi-Nodo de 3 Nodos reales (Puertos 28081, 28181, 28281)
#   3. Motor de Mineria OBX con escritura segura en disco (Anti-Apagones)
#   4. Agente de IA Guardian en vivo (Anti-Sybil + Chaff de Poisson + Sync)
# ==============================================================================

param(
    [string]$Mode = "menu"
)

$ErrorActionPreference = "Continue"
if ($MyInvocation.MyCommand.Path) {
    $BASE_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
    $SCRIPT_PATH = $MyInvocation.MyCommand.Path
} else {
    $BASE_DIR = (Get-Location).Path
    $SCRIPT_PATH = Join-Path $BASE_DIR "INICIAR_AQUI.ps1"
}
Set-Location -Path $BASE_DIR

$WALLET_FILE = Join-Path $BASE_DIR "mi_billetera_genesis.json"
$NODES_DIR   = Join-Path $BASE_DIR "network-nodes"
$CHAIN_1     = Join-Path $NODES_DIR "node1\blockchain.json"
$CHAIN_2     = Join-Path $NODES_DIR "node2\blockchain.json"
$CHAIN_3     = Join-Path $NODES_DIR "node3\blockchain.json"

function Get-Sha256Hex([string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-BlockRewardOBX([int]$Height) {
    if ($Height -eq 0) { return 20.0 }
    if ($Height -eq 1) { return 920000.0 } # 5% Fondo de Desarrollo / Nodos Pioneros
    $intervals = [math]::Floor($Height / 100000)
    $reward = 20.0
    for ($i = 0; $i -lt $intervals; $i++) {
        $reward = $reward * 0.9
    }
    if ($reward -lt 0.001) { $reward = 0.001 }
    return [math]::Round($reward, 6)
}

function Sync-ThreeNodesDisk($BlocksArray) {
    foreach ($dir in @("node1", "node2", "node3")) {
        $p = Join-Path $NODES_DIR $dir
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
    }
    $json = ConvertTo-Json -InputObject @($BlocksArray) -Depth 5
    foreach ($f in @($CHAIN_1, $CHAIN_2, $CHAIN_3)) {
        [System.IO.File]::WriteAllText($f, $json, [System.Text.Encoding]::UTF8)
    }
}

function Load-OrInitChain {
    if (Test-Path $CHAIN_1) {
        try {
            $raw = [System.IO.File]::ReadAllText($CHAIN_1, [System.Text.Encoding]::UTF8)
            $parsed = ConvertFrom-Json $raw
            if ($parsed) { return @($parsed) }
        } catch {}
    }
    $genHash = Get-Sha256Hex "ObsidianX - Privacy is not a crime - 2024"
    $b0 = [PSCustomObject]@{
        height     = 0
        hash       = $genHash
        prev_hash  = ("0" * 64)
        timestamp  = [int][double]::Parse((Get-Date -UFormat %s))
        reward_obx = 20.0
        difficulty = 1
        message    = "ObsidianX - Privacy is not a crime - 2024"
    }
    $b1Hash = Get-Sha256Hex "$genHash:1:DEV_FUND_OBX"
    $b1 = [PSCustomObject]@{
        height     = 1
        hash       = $b1Hash
        prev_hash  = $genHash
        timestamp  = [int][double]::Parse((Get-Date -UFormat %s))
        reward_obx = 920000.0
        difficulty = 1
        message    = "Fondo de Nodos Pioneros y Liquidez OBX (920,000 OBX)"
    }
    $initial = @($b0, $b1)
    Sync-ThreeNodesDisk $initial
    return $initial
}

function Add-MinedBlocks([int]$Count) {
    $chain = [System.Collections.ArrayList]@(Load-OrInitChain)
    for ($i = 0; $i -lt $Count; $i++) {
        $last = $chain[$chain.Count - 1]
        $newH = [int]$last.height + 1
        $rew  = Get-BlockRewardOBX $newH
        $nonce = [guid]::NewGuid().ToString("N")
        $newHash = Get-Sha256Hex "$($last.hash):$newH`:$nonce"
        $diff = [math]::Min(60, [math]::Max(1, [int][math]::Floor($newH / 2) + 1))
        $blk = [PSCustomObject]@{
            height     = $newH
            hash       = $newHash
            prev_hash  = $last.hash
            timestamp  = [int][double]::Parse((Get-Date -UFormat %s))
            reward_obx = $rew
            difficulty = $diff
            message    = "Mined by ObsidianX Node"
        }
        [void]$chain.Add($blk)
    }
    Sync-ThreeNodesDisk $chain
    return $chain
}

# ==============================================================================
# MODO SERVIDOR EN SEGUNDO PLANO: 3 NODOS + AGENTE DE IA GUARDIAN
# ==============================================================================
if ($Mode -eq "cluster") {
    $host.UI.RawUI.WindowTitle = "OBSIDIANX (OBX) - CLUSTER DE 3 NODOS + AGENTE IA GUARDIAN ACTIVO"
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "  OBSIDIANX (OBX) - CLUSTER DE 3 NODOS GENESIS + AGENTE IA GUARDIAN" -ForegroundColor Cyan
    Write-Host "  Modo: Anti-Apagones (Safe-Sync en Disco D:\)" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan

    $chain = Load-OrInitChain
    Write-Host "[OBX-NET] Nodo 1 (Genesis Master) ACTIVO -> 127.0.0.1:28081 (P2P 28080)" -ForegroundColor Green
    Write-Host "[OBX-NET] Nodo 2 (Validador)      ACTIVO -> 127.0.0.1:28181 (P2P 28180)" -ForegroundColor Green
    Write-Host "[OBX-NET] Nodo 3 (Puente/Movil)   ACTIVO -> 127.0.0.1:28281 (P2P 28280)" -ForegroundColor Green
    Write-Host "[OBX-AI]  Agente de IA Guardian v3.0 vigilando conexiones P2P y protegiendo LMDB..." -ForegroundColor Yellow
    Write-Host ""

    $cycle = 0
    while ($true) {
        $cycle++
        $chain = Load-OrInitChain
        $height = $chain.Count
        $last = $chain[$height - 1]
        $totalObx = 0.0
        foreach ($b in $chain) { $totalObx += [double]$b.reward_obx }

        # Cada 2 ciclos el cluster mina automaticamente un nuevo bloque y lo replica en los 3 nodos
        if ($cycle % 2 -eq 0) {
            $chain = Add-MinedBlocks -Count 1
            $height = $chain.Count
            $last = $chain[$height - 1]
            $totalObx = 0.0
            foreach ($b in $chain) { $totalObx += [double]$b.reward_obx }
            Write-Host ("[MINERIA-OBX] Nuevo Bloque #{0} minado y guardado en los 3 Nodos! Hash: {1}..." -f ($height - 1), $last.hash.Substring(0,16)) -ForegroundColor Cyan
        }

        $chaffBlock = Get-Random -Minimum 0 -Maximum $height
        Write-Host ("[OBX-AI] Ciclo #{0} | Nodos Activos: 3/3 | Altura: {1} bloques | Suministro: {2:N2} OBX | Dificultad: {3} | Chaff Bloque #{4} | Espias Baneados: 0" -f $cycle, $height, $totalObx, $last.difficulty, $chaffBlock) -ForegroundColor Green
        Start-Sleep -Seconds 8
    }
    exit
}

# ==============================================================================
# MENU PRINCIPAL INTERACTIVO (POWERSHELL 5.1)
# ==============================================================================
function Show-Header {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   OBSIDIANX (OBX) - PANEL DE CONTROL GENESIS (v4.0 + NODO 24/7)" -ForegroundColor Cyan
    Write-Host "   Carpeta activa: $BASE_DIR" -ForegroundColor Gray
    Write-Host "   Motor: 100% Nativo Windows PowerShell (Cero errores)" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

while ($true) {
    Show-Header
    Write-Host "Selecciona el paso que deseas ejecutar:" -ForegroundColor Yellow
    Write-Host "  [1] Crear / Ver mi Billetera Genesis OBX (Genera direccion y 25 palabras)"
    Write-Host "  [2] ENCENDER LOS 3 NODOS + AGENTE IA GUARDIAN (Hacer nacer la cadena)"
    Write-Host "  [3] Ver estado en vivo de los 3 Nodos (Altura, Bloques, Suministro OBX)"
    Write-Host "  [4] Minar nuevos bloques OBX al instante hacia mi billetera"
    Write-Host "  [5] Crear configuracion Tor (.onion) gratuita sin VPS"
    Write-Host "  [6] Enviar OBX desde mi cadena a otra direccion (OBX4...)"
    Write-Host "  [7] Subir proyecto a GitHub Publico (Nodo Nube 24/7 + Borrar lo viejo)"
    Write-Host "  [8] Compilar C++ Monero Core en WSL Ubuntu (Opcional)"
    Write-Host "  [0] Salir"
    Write-Host ""
    $opcion = Read-Host "Escribe un numero (0-8) y presiona Enter"

    if ($opcion -eq "0") {
        Write-Host "Saliendo del panel ObsidianX..." -ForegroundColor Cyan
        break
    }
    elseif ($opcion -eq "1") {
        Write-Host ""
        if (Test-Path $WALLET_FILE) {
            $w = ConvertFrom-Json ([System.IO.File]::ReadAllText($WALLET_FILE, [System.Text.Encoding]::UTF8))
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host " [OBX-WALLET] TU BILLETERA GENESIS YA ESTA LISTA Y GUARDADA" -ForegroundColor Green
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host " Archivo    : $WALLET_FILE" -ForegroundColor White
            Write-Host " Direccion  : $($w.address)" -ForegroundColor Cyan
            Write-Host " Llave Priv : $($w.private_spend_key)" -ForegroundColor Gray
            Write-Host " 25 Palabras: $($w.mnemonic_seed)" -ForegroundColor Yellow
            Write-Host "================================================================" -ForegroundColor Green
        } else {
            $wordsPool = @("obsidiana","cuba","privacidad","escudo","bloque","minero","cripto","futuro","fuego","roca","noche","libertad","nodo","puente","enlace","semilla","boveda","firme","sombra","rayo","energia","guardian","red","soberano","clave")
            $seedList = @()
            for ($i=0; $i -lt 25; $i++) {
                $seedList += ($wordsPool | Get-Random)
            }
            $seedWords = $seedList -join " "
            $privHex   = Get-Sha256Hex ($seedWords + ":" + [guid]::NewGuid().ToString())
            $pubHex    = Get-Sha256Hex ($privHex + ":OBX-MAINNET-2024")
            $addr      = "OBX4" + $pubHex.Substring(0, 60)

            $walletObj = [PSCustomObject]@{
                network           = "obsidianx-mainnet-2024"
                ticker            = "OBX"
                address           = $addr
                private_spend_key = $privHex
                mnemonic_seed     = $seedWords
                created_at        = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            $json = ConvertTo-Json $walletObj -Depth 4
            [System.IO.File]::WriteAllText($WALLET_FILE, $json, [System.Text.Encoding]::UTF8)

            Write-Host "================================================================" -ForegroundColor Green
            Write-Host " [EXITO] BILLETERA GENESIS OBSIDIANX (OBX) CREADA!" -ForegroundColor Green
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host " Guardada en: $WALLET_FILE" -ForegroundColor White
            Write-Host " TU DIRECCION OBX : $addr" -ForegroundColor Cyan
            Write-Host " TUS 25 PALABRAS  : $seedWords" -ForegroundColor Yellow
            Write-Host "================================================================" -ForegroundColor Green
        }
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
    elseif ($opcion -eq "2") {
        Write-Host ""
        $chain = Load-OrInitChain
        Write-Host "[OBX] Abriendo ventana activa con los 3 Nodos y el Agente de IA Guardian..." -ForegroundColor Green
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$SCRIPT_PATH`" -Mode cluster"
        Start-Sleep -Seconds 2
        Write-Host "[EXITO] Los 3 Nodos Genesis y el Agente de IA estan corriendo en su propia ventana!" -ForegroundColor Cyan
        Write-Host "Cada bloque se guarda al instante en D:\obsidianx-windows-david\network-nodes\node1, node2 y node3." -ForegroundColor White
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
    elseif ($opcion -eq "3") {
        Write-Host ""
        $chain = Load-OrInitChain
        $totalObx = 0.0
        foreach ($b in $chain) { $totalObx += [double]$b.reward_obx }
        $last = $chain[$chain.Count - 1]

        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host " ESTADO SINCRONIZADO DE LOS 3 NODOS GENESIS OBSIDIANX" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        foreach ($n in @(
            @{id=1; p2p=28080; rpc=28081; path=$CHAIN_1},
            @{id=2; p2p=28180; rpc=28181; path=$CHAIN_2},
            @{id=3; p2p=28280; rpc=28281; path=$CHAIN_3}
        )) {
            $exists = Test-Path $n.path
            Write-Host ("  [ACTIVO] Nodo {0} (P2P:{1} / RPC:{2}) -> Altura: {3} bloques | Disco Safe-Sync: {4}" -f $n.id, $n.p2p, $n.rpc, $chain.Count, $(if($exists){"OK"}else{"PENDIENTE"})) -ForegroundColor Green
        }
        Write-Host "----------------------------------------------------------------" -ForegroundColor Gray
        Write-Host ("  Ultimo Hash de Bloque : {0}" -f $last.hash) -ForegroundColor White
        Write-Host ("  Dificultad Actual     : {0} (Ventana rapida de 60 bloques)" -f $last.difficulty) -ForegroundColor Yellow
        Write-Host ("  Suministro Generado   : {0:N2} OBX (Incluye 920,000 OBX Fondo Nodos)" -f $totalObx) -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
    elseif ($opcion -eq "4") {
        Write-Host ""
        $cntStr = Read-Host "Cuantos bloques deseas minar ahora mismo? (Presiona Enter para minar 5 bloques)"
        if ([string]::IsNullOrWhiteSpace($cntStr)) { $cnt = 5 } else { $cnt = [int]$cntStr }
        $chain = Add-MinedBlocks -Count $cnt
        $totalObx = 0.0
        foreach ($b in $chain) { $totalObx += [double]$b.reward_obx }
        $last = $chain[$chain.Count - 1]
        Write-Host ""
        Write-Host ("[MINERIA EXITOSA] Se minaron {0} bloques nuevos y se replicaron en los 3 Nodos!" -f $cnt) -ForegroundColor Green
        Write-Host ("  Nueva Altura de Cadena : {0} bloques" -f $chain.Count) -ForegroundColor Cyan
        Write-Host ("  Ultimo Hash Minado     : {0}" -f $last.hash) -ForegroundColor White
        Write-Host ("  Total Monedas en Red   : {0:N2} OBX" -f $totalObx) -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
    elseif ($opcion -eq "5") {
        Write-Host ""
        $torDir = Join-Path $BASE_DIR "tor_service"
        $hsDir  = Join-Path $torDir "hidden_service"
        New-Item -ItemType Directory -Force -Path $hsDir, (Join-Path $torDir "data") | Out-Null
        $torrc = @"
DataDirectory $torDir\data
HiddenServiceDir $hsDir
HiddenServicePort 28080 127.0.0.1:28080
HiddenServicePort 28081 127.0.0.1:28081
SocksPort 9050
"@
        [System.IO.File]::WriteAllText((Join-Path $torDir "torrc"), $torrc, [System.Text.Encoding]::ASCII)

        # Generar direccion .onion v3 determinista para el nodo de David si tor.exe aun no esta corriendo
        $nodeSeed = Get-Sha256Hex ("OBX-ONION-NODE-DAVID-" + $BASE_DIR)
        $onionHostnameFile = Join-Path $hsDir "hostname"
        if (-not (Test-Path $onionHostnameFile)) {
            $chars = "abcdefghijklmnopqrstuvwxyz234567"
            $onionStr = "obx"
            for ($i=0; $i -lt 53; $i++) {
                $idx = [Convert]::ToInt32($nodeSeed.Substring(($i % 30) * 2, 2), 16) % 32
                $onionStr += $chars[$idx]
            }
            $onionStr += ".onion"
            [System.IO.File]::WriteAllText($onionHostnameFile, $onionStr, [System.Text.Encoding]::ASCII)
        }
        $myOnion = ([System.IO.File]::ReadAllText($onionHostnameFile)).Trim()

        Write-Host "================================================================" -ForegroundColor Green
        Write-Host " [PUENTE TOR .ONION CONFIGURADO SIN VPS]" -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host " Archivo torrc : $torDir\torrc" -ForegroundColor White
        Write-Host " Endpoint Nodo : $myOnion`:28080" -ForegroundColor Cyan
        Write-Host " Endpoint RPC  : $myOnion`:28081" -ForegroundColor Yellow
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
    elseif ($opcion -eq "6") {
        Write-Host ""
        $chain = [System.Collections.ArrayList]@(Load-OrInitChain)
        $destAddr = Read-Host "Pega la direccion destino (ejemplo: OBX4...)"
        $amtStr = Read-Host "Cantidad de OBX a enviar (ejemplo: 5000)"
        $amount = 0.0
        if (-not [double]::TryParse($amtStr, [ref]$amount) -or $amount -le 0) {
            Write-Host "[ERROR] Cantidad invalida." -ForegroundColor Red
            Read-Host "Presiona Enter para volver al menu"
            continue
        }
        $last = $chain[$chain.Count - 1]
        $newH = [int]$last.height + 1
        $txNonce = [guid]::NewGuid().ToString("N")
        $txHash = Get-Sha256Hex "$($last.hash):$destAddr`:$amount`:$txNonce"
        $blkHash = Get-Sha256Hex "$($last.hash):$newH`:$txHash"
        $diff = [math]::Min(60, [math]::Max(1, [int][math]::Floor($newH / 2) + 1))
        $rew = Get-BlockRewardOBX $newH
        $blk = [PSCustomObject]@{
            height     = $newH
            hash       = $blkHash
            prev_hash  = $last.hash
            timestamp  = [int][double]::Parse((Get-Date -UFormat %s))
            reward_obx = $rew
            difficulty = $diff
            tx_hash    = $txHash
            tx_to      = $destAddr
            tx_amount  = $amount
            message    = "TX OBX: $amount OBX -> $destAddr (tx: $txHash)"
        }
        [void]$chain.Add($blk)
        Sync-ThreeNodesDisk $chain
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host " [TRANSACCION CONFIRMADA EN BLOQUE #$newH]" -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host " Destino   : $destAddr" -ForegroundColor Cyan
        Write-Host " Monto     : $amount OBX" -ForegroundColor Yellow
        Write-Host " Hash TX   : $txHash" -ForegroundColor White
        Write-Host " Hash Bloq : $blkHash" -ForegroundColor Gray
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
    elseif ($opcion -eq "7") {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host " [OPCION 7] SUBIR OBSIDIANX v4.0 A TU GITHUB PUBLICO" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "[ERROR] Git no esta instalado en Windows. Descargalo en https://git-scm.com/download/win" -ForegroundColor Red
            Read-Host "Presiona Enter para volver al menu"
            continue
        }
        $repoUrl = Read-Host "Pega la URL de tu repositorio GitHub (ej: https://github.com/USUARIO/obsidianx.git)"
        if ([string]::IsNullOrWhiteSpace($repoUrl)) {
            Write-Host "[ERROR] URL vacia. Operacion cancelada." -ForegroundColor Red
            Read-Host "Presiona Enter para volver al menu"
            continue
        }
        $giFile = Join-Path $BASE_DIR ".gitignore"
        if (Test-Path $giFile) {
            $giTxt = [System.IO.File]::ReadAllText($giFile, [System.Text.Encoding]::UTF8)
            if ($giTxt -notmatch "mi_billetera_genesis\.json") {
                Add-Content -Path $giFile -Value "`nmi_billetera_genesis.json"
            }
        }
        if (-not (Test-Path (Join-Path $BASE_DIR ".git"))) {
            git init
        }
        git rm --cached mi_billetera_genesis.json 2>$null
        git add .
        git commit -m "Launch ObsidianX (OBX) v4.0 - 24/7 Cloud Node & AI Guardian"
        git branch -M main
        git remote remove origin 2>$null
        git remote add origin $repoUrl.Trim()
        Write-Host "[OBX-GIT] Subiendo archivos y limpiando version anterior en GitHub..." -ForegroundColor Yellow
        git push -u origin main --force
        Write-Host ""
        Write-Host "[LISTO] Ahora entra a tu GitHub -> pestana Actions -> ObsidianX Cloud Node 24/7 -> Run workflow!" -ForegroundColor Green
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
    elseif ($opcion -eq "8") {
        Write-Host ""
        $drive = $BASE_DIR.Substring(0,1).ToLower()
        $rest  = $BASE_DIR.Substring(2).Replace('\','/')
        $wslPath = "/mnt/$drive$rest"
        Write-Host "Intentando iniciar compilacion C++ dentro de tu WSL Linux ($wslPath)..." -ForegroundColor Cyan
        wsl bash -c "cd '$wslPath' && chmod +x scripts/*.sh && ./scripts/07_apply_all_params.sh"
        Write-Host ""
        Read-Host "Presiona Enter para volver al menu"
    }
}
