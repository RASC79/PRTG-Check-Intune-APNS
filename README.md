# Intune APNS Certificate Monitoring (PRTG)

Dieses PowerShell-Script überwacht das Ablaufdatum des **Apple Push
Notification Service (APNS) Zertifikats** in Microsoft Intune und gibt
die Ergebnisse im Format eines **PRTG EXE/Script Advanced Sensors** aus.

------------------------------------------------------------------------

## 🚀 Features

-   Überwachung des APNS Zertifikats in Intune
-   Anzeige von:
    -   Tage bis Ablauf
    -   Stunden bis Ablauf
    -   Tage seit letzter Erneuerung
-   Anzeige zusätzlicher Informationen:
    -   Apple ID
    -   Ablaufdatum
    -   Upload-Status
-   **PRTG-kompatible JSON-Ausgabe**
-   Detaillierte Fehlerausgabe bei Graph/API-Problemen

------------------------------------------------------------------------

## 📋 Voraussetzungen

-   PRTG Network Monitor
-   PowerShell (auf Probe oder Core Server)
-   Internetzugriff auf:
    -   login.microsoftonline.com
    -   graph.microsoft.com
-   Microsoft Intune Tenant

### 🔐 Microsoft Entra App Registration

Erforderliche Einstellungen:

-   API Permission (Application): DeviceManagementServiceConfig.Read.All
-   Admin Consent: erforderlich
-   Authentifizierung:
    -   Client ID
    -   Client Secret (Value!)

------------------------------------------------------------------------

## ⚙️ Verwendung in PRTG

### Sensor-Typ

EXE/Script Advanced

### Parameter

-TenantId "%scriptplaceholder1" -ClientId "%scriptplaceholder2"
-ClientSecret "%scriptplaceholder3" -WarningDays 30 -ErrorDays 7

### Platzhalter

-   %scriptplaceholder1 = Tenant ID
-   %scriptplaceholder2 = Client ID
-   %scriptplaceholder3 = Client Secret

------------------------------------------------------------------------

## 📊 Sensor-Channels

-   Days Until Expiry -- Tage bis Ablauf
-   Hours Until Expiry -- Stunden bis Ablauf
-   Days Since Renewal -- Tage seit letzter Erneuerung (optional)

------------------------------------------------------------------------

## 🔔 Schwellenwerte

Standard: - Warning: 30 Tage - Error: 7 Tage

------------------------------------------------------------------------

## 🧠 Funktionsweise

1.  Authentifizierung gegen Microsoft Entra ID
2.  Abruf des APNS Zertifikats über Graph API:
    https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate
3.  Auswertung des Ablaufdatums
4.  Rückgabe an PRTG als JSON

------------------------------------------------------------------------

## ⚠️ Hinweis

-   APNS Zertifikat ist 365 Tage gültig
-   Muss jährlich erneuert werden
-   Nach Ablauf eingeschränkte Geräteverwaltung möglich

------------------------------------------------------------------------

## 🛠 Troubleshooting

### Auth Fehler

-   Client Secret prüfen (Value!)
-   Admin Consent prüfen
-   Permissions prüfen

### Keine Daten

-   Intune korrekt konfiguriert?
-   APNS Zertifikat vorhanden?

------------------------------------------------------------------------

## 📌 Empfehlung

-   Intervall: täglich
-   Primary Channel: Days Until Expiry

------------------------------------------------------------------------

## 👤 Autor

RASC79
