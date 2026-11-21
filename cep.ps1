<#
.SYNOPSIS
    cep.ps1 — Brazilian Postal Code (CEP) Lookup CLI (PowerShell)

.DESCRIPTION
    Queries Brazilian postal codes (CEP) with an automatic HTTPS fallback chain:
    BrasilAPI v2 -> OpenCEP -> ViaCEP. Supports single/multiple lookups, batch files,
    strict 8-digit validation, and table/json/csv outputs.

    Author  : Percio Castelo (Percio Andrade) <percio@perciocastelo.com.br>
    Website : https://perciocastelo.com.br
    Project : https://perciocastelo.com.br/projetos/en/cep-cli.html
    Repo    : https://github.com/sr00t3d/cep-cli
    License : Apache-2.0
    Version : 2.1.0

.EXAMPLE
    .\cep.ps1 01001-000
    .\cep.ps1 -Provider opencep 69042-500
    .\cep.ps1 -File ceps.txt -Output csv
    .\cep.ps1 01001-000 90250-210 -Output json
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Ceps,

    [Alias('f')]
    [string]$File,

    [ValidateSet('auto', 'brasilapi', 'opencep', 'viacep')]
    [string]$Provider = 'auto',

    [Alias('o')]
    [ValidateSet('table', 'json', 'csv')]
    [string]$Output = 'table',

    [int]$Timeout = 8,

    [Alias('q')]
    [switch]$Quiet,

    [switch]$NoColor,

    [Alias('V')]
    [switch]$Version,

    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptName = 'cep.ps1'
$ScriptVersion = '2.1.0'
$TimestampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

function Show-Help {
@"
$ScriptName v$ScriptVersion — Brazilian Postal Code (CEP) Lookup CLI (PowerShell)

Usage:
  .\cep.ps1 <cep> [cep2 ...] [options]
  .\cep.ps1 -File <ceps.txt> [options]

Options:
  -File, -f <path>           Read CEPs from a file (one per line, # comments ignored)
  -Provider <name>           Provider: auto (default: brasilapi -> opencep -> viacep), brasilapi, opencep, viacep
  -Output, -o <fmt>          Output format: table (default), json, csv
  -Timeout <sec>             HTTP timeout in seconds (default: 8)
  -Quiet, -q                 Suppress banner header
  -NoColor                   Disable colored output
  -Version, -V               Show version and exit
  -Help, -h                  Show this help and exit

Examples:
  .\cep.ps1 01001-000
  .\cep.ps1 -Provider opencep 69042-500
  .\cep.ps1 01001-000 90250-210 -Output csv
"@ | Write-Output
}

function Write-ColorLine {
    param([string]$Text, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    if ($NoColor -or $env:NO_COLOR -or $Output -ne 'table') {
        Write-Output $Text
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

function Format-CepMask {
    param([string]$Digits)
    return ($Digits.Substring(0, 5) + '-' + $Digits.Substring(5, 3))
}

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return '' }
    if ($Obj.PSObject.Properties[$Name] -and $null -ne $Obj.$Name) {
        return [string]$Obj.$Name
    }
    return ''
}

function Invoke-ProviderLookup {
    param([string]$Prov, [string]$Digits)
    $headers = @{ 'User-Agent' = "cep-cli/$ScriptVersion (+https://github.com/sr00t3d/cep-cli)" }
    try {
        switch ($Prov) {
            'brasilapi' {
                $r = Invoke-RestMethod -Uri "https://brasilapi.com.br/api/cep/v2/$Digits" -Headers $headers -TimeoutSec $Timeout -ErrorAction Stop
                $lat = ''; $lng = ''
                if ($r.PSObject.Properties['location'] -and $r.location -and $r.location.PSObject.Properties['coordinates'] -and $r.location.coordinates) {
                    $lat = Get-Prop $r.location.coordinates 'latitude'
                    $lng = Get-Prop $r.location.coordinates 'longitude'
                }
                return [PSCustomObject]@{
                    cep          = Format-CepMask $Digits
                    status       = 'found'
                    provider     = 'brasilapi'
                    street       = Get-Prop $r 'street'
                    neighborhood = Get-Prop $r 'neighborhood'
                    city         = Get-Prop $r 'city'
                    state        = Get-Prop $r 'state'
                    ibge         = Get-Prop $r 'ibge'
                    latitude     = $lat
                    longitude    = $lng
                    timezone     = ''
                }
            }
            'opencep' {
                $r = Invoke-RestMethod -Uri "https://opencep.com/v1/$Digits.json" -Headers $headers -TimeoutSec $Timeout -ErrorAction Stop
                return [PSCustomObject]@{
                    cep          = Format-CepMask $Digits
                    status       = 'found'
                    provider     = 'opencep'
                    street       = Get-Prop $r 'logradouro'
                    neighborhood = Get-Prop $r 'bairro'
                    city         = Get-Prop $r 'localidade'
                    state        = Get-Prop $r 'uf'
                    ibge         = Get-Prop $r 'ibge'
                    latitude     = ''
                    longitude    = ''
                    timezone     = ''
                }
            }
            'viacep' {
                $r = Invoke-RestMethod -Uri "https://viacep.com.br/ws/$Digits/json/" -Headers $headers -TimeoutSec $Timeout -ErrorAction Stop
                if ($r.PSObject.Properties['erro'] -and $r.erro) { return $null }
                return [PSCustomObject]@{
                    cep          = Format-CepMask $Digits
                    status       = 'found'
                    provider     = 'viacep'
                    street       = Get-Prop $r 'logradouro'
                    neighborhood = Get-Prop $r 'bairro'
                    city         = Get-Prop $r 'localidade'
                    state        = Get-Prop $r 'uf'
                    ibge         = Get-Prop $r 'ibge'
                    latitude     = ''
                    longitude    = ''
                    timezone     = ''
                }
            }
        }
    } catch {
        return $null
    }
    return $null
}

if ($Help) { Show-Help; exit 0 }
if ($Version) { Write-Output "$ScriptName $ScriptVersion"; exit 0 }

$Inputs = New-Object System.Collections.Generic.List[string]
if ($Ceps) {
    foreach ($c in $Ceps) {
        if (-not [string]::IsNullOrWhiteSpace($c)) { $Inputs.Add($c.Trim()) }
    }
}
if ($File) {
    if (-not (Test-Path -LiteralPath $File)) {
        Write-Error "[ERR] File not found: $File"
        exit 1
    }
    foreach ($raw in (Get-Content -LiteralPath $File -Encoding UTF8)) {
        $line = ($raw -replace '#.*$', '').Trim()
        if ($line) { $Inputs.Add($line) }
    }
}

if ($Inputs.Count -eq 0) {
    Show-Help
    exit 1
}

$Chain = if ($Provider -eq 'auto') { @('brasilapi', 'opencep', 'viacep') } else { @($Provider) }
$Results = New-Object System.Collections.Generic.List[object]
$NotFoundCount = 0

foreach ($rawCep in $Inputs) {
    $digits = ($rawCep -replace '[^0-9]', '')
    if ($digits.Length -ne 8) {
        $NotFoundCount++
        $Results.Add([PSCustomObject]@{
            cep = $rawCep; status = 'invalid'; provider = ''; street = ''; neighborhood = ''
            city = ''; state = ''; ibge = ''; latitude = ''; longitude = ''; timezone = ''
        })
        continue
    }

    $hit = $null
    foreach ($p in $Chain) {
        $hit = Invoke-ProviderLookup -Prov $p -Digits $digits
        if ($null -ne $hit) { break }
    }

    if ($null -eq $hit) {
        $NotFoundCount++
        $Results.Add([PSCustomObject]@{
            cep = Format-CepMask $digits; status = 'not_found'; provider = ''; street = ''; neighborhood = ''
            city = ''; state = ''; ibge = ''; latitude = ''; longitude = ''; timezone = ''
        })
    } else {
        $Results.Add($hit)
    }
}

switch ($Output) {
    'json' {
        $payload = [PSCustomObject]@{
            tool      = $ScriptName
            version   = $ScriptVersion
            timestamp = $TimestampUtc
            total     = $Results.Count
            results   = $Results
        }
        $payload | ConvertTo-Json -Depth 5 | Write-Output
    }
    'csv' {
        Write-Output 'cep,status,provider,street,neighborhood,city,state,ibge,latitude,longitude,timezone'
        foreach ($r in $Results) {
            $vals = @($r.cep, $r.status, $r.provider, $r.street, $r.neighborhood, $r.city, $r.state, $r.ibge, $r.latitude, $r.longitude, $r.timezone) |
                ForEach-Object { '"' + ([string]$_ -replace '"', '""') + '"' }
            Write-Output ($vals -join ',')
        }
    }
    default {
        if (-not $Quiet) {
            Write-ColorLine ('=' * 69) ([ConsoleColor]::Cyan)
            Write-Output (" {0} v{1} | Brazilian CEP Lookup | {2}" -f $ScriptName, $ScriptVersion, $TimestampUtc)
            Write-ColorLine ('=' * 69) ([ConsoleColor]::Cyan)
            Write-Output ''
        }
        foreach ($r in $Results) {
            if ($r.status -eq 'found') {
                Write-ColorLine ("[OK] {0,-11} : {1} (provider: {2})" -f 'CEP', $r.cep, $r.provider) ([ConsoleColor]::Green)
                if ($r.street)       { Write-Output ("     {0,-11} : {1}" -f 'Logradouro', $r.street) }
                if ($r.neighborhood) { Write-Output ("     {0,-11} : {1}" -f 'Bairro', $r.neighborhood) }
                if ($r.city)         { Write-Output ("     {0,-11} : {1} / {2}" -f 'Cidade/UF', $r.city, $r.state) }
                if ($r.ibge)         { Write-Output ("     {0,-11} : {1}" -f 'IBGE', $r.ibge) }
                if ($r.latitude -and $r.longitude) {
                    Write-Output ("     {0,-11} : {1}, {2} (https://www.openstreetmap.org/?mlat={1}&mlon={2}#map=16/{1}/{2})" -f 'Coords', $r.latitude, $r.longitude)
                }
            } elseif ($r.status -eq 'invalid') {
                Write-ColorLine ("[ERR] {0,-10} : {1} (must contain exactly 8 digits)" -f 'CEP', $r.cep) ([ConsoleColor]::Red)
            } else {
                Write-ColorLine ("[!]  {0,-11} : {1} (not found across providers)" -f 'CEP', $r.cep) ([ConsoleColor]::Yellow)
            }
            Write-Output ''
        }
    }
}

if ($NotFoundCount -gt 0 -and $NotFoundCount -eq $Results.Count) {
    exit 2
}
exit 0
