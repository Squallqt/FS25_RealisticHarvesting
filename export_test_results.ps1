# ==============================================================================
# RHM Harvest Test Results Exporter & Telemetry Viewer
# ==============================================================================

[CmdletBinding()]
param(
    [string]$XmlPath = "",
    [string]$LogPath = "",
    [switch]$ClearAfterExport
)

$myDocs = [Environment]::GetFolderPath("MyDocuments")
if ([string]::IsNullOrWhiteSpace($XmlPath)) {
    $XmlPath = Join-Path $myDocs "My Games\FarmingSimulator2025\modSettings\FS25_RealisticHarvesting\crop_test_records.xml"
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $myDocs "My Games\FarmingSimulator2025\log.txt"
}

$records = [System.Collections.Generic.List[PSCustomObject]]::new()

# 1. Parse XML file if present
if (Test-Path $XmlPath) {
    try {
        [xml]$xml = Get-Content -Path $XmlPath -Raw
        if ($xml.cropTestRecords -and $xml.cropTestRecords.record) {
            foreach ($rec in $xml.cropTestRecords.record) {
                $records.Add([PSCustomObject]@{
                    ID           = [int]$rec.id
                    Timestamp    = [string]$rec.timestamp
                    Crop         = [string]$rec.crop
                    Vehicle      = [string]$rec.vehicle
                    Category     = [string]$rec.category
                    MachineType  = [string]$rec.machineType
                    HP           = [double]$rec.engineHp
                    Width_m      = [double]$rec.width
                    HeaderPTO_HP = [double]$rec.headerHp
                    Yield_t_ha   = [double]$rec.yieldTph
                    Nominal_t_ha = [double]$rec.nominalYieldTph
                    Speed_kmh    = [double]$rec.speedKmh
                    Target_kmh   = [double]$rec.targetSpeedKmh
                    Tph          = [double]$rec.throughputTph
                    Load_pct     = [double]$rec.engineLoadPct
                    Loss_pct     = [double]$rec.cropLossPct
                    ESpec        = [double]$rec.eSpec
                    Moisture     = [double]$rec.moisture
                    P_base       = [double]$rec.pBase
                    P_header     = [double]$rec.pHeader
                    P_process    = [double]$rec.pProcess
                    P_soil       = [double]$rec.pSoil
                    P_total      = [double]$rec.pTotal
                })
            }
        }
    } catch {
        Write-Warning "Failed to parse XML file: $_"
    }
}

# 2. If XML has no records, fallback to parsing [RHM_CSV] lines in log.txt
if ($records.Count -eq 0 -and (Test-Path $LogPath)) {
    Write-Host "Scanning log.txt for [RHM_CSV] entries..."
    $lines = Get-Content -Path $LogPath | Where-Object { $_ -match "^\[RHM_CSV\];" }
    foreach ($line in $lines) {
        $parts = $line.Split(';')
        if ($parts.Length -ge 18) {
            $records.Add([PSCustomObject]@{
                ID           = [int]$parts[1]
                Timestamp    = [string]$parts[2]
                Crop         = [string]$parts[3]
                Vehicle      = [string]$parts[4]
                Category     = "log"
                MachineType  = "log"
                HP           = [double]$parts[5]
                Width_m      = [double]$parts[6]
                HeaderPTO_HP = 0.0
                Yield_t_ha   = [double]$parts[7]
                Nominal_t_ha = [double]$parts[8]
                Speed_kmh    = [double]$parts[9]
                Target_kmh   = [double]$parts[10]
                Tph          = [double]$parts[11]
                Load_pct     = [double]$parts[12]
                Loss_pct     = 0.0
                ESpec        = [double]$parts[13]
                Moisture     = 0.0
                P_base       = [double]$parts[14]
                P_header     = [double]$parts[15]
                P_process    = [double]$parts[16]
                P_soil       = [double]$parts[17]
                P_total      = [double]$parts[18]
            })
        }
    }
}

Write-Host ""
Write-Host "==========================================================================================================" -ForegroundColor Cyan
Write-Host "                       RHM HARVEST TEST RESULTS (TOTAL RECORDS: $($records.Count))" -ForegroundColor Cyan
Write-Host "==========================================================================================================" -ForegroundColor Cyan

if ($records.Count -eq 0) {
    Write-Host "No test records found yet." -ForegroundColor Yellow
    Write-Host "To record a harvest test in FS25:"
    Write-Host "  1. Start harvesting in any field."
    Write-Host "  2. Open console and type: rhm_record"
    Write-Host "     OR enable auto-recording: rhm_auto_record on"
    Write-Host "  3. Run this script again to see the compiled results!"
    Write-Host ""
    exit 0
}

# Display Table in Console
$displayTable = $records | Select-Object `
    @{N="#"; E={$_.ID}}, `
    @{N="Crop"; E={$_.Crop}}, `
    @{N="Vehicle"; E={$_.Vehicle}}, `
    @{N="HP"; E={"$($_.HP)"}}, `
    @{N="Width"; E={"$($_.Width_m)m"}}, `
    @{N="Yield"; E={"$([math]::Round($_.Yield_t_ha, 1)) t/ha"}}, `
    @{N="Speed"; E={"$([math]::Round($_.Speed_kmh, 1)) km/h"}}, `
    @{N="TargetV"; E={"$([math]::Round($_.Target_kmh, 1))"}}, `
    @{N="Load"; E={"$([math]::Round($_.Load_pct, 1))%"}}, `
    @{N="Throughput"; E={"$([math]::Round($_.Tph, 1)) t/h"}}, `
    @{N="E_spec"; E={"$([math]::Round($_.ESpec, 2))"}}, `
    @{N="Power (P_tot / P_eng)"; E={"$([math]::Round($_.P_total, 0)) / $([math]::Round($_.HP, 0)) HP"}}

$displayTable | Format-Table -AutoSize

# Export to CSV
$csvOutPath = Join-Path $PSScriptRoot "crop_test_summary.csv"
$records | Export-Csv -Path $csvOutPath -NoTypeInformation -Encoding utf8
Write-Host "Exported to CSV: $csvOutPath" -ForegroundColor Green

# Export to Markdown
$mdOutPath = Join-Path $PSScriptRoot "crop_test_summary.md"
$nowStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$mdLines = @(
    "# RHM Harvest Test Summary",
    "",
    "Total Records: **$($records.Count)** | Export Date: **$nowStr**",
    "",
    "| # | Crop | Vehicle | HP | Width | Yield (t/ha) | Speed (km/h) | Load (%) | Throughput (t/h) | E_spec | Power (Total / Eng) |",
    "|---|---|---|---|---|---|---|---|---|---|---|"
)

foreach ($r in $records) {
    $powStr = "$([math]::Round($r.P_total, 0)) / $([math]::Round($r.HP, 0)) HP"
    $mdLines += "| $($r.ID) | **$($r.Crop)** | $($r.Vehicle) | $($r.HP) HP | $($r.Width_m) m | $([math]::Round($r.Yield_t_ha, 1)) | **$([math]::Round($r.Speed_kmh, 1))** | **$([math]::Round($r.Load_pct, 1))%** | $([math]::Round($r.Tph, 1)) | $([math]::Round($r.ESpec, 2)) | $powStr |"
}

$mdLines += ""
[System.IO.File]::WriteAllLines($mdOutPath, $mdLines, [System.Text.Encoding]::UTF8)
Write-Host "Exported to Markdown: $mdOutPath" -ForegroundColor Green
Write-Host ""
