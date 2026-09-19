<#
.SYNOPSIS
  Collects Windows computer hardware information and returns it to the PowerShell output pipeline.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name,
        [string]$Default = 'No data available'
    )
    $value = $Object.$Name
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $Default }
    return $value
}

function Format-Bytes {
    param([Nullable[UInt64]]$Bytes)
    if ($null -eq $Bytes) { return 'No data available' }
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    return "$Bytes B"
}

$computerSystem = Get-CimInstance Win32_ComputerSystem
$bios           = Get-CimInstance Win32_BIOS
$baseboard      = Get-CimInstance Win32_BaseBoard
$os             = Get-CimInstance Win32_OperatingSystem
$cpu            = Get-CimInstance Win32_Processor
$gpus           = Get-CimInstance Win32_VideoController
$memory         = Get-CimInstance Win32_PhysicalMemory
$disks          = Get-CimInstance Win32_DiskDrive
$logicalDisks   = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$network        = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"

$report = [System.Collections.Generic.List[string]]::new()
$report.Add('HARDWARE REPORT')
$report.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$report.Add(('Computer: {0}' -f $env:COMPUTERNAME))
$report.Add('')

$report.Add('=== SYSTEM ===')
$report.Add(('Manufacturer: {0}' -f (Get-PropertyValue $computerSystem 'Manufacturer')))
$report.Add(('Model: {0}' -f (Get-PropertyValue $computerSystem 'Model')))
$report.Add(('System type: {0}' -f (Get-PropertyValue $computerSystem 'SystemType')))
$report.Add(('BIOS: {0} {1} ({2})' -f (Get-PropertyValue $bios 'Manufacturer'), (Get-PropertyValue $bios 'SMBIOSBIOSVersion'), (Get-PropertyValue $bios 'ReleaseDate')))
$report.Add('')

$report.Add('=== MOTHERBOARD ===')
foreach ($item in $baseboard) {
    $report.Add(('Manufacturer: {0}' -f (Get-PropertyValue $item 'Manufacturer')))
    $report.Add(('Product: {0}' -f (Get-PropertyValue $item 'Product')))
    $report.Add(('Version: {0}' -f (Get-PropertyValue $item 'Version')))
    $report.Add(('Serial number: {0}' -f (Get-PropertyValue $item 'SerialNumber')))
}
$report.Add('')

$report.Add('=== OPERATING SYSTEM ===')
$report.Add(('Name: {0}' -f (Get-PropertyValue $os 'Caption')))
$report.Add(('Version: {0} (build {1})' -f (Get-PropertyValue $os 'Version'), (Get-PropertyValue $os 'BuildNumber')))
$report.Add(('Architecture: {0}' -f (Get-PropertyValue $os 'OSArchitecture')))
$report.Add('')

$report.Add('=== PROCESSOR ===')
foreach ($item in $cpu) {
    $report.Add(('Name: {0}' -f (Get-PropertyValue $item 'Name')))
    $report.Add(('Cores / logical processors: {0} / {1}' -f $item.NumberOfCores, $item.NumberOfLogicalProcessors))
    $report.Add(('Maximum clock speed: {0} MHz' -f $item.MaxClockSpeed))
}
$report.Add('')

$totalMemory = ($memory | Measure-Object -Property Capacity -Sum).Sum
$report.Add('=== MEMORY (RAM) ===')
$report.Add(('Total: {0}' -f (Format-Bytes $totalMemory)))
foreach ($item in $memory) {
    $speed = if ($item.ConfiguredClockSpeed) { $item.ConfiguredClockSpeed } else { $item.Speed }
    $report.Add(('Slot {0}: {1}, {2} MHz, manufacturer: {3}' -f (Get-PropertyValue $item 'DeviceLocator'), (Format-Bytes $item.Capacity), $speed, (Get-PropertyValue $item 'Manufacturer')))
}
$report.Add('')

$report.Add('=== GRAPHICS CARDS ===')
foreach ($item in $gpus) {
    $ram = if ($item.AdapterRAM) { Format-Bytes ([UInt64]$item.AdapterRAM) } else { 'No data available' }
    $report.Add(('{0} | driver: {1} | memory: {2} | resolution: {3} x {4}' -f (Get-PropertyValue $item 'Name'), (Get-PropertyValue $item 'DriverVersion'), $ram, $item.CurrentHorizontalResolution, $item.CurrentVerticalResolution))
}
$report.Add('')

$report.Add('=== PHYSICAL DISKS ===')
foreach ($item in $disks) {
    $report.Add(('{0} | model: {1} | interface: {2} | size: {3}' -f (Get-PropertyValue $item 'DeviceID'), (Get-PropertyValue $item 'Model'), (Get-PropertyValue $item 'InterfaceType'), (Format-Bytes $item.Size)))
}
$report.Add('')

$report.Add('=== LOGICAL DISKS / PARTITIONS ===')
foreach ($item in $logicalDisks) {
    $report.Add(('{0} ({1}) | capacity: {2} | free space: {3}' -f $item.DeviceID, (Get-PropertyValue $item 'VolumeName' 'no label'), (Format-Bytes $item.Size), (Format-Bytes $item.FreeSpace)))
}
$report.Add('')

$report.Add('=== NETWORK ===')
foreach ($item in $network) {
    $report.Add(('{0} | MAC: {1} | IPv4: {2}' -f (Get-PropertyValue $item 'Description'), (Get-PropertyValue $item 'MACAddress'), (($item.IPAddress | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' }) -join ', ')))
}

# Return the report directly to the PowerShell output pipeline.
$report
