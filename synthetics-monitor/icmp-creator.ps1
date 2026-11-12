<#
.SYNOPSIS
    Kibana Synthetics ICMP Bulk Monitor Creator

.DESCRIPTION
    A professional PowerShell script to bulk-create ICMP monitors in Kibana Synthetics.
    Reads a structured text file and provisions monitors via the Kibana API.
    Compatible with Windows PowerShell 5.1 and PowerShell 7+.

.PARAMETER f
    Path to the text file containing the monitor list.

.PARAMETER k
    Kibana URL (If omitted, you will be prompted).

.PARAMETER a
    Kibana API Key (If omitted, you will be prompted).

.PARAMETER l
    Private Location Name (If omitted, you will be prompted).

.PARAMETER s
    Schedule interval in minutes (Default: 3).

.PARAMETER t
    Timeout in seconds (Default: 16).

.PARAMETER e
    Enable or disable the monitor (Default: true).

.PARAMETER n
    Namespace for the data stream (Default: "default").

.PARAMETER lbl
    Labels in "key:value,key2:value2" format (Default: empty).

.PARAMETER al
    Enable status alerts (Default: true).

.PARAMETER re
    Retest on failure (Default: true).

.PARAMETER h
    Show this help menu (--help also works).

.EXAMPLE
    .\icmp-creator.ps1 -f .\List.txt

.EXAMPLE
    .\icmp-creator.ps1 -f .\List.txt -s 5 -t 30 -lbl "env:prod,team:network"
#>

param (
    [Alias('f')] [string]$FilePath,
    [Alias('k')] [string]$KibanaUrl = "",
    [Alias('a')] [string]$ApiKey = "",
    [Alias('l')] [string]$Location = "",
    
    # Advanced optional parameters
    [Alias('s')] [int]$Schedule = 0,
    [Alias('t')] [int]$Timeout = 0,
    [Alias('e')] [string]$Enabled = "",
    [Alias('n')] [string]$Namespace = "",
    [Alias('lbl')] [string]$Labels = "",
    [Alias('al')] [string]$AlertStatus = "",
    [Alias('re')] [string]$RetestOnFailure = "",

    [Alias('h')] [switch]$Help
)

# Handle custom --help switch
if ($args -contains '--help') { $Help = $true }

# Display Help
if ($Help) {
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   Kibana ICMP Monitor Creator - Help" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\icmp-creator.ps1 -f <path_to_txt> [-s <min>] [-t <sec>] ..."
    Write-Host ""
    Write-Host "REQUIRED:" -ForegroundColor Yellow
    Write-Host "  -f   : Path to the text file containing targets."
    Write-Host ""
    Write-Host "CONNECTION:" -ForegroundColor Yellow
    Write-Host "  -k   : Kibana URL (If omitted, you will be prompted)."
    Write-Host "  -a   : API Key (If omitted, you will be prompted)."
    Write-Host "  -l   : Private Location (If omitted, you will be prompted)."
    Write-Host ""
    Write-Host "ADVANCED SETTINGS (Optional):" -ForegroundColor Yellow
    Write-Host "  -s   : Schedule in minutes (Default: 3) [1,3,5,10,15,30,60,120,240]"
    Write-Host "  -t   : Timeout in seconds (Default: 16)"
    Write-Host "  -e   : Enabled state (Default: true) [true/false]"
    Write-Host "  -n   : Data stream namespace (Default: ""default"")"
    Write-Host "  -lbl : Labels e.g. ""env:prod,team:network"" (Default: none)"
    Write-Host "  -al  : Alert on status change (Default: true) [true/false]"
    Write-Host "  -re  : Retest on failure (Default: true) [true/false]"
    Write-Host "  -h   : Display this help menu."
    Write-Host ""
    Write-Host "FILE FORMAT (one line per monitor):" -ForegroundColor Yellow
    Write-Host "  IP|Name|Tag1,Tag2"
    Write-Host ""
    Write-Host "EXAMPLE FILE CONTENT:" -ForegroundColor Green
    Write-Host "  10.0.0.1|server-alpha - windows - 10.0.0.1|Windows"
    Write-Host "  10.0.0.2|core-router - cisco-ios - 10.0.0.2|CiscoRS"
    Write-Host "  10.0.0.3|fw-edge - fortigate - 10.0.0.3|Firewall,Edge"
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor Yellow
    Write-Host "  Execution Policy error? Run once per session:"
    Write-Host "    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass" -ForegroundColor Green
    Write-Host ""
    exit
}

# Validate Input File
if (-not $FilePath) {
    Write-Host "Error: You must provide a FilePath using -f. Use -h or --help for help." -ForegroundColor Red
    exit
}

if (-not (Test-Path $FilePath)) {
    Write-Host "Error: File not found at $FilePath" -ForegroundColor Red
    exit
}

# Prompt for Kibana URL if not provided via switch
if ([string]::IsNullOrWhiteSpace($KibanaUrl)) {
    Write-Host "Kibana URL not provided." -ForegroundColor Yellow
    $KibanaUrl = Read-Host "Please enter your Kibana URL"
    if ([string]::IsNullOrWhiteSpace($KibanaUrl)) {
        Write-Host "Error: Kibana URL is required to proceed." -ForegroundColor Red
        exit
    }
}

# -----------------------------------------------------------------
# URL Formatting and Sanitization
# -----------------------------------------------------------------
$KibanaUrl = $KibanaUrl.Trim()
if ($KibanaUrl -notmatch '^https?://') {
    Write-Host "Info: Protocol missing. Prepending 'https://'." -ForegroundColor Cyan
    $KibanaUrl = "https://$KibanaUrl"
}
try {
    $uri = [System.Uri]$KibanaUrl
    $BaseUrl = "$($uri.Scheme)://$($uri.Authority)"
    if ($KibanaUrl -ne $BaseUrl) {
        Write-Host "Info: Path or query detected. Using base URL: $BaseUrl" -ForegroundColor Cyan
        $KibanaUrl = $BaseUrl
    }
} catch {
    Write-Host "Warning: Could not automatically parse the URL. Proceeding with: $KibanaUrl" -ForegroundColor Yellow
}

# Prompt for API Key if not provided via switch
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "API Key not provided." -ForegroundColor Yellow
    $ApiKey = Read-Host "Please enter your Kibana API Key"
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Host "Error: API Key is required to proceed." -ForegroundColor Red
        exit
    }
}

# Prompt for Private Location if not provided via switch
if ([string]::IsNullOrWhiteSpace($Location)) {
    Write-Host "Private Location not provided." -ForegroundColor Yellow
    $Location = Read-Host "Please enter your Private Location name"
    if ([string]::IsNullOrWhiteSpace($Location)) {
        Write-Host "Error: Private Location is required to proceed." -ForegroundColor Red
        exit
    }
}

# -----------------------------------------------------------------
# Security Notice
# -----------------------------------------------------------------
Write-Host "`n[SECURITY NOTICE]" -ForegroundColor Magenta
Write-Host "The provided URL, API Key, and Location are used strictly in-memory for this session." -ForegroundColor Gray
Write-Host "They are NOT saved to disk, logged, or sent to any third-party servers." -ForegroundColor Gray
Write-Host "Once this PowerShell window is closed, these credentials are forgotten." -ForegroundColor Gray
Write-Host "---------------------------------------------------------`n" -ForegroundColor DarkGray

# -----------------------------------------------------------------
# SSL Certificate Handling (Version-Aware)
# -----------------------------------------------------------------
$SkipCertCheckParam = @{}
if ($PSVersionTable.PSVersion.Major -lt 6) {
    # Windows PowerShell 5.1
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
} else {
    # PowerShell 6/7+
    if ((Get-Command Invoke-RestMethod).Parameters.ContainsKey('SkipCertificateCheck')) {
        $SkipCertCheckParam = @{ SkipCertificateCheck = $true }
    }
}

$monitors = Get-Content -LiteralPath $FilePath
$total = $monitors.Count
$current = 0

Write-Host "=========================================================" -ForegroundColor DarkGray
Write-Host " Starting bulk monitor creation process..." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor DarkGray

foreach ($monitor in $monitors) {
    if ([string]::IsNullOrWhiteSpace($monitor) -or $monitor.Trim().StartsWith("#")) { continue }

    $current++
    $parts = $monitor.Split("|")
    
    if ($parts.Length -lt 2) {
        Write-Host "Skipping invalid line: $monitor" -ForegroundColor DarkGray
        continue
    }

    $ip = $parts[0].Trim()
    $name = $parts[1].Trim()
    $tagString = ""
    if ($parts.Length -gt 2) { $tagString = $parts[2].Trim() }

    # --- Print Monitor Settings ---
    Write-Host ("[{0}/{1}] Preparing Monitor: {2}" -f $current, $total, $name) -ForegroundColor Cyan
    Write-Host "      - Target IP    : $ip" -ForegroundColor Gray
    Write-Host "      - Location     : $Location" -ForegroundColor Gray
    Write-Host "      - Tags         : $(if ($tagString) { $tagString } else { 'None' })" -ForegroundColor Gray
    Write-Host "      - Schedule     : $(if ($Schedule -gt 0) { "$Schedule min" } else { '3 min (Default)' })" -ForegroundColor Gray
    Write-Host "      - Timeout      : $(if ($Timeout -gt 0) { "$Timeout sec" } else { '16 sec (Default)' })" -ForegroundColor Gray
    Write-Host "      - Enabled      : $(if ($Enabled) { $Enabled } else { 'true (Default)' })" -ForegroundColor Gray
    Write-Host "      - Namespace    : $(if ($Namespace) { $Namespace } else { 'default (Default)' })" -ForegroundColor Gray
    Write-Host "      - Labels       : $(if ($Labels) { $Labels } else { 'None' })" -ForegroundColor Gray
    Write-Host "      - Alert Status : $(if ($AlertStatus) { $AlertStatus } else { 'true (Default)' })" -ForegroundColor Gray
    Write-Host "      - Retest Fail  : $(if ($RetestOnFailure) { $RetestOnFailure } else { 'true (Default)' })" -ForegroundColor Gray
    Write-Host "      - API Result   : " -NoNewline

    # --- Build JSON Body ---
    $bodyObj = @{
        type              = "icmp"
        name              = $name
        host              = $ip
        private_locations = @($Location)
        enabled           = $true
    }

    if ($Schedule -gt 0) { $bodyObj.schedule = $Schedule }
    if ($Timeout -gt 0) { $bodyObj.timeout = $Timeout }
    if ($Enabled) { $bodyObj.enabled = [System.Convert]::ToBoolean($Enabled) }
    if ($Namespace) { $bodyObj.namespace = $Namespace }

    if ($Labels) {
        $labelHash = @{}
        foreach ($pair in $Labels.Split(',')) {
            if ($pair -match '^([^:]+):(.+)$') {
                $labelHash[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        if ($labelHash.Count -gt 0) { $bodyObj.labels = $labelHash }
    }

    if ($AlertStatus) {
        $bodyObj.alert = @{ status = @{ enabled = [System.Convert]::ToBoolean($AlertStatus) } }
    }

    if ($RetestOnFailure) {
        $bodyObj.retest_on_failure = [System.Convert]::ToBoolean($RetestOnFailure)
    }

    if ($tagString -ne "") {
        $tagArray = $tagString -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        if ($tagArray.Count -gt 0) {
            $bodyObj.tags = @($tagArray)
        }
    }

    $body = $bodyObj | ConvertTo-Json -Depth 5

    # --- Send API Request ---
    try {
        $response = Invoke-RestMethod -Uri "$KibanaUrl/api/synthetics/monitors" `
            -Method Post `
            -Headers @{
                "Authorization" = "ApiKey $ApiKey"
                "Content-Type"  = "application/json"
                "kbn-xsrf"      = "true"
            } `
            -Body $body `
            -ErrorAction Stop `
            @SkipCertCheckParam
        
        Write-Host "SUCCESS" -ForegroundColor Green
    } catch {
        $errMsg = $_.Exception.Message
        if ($errMsg -match "409" -or $errMsg -match "Conflict") {
            Write-Host "SKIPPED (Already exists)" -ForegroundColor Yellow
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "      -> Error Details: $errMsg" -ForegroundColor DarkRed
        }
    }
    
    Write-Host "---------------------------------------------------------" -ForegroundColor DarkGray
    
    # Small delay to prevent API rate limiting
    Start-Sleep -Milliseconds 150
}

Write-Host "All tasks finished successfully!" -ForegroundColor Cyan
