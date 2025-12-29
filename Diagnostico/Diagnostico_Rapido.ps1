# SCRIPT DE DIAGNÓSTICO TI - VERSIÓN FINAL INTEGRADA
# Incluye: ISP Lookup con nombre, Uso de CPU, RAM, Disco y Seguridad.

Clear-Host
Write-Host "--- REPORTE DE DIAGNÓSTICO (Soporte TI) ---" -ForegroundColor Cyan

# -----------------------------------------------------------------
# 1. SISTEMA OPERATIVO Y VERSIÓN
# -----------------------------------------------------------------
$OS = Get-CimInstance Win32_OperatingSystem
$OSVersion = $OS.Caption
$OSBuild = $OS.BuildNumber

Write-Host "`n[S.O. Y VERSIÓN:] " -NoNewline -ForegroundColor Yellow
Write-Host "$($OSVersion) (Build $OSBuild)" -ForegroundColor White

# -----------------------------------------------------------------
# 2. CONECTIVIDAD EXTERNA
# -----------------------------------------------------------------
Write-Host "[INTERNET EXTERNO:] " -NoNewline -ForegroundColor Yellow
$PingResult = Test-Connection -ComputerName "8.8.8.8" -Count 1 -ErrorAction SilentlyContinue

if ($PingResult) {
    Write-Host "OK (Acceso a Internet)" -ForegroundColor Green
} else {
    Write-Host "FALLO (Sin acceso a Internet)" -ForegroundColor Red
}

# -----------------------------------------------------------------
# 3. LOOKUP DE PROVEEDOR (ISP)
# -----------------------------------------------------------------
Write-Host "[PROVEEDOR ACTUAL:] " -NoNewline -ForegroundColor Yellow

try {
    # Usamos ipinfo.io/json para obtener el nombre de la organización
    $Lookup = Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 5 -ErrorAction Stop
    
    if ($Lookup.org) {
        # Limpiamos el texto para quitar el número de AS y dejar solo el nombre comercial
        $NombreISP = $Lookup.org -replace 'AS\d+\s', ''
        Write-Host "$($NombreISP) (IP: $($Lookup.ip))" -ForegroundColor Green
    } else {
        Write-Host "Identificado por IP: $($Lookup.ip)" -ForegroundColor Green
    }
} catch {
    Write-Host "No se pudo identificar el nombre (Verificar salida a Internet)" -ForegroundColor Red
}

# -----------------------------------------------------------------
# 4. CONEXIÓN DE RED LOCAL
# -----------------------------------------------------------------
Write-Host "[CONEXIÓN LOCAL:] " -NoNewline -ForegroundColor Yellow

$ActiveAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -notlike "*VPN*" -and $_.Name -notlike "*Virtual*" } | Select-Object -First 1

if ($ActiveAdapter) {
    $AdapterName = $ActiveAdapter.Name
    try {
        $WifiInfo = (netsh wlan show interfaces | Select-String "SSID" -Context 0, 1 | Select-Object -Last 1).ToString().Trim()
        if ($WifiInfo -like "*SSID*") {
            $SSID = $WifiInfo -replace '.*: '
            Write-Host "Wi-Fi: $($SSID)" -ForegroundColor Green
        } else {
            Write-Host "Cable: $($AdapterName)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Conectado: $($AdapterName)" -ForegroundColor Green
    }
} else {
    Write-Host "DESCONECTADO" -ForegroundColor Red
}

# -----------------------------------------------------------------
# 5. DIRECCIÓN IP Y DNS
# -----------------------------------------------------------------
if ($ActiveAdapter) {
    $IPAddress = Get-NetIPAddress -InterfaceAlias $ActiveAdapter.Name -AddressFamily IPv4 | Where-Object { $_.PrefixLength -ne 128 } | Select-Object -ExpandProperty IPAddress -First 1
    $DnsServers = (Get-DnsClientServerAddress -InterfaceAlias $ActiveAdapter.Name).ServerAddresses -join ", "
    
    Write-Host "[DIRECCIÓN IP LOCAL:] " -NoNewline -ForegroundColor Yellow
    Write-Host "$($IPAddress)" -ForegroundColor Green
    Write-Host "[DNS PRINCIPALES:] " -NoNewline -ForegroundColor Yellow
    Write-Host "$($DnsServers)" -ForegroundColor Green
}

# -----------------------------------------------------------------
# 6. RECURSOS DEL SISTEMA (CPU, RAM, DISCO)
# -----------------------------------------------------------------
# --- CPU ---
Write-Host "[USO DE CPU:] " -NoNewline -ForegroundColor Yellow
try {
    $CPUUsage = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Where-Object {$_.Name -eq "_Total"}).PercentProcessorTime
    $CPUUsage = [math]::Round($CPUUsage, 1)
    if ($CPUUsage -gt 85) { Write-Host "$($CPUUsage)%" -ForegroundColor Red } else { Write-Host "$($CPUUsage)%" -ForegroundColor Green }
} catch { Write-Host "No disponible" -ForegroundColor Yellow }

# --- RAM ---
$Memory = Get-WmiObject -Class Win32_OperatingSystem
$UsedRAM = [math]::Round((($Memory.TotalVisibleMemorySize - $Memory.FreePhysicalMemory) / $Memory.TotalVisibleMemorySize) * 100, 1)
Write-Host "[MEMORIA RAM:] " -NoNewline -ForegroundColor Yellow
if ($UsedRAM -gt 85) { Write-Host "$($UsedRAM)% Usado" -ForegroundColor Red } else { Write-Host "$($UsedRAM)% Usado" -ForegroundColor Green }

# --- DISCO ---
$Disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
$FreeSpace = [math]::Round(($Disk.FreeSpace / $Disk.Size) * 100, 1)
Write-Host "[DISCO C:] " -NoNewline -ForegroundColor Yellow
if ($FreeSpace -lt 15) { Write-Host "$($FreeSpace)% Libre" -ForegroundColor Red } else { Write-Host "$($FreeSpace)% Libre" -ForegroundColor Green }

# -----------------------------------------------------------------
# 7. SEGURIDAD Y SERVICIOS
# -----------------------------------------------------------------
Write-Host "`n[ANTIVIRUS:] " -NoNewline -ForegroundColor Yellow
$AV = Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntivirusProduct | Where-Object { $_.productState -ne 393472 } | Select-Object -First 1
if ($AV) { Write-Host "ACTIVO: $($AV.DisplayName)" -ForegroundColor Green } else { Write-Host "NO DETECTADO" -ForegroundColor Red }

$FW = Get-Service -Name MpsSvc -ErrorAction SilentlyContinue
Write-Host "[FIREWALL:] " -NoNewline -ForegroundColor Yellow
if ($FW.Status -eq "Running") { Write-Host "ACTIVO" -ForegroundColor Green } else { Write-Host "INACTIVO" -ForegroundColor Red }

$VPN = Get-NetAdapter | Where-Object { ($_.InterfaceDescription -like "*VPN*" -or $_.Name -like "*VPN*") -and $_.Status -eq "Up" }
Write-Host "[VPN:] " -NoNewline -ForegroundColor Yellow
if ($VPN) { Write-Host "CONECTADO" -ForegroundColor Green } else { Write-Host "DESCONECTADO" -ForegroundColor Red }

$UpdateSvc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
Write-Host "[SERVICIO UPDATE:] " -NoNewline -ForegroundColor Yellow
if ($UpdateSvc.Status -eq "Running") { Write-Host "ACTIVO" -ForegroundColor Green } else { Write-Host "DETENIDO" -ForegroundColor Red }

Write-Host "----------------------------------------------" -ForegroundColor Cyan