-- Smart Car ADAS - Server side
-- Gestione modulo ADAS tramite item (ESX/QBCore compatibile, ok anche ox_inventory/qs-inventory)

Config = Config or {}

local VehicleModules = {}  -- [plate] = true/false

local Framework = {
    name = "standalone",
    ESX = nil,
    QBCore = nil
}

CreateThread(function()
    if GetResourceState("qb-core") == "started" then
        Framework.QBCore = exports["qb-core"]:GetCoreObject()
        Framework.name = "qbcore"
        print("[smartcar_adas] Framework rilevato: QBCore")
    elseif GetResourceState("es_extended") == "started" then
        TriggerEvent("esx:getSharedObject", function(obj)
            Framework.ESX = obj
        end)
        if Framework.ESX then
            Framework.name = "esx"
            print("[smartcar_adas] Framework rilevato: ESX")
        end
    else
        print("[smartcar_adas] Nessun framework rilevato (standalone). Gestione item ADAS limitata.")
    end
end)

local function TrimPlate(plate)
    plate = plate or ""
    return string.gsub(plate, "%s+", "")
end

local function IsMechanic(src)
    if not Config.MechanicModule or not Config.MechanicModule.RequireJob then
        return true
    end

    local allowedJobs = Config.MechanicModule.JobNames or {}

    if Framework.name == "qbcore" and Framework.QBCore then
        local Player = Framework.QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData and Player.PlayerData.job then
            local job = Player.PlayerData.job.name
            for _, name in ipairs(allowedJobs) do
                if job == name then
                    return true
                end
            end
        end
    elseif Framework.name == "esx" and Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.job and xPlayer.job.name then
            for _, name in ipairs(allowedJobs) do
                if xPlayer.job.name == name then
                    return true
                end
            end
        end
    else
        -- standalone: se vuoi bloccare, ritorna false
        return true
    end

    return false
end

local function NotifyClient(src, msg)
    TriggerClientEvent("smartcar:notify", src, msg)
end

-- Registra item usabile ADAS (ESX / QBCore)
CreateThread(function()
    Wait(2000) -- diamo tempo al framework di inizializzarsi

    if not Config.MechanicModule or not Config.MechanicModule.Enabled then
        return
    end

    local itemName = Config.MechanicModule.ItemName or "ADAS"

    if Framework.name == "esx" and Framework.ESX then
        Framework.ESX.RegisterUsableItem(itemName, function(source)
            TriggerClientEvent("smartcar:useModuleItem", source)
        end)
        print("[smartcar_adas] Usable item registrato (ESX): " .. itemName)
    elseif Framework.name == "qbcore" and Framework.QBCore then
        Framework.QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            TriggerClientEvent("smartcar:useModuleItem", source)
        end)
        print("[smartcar_adas] Usable item registrato (QBCore): " .. itemName)
    else
        print("[smartcar_adas] Nessun framework per registrare item ADAS automaticamente.")
        print("[smartcar_adas] Per ox_inventory puro: usa un export che trigghera` l'evento smartcar:useModuleItem")
    end
end)

-- Installazione modulo su una targa
RegisterNetEvent("smartcar:installModuleOnVehicle", function(plate)
    local src = source

    if not Config.MechanicModule or not Config.MechanicModule.Enabled then
        NotifyClient(src, "Il sistema ADAS è disabilitato.")
        return
    end

    if not IsMechanic(src) then
        NotifyClient(src, "Non sei un meccanico.")
        return
    end

    plate = TrimPlate(plate or "")
    if plate == "" then
        NotifyClient(src, "Nessun veicolo valido.")
        return
    end

    if VehicleModules[plate] then
        NotifyClient(src, "Questo veicolo ha già un modulo ADAS.")
        return
    end

    -- Controllo & rimozione item
    local itemName = Config.MechanicModule.ItemName or "ADAS"

    if Framework.name == "esx" and Framework.ESX then
        local xPlayer = Framework.ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        local item = xPlayer.getInventoryItem(itemName)
        if not item or item.count <= 0 then
            NotifyClient(src, "Non hai un modulo ADAS in inventario.")
            return
        end

        xPlayer.removeInventoryItem(itemName, 1)

    elseif Framework.name == "qbcore" and Framework.QBCore then
        local Player = Framework.QBCore.Functions.GetPlayer(src)
        if not Player then return end

        local itm = Player.Functions.GetItemByName(itemName)
        if not itm then
            NotifyClient(src, "Non hai un modulo ADAS in inventario.")
            return
        end

        Player.Functions.RemoveItem(itemName, 1)

        -- Supporto opzionale per inventari tipo qb-inventory, qs-inventory ecc.
        if Framework.QBCore.Shared and Framework.QBCore.Shared.Items then
            TriggerClientEvent("inventory:client:ItemBox", src, Framework.QBCore.Shared.Items[itemName], "remove")
        end
    else
        -- standalone: niente inventario, niente rimozione item
        print("[smartcar_adas] ATTENZIONE: installModuleOnVehicle chiamato in modalità standalone, nessuna rimozione item.")
    end

    VehicleModules[plate] = true

    NotifyClient(src, "Modulo ADAS installato sulla targa: " .. plate)
    TriggerClientEvent("smartcar:setModule", -1, plate, true)
end)

-- Sync iniziale per chi entra dopo
RegisterNetEvent("smartcar:requestModules", function()
    local src = source
    TriggerClientEvent("smartcar:initialModules", src, VehicleModules)
end)
