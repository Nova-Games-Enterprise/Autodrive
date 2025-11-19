------
-- Smart Car System / ADAS Config
------

Config = Config or {}

-- Veicoli che supportano il sistema (modelli in lowercase)
Config.AllowedModels = {
    ["tesla"] = true,
    ["gbschwartzers"]  = true,
    -- ["police3"] = true,
}

-- Autopilot / cruise control (mph)
Config.Autopilot = {
    DefaultCruise = 40.0,   -- vel. di default quando attivi AP
    MinCruise     = 20.0,   -- minimo regolabile
    MaxCruise     = 130.0   -- massimo regolabile
}

-- Tasti (keycodes: https://docs.fivem.net/docs/game-references/controls/)
Config.Keys = {
    Autopilot  = 311,  -- K
    ReverseCam = 20,   -- Z
    SportMode  = 245,  -- T
    SpeedUp    = 175,  -- Numpad +
    SpeedDown  = 174   -- Numpad -
}

-- Sicurezza / frenata automatica
Config.Safety = {
    Enabled              = true,   -- abilita/disabilita tutti i controlli di sicurezza
    MinSpeedForwardBrake = 10.0,   -- mph minimi per auto-brake in avanti
    MinSpeedReverseBrake = 3.0,    -- mph minimi per auto-brake in retro
    EmergencyDistance    = 5.0,    -- metri: sotto questo valore frenata d’emergenza
    WarningDistance      = 12.0,   -- metri: sotto questo valore warning + rallentamento
    DisableInSportMode   = true,   -- in Sport Mode niente aiuti
    DisableInAutodrive   = false   -- se true: in Autopilot disattiva gli aiuti
}

-- Abilita/disabilita singole funzioni
Config.EnableAutoBrake       = true   -- frenata automatica avanti/retro
Config.EnableReverseCamera   = true   -- retrocamera + linee guida
Config.EnableHeadlightAssist = false  -- placeholder per futura assistenza fari

-- Audio sensori (InteractSound)
Config.BeepSoundVolume = 0.8   -- 0.1 - 1.0

-- Sistema modulo ADAS installato dal meccanico tramite item
Config.MechanicModule = {
    Enabled     = true,          -- se false: tutti i veicoli AllowedModels hanno il sistema attivo
    ItemName    = "ADAS",        -- nome item in ESX/QB/ox
    UseDistance = 5.0,           -- raggio massimo dal veicolo per l’uso dell’item

    RequireJob  = true,          -- solo certe job possono installare
    JobNames    = { "mechanic", "mecano","rising_sun_customs" }, -- nomi job meccanico

    -- veicoli che nascono già col modulo montato di fabbrica
    FactoryModels = {
        ["tesla"] = true,
        ["gbschwartzers"]  = true
    }
}
