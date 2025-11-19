-- Smart Car ADAS - Client side
-- Autopilot, frenata automatica, retrocamera e HUD NUI

Config = Config or {}

-- ########################
-- ##  FRAMEWORK WRAPPER ##
-- ########################

local Framework = {
    name = "standalone",
    ESX = nil,
    QBCore = nil
}

local function InitFramework()
    if GetResourceState("qb-core") == "started" then
        Framework.QBCore = exports["qb-core"]:GetCoreObject()
        Framework.name = "qbcore"
        print("[smartcar_adas] Client framework: QBCore")
    elseif GetResourceState("es_extended") == "started" then
        TriggerEvent("esx:getSharedObject", function(obj)
            Framework.ESX = obj
        end)
        if Framework.ESX then
            Framework.name = "esx"
            print("[smartcar_adas] Client framework: ESX")
        end
    else
        print("[smartcar_adas] Client framework: standalone")
    end
end

CreateThread(InitFramework)

local function Notify(msg)
    if Framework.name == "qbcore" and Framework.QBCore and Framework.QBCore.Functions and Framework.QBCore.Functions.Notify then
        Framework.QBCore.Functions.Notify(msg, "primary")
    elseif Framework.name == "esx" and Framework.ESX and Framework.ESX.ShowNotification then
        Framework.ESX.ShowNotification(msg)
    else
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

-- ######################
-- ##   CONFIG FALLBACK##
-- ######################

Config.AllowedModels = Config.AllowedModels or {}

Config.Autopilot = Config.Autopilot or {
    DefaultCruise = 40.0,
    MinCruise     = 20.0,
    MaxCruise     = 130.0
}

Config.Keys = Config.Keys or {
    Autopilot  = 311,
    ReverseCam = 20,
    SportMode  = 245,
    SpeedUp    = 175,
    SpeedDown  = 174
}

Config.Safety = Config.Safety or {
    Enabled              = true,
    MinSpeedForwardBrake = 10.0,
    MinSpeedReverseBrake = 3.0,
    EmergencyDistance    = 5.0,
    WarningDistance      = 12.0,
    DisableInSportMode   = true,
    DisableInAutodrive   = false
}

Config.EnableAutoBrake       = (Config.EnableAutoBrake ~= false)
Config.EnableReverseCamera   = (Config.EnableReverseCamera ~= false)
Config.EnableHeadlightAssist = (Config.EnableHeadlightAssist == true)

Config.BeepSoundVolume = Config.BeepSoundVolume or 0.5

Config.MechanicModule = Config.MechanicModule or {
    Enabled     = false,
    ItemName    = "ADAS",
    UseDistance = 5.0,
    RequireJob  = false,
    JobNames    = { "mechanic" },
    FactoryModels = {}
}

-- ######################
-- ##   LOCAL STATE    ##
-- ######################

local reverse     = false
local autodrive   = false
local sportMode   = false
local safetyState = "off" -- "off", "normal", "warning", "brake"

local cruisespeed = Config.Autopilot.DefaultCruise or 40.0

local lastErrorSound = 0
local lastSensorBeep = 0
local timer          = 200   -- ms minimo tra error sound
local sensor         = 25    -- ms minimo tra beep sensori

local debugMode = false

local VehicleModules = {} -- [plate] = true/false

-- ######################
-- ##   UTIL FUNCS     ##
-- ######################

local function DebugPrint(msg)
    if debugMode then
        print("[smartcar_adas] " .. msg)
    end
end

local function IsAllowedVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return false end

    local model = GetEntityModel(veh)
    for name, allowed in pairs(Config.AllowedModels) do
        if allowed and model == GetHashKey(name) then
            return true
        end
    end

    return false
end

local function HasSmartModule(veh)
    if not Config.MechanicModule.Enabled then
        -- se il sistema moduli è disattivato, consideriamo tutti i veicoli AllowedModels come “moddati”
        return true
    end

    if veh == 0 or not DoesEntityExist(veh) then return false end

    local model = GetEntityModel(veh)

    -- moduli di fabbrica
    if Config.MechanicModule.FactoryModels then
        for name, allowed in pairs(Config.MechanicModule.FactoryModels) do
            if allowed and model == GetHashKey(name) then
                return true
            end
        end
    end

    local plate = GetVehicleNumberPlateText(veh) or ""
    plate = plate:gsub("%s+", "")

    return VehicleModules[plate] == true
end

local function MpsToMph(ms)
    return ms * 2.23694
end

local function MphToMps(mph)
    return mph / 2.23694
end

local function PlaySensorBeep(sound)
    sound = sound or "sensor"
    TriggerServerEvent("InteractSound_SV:PlayOnSource", sound, Config.BeepSoundVolume)
end

local function UpdateHud()
    local shouldShow = reverse or autodrive or (Config.Safety.Enabled and safetyState ~= "off")

    SendNUIMessage({
        type   = "ui",
        status = shouldShow
    })

    SendNUIMessage({
        type        = "hud",
        autopilot   = autodrive,
        cruiseSpeed = cruisespeed,
        safety      = safetyState
    })
end

local function SoftBrake(veh)
    TaskVehicleTempAction(PlayerPedId(), veh, 3, 1)
    SetVehicleBrake(veh, true)
    SetVehicleBrakeLights(veh, true)
end

local function EmergencyBrake(veh)
    TaskVehicleTempAction(PlayerPedId(), veh, 27, 500)
    SetVehicleBrake(veh, true)
    SetVehicleHandbrake(veh, true)
    SetVehicleBrakeLights(veh, true)
end

local function DisableAutodrive(reason)
    if autodrive then
        ClearPedTasks(PlayerPedId())
        autodrive = false
        Notify("Autopilot disattivato" .. (reason and (": " .. reason) or ""))
        DebugPrint("Autodrive OFF (" .. (reason or "no reason") .. ")")
        safetyState = "normal"
        UpdateHud()
    end
end

local function ToggleSportMode()
    sportMode = not sportMode
    if sportMode then
        Notify("Sport Mode attivata")
    else
        Notify("Sport Mode disattivata")
    end
    UpdateHud()
end

-- ######################
-- ##  SAFETY LOGIC    ##
-- ######################

local function ForwardSafetyCheck(ped, veh)
    if not Config.Safety.Enabled or not Config.EnableAutoBrake then
        safetyState = "off"
        return
    end
    if sportMode and Config.Safety.DisableInSportMode then
        safetyState = "off"
        return
    end

    local speedMps = GetEntitySpeed(veh)
    local speedMph = MpsToMph(speedMps)
    if speedMph < (Config.Safety.MinSpeedForwardBrake or 10.0) then
        safetyState = "normal"
        return
    end

    local coords = GetEntityCoords(veh)
    local fwd    = GetEntityForwardVector(veh)
    local from   = coords + fwd * 2.0
    local to     = coords + fwd * 40.0

    local rayHandle         = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 10, veh, 0)
    local _, hit, hitCoords, _, hitEntity = GetShapeTestResult(rayHandle)

    if hit == 1 and DoesEntityExist(hitEntity) then
        local dist = #(coords - hitCoords)
        local emergencyDist = Config.Safety.EmergencyDistance or 5.0
        local warningDist   = Config.Safety.WarningDistance or 12.0

        if dist <= emergencyDist then
            safetyState = "brake"
            EmergencyBrake(veh)
            if GetGameTimer() - lastErrorSound > timer then
                PlaySensorBeep("error")
                lastErrorSound = GetGameTimer()
            end
            if autodrive and Config.Safety.DisableInAutodrive then
                DisableAutodrive("Ostacolo rilevato")
            end
        elseif dist <= warningDist then
            safetyState = "warning"
            SoftBrake(veh)
            if GetGameTimer() - lastSensorBeep > sensor then
                PlaySensorBeep("sensor")
                lastSensorBeep = GetGameTimer()
            end
        else
            safetyState = "normal"
        end
    else
        safetyState = "normal"
    end
end

local function ReverseSafetyCheck(ped, veh)
    if not Config.Safety.Enabled or not Config.EnableAutoBrake then
        return
    end
    if sportMode and Config.Safety.DisableInSportMode then
        return
    end

    local speedMps = GetEntitySpeed(veh)
    local speedMph = MpsToMph(speedMps)
    if speedMph < (Config.Safety.MinSpeedReverseBrake or 3.0) then
        return
    end

    local coords = GetEntityCoords(veh)
    local fwd    = GetEntityForwardVector(veh)
    local back   = vector3(-fwd.x, -fwd.y, fwd.z)

    local from   = coords + back * 2.0
    local to     = coords + back * 25.0

    local rayHandle         = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 10, veh, 0)
    local _, hit, hitCoords, _, hitEntity = GetShapeTestResult(rayHandle)

    if hit == 1 and DoesEntityExist(hitEntity) then
        local dist         = #(coords - hitCoords)
        local emergencyDist = Config.Safety.EmergencyDistance or 5.0
        local warningDist   = Config.Safety.WarningDistance or 12.0

        if dist <= emergencyDist then
            safetyState = "brake"
            EmergencyBrake(veh)
            if GetGameTimer() - lastErrorSound > timer then
                PlaySensorBeep("error")
                lastErrorSound = GetGameTimer()
            end
        elseif dist <= warningDist then
            safetyState = "warning"
            SoftBrake(veh)
            if GetGameTimer() - lastSensorBeep > sensor then
                PlaySensorBeep("sensor")
                lastSensorBeep = GetGameTimer()
            end
        end
    end
end

-- ######################
-- ##  AUTOPILOT LOGIC ##
-- ######################

local function StartAutodrive(ped, veh)
    if autodrive then
        DisableAutodrive()
        return
    end

    if not IsWaypointActive() then
        Notify("Imposta un waypoint sulla mappa per usare l'autopilot.")
        return
    end

    local blip = GetFirstBlipInfoId(8)
    local dest = GetBlipInfoIdCoord(blip)

    TaskVehicleDriveToCoordLongrange(
        ped,
        veh,
        dest.x, dest.y, dest.z,
        MphToMps(cruisespeed),
        447,
        5.0
    )

    autodrive   = true
    safetyState = "normal"
    Notify("Autopilot attivato")
    DebugPrint("Autodrive ON")
    UpdateHud()
end

-- ######################
-- ##      THREADS     ##
-- ######################

-- input handler (tasti)
CreateThread(function()
    while true do
        local sleep = 500

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            sleep = 0
            local veh = GetVehiclePedIsIn(ped, false)

            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and IsAllowedVehicle(veh) then
                -- Autopilot toggle (richiede modulo)
                if IsControlJustPressed(0, Config.Keys.Autopilot) then
                    if HasSmartModule(veh) then
                        StartAutodrive(ped, veh)
                    else
                        Notify("Questo veicolo non ha il modulo ADAS installato.")
                    end
                end

                -- Reverse camera (solo modello ammesso, modulo non obbligatorio)
                if IsControlJustPressed(0, Config.Keys.ReverseCam) then
                    reverse = not reverse
                    UpdateHud()
                end

                -- Sport mode (richiede modulo)
                if IsControlJustPressed(0, Config.Keys.SportMode) then
                    if HasSmartModule(veh) then
                        ToggleSportMode()
                    else
                        Notify("Questo veicolo non ha il modulo ADAS installato.")
                    end
                end

                -- Speed up / down (solo se modulo presente)
                if HasSmartModule(veh) then
                    if IsControlJustPressed(0, Config.Keys.SpeedUp) then
                        cruisespeed = math.min(cruisespeed + 5.0, Config.Autopilot.MaxCruise or 130.0)
                        Notify("Velocità autopilot: " .. math.floor(cruisespeed) .. " mph")
                        UpdateHud()
                    elseif IsControlJustPressed(0, Config.Keys.SpeedDown) then
                        cruisespeed = math.max(cruisespeed - 5.0, Config.Autopilot.MinCruise or 20.0)
                        Notify("Velocità autopilot: " .. math.floor(cruisespeed) .. " mph")
                        UpdateHud()
                    end
                end

                -- Manual override per l'autopilot
                if autodrive then
                    if IsControlPressed(0, 71) or IsControlPressed(0, 72) or IsControlPressed(0, 59) or IsControlPressed(0, 60) then
                        DisableAutodrive("Input manuale")
                    end
                end
            else
                if autodrive then
                    DisableAutodrive("Non più alla guida")
                end
                if reverse then
                    reverse = false
                    UpdateHud()
                end
            end
        else
            if autodrive then
                DisableAutodrive("Non più nel veicolo")
            end
            if reverse then
                reverse = false
                UpdateHud()
            end
        end

        Wait(sleep)
    end
end)

-- loop sicurezza + update HUD
CreateThread(function()
    while true do
        local sleep = 200

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and IsAllowedVehicle(veh) then
                sleep = 50

                if HasSmartModule(veh) then
                    local velVec = GetEntitySpeedVector(veh, true)

                    if velVec.y > 0.1 then
                        ForwardSafetyCheck(ped, veh)
                    end

                    if velVec.y < -0.1 or reverse then
                        ReverseSafetyCheck(ped, veh)
                    end
                else
                    safetyState = "off"
                end

                UpdateHud()
            end
        else
            safetyState = "off"
            UpdateHud()
        end

        Wait(sleep)
    end
end)

-- reverse camera: invio angolo sterzo alla NUI
CreateThread(function()
    while true do
        local sleep = 250

        if reverse and Config.EnableReverseCamera then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 then
                    local steeringAngle = GetVehicleSteeringAngle(veh)
                    SendNUIMessage({
                        type  = "angleinfo",
                        angle = steeringAngle
                    })
                    sleep = 50
                end
            end
        end

        Wait(sleep)
    end
end)

-- thread generale HUD (per sicurezza)
CreateThread(function()
    while true do
        UpdateHud()
        Wait(500)
    end
end)

-- ######################
-- ##   NET EVENTS     ##
-- ######################

RegisterNetEvent("smartcar:setModule", function(plate, state)
    if type(plate) ~= "string" then return end
    plate = plate:gsub("%s+", "")
    if plate == "" then return end

    if state then
        VehicleModules[plate] = true
    else
        VehicleModules[plate] = nil
    end
end)

RegisterNetEvent("smartcar:initialModules", function(data)
    if type(data) == "table" then
        VehicleModules = data
    end
end)

RegisterNetEvent("smartcar:notify", function(msg)
    Notify(msg)
end)

-- Uso dell’item ADAS (lato client): trova veicolo vicino e avvia installazione
RegisterNetEvent("smartcar:useModuleItem", function()
    local ped   = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local dist = (Config.MechanicModule.UseDistance or 5.0)

    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, dist, 0, 71)

    if veh == 0 or not DoesEntityExist(veh) then
        Notify("Nessun veicolo vicino da modificare.")
        return
    end

    if not IsAllowedVehicle(veh) then
        Notify("Questo veicolo non supporta il sistema ADAS.")
        return
    end

    if HasSmartModule(veh) then
        Notify("Questo veicolo ha già un modulo ADAS.")
        return
    end

    local plate = GetVehicleNumberPlateText(veh) or ""
    plate = plate:gsub("%s+", "")

    if plate == "" then
        Notify("Targa non valida.")
        return
    end

    -- Qui puoi aggiungere animazione/progress bar a piacere
    Notify("Installazione modulo ADAS in corso...")
    Wait(3000)

    TriggerServerEvent("smartcar:installModuleOnVehicle", plate)
end)

-- sync iniziale moduli
CreateThread(function()
    Wait(3000)
    if Config.MechanicModule.Enabled then
        TriggerServerEvent("smartcar:requestModules")
    end
end)

-- debug command
RegisterCommand("smartcar_debug", function()
    debugMode = not debugMode
    Notify("SmartCar debug: " .. (debugMode and "ON" or "OFF"))
end, false)
