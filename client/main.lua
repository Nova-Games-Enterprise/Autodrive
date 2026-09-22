local App = NGEAutodrive
local C = App.Core
local valid, reason = C.validate(Config)
if not valid then print('[nge_autodrive] Disabled: ' .. reason); return end

local models = {}
for name, enabled in pairs(Config.Vehicles) do
    if enabled then models[GetHashKey(name)] = true end
end
local activeTask = GetHashKey('SCRIPT_TASK_VEHICLE_DRIVE_TO_COORD_LONGRANGE')
local sensors = App.newSensors(Config.Sensor)
local hud = App.newHud(SendNUIMessage, Config.Hud)
local assistance = Config.Safety.Enabled
local context, safety = nil, 'off'
local healthy = true

local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function readContext()
    if IsPauseMenuActive() or IsNuiFocused() then return nil end
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) or not IsPlayerControlOn(PlayerId()) then return nil end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped
        or not models[GetEntityModel(vehicle)] or not IsVehicleDriveable(vehicle, false) then return nil end
    return { ped = ped, vehicle = vehicle, coords = GetEntityCoords(vehicle),
        signedSpeed = GetEntitySpeedVector(vehicle, true).y,
        hasControl = NetworkHasControlOfEntity(vehicle) }
end

local function waypoint()
    if not IsWaypointActive() then return nil end
    local blip = GetFirstBlipInfoId(8)
    if blip == 0 then return nil end
    return GetBlipInfoIdCoord(blip)
end

local controller = App.newController({
    start = function(ped, vehicle, dest, speed, style)
        TaskVehicleDriveToCoordLongrange(ped, vehicle, dest.x, dest.y, dest.z, speed, style, 5.0)
    end,
    stop = function(ped, vehicle)
        -- Never clear an unrelated ped's tasks or take network ownership of a vehicle.
        if ped ~= PlayerPedId() or not DoesEntityExist(ped) or not DoesEntityExist(vehicle)
            or GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
        local status = GetScriptTaskStatus(ped, activeTask)
        if status == 0 or status == 1 then ClearPedTasks(ped) end
    end,
    running = function(ped, vehicle)
        if ped ~= PlayerPedId() or not DoesEntityExist(vehicle)
            or GetVehiclePedIsIn(ped, false) ~= vehicle
            or GetPedInVehicleSeat(vehicle, -1) ~= ped then return false end
        local status = GetScriptTaskStatus(ped, activeTask)
        return status == 0 or status == 1
    end,
    speed = function(ped, speed, vehicle)
        if ped ~= PlayerPedId() or not DoesEntityExist(vehicle)
            or GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped
            or not NetworkHasControlOfEntity(vehicle) then return end
        local status = GetScriptTaskStatus(ped, activeTask)
        if status == 0 or status == 1 then SetDriveTaskCruiseSpeed(ped, speed) end
    end
}, Config.Cruise, Config.Units)

local function snapshot()
    return { visible = context ~= nil, autopilot = controller.state, safety = safety,
        cruiseSpeed = math.floor(controller.speed + 0.5), units = Config.Units,
        reason = controller.reason, audio = Config.Hud.Audio }
end

local function manualInput()
    return IsControlPressed(0, 71) or IsControlPressed(0, 72)
        or math.abs(GetControlNormal(0, 59)) > 0.2
        or math.abs(GetControlNormal(0, 60)) > 0.2
end

local function bind(command, label, key, action)
    RegisterCommand(command, function()
        if not healthy then return end
        context = readContext()
        if not context or not context.hasControl or IsPauseMenuActive() or IsNuiFocused() then return end
        action()
    end, false)
    RegisterKeyMapping(command, label, 'keyboard', key)
end

bind('nge_ad_toggle', 'NGE Autodrive: toggle waypoint drive', Config.Keys.Toggle, function()
    local sample = sensors:update(assistance and Config.Safety.Enabled and context or nil, GetGameTimer())
    safety = C.classify(context.signedSpeed, sample, Config.Safety, assistance)
    local ok, why = controller:start(context, waypoint(), GetGameTimer(), safety)
    if not ok then notify('NGE Autodrive: ' .. why:gsub('_', ' ')) end
end)
bind('nge_ad_assistance', 'NGE Autodrive: toggle collision assistance', Config.Keys.Assistance, function()
    assistance = not assistance
    if not assistance then controller:stop('assistance_disabled', 'off') end
    notify('NGE collision assistance: ' .. (assistance and 'ON' or 'OFF'))
end)
bind('nge_ad_faster', 'NGE Autodrive: increase set speed', Config.Keys.Faster, function()
    controller:setSpeed(controller.speed + Config.Cruise.Step)
end)
bind('nge_ad_slower', 'NGE Autodrive: decrease set speed', Config.Keys.Slower, function()
    controller:setSpeed(controller.speed - Config.Cruise.Step)
end)

CreateThread(function()
    while true do
        local ok, failure = xpcall(function()
            local now = GetGameTimer()
            context = readContext()
            if context and not context.hasControl then context = nil end
            local sample = sensors:update(assistance and Config.Safety.Enabled and context or nil, now)
            safety = context and C.classify(context.signedSpeed, sample, Config.Safety, assistance) or 'off'
            controller:tick(context, waypoint(), now, context and manualInput() or false, safety)

            -- Per-frame controls expire naturally. No latched brake/handbrake flags.
            -- Cancel the AI task before requesting any manual brake input.
            if context and math.abs(context.signedSpeed) >= Config.Safety.MinSpeed
                and (safety == 'brake' or safety == 'warning') then
                local backwards = C.direction(context.signedSpeed) == -1
                local brakeControl = backwards and 71 or 72
                local throttleControl = backwards and 72 or 71
                DisableControlAction(0, throttleControl, true)
                SetControlNormal(0, brakeControl, safety == 'brake' and 1.0 or 0.25)
            end
            hud:update(snapshot(), now)
        end, debug.traceback)
        if not ok then
            healthy = false
            pcall(function() controller:stop('runtime_error', 'interrupted') end)
            pcall(function() sensors:reset() end)
            context, safety = nil, 'off'
            pcall(function() hud:update(snapshot(), GetGameTimer(), true) end)
            print('[nge_autodrive] Assistance disabled after runtime error: ' .. tostring(failure))
            return
        end
        Wait(context and 0 or 200)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    healthy = false
    controller:stop('resource_stopped', 'off')
    sensors:reset()
    context, safety = nil, 'off'
    hud:update(snapshot(), GetGameTimer(), true)
end)
