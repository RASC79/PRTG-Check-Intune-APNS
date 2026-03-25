<#
.SYNOPSIS
    �berwacht das Ablaufdatum des Apple Push Notification Service (APNS) Zertifikats in Microsoft Intune.

.DESCRIPTION
    Dieses Script authentifiziert sich per Application Registration gegen Microsoft Entra ID,
    ruft �ber Microsoft Graph das Intune APNS Zertifikat ab und wertet dessen Ablaufdatum aus.

    Die Ausgabe erfolgt im JSON-Format f�r einen PRTG EXE/Script Advanced Sensor.
    �berwacht werden insbesondere:
        - Tage bis zum Ablauf
        - Stunden bis zum Ablauf
        - Tage seit letzter Erneuerung

    Zus�tzlich werden Statusinformationen wie Apple ID, Ablaufzeitpunkt und Upload-Status
    in den Sensortext �bernommen.

.PURPOSE
    Fr�hzeitige Erkennung eines ablaufenden oder abgelaufenen Intune APNS Zertifikats,
    um Unterbrechungen bei der Verwaltung und Registrierung von Apple-Ger�ten zu vermeiden.

.AUTHOR
    RASC79

.COMPANY
    <company name>

.VERSION
    1.0.0

.DATE
    2026-03-25

.REQUIREMENTS
    - PRTG Network Monitor mit EXE/Script Advanced Sensor
    - PowerShell auf dem Probe- oder Core-Server
    - Internetzugriff auf login.microsoftonline.com und graph.microsoft.com
    - Microsoft Entra App Registration
    - Microsoft Graph Application Permission:
        DeviceManagementServiceConfig.Read.All
    - Admin Consent f�r die App Registration
    - Aktiver Microsoft Intune Tenant

.PARAMETER TenantId
    Microsoft Entra Tenant ID oder Tenant-Domain.

.PARAMETER ClientId
    Client ID der verwendeten App Registration.

.PARAMETER ClientSecret
    Client Secret (Value) der App Registration.

.PARAMETER WarningDays
    Warnschwelle in Tagen bis zum Ablauf des Zertifikats.
    Standardwert: 30

.PARAMETER ErrorDays
    Fehlerschwelle in Tagen bis zum Ablauf des Zertifikats.
    Standardwert: 7

.OUTPUT
    JSON-Ausgabe im Format f�r PRTG EXE/Script Advanced Sensor.

.NOTES
    Das Script ist f�r die nicht-interaktive Ausf�hrung im Monitoring konzipiert.
    Fehler von Microsoft Entra ID oder Microsoft Graph werden m�glichst detailliert
    aufbereitet und direkt an PRTG zur�ckgegeben.

    Empfohlene Verwendung in PRTG:
        - Primary Channel: Days Until Expiry
        - Ausf�hrungsintervall: t�glich

.EXAMPLE
    .\Check-IntuneApnsCertificate.ps1 `
        -TenantId "contoso.onmicrosoft.com" `
        -ClientId "00000000-0000-0000-0000-000000000000" `
        -ClientSecret "<secret>" `
        -WarningDays 30 `
        -ErrorDays 7

.CHANGELOG
    1.0.0 - Initiale produktive Version zur �berwachung des Intune APNS Zertifikats
#>
param(
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [int]$WarningDays = 30,
    [int]$ErrorDays = 7
)

$ErrorActionPreference = 'Stop'

function Write-PrtgResult {
    param(
        [string]$Text,
        [array]$Results
    )

    $Text = ($Text -replace "`r|`n", ' ').Trim()

    $output = @{
        prtg = @{
            text   = $Text
            result = $Results
        }
    }

    Write-Output ($output | ConvertTo-Json -Depth 10 -Compress)
    exit 0
}

function Write-PrtgError {
    param(
        [string]$Text
    )

    $Text = ($Text -replace "`r|`n", ' ').Trim()

    $output = @{
        prtg = @{
            error = 1
            text  = $Text
        }
    }

    Write-Output ($output | ConvertTo-Json -Depth 10 -Compress)
    exit 1
}

function Get-ErrorDetails {
    param(
        [System.Management.Automation.ErrorRecord]$Err
    )

    $message = $Err.Exception.Message

    try {
        $response = $Err.Exception.Response
        if ($null -ne $response) {
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()

                if (-not [string]::IsNullOrWhiteSpace($body)) {
                    try {
                        $json = $body | ConvertFrom-Json

                        if ($json.error_description) {
                            return "$($json.error): $($json.error_description)"
                        }

                        if ($json.error.message) {
                            return $json.error.message
                        }

                        if ($json.error.code -and $json.error.message) {
                            return "$($json.error.code): $($json.error.message)"
                        }

                        return ($body -replace "`r|`n", ' ').Trim()
                    }
                    catch {
                        return ($body -replace "`r|`n", ' ').Trim()
                    }
                }
            }
        }
    }
    catch {
        # fallback auf Standardmeldung
    }

    return ($message -replace "`r|`n", ' ').Trim()
}

function Get-GraphToken {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    $tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $tokenBody = "client_id=$([uri]::EscapeDataString($ClientId))&" +
                 "client_secret=$([uri]::EscapeDataString($ClientSecret))&" +
                 "scope=$([uri]::EscapeDataString('https://graph.microsoft.com/.default'))&" +
                 "grant_type=client_credentials"

    return Invoke-RestMethod `
        -Method Post `
        -Uri $tokenUri `
        -Body $tokenBody `
        -ContentType "application/x-www-form-urlencoded"
}

try {
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        Write-PrtgError "TenantId fehlt."
    }

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        Write-PrtgError "ClientId fehlt."
    }

    if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
        Write-PrtgError "ClientSecret fehlt."
    }

    if ($WarningDays -lt 1) {
        Write-PrtgError "WarningDays muss gr��er als 0 sein."
    }

    if ($ErrorDays -lt 1) {
        Write-PrtgError "ErrorDays muss gr��er als 0 sein."
    }

    if ($ErrorDays -ge $WarningDays) {
        Write-PrtgError "ErrorDays muss kleiner als WarningDays sein."
    }

    $tokenResponse = Get-GraphToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

    if (-not $tokenResponse.access_token) {
        Write-PrtgError "Kein Access Token von Microsoft Entra erhalten."
    }

    $headers = @{
        Authorization = "Bearer $($tokenResponse.access_token)"
        Accept        = "application/json"
    }

    $certUri = "https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate"
    $cert = Invoke-RestMethod -Method Get -Uri $certUri -Headers $headers

    if (-not $cert) {
        Write-PrtgError "Keine Daten vom Graph-Endpunkt erhalten."
    }

    if (-not $cert.expirationDateTime) {
        Write-PrtgError "expirationDateTime wurde vom Graph-Endpunkt nicht geliefert."
    }

    $nowUtc    = (Get-Date).ToUniversalTime()
    $expiryUtc = [datetime]::Parse($cert.expirationDateTime).ToUniversalTime()
    $timeLeft  = $expiryUtc - $nowUtc

    $daysLeft  = [math]::Floor($timeLeft.TotalDays)
    $hoursLeft = [math]::Floor($timeLeft.TotalHours)

    $appleId      = if ($cert.appleIdentifier) { $cert.appleIdentifier } else { 'n/a' }
    $topicId      = if ($cert.topicIdentifier) { $cert.topicIdentifier } else { 'n/a' }
    $uploadStatus = if ($cert.certificateUploadStatus) { $cert.certificateUploadStatus } else { 'unknown' }

    $lastModifiedUtc = $null
    $daysSinceRenewal = $null

    if ($cert.lastModifiedDateTime) {
        $lastModifiedUtc = [datetime]::Parse($cert.lastModifiedDateTime).ToUniversalTime()
        $daysSinceRenewal = [math]::Floor((($nowUtc) - $lastModifiedUtc).TotalDays)
    }

    $expiryText = $expiryUtc.ToString("yyyy-MM-dd HH:mm:ss 'UTC'")

    if ($daysLeft -lt 0) {
        $statusText = "APNS Zertifikat abgelaufen seit $([math]::Abs($daysLeft)) Tagen | Apple ID: $appleId | Ablauf: $expiryText | Upload-Status: $uploadStatus"
    }
    elseif ($daysLeft -le $ErrorDays) {
        $statusText = "APNS Zertifikat kritisch: noch $daysLeft Tage | Apple ID: $appleId | Ablauf: $expiryText | Upload-Status: $uploadStatus"
    }
    elseif ($daysLeft -le $WarningDays) {
        $statusText = "APNS Zertifikat Warnung: noch $daysLeft Tage | Apple ID: $appleId | Ablauf: $expiryText | Upload-Status: $uploadStatus"
    }
    else {
        $statusText = "APNS Zertifikat OK: noch $daysLeft Tage | Apple ID: $appleId | Ablauf: $expiryText | Upload-Status: $uploadStatus"
    }

    $results = @(
        @{
            channel         = "Days Until Expiry"
            value           = $daysLeft
            unit            = "Count"
            float           = 0
            LimitMode       = 1
            LimitMinWarning = $WarningDays
            LimitMinError   = $ErrorDays
        },
        @{
            channel = "Hours Until Expiry"
            value   = $hoursLeft
            unit    = "Count"
            float   = 0
        }
    )

    if ($daysSinceRenewal -ne $null) {
        $results += @{
            channel = "Days Since Renewal"
            value   = $daysSinceRenewal
            unit    = "Count"
            float   = 0
        }
    }

    if ($topicId -ne 'n/a') {
        # Optionaler numerischer Info-Kanal nicht sinnvoll, deshalb nur im Text
    }

    Write-PrtgResult -Text $statusText -Results $results
}
catch {
    $details = Get-ErrorDetails -Err $_
    Write-PrtgError $details
}