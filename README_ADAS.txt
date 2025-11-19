Smart Car ADAS

Sistema avanzato di assististenza alla guida per FiveM, con:

- Autopilot verso il waypoint (tipo cruise assist)
- Frenata automatica avanti/retro (ADAS)
- Retrocamera con linee guida dinamiche
- HUD NUI con stato Autopilot / Safety / Velocità
- Sport Mode (disattiva gli aiuti, guida “libera”)
- Modulo ADAS installabile dal meccanico tramite item

Compatibile con:
- ESX
- QBCore
- Standalone (senza framework, con alcune limitazioni)
- Inventari tipo ox_inventory, qs-inventory, ecc. (tramite ESX/QB)

----------------------------------------
REQUISITI
----------------------------------------

- Server FiveM
- InteractSound (per i beep sensori / errori)
- Uno tra:
  - es_extended (ESX)
  - qb-core (QBCore)
  - oppure nessuno (standalone, ma senza gestione item)
- (Consigliato) Un inventario come ox_inventory o simili

----------------------------------------
INSTALLAZIONE
----------------------------------------

1. Copia la cartella della resource, ad es.:
   resources/[vehicles]/smartcar_adas

2. Aggiungi al tuo server.cfg:
   ensure smartcar_adas

3. Verifica in config.lua i modelli supportati:
   Config.AllowedModels = {
       ["tesla"] = true,
       ["tr22"]  = true,
   }

4. Assicurati di avere InteractSound installato e funzionante.

----------------------------------------
ITEM ADAS (ox_inventory & co.)
----------------------------------------

Per abilitare il sistema a modulo installabile dal meccanico, crea l’item ADAS nel tuo inventario.

Esempio per ox_inventory (items.lua):

["ADAS"] = { 
    label = "ADAS", 
    weight = 1,
    stack = true,
    close = true,
    description = "Modulo avanzato di assistenza alla guida.",
    -- client = { image = "adas.png" }, -- se vuoi una icona custom
},

Per l’icona: metti ADAS.png in ox_inventory/web/images/
Il nome del file deve corrispondere al nome dell’item.

----------------------------------------
CONFIGURAZIONE PRINCIPALE (config.lua)
----------------------------------------

Veicoli abilitati:
Config.AllowedModels = {
    ["tesla"] = true,
    ["tr22"]  = true,
}

Autopilot:
Config.Autopilot = {
    DefaultCruise = 40.0,
    MinCruise     = 20.0,
    MaxCruise     = 130.0
}

Tasti:
Config.Keys = {
    Autopilot  = 311,  -- K
    ReverseCam = 20,   -- Z
    SportMode  = 245,  -- T
    SpeedUp    = 175,  -- Numpad +
    SpeedDown  = 174   -- Numpad -
}

Sicurezza / ADAS:
Config.Safety = {
    Enabled              = true,
    MinSpeedForwardBrake = 10.0,
    MinSpeedReverseBrake = 3.0,
    EmergencyDistance    = 5.0,
    WarningDistance      = 12.0,
    DisableInSportMode   = true,
    DisableInAutodrive   = false
}

Flag rapidi:
Config.EnableAutoBrake       = true
Config.EnableReverseCamera   = true
Config.EnableHeadlightAssist = false

Modulo ADAS:
Config.MechanicModule = {
    Enabled     = true,
    ItemName    = "ADAS",
    UseDistance = 5.0,

    RequireJob  = true,
    JobNames    = { "mechanic", "mecano" },

    FactoryModels = {
        ["tesla"] = true,
        ["tr22"]  = true
    }
}

----------------------------------------
COME FUNZIONA IN GIOCO
----------------------------------------

Installazione modulo ADAS:
1. Il meccanico ha l’item ADAS.
2. Va vicino al veicolo (entro UseDistance).
3. Usa l’item dall’inventario.
4. Lo script controlla job, item, rimuove l’ADAS e lega il modulo a quella targa.
5. Quel veicolo ottiene Autopilot, Sport Mode e ADAS.

Retrocamera:
- Funziona per veicoli in Config.AllowedModels, indipendentemente dal modulo ADAS.

Controlli di default:
- K         → Autopilot ON/OFF (se veicolo ha modulo)
- Z         → Retrocamera ON/OFF
- T         → Sport Mode ON/OFF (se veicolo ha modulo)
- Numpad +  → Aumenta velocità AP
- Numpad -  → Diminuisce velocità AP

Autopilot:
- Richiede un waypoint sulla mappa.
- Guida il veicolo verso il waypoint alla velocità impostata.
- Si disattiva con input manuale (gas/freno/sterzo), uscita dal veicolo o ostacolo (se configurato).

Frenata automatica:
- Davanti:
  - Sopra MinSpeedForwardBrake:
    - Se distanza < WarningDistance → rallenta + beep
    - Se distanza < EmergencyDistance → frenata d’emergenza + beep errore
- Retro:
  - Logica simile per parcheggi / ostacoli dietro.

HUD NUI:
- Mostra:
  - AP: ON/OFF
  - SAFETY: OFF / ON / WARNING / BRAKE
  - SPD: velocità AP
- Compare automaticamente quando:
  - sei in autopilot,
  - la safety è attiva,
  - o hai la retrocamera attiva.

----------------------------------------
DEBUG
----------------------------------------

Comando client:
/smartcar_debug

Attiva/disattiva messaggi di debug in console.

----------------------------------------
TEST SENZA ITEM
----------------------------------------

Se il server è pieno e non puoi riavviare l’inventario:

1. Metti temporaneamente in config.lua:
   Config.MechanicModule.Enabled = false

2. Riavvia solo la resource:
   stop smartcar_adas
   start smartcar_adas

In questo modo tutti i veicoli AllowedModels hanno già sistemi attivi (senza uso item).

Quando hai creato l’item ADAS e riavviato l’inventario, rimetti Enabled = true.
