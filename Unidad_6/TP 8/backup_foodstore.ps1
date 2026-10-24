# backup_foodstore.ps1
# Respaldo automatizable de la base foodstore (formato custom para pg_restore)
# Parte 2 - TP Unidad 6 - Food Store
#
# Requisitos cumplidos:
#  * pg_dump en formato custom (-Fc)
#  * Fecha y hora en el nombre del archivo
#  * Registro del resultado en carpeta logs/
#  * Finaliza con error si pg_dump falla
#  * No contiene contraseña

# ===================== Configuración (sin contraseñas) =====================
$pgHost   = "localhost"
$pgPort   = "5432"
$user     = "postgres"
$database = "foods_store_completo"

# Directorios relativos a la ubicación de este script
$backupDir = Join-Path $PSScriptRoot "backups"
$logDir    = Join-Path $PSScriptRoot "logs"

# Crear directorios si no existen
if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
if (!(Test-Path $logDir))    { New-Item -ItemType Directory -Path $logDir | Out-Null }

# Fecha y hora para nombre de archivo y log
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$backupFile = Join-Path $backupDir "foodstore_$timestamp.dump"
$logFile    = Join-Path $logDir    "backup_$timestamp.log"

# Función para escribir en log y consola
function Write-Log {
    param([string]$Message, [string]$LogPath)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    if (-not [string]::IsNullOrEmpty($LogPath)) {
        Add-Content -Path $LogPath -Value $line
    }
    Write-Host $line
}

# Ruta completa de pg_dump (PostgreSQL 17)
$pgDumpPath = "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"

# ===================== Ejecución del respaldo =====================
try {
    Write-Log "Iniciando respaldo de la base '$database' en ${pgHost}:${pgPort}" -LogPath $logFile
    Write-Log "Archivo de destino: $backupFile" -LogPath $logFile
    Write-Log "Usando pg_dump: $pgDumpPath" -LogPath $logFile

    # Ejecutar pg_dump (formato custom -Fc).
    # La contraseña NO se escribe aquí. Se espera que PGPASSWORD esté definida
    # en el entorno o que se use autenticación integrada de PostgreSQL/Windows.
    $pgOutput = & $pgDumpPath -h $pgHost -p $pgPort -U $user -d $database -Fc -f $backupFile 2>&1

    $exitCode = $LASTEXITCODE

    # Registrar la salida de pg_dump en el log (incluye mensajes de error)
    if ($pgOutput) {
        foreach ($line in $pgOutput) {
            Write-Log "pg_dump: $line" -LogPath $logFile
        }
    }

    if ($exitCode -eq 0) {
        Write-Log "Respaldo completado exitosamente: $backupFile" -LogPath $logFile
        exit 0
    }
    else {
        Write-Log "ERROR: pg_dump falló con código de salida $exitCode" -LogPath $logFile
        exit $exitCode
    }
}
catch {
    Write-Log "ERROR inesperado: $_" -LogPath $logFile
    exit 1
}
