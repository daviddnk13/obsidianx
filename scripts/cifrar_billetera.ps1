# ==============================================================================
# ObsidianX (OBX) - Cifrado AES-256 para mi_billetera_genesis.json (Windows)
# ==============================================================================
param(
    [ValidateSet("cifrar","descifrar")]
    [string]$Accion = "cifrar"
)

$BaseDir   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$PlainFile = Join-Path $BaseDir "mi_billetera_genesis.json"
$EncFile   = Join-Path $BaseDir "mi_billetera_genesis.enc"

function Derive-Key([string]$Password, [byte[]]$Salt) {
    $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    return $pbkdf2.GetBytes(32)
}

$secPass = Read-Host "Escribe una contrasena fuerte para tu boveda" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPass)
$pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

if ($Accion -eq "cifrar") {
    if (-not (Test-Path $PlainFile)) {
        Write-Host "[ERROR] No se encontro $PlainFile" -ForegroundColor Red
        exit 1
    }
    $plainBytes = [System.IO.File]::ReadAllBytes($PlainFile)
    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
    $key = Derive-Key $pass $salt

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.GenerateIV()
    $enc = $aes.CreateEncryptor().TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

    $outBytes = $salt + $aes.IV + $enc
    [System.IO.File]::WriteAllBytes($EncFile, $outBytes)
    Write-Host "[OK] Billetera cifrada en: $EncFile" -ForegroundColor Green

    $del = Read-Host "Deseas borrar el archivo en texto plano mi_billetera_genesis.json? (S/N)"
    if ($del -match "^[Ss]$") {
        Remove-Item $PlainFile -Force
        Write-Host "[SEGURIDAD] Archivo en texto plano eliminado." -ForegroundColor Yellow
    }
} else {
    if (-not (Test-Path $EncFile)) {
        Write-Host "[ERROR] No se encontro $EncFile" -ForegroundColor Red
        exit 1
    }
    $all  = [System.IO.File]::ReadAllBytes($EncFile)
    $salt = $all[0..15]
    $iv   = $all[16..31]
    $cipher = $all[32..($all.Length - 1)]
    $key  = Derive-Key $pass $salt

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV  = $iv
    try {
        $dec = $aes.CreateDecryptor().TransformFinalBlock($cipher, 0, $cipher.Length)
        [System.IO.File]::WriteAllBytes($PlainFile, $dec)
        Write-Host "[OK] Billetera descifrada temporalmente en: $PlainFile" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Contrasena incorrecta o archivo danado." -ForegroundColor Red
    }
}
